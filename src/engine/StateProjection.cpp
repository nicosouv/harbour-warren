#include "StateProjection.h"
#include "Rng.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <cmath>

namespace warren {

using namespace Balance;

namespace {

double rollUnit(quint64 salt, int counter)
{
    const quint64 r = Rng::mix(salt, static_cast<quint64>(counter) + Q_UINT64_C(0x9E37));
    return (r >> 11) * (1.0 / 9007199254740992.0); // [0, 1)
}

QJsonObject parse(const Event& e)
{
    return QJsonDocument::fromJson(e.payload.toUtf8()).object();
}

double clampd(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }

void reassignWithin(GameState& s)
{
    // Keep worker assignments within the current population.
    int sum = 0;
    for (int j = 0; j < JobCount; ++j)
        sum += s.assigned[j];
    for (int j = JobCount - 1; j >= 0 && sum > s.population; --j) {
        const int cut = sum - s.population < s.assigned[j] ? sum - s.population : s.assigned[j];
        s.assigned[j] -= cut;
        sum -= cut;
    }
}

void advanceStage(GameState& s)
{
    while (s.stage < kStageCount - 1) {
        bool ok = false;
        switch (s.stage) {
        case 0: ok = s.population >= kGatePopulation; break;
        case 1: ok = s.buildingsBuilt >= kGateBuildings; break;
        case 2: ok = s.goldEarned >= kGateGoldEarned; break;
        case 3: ok = s.unitsTrained >= kGateUnitsTrained; break;
        case 4: ok = s.raidsWon >= kGateRaidsWon; break;
        default: ok = false; break;
        }
        if (ok) ++s.stage; else break;
    }
}

} // namespace

int housingCap(const GameState& s)
{
    return kHousingBase + kHousingPerBurrow * s.buildings[Burrow];
}

double foodCap(const GameState& s)
{
    return kFoodCapBase + kFoodCapPerGranary * s.buildings[Granary];
}

double energyCap(const GameState& s)
{
    return kEnergyCapBase + kEnergyCapPerPost * s.buildings[TradingPost];
}

int totalBuildings(const GameState& s)
{
    int n = 0;
    for (int b = 0; b < BldCount; ++b) n += s.buildings[b];
    return n;
}

int totalUnits(const GameState& s)
{
    int n = 0;
    for (int u = 0; u < UnitCount; ++u) n += s.units[u];
    return n;
}

int idleWorkers(const GameState& s)
{
    int a = 0;
    for (int j = 0; j < JobCount; ++j) a += s.assigned[j];
    return s.population - a;
}

double territoryMult(const GameState& s)
{
    return 1.0 + kTerritoryBonus * s.territory;
}

double energyMult(const GameState& s)
{
    // No energy concern until you build a trading post; then it boosts while powered, penalises
    // when the store runs dry.
    if (s.buildings[TradingPost] < 1) return 1.0;
    return s.res[Energy] > 0.0 ? kEnergyBonus : kBlackout;
}

static double bldMult(const GameState& s, int job)
{
    if (job == Forage)  return 1.0 + kForageBonusPerGranary * s.buildings[Granary];
    if (job == Gather)  return 1.0 + kGatherBonusPerWorkshop * s.buildings[Workshop];
    if (job == MineJob) return 1.0 + kMineBonusPerShaft * s.buildings[MineShaft];
    return 1.0;
}

double perWorker(const GameState& s, int job)
{
    if (job < 0 || job >= JobCount) return 0.0;
    return kJobBase[job] * bldMult(s, job) * territoryMult(s) * energyMult(s);
}

double production(const GameState& s, int job)
{
    if (job < 0 || job >= JobCount) return 0.0;
    return s.assigned[job] * perWorker(s, job);
}

double foodConsumption(const GameState& s)
{
    return s.population * kFoodPerPop + totalUnits(s) * kFoodPerUnit;
}

double energyDrain(const GameState& s)
{
    if (s.buildings[TradingPost] < 1) return 0.0;   // only an electrified colony draws power
    return kEnergyPerPop * s.population + kEnergyPerBld * totalBuildings(s);
}

double netFood(const GameState& s)
{
    return production(s, Forage) - foodConsumption(s);
}

double buildCost(const GameState& s, int b, int n)
{
    if (b < 0 || b >= BldCount || n < 1) return 0.0;
    const double r = kBld[b].costGrowth;
    const double first = kBld[b].baseCost * std::pow(r, s.buildings[b]);
    if (n == 1) return first;
    return first * (std::pow(r, n) - 1.0) / (r - 1.0);
}

double armyPower(const GameState& s)
{
    double p = 0.0;
    for (int u = 0; u < UnitCount; ++u) p += s.units[u] * kUnit[u].power;
    return p;
}

bool targetUnlocked(const GameState& s, int t)
{
    return t >= 0 && t < kTargetCount && s.stage >= kTarget[t].unlockStage;
}

qint64 raidCooldownLeft(const GameState& s, int t, qint64 nowMs)
{
    if (s.lastRaidMs == 0) return 0;
    const qint64 readyAt = s.lastRaidMs + kTarget[t].cooldownMs;
    return nowMs >= readyAt ? 0 : readyAt - nowMs;
}

bool raidReady(const GameState& s, int t, qint64 nowMs)
{
    return targetUnlocked(s, t) && totalUnits(s) > 0 && raidCooldownLeft(s, t, nowMs) == 0;
}

void applyEvent(GameState& s, const Event& e, quint64 salt)
{
    const QJsonObject p = parse(e);
    const qint64 at = static_cast<qint64>(p.value(QLatin1String("at")).toDouble());

    if (e.kind == QLatin1String("arrive")) {
        s.arrived = true;
    } else if (e.kind == QLatin1String("tap")) {
        const int n = p.value(QLatin1String("n")).toInt();
        if (n > 0) {
            s.res[Food] = clampd(s.res[Food] + kDigFood * n, 0.0, foodCap(s));
            s.tapsTotal += n;
        }
    } else if (e.kind == QLatin1String("assign")) {
        const int j = p.value(QLatin1String("j")).toInt(-1);
        const int d = p.value(QLatin1String("d")).toInt();
        if (j >= 0 && j < JobCount) {
            int nv = s.assigned[j] + d;
            if (nv < 0) nv = 0;
            const int others = [&]() { int o = 0; for (int k = 0; k < JobCount; ++k) if (k != j) o += s.assigned[k]; return o; }();
            if (nv > s.population - others) nv = s.population - others;
            if (nv < 0) nv = 0;
            s.assigned[j] = nv;
        }
    } else if (e.kind == QLatin1String("build")) {
        // Opens a construction site (one at a time). Builders finish it during ticks.
        const int b = p.value(QLatin1String("b")).toInt(-1);
        if (b >= 0 && b < BldCount && s.stage >= kBld[b].unlockStage && s.siteBld < 0) {
            const double cost = buildCost(s, b, 1);
            if (s.res[Materials] >= cost) {
                s.res[Materials] -= cost;
                s.siteBld = b;
                s.siteProgress = 0.0;
            }
        }
    } else if (e.kind == QLatin1String("buyenergy")) {
        const double amount = p.value(QLatin1String("e")).toDouble();
        if (s.stage >= 2 && s.buildings[TradingPost] >= 1 && amount > 0.0) {
            const double cost = amount * kEnergyPrice;
            if (s.res[Gold] >= cost) {
                s.res[Gold] -= cost;
                s.res[Energy] = clampd(s.res[Energy] + amount, 0.0, energyCap(s));
                s.energyBuys += 1;
            }
        }
    } else if (e.kind == QLatin1String("train")) {
        const int u = p.value(QLatin1String("u")).toInt(-1);
        int n = p.value(QLatin1String("n")).toInt();
        if (n < 1) n = 1;
        if (u >= 0 && u < UnitCount && s.stage >= kUnit[u].unlockStage
            && s.buildings[Barracks] >= 1) {
            const UnitDef& d = kUnit[u];
            const int affordPop = s.population / (d.costPop > 0 ? d.costPop : 1);
            if (n > affordPop) n = affordPop;
            while (n > 0 && (s.res[Gold] < d.costGold * n || s.res[Materials] < d.costMaterials * n))
                --n;
            if (n > 0) {
                s.res[Gold] -= d.costGold * n;
                s.res[Materials] -= d.costMaterials * n;
                s.population -= d.costPop * n;
                s.units[u] += n;
                s.unitsTrained += n;
                reassignWithin(s);
            }
        }
    } else if (e.kind == QLatin1String("raid")) {
        const int t = p.value(QLatin1String("t")).toInt(-1);
        if (targetUnlocked(s, t) && totalUnits(s) > 0
            && (s.lastRaidMs == 0 || at - s.lastRaidMs >= kTarget[t].cooldownMs)) {
            const TargetDef& tg = kTarget[t];
            const int committed = totalUnits(s);
            const double power = armyPower(s) * (1.0 + s.intel[t]);
            const double roll = rollUnit(salt, s.raidCount);
            const double score = (power / tg.defense) * (1.0 - kLuckBand + 2.0 * kLuckBand * roll);
            s.raidCount += 1;

            int outcome;
            double lossFrac;
            if (score >= kDecisiveScore) { outcome = 1; lossFrac = kCasualtyDecisive; }
            else if (score >= kWinScore) { outcome = 2; lossFrac = kCasualtyCostly; }
            else { outcome = 3; lossFrac = kCasualtyDefeat; }

            int losses = static_cast<int>(std::ceil(committed * lossFrac));
            if (losses > committed) losses = committed;
            int rem = losses;
            for (int u = 0; u < UnitCount && rem > 0; ++u) {   // militia fall first
                const int take = rem < s.units[u] ? rem : s.units[u];
                s.units[u] -= take;
                rem -= take;
            }

            if (outcome == 1 || outcome == 2) {
                const double sc = outcome == 1 ? 1.0 : kLootCostlyScale;
                s.res[Gold] += tg.lootGold * sc;
                s.goldEarned += tg.lootGold * sc;
                s.res[Materials] += tg.lootMaterials * sc;
                s.res[Food] = clampd(s.res[Food] + tg.lootFood * sc, 0.0, foodCap(s));
                s.raidsWon += 1;
                if (outcome == 1) s.territory += 1;
            } else {
                s.res[Gold] *= (1.0 - kDefeatLossFrac);
                s.res[Materials] *= (1.0 - kDefeatLossFrac);
                s.intel[t] = clampd(s.intel[t] + kIntelPerDefeat, 0.0, kIntelCap);
                s.raidsLost += 1;
            }
            s.lastRaidMs = at;
            s.lastRaidTarget = t;
            s.lastRaidOutcome = outcome;
            s.lastRaidCommitted = committed;
            s.lastRaidLosses = losses;
        }
    } else if (e.kind == QLatin1String("tick")) {
        qint64 ms = static_cast<qint64>(p.value(QLatin1String("ms")).toDouble());
        if (ms < 0) ms = 0;
        if (ms > kOfflineCapMs) ms = kOfflineCapMs;
        const double secs = ms / 1000.0;

        // Rates from the state at tick start (energy penalty included via perWorker).
        const double food = (production(s, Forage) - foodConsumption(s)) * secs;
        const double mat  = production(s, Gather) * secs;
        const double gold = production(s, MineJob) * secs;

        s.res[Food] = clampd(s.res[Food] + food, 0.0, foodCap(s));
        s.res[Materials] += mat;
        s.res[Gold] += gold;
        if (gold > 0.0) s.goldEarned += gold;

        if (s.stage >= 2)
            s.res[Energy] = clampd(s.res[Energy] - energyDrain(s) * secs, 0.0, energyCap(s));

        // Builders raise the site; the dark slows them like everyone else.
        if (s.siteBld >= 0 && s.assigned[Build] > 0) {
            s.siteProgress += s.assigned[Build] * kJobBase[Build] * energyMult(s) * secs;
            if (s.siteProgress >= kBld[s.siteBld].work) {
                s.buildings[s.siteBld] += 1;
                s.buildingsBuilt += 1;
                s.siteBld = -1;
                s.siteProgress = 0.0;
            }
        }

        // Growth: fed and housed colonies raise a new worker over time.
        if (s.res[Food] > kGrowthFoodFloor && s.population < housingCap(s))
            s.brood += kGrowthRate * secs;
        int grown = static_cast<int>(std::floor(s.brood));
        if (grown > 0) {
            int room = housingCap(s) - s.population;
            if (room < 0) room = 0;
            const int add = grown < room ? grown : room;
            s.population += add;
            s.brood -= grown;
            if (s.brood < 0.0) s.brood = 0.0;
        }
    }

    if (at > s.lastSeenMs) s.lastSeenMs = at;
    advanceStage(s);
}

GameState fold(const QVector<Event>& events, quint64 salt)
{
    GameState s;
    for (int i = 0; i < events.size(); ++i)
        applyEvent(s, events.at(i), salt);
    return s;
}

} // namespace warren
