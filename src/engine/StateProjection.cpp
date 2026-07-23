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

const FactionDef& fac(const GameState& s)
{
    return kFaction[(s.faction >= 0 && s.faction < kFactionCount) ? s.faction : 0];
}

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
    const bool flock = !fac(s).worksLand;   // raid-driven progression instead of build-driven
    while (s.stage < kStageCount - 1) {
        bool ok = false;
        if (flock) {
            switch (s.stage) {
            case 0: ok = s.population >= kStartPopulation; break;  // raids open at stage 1
            case 1: ok = s.raidsWon >= 1; break;
            case 2: ok = s.goldEarned >= kGateGoldEarned; break;
            case 3: ok = s.territory >= 1; break;
            case 4: ok = s.raidsWon >= 3; break;
            default: ok = false; break;
            }
        } else {
            switch (s.stage) {
            case 0: ok = s.population >= kGatePopulation; break;
            case 1: ok = s.buildingsBuilt >= kGateBuildings; break;
            case 2: ok = s.goldEarned >= kGateGoldEarned; break;
            case 3: ok = s.unitsTrained >= kGateUnitsTrained; break;
            case 4: ok = s.raidsWon >= kGateRaidsWon; break;
            default: ok = false; break;
            }
        }
        if (ok) ++s.stage; else break;
    }
}

void expireModifiers(GameState& s, qint64 at)
{
    if (s.modProdUntil > 0 && at >= s.modProdUntil) { s.modProdFactor = 1.0; s.modProdUntil = 0; }
    if (s.modDrainUntil > 0 && at >= s.modDrainUntil) { s.modDrainFactor = 1.0; s.modDrainUntil = 0; }
    for (int j = 0; j < JobCount; ++j)
        if (s.modJobUntil[j] > 0 && at >= s.modJobUntil[j]) { s.modJob[j] = 1.0; s.modJobUntil[j] = 0; }
}

// Resolve the player's choice for an event. opt 0 = first button, 1 = second. Magnitudes rise
// gently with the event's escalation level.
void applyEventChoice(GameState& s, int ev, int opt, qint64 at, quint64 salt)
{
    const int lvl = s.eventLevel[ev];
    const double scale = 1.0 + 0.5 * lvl;
    switch (ev) {
    case EvStorm:
        if (opt == 0) {                     // repair now (damage was set when the storm fired)
            const double cost = 40.0 * scale;
            if (s.res[Materials] >= cost) { s.res[Materials] -= cost; s.damaged = 0; }
        }
        break;
    case EvRats:
        if (opt == 0) {
            const double cost = 30.0 * scale;
            if (s.res[Materials] >= cost) s.res[Materials] -= cost;
            else s.res[Food] *= (1.0 - kRatsFoodLoss);
        } else {
            s.res[Food] *= (1.0 - kRatsFoodLoss);
        }
        break;
    case EvWanderer:
        if (opt == 0 && s.population < housingCap(s)) s.population += 1;
        break;
    case EvRain:
        if (opt == 0) { s.modProdFactor = 0.85; s.modProdUntil = at + kModShortMs; }
        else { s.modProdFactor = 0.2; s.modProdUntil = at + Q_INT64_C(1200000); }
        break;
    case EvMerchant:
        if (opt == 0) {
            const double sold = s.res[Food] * kMerchantSell;
            s.res[Food] -= sold;
            s.res[Gold] += sold * kMerchantRate;
            s.goldEarned += sold * kMerchantRate;
        }
        break;
    case EvTransformer:
        if (opt == 0) {
            const double cost = 60.0 * scale;
            if (s.res[Gold] >= cost) s.res[Gold] -= cost;
            else { s.modDrainFactor = 2.0; s.modDrainUntil = at + kModShortMs; }
        } else { s.modDrainFactor = 2.0; s.modDrainUntil = at + kModShortMs; }
        break;
    case EvCollapse:
        if (opt == 0) {
            const double cost = 80.0 * scale;
            if (s.res[Materials] >= cost) s.res[Materials] -= cost;
            else if (s.population > 1) s.population -= 1;
        } else if (s.population > 1) {
            s.population -= 1;
        }
        break;
    case EvTax:
        if (opt == 0) {
            s.res[Gold] *= (1.0 - kTaxGoldFrac * scale);
        } else {
            const double roll = (Rng::mix(salt, static_cast<quint64>(at)) % 100) / 100.0;
            if (roll < 0.5) s.res[Gold] *= (1.0 - 2.0 * kTaxGoldFrac * scale);
        }
        break;
    case EvScouts:
        if (opt == 0) {
            const double cost = 40.0 * scale;
            if (s.res[Gold] >= cost) s.res[Gold] -= cost;
        } else {
            const double roll = (Rng::mix(salt, static_cast<quint64>(at) ^ Q_UINT64_C(0x5c)) % 100) / 100.0;
            if (roll < 0.5) {
                s.res[Gold] *= (1.0 - kScoutsLoss);
                s.res[Food] *= (1.0 - kScoutsLoss);
            }
        }
        break;
    case EvFeast:
        if (opt == 0) {
            s.res[Food] *= (1.0 - kFeastFoodCost);
            s.modProdFactor = kFeastProd; s.modProdUntil = at + kModFeastMs;
        } else {
            s.modProdFactor = kFeastRefusePenalty; s.modProdUntil = at + kModShortMs;
        }
        break;
    case EvCounterRaid: {
        // The foxes strike back. Their force grows with the territory you have taken from them.
        const double force = kCounterBaseForce * (1.0 + kCounterForcePerTerr * s.territory) * scale;
        if (opt == 0) {                     // stand and defend
            const double defense = garrisonDefense(s);
            const double roll = rollUnit(salt, static_cast<int>(at) ^ 0x1d3f);
            const double score = (defense / force) * (1.0 - kLuckBand + 2.0 * kLuckBand * roll);
            const bool won = score >= kWinScore;
            const double frac = won ? kCounterCasualtyWin : kCounterCasualtyLoss;
            int losses = static_cast<int>(std::ceil(totalUnits(s) * frac));
            if (losses > totalUnits(s)) losses = totalUnits(s);
            for (int u = 0; u < UnitCount && losses > 0; ++u) {   // militia fall first
                const int take = losses < s.units[u] ? losses : s.units[u];
                s.units[u] -= take; losses -= take;
            }
            if (won) {
                s.counterWins += 1;
            } else {
                s.res[Gold] *= (1.0 - kCounterPillageFrac);
                s.res[Materials] *= (1.0 - kCounterPillageFrac);
            }
            s.lastEventResult = won ? 1 : 2;
        } else {                            // pay them off
            s.res[Gold] *= (1.0 - kCounterTributeFrac * scale);
            s.lastEventResult = 0;
        }
        break;
    }
    case EvExodus:
        if (opt == 0) {                     // take the newcomers in, up to housing
            int room = housingCap(s) - s.population;
            if (room < 0) room = 0;
            s.population += room < 3 ? room : 3;
        }
        break;
    case EvWoundedVet:
        if (opt == 0) {                     // patch him up
            const double cost = 30.0 * scale;
            if (s.res[Food] >= cost) s.res[Food] -= cost;
        } else if (s.units[Veteran] > 0) {  // reform him back into the workforce
            s.units[Veteran] -= 1;
            s.population += 1;
        }
        break;
    case EvCult:
        if (opt == 0) {                     // fund the tunnel-diggers
            const double cost = 60.0 * scale;
            if (s.res[Gold] >= cost) {
                s.res[Gold] -= cost;
                s.modProdFactor = 1.15; s.modProdUntil = at + kModFeastMs;
            }
        } else {                            // ban it
            s.modProdFactor = 0.9; s.modProdUntil = at + kModShortMs;
        }
        break;
    case EvWolves:
        if (opt == 0) {                     // send the army to chase them off
            const double cost = 20.0 * scale;
            if (s.res[Food] >= cost) s.res[Food] -= cost;
        } else {                            // ration through the winter
            s.res[Food] *= 0.7;
            s.modProdFactor = 0.8; s.modProdUntil = at + kModFeastMs;
        }
        break;
    case EvMinerStrike:
        if (opt == 0) {                     // pay the bonus
            const double cost = 50.0 * scale;
            if (s.res[Gold] >= cost) s.res[Gold] -= cost;
        } else {                            // hold firm: the mine stops for two hours
            s.modJob[MineJob] = 0.0; s.modJobUntil[MineJob] = at + kModFeastMs;
        }
        break;
    case EvCaveIn:
        if (opt == 0) {                     // clear the entrance
            const double cost = 30.0 * scale;
            if (s.res[Materials] >= cost) s.res[Materials] -= cost;
        } else {                            // take the other hole: foraging slows for an hour
            s.modJob[Forage] = 0.75; s.modJobUntil[Forage] = at + kModShortMs;
        }
        break;
    case EvVein:
        if (opt == 0)                       // dig greedily: the mine doubles for half an hour
            { s.modJob[MineJob] = 2.0; s.modJobUntil[MineJob] = at + Q_INT64_C(1800000); }
        else                                // shore it up first: a safe modest payout
            { s.res[Gold] += 40.0 * scale; s.goldEarned += 40.0 * scale; }
        break;
    case EvDeserter:
        if (opt == 0) {                     // listen: intel on the toughest target you can reach
            int best = -1;
            for (int tt = 0; tt < kTargetCount; ++tt) if (targetUnlocked(s, tt)) best = tt;
            if (best >= 0) s.intel[best] = clampd(s.intel[best] + kIntelPerDefeat, 0.0, kIntelCap);
        }
        break;
    case EvPrisoners:
        if (opt == 0)                       // ransom them
            { s.res[Gold] += 120.0 * scale; s.goldEarned += 120.0 * scale; }
        else                                // release them: a little intel on every known target
            for (int tt = 0; tt < kTargetCount; ++tt)
                if (targetUnlocked(s, tt)) s.intel[tt] = clampd(s.intel[tt] + 0.08, 0.0, kIntelCap);
        break;
    case EvCrate:
        if (opt == 0) {                     // pry it open: fortune or regret
            const double roll = rollUnit(salt, static_cast<int>(at) ^ 0x3c7);
            if (roll < 0.5) { s.res[Gold] += 300.0 * scale; s.goldEarned += 300.0 * scale; }
            else s.res[Gold] *= 0.9;
        } else                              // sell it sealed, mystery included
            { s.res[Gold] += 90.0 * scale; s.goldEarned += 90.0 * scale; }
        break;
    // --- Arcs: once-per-game set pieces with distinctive payoffs. ------------------------------
    case EvArcFoxWar:
        s.arcDone[0] = true;
        if (opt == 0) {                     // the battle of the hill
            const double force = kCounterBaseForce * (1.0 + kCounterForcePerTerr * s.territory) * 2.5;
            const double roll = rollUnit(salt, static_cast<int>(at) ^ 0x7a11);
            const double score = (garrisonDefense(s) / force)
                               * (1.0 - kLuckBand + 2.0 * kLuckBand * roll);
            if (score >= kWinScore) {       // the fox tribute: territory and intel
                s.territory += 2;
                for (int tt = 0; tt < kTargetCount; ++tt)
                    if (targetUnlocked(s, tt)) s.intel[tt] = clampd(s.intel[tt] + 0.2, 0.0, kIntelCap);
                s.lastEventResult = 1;
            } else {
                s.res[Gold] *= 0.75; s.res[Materials] *= 0.75;
                s.lastEventResult = 2;
            }
        } else {                            // pay them off
            s.res[Gold] *= 0.8;
            s.lastEventResult = 0;
        }
        break;
    case EvArcRiver:
        s.arcDone[1] = true;
        if (opt == 0) {                     // drain it: safe, sure
            const double cost = 120.0;
            if (s.res[Materials] >= cost) s.res[Materials] -= cost;
        } else {                            // channel it: the watermill, or a lost gallery
            const double cost = 260.0;
            if (s.res[Materials] >= cost) {
                s.res[Materials] -= cost;
                const double roll = rollUnit(salt, static_cast<int>(at) ^ 0x21f5);
                if (roll < 0.6) { s.buildings[Watermill] += 1; s.buildingsBuilt += 1; }
                else if (s.buildings[MineShaft] > 0) s.buildings[MineShaft] -= 1;
            }
        }
        break;
    case EvArcElder:
        s.arcDone[2] = true;
        if (opt == 0) {                     // follow the clues to the founder's cache
            const double cost = 60.0;
            if (s.res[Gold] >= cost) {
                s.res[Gold] -= cost;
                s.res[Gold] += 500.0; s.goldEarned += 500.0;
                s.res[Materials] += 300.0;
                s.territory += 1;
            }
        }
        break;
    default: break;
    }
}

} // namespace

bool bldDamaged(const GameState& s, int b)
{
    return (s.damaged & (1u << b)) != 0;
}

int housingCap(const GameState& s)
{
    // No buildings? Housing comes from the ground you hold, not from burrows (magpie roosts widen).
    if (!fac(s).canBuild)
        return kMagpieHousingBase + kMagpieHousingPerTerr * s.territory;
    return kHousingBase + kHousingPerBurrow * (bldDamaged(s, Burrow) ? 0 : s.buildings[Burrow]);
}

double foodCap(const GameState& s)
{
    return kFoodCapBase + kFoodCapPerGranary * (bldDamaged(s, Granary) ? 0 : s.buildings[Granary]);
}

double energyCap(const GameState& s)
{
    return kEnergyCapBase + kEnergyCapPerPost * (bldDamaged(s, TradingPost) ? 0 : s.buildings[TradingPost]);
}

bool canBuild(const GameState& s) { return fac(s).canBuild; }
bool worksLand(const GameState& s) { return fac(s).worksLand; }

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

double watermillMult(const GameState& s)
{
    return 1.0 + kWatermillProdBonus * (bldDamaged(s, Watermill) ? 0 : s.buildings[Watermill]);
}

double garrisonDefense(const GameState& s)
{
    return armyPower(s)
         + kWatchtowerDefense * (bldDamaged(s, Watchtower) ? 0 : s.buildings[Watchtower]);
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
    if (job == Forage)  return 1.0 + kForageBonusPerGranary * (bldDamaged(s, Granary) ? 0 : s.buildings[Granary]);
    if (job == Gather)  return 1.0 + kGatherBonusPerWorkshop * (bldDamaged(s, Workshop) ? 0 : s.buildings[Workshop]);
    if (job == MineJob) return 1.0 + kMineBonusPerShaft * (bldDamaged(s, MineShaft) ? 0 : s.buildings[MineShaft]);
    return 1.0;
}

double perWorker(const GameState& s, int job)
{
    if (job < 0 || job >= JobCount) return 0.0;
    // Factions that do not work the land loot their materials and gold instead of producing them.
    if (!fac(s).worksLand && (job == Gather || job == MineJob)) return 0.0;
    return kJobBase[job] * bldMult(s, job) * territoryMult(s) * watermillMult(s)
         * energyMult(s) * s.modProdFactor * s.modJob[job];
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
    return (kEnergyPerPop * s.population + kEnergyPerBld * totalBuildings(s)) * s.modDrainFactor;
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

// Unit prices climb with the size of the standing army, so gold and materials never just pile up.
double unitCostGold(const GameState& s, int u)
{
    if (u < 0 || u >= UnitCount) return 0.0;
    return kUnit[u].costGold * std::pow(kUnit[u].costGrowth, s.units[u]);
}
double unitCostMaterials(const GameState& s, int u)
{
    if (u < 0 || u >= UnitCount) return 0.0;
    return kUnit[u].costMaterials * std::pow(kUnit[u].costGrowth, s.units[u]);
}

double armyPower(const GameState& s)
{
    // The whole flock raids: a faction without a standing army throws its numbers at the target.
    if (!fac(s).worksLand) return s.population * kMagpiePowerPerBird;
    double p = 0.0;
    for (int u = 0; u < UnitCount; ++u) p += s.units[u] * kUnit[u].power;
    return p;
}

// Bodies committed to a raid: soldiers for an army faction, the flock itself otherwise.
int raidForce(const GameState& s)
{
    return fac(s).worksLand ? totalUnits(s) : s.population;
}

bool targetUnlocked(const GameState& s, int t)
{
    if (t < 0 || t >= kTargetCount) return false;
    // Raiding is the magpie's core loop, not a late unlock: targets open far earlier for them.
    const int gate = fac(s).worksLand ? kTarget[t].unlockStage
                                      : (t <= 1 ? 1 : t <= 2 ? 2 : t <= 3 ? 3 : t <= 4 ? 4 : 5);
    return s.stage >= gate;
}

qint64 raidCooldownLeft(const GameState& s, int t, qint64 nowMs)
{
    if (s.lastRaidMs == 0) return 0;
    const qint64 readyAt = s.lastRaidMs + kTarget[t].cooldownMs;
    return nowMs >= readyAt ? 0 : readyAt - nowMs;
}

bool raidReady(const GameState& s, int t, qint64 nowMs)
{
    return targetUnlocked(s, t) && raidForce(s) > 0 && raidCooldownLeft(s, t, nowMs) == 0;
}

bool eventEligible(const GameState& s, int ev, qint64 nowMs)
{
    if (ev < 0 || ev >= EventCount) return false;
    const EventDef& d = kEvent[ev];
    if (d.tier == 1 && s.stage < 1) return false;
    if (d.tier == 2 && s.stage < 2) return false;
    if (d.tier == 3 && s.stage < 4) return false;
    if (d.tier == 4 && s.stage < 5) return false;
    // Watchtowers keep the foxes at bay: each one stretches the counter-raid cooldown.
    qint64 cd = d.cooldownMs;
    if (ev == EvCounterRaid)
        cd = static_cast<qint64>(cd * (1.0 + kWatchtowerCdBonus * s.buildings[Watchtower]));
    if (s.eventLastMs[ev] > 0 && nowMs - s.eventLastMs[ev] < cd) return false;
    switch (ev) {
    case EvStorm:       return totalBuildings(s) >= 4 && s.damaged == 0;
    case EvRats:        return s.res[Food] > 20.0;
    case EvWanderer:    return true;
    case EvRain:        return s.assigned[Forage] > 0;
    case EvMerchant:    return s.buildings[TradingPost] >= 1 && s.res[Food] > 15.0;
    case EvTransformer: return s.buildings[TradingPost] >= 1;
    case EvCollapse:    return s.buildings[MineShaft] >= 1;
    case EvTax:         return s.goldEarned > 500.0;
    case EvScouts:      return s.raidsWon >= 1;
    case EvCounterRaid: return s.territory >= 1;   // provoked by taking their ground
    case EvExodus:      return s.population < housingCap(s);   // needs room to welcome them
    case EvWoundedVet:  return s.units[Veteran] >= 1;
    case EvCult:        return s.population >= 15;
    case EvWolves:      return true;
    case EvMinerStrike: return s.buildings[MineShaft] >= 1;
    case EvCaveIn:      return totalBuildings(s) >= 2;
    case EvVein:        return s.buildings[MineShaft] >= 1;
    case EvDeserter:    return s.raidsWon >= 1;
    case EvPrisoners:   return s.raidsWon >= 1;
    case EvCrate:       return s.raidsWon >= 1;
    case EvArcFoxWar:   return !s.arcDone[0] && s.counterWins >= 3;
    case EvArcRiver:    return !s.arcDone[1] && s.buildings[MineShaft] >= 5;
    case EvArcElder:    return !s.arcDone[2] && s.raidsWon >= 2;
    case EvFeast:       return s.population >= 12 && s.res[Food] > foodCap(s) * 0.5;
    default:            return false;
    }
}

int rollEvent(const GameState& s, quint64 salt, qint64 nowMs)
{
    if (s.eventActive >= 0) return -1;
    if (s.lastEventMs > 0 && nowMs - s.lastEventMs < kEventGlobalCd) return -1;
    const qint64 window = nowMs / Q_INT64_C(300000);   // one roll per ~5-minute window
    const double roll = rollUnit(salt, static_cast<int>(window) ^ (s.eventsSeen * 131));
    if (roll >= kEventChance) return -1;
    int cands[EventCount]; int n = 0;
    for (int e = 0; e < EventCount; ++e) if (eventEligible(s, e, nowMs)) cands[n++] = e;
    if (n == 0) return -1;
    const quint64 pick = Rng::mix(salt, static_cast<quint64>(window) + Q_UINT64_C(777));
    return cands[pick % static_cast<quint64>(n)];
}

void applyEvent(GameState& s, const Event& e, quint64 salt)
{
    const QJsonObject p = parse(e);
    const qint64 at = static_cast<qint64>(p.value(QLatin1String("at")).toDouble());

    expireModifiers(s, at);

    if (e.kind == QLatin1String("arrive")) {
        s.arrived = true;
        const int f = p.value(QLatin1String("faction")).toInt(0);
        if (f >= 0 && f < kFactionCount) s.faction = f;
    } else if (e.kind == QLatin1String("event")) {
        const int ev = p.value(QLatin1String("ev")).toInt(-1);
        if (ev >= 0 && ev < EventCount && s.eventActive < 0) {
            s.eventActive = ev;
            if (ev == EvStorm) {   // the storm tears a roof the moment it arrives
                int built[BldCount]; int nb = 0;
                for (int b = 0; b < BldCount; ++b) if (s.buildings[b] > 0) built[nb++] = b;
                if (nb > 0) {
                    const int idx = static_cast<int>(
                        Rng::mix(salt, static_cast<quint64>(at)) % static_cast<quint64>(nb));
                    s.damaged |= (1u << built[idx]);
                }
            }
        }
    } else if (e.kind == QLatin1String("choose")) {
        const int ev = p.value(QLatin1String("ev")).toInt(-1);
        const int opt = p.value(QLatin1String("opt")).toInt(0);
        if (ev >= 0 && ev < EventCount && s.eventActive == ev) {
            applyEventChoice(s, ev, opt, at, salt);
            s.eventActive = -1;
            s.eventsSeen += 1;
            s.lastEventMs = at;
            s.eventLastMs[ev] = at;
            s.eventLevel[ev] += 1;
        }
    } else if (e.kind == QLatin1String("repairbld")) {
        const int b = p.value(QLatin1String("b")).toInt(-1);
        if (b >= 0 && b < BldCount && bldDamaged(s, b) && s.res[Materials] >= 40.0) {
            s.res[Materials] -= 40.0;
            s.damaged &= ~(1u << b);
        }
    } else if (e.kind == QLatin1String("tap")) {
        const int n = p.value(QLatin1String("n")).toInt();
        for (int i = 0; i < n; ++i) {
            if (s.stage >= 1 && (s.tapsTotal % 4) == 3)
                s.res[Materials] += kDigMat;                 // an apple's worth of luck: kindling
            else
                s.res[Food] = clampd(s.res[Food] + kDigFood, 0.0, foodCap(s));
            s.tapsTotal += 1;
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
        if (canBuild(s) && b >= 0 && b < BldCount && s.stage >= kBld[b].unlockStage && s.siteBld < 0) {
            const double cost = buildCost(s, b, 1);
            if (s.res[Materials] >= cost) {
                s.res[Materials] -= cost;
                s.siteBld = b;
                s.siteProgress = 0.0;
            }
        }
    } else if (e.kind == QLatin1String("cancelbuild")) {
        // Abandon the site and hand back half the materials; the rest is a lesson.
        if (s.siteBld >= 0) {
            s.res[Materials] += 0.5 * buildCost(s, s.siteBld, 1);
            s.siteBld = -1;
            s.siteProgress = 0.0;
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
            // Buy them one at a time: each soldier costs more than the last (army-size scaling).
            int made = 0;
            for (int k = 0; k < n; ++k) {
                const double cg = unitCostGold(s, u), cm = unitCostMaterials(s, u);
                if (s.population < d.costPop || s.res[Gold] < cg || s.res[Materials] < cm) break;
                s.res[Gold] -= cg;
                s.res[Materials] -= cm;
                s.population -= d.costPop;
                s.units[u] += 1;
                s.unitsTrained += 1;
                ++made;
            }
            if (made > 0)
                reassignWithin(s);
        }
    } else if (e.kind == QLatin1String("raid")) {
        const int t = p.value(QLatin1String("t")).toInt(-1);
        if (targetUnlocked(s, t) && raidForce(s) > 0
            && (s.lastRaidMs == 0 || at - s.lastRaidMs >= kTarget[t].cooldownMs)) {
            const TargetDef& tg = kTarget[t];
            const bool flock = !fac(s).worksLand;
            const int committed = raidForce(s);

            // A raiding flock spends stamina; an empty pool sends them out at half strength.
            double staminaFactor = 1.0;
            if (flock) {
                if (s.res[Energy] >= kStaminaRaidCost) s.res[Energy] -= kStaminaRaidCost;
                else { s.res[Energy] = 0.0; staminaFactor = kStaminaLowFactor; }
            }
            const double power = armyPower(s) * staminaFactor * (1.0 + s.intel[t]);
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
            if (flock) {                       // birds fall from the flock, never the last one
                int take = losses;
                if (take > s.population - 1) take = s.population - 1;
                if (take < 0) take = 0;
                s.population -= take;
                losses = take;
                reassignWithin(s);
            } else {
                int rem = losses;
                for (int u = 0; u < UnitCount && rem > 0; ++u) {   // militia fall first
                    const int take = rem < s.units[u] ? rem : s.units[u];
                    s.units[u] -= take;
                    rem -= take;
                }
            }

            if (outcome == 1 || outcome == 2) {
                const double sc = outcome == 1 ? 1.0 : kLootCostlyScale;
                s.res[Gold] += tg.lootGold * sc;
                s.goldEarned += tg.lootGold * sc;
                s.res[Materials] += tg.lootMaterials * sc;
                s.res[Food] = clampd(s.res[Food] + tg.lootFood * sc, 0.0, foodCap(s));
                s.raidsWon += 1;
                if (outcome == 1) s.territory += 1;
                if (flock) {                   // recruits swell the flock, up to the roost's room
                    int room = housingCap(s) - s.population;
                    if (room < 0) room = 0;
                    s.population += kMagpieRecruitPerWin < room ? kMagpieRecruitPerWin : room;
                }
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

        // The res[Energy] slot: energy that drains for builders, or stamina that rests back for
        // raiders. A resting flock refills its stamina; a powered colony spends its energy.
        if (fac(s).recharge == RMStamina)
            s.res[Energy] = clampd(s.res[Energy] + kStaminaRegenPerSec * secs, 0.0, kStaminaCap);
        else if (s.stage >= 2)
            s.res[Energy] = clampd(s.res[Energy] - energyDrain(s) * secs, 0.0, energyCap(s));

        // Builders raise the site; the dark slows them like everyone else.
        if (s.siteBld >= 0 && s.assigned[Build] > 0) {
            s.siteProgress += s.assigned[Build] * kJobBase[Build] * energyMult(s) * secs;
            if (s.siteProgress >= kBld[s.siteBld].work) {
                s.buildings[s.siteBld] += 1;
                s.buildingsBuilt += 1;
                if (s.siteBld == TradingPost && s.buildings[TradingPost] == 1)
                    s.res[Energy] = clampd(s.res[Energy] + kEnergyGift, 0.0, energyCap(s));
                s.siteBld = -1;
                s.siteProgress = 0.0;
            }
        }

        // Growth: fed and housed colonies breed a new worker over time. Non-breeding factions
        // (magpies) grow only by recruiting on raids, so they never accrue brood here.
        if (fac(s).breeds && s.res[Food] > kGrowthFoodFloor && s.population < housingCap(s))
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
