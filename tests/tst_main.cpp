// Engine unit tests + a headless simulation of the staged progression. Pure fold, so everything
// is asserted by folding hand-built event vectors. Runs against plain Qt5 (no Sailfish SDK).
#include <QtTest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QPair>
#include <QVector>
#include <cmath>
#include <initializer_list>

#include "engine/Balance.h"
#include "engine/EventStore.h"
#include "engine/GameState.h"
#include "engine/Rng.h"
#include "engine/StateProjection.h"

using namespace warren;
using namespace warren::Balance;

namespace {

const quint64 kSalt = Q_UINT64_C(0xA5A5A5A5DEADBEEF);

QString json(std::initializer_list<QPair<QString, QJsonValue>> pairs)
{
    QJsonObject o;
    for (const auto& p : pairs) o.insert(p.first, p.second);
    return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

Event ev(const QString& kind, const QString& payload)
{
    Event e; e.kind = kind; e.payload = payload; return e;
}

Event arrive(qint64 at = 1000) { return ev("arrive", json({{"at", double(at)}})); }
Event arriveF(int f, qint64 at = 1000) { return ev("arrive", json({{"faction", f}, {"at", double(at)}})); }
Event tap(int n, qint64 at = 1000) { return ev("tap", json({{"n", n}, {"at", double(at)}})); }
Event assign(int j, int d, qint64 at = 1000) { return ev("assign", json({{"j", j}, {"d", d}, {"at", double(at)}})); }
Event build(int b, qint64 at = 1000) { return ev("build", json({{"b", b}, {"n", 1}, {"at", double(at)}})); }
Event buyenergy(double e, qint64 at) { return ev("buyenergy", json({{"e", e}, {"at", double(at)}})); }
Event train(int u, int n, qint64 at) { return ev("train", json({{"u", u}, {"n", n}, {"at", double(at)}})); }
Event raidEv(int t, qint64 at) { return ev("raid", json({{"t", t}, {"at", double(at)}})); }
Event tick(qint64 ms, qint64 at) { return ev("tick", json({{"ms", double(ms)}, {"active", true}, {"at", double(at)}})); }

} // namespace

class TstWarren : public QObject
{
    Q_OBJECT
private slots:
    void rngDeterminism();
    void storeRoundtrip();
    void foldTapAndArrive();
    void foldAssignClamped();
    void foldBuildCostAndGate();
    void foldStageAdvance();
    void foldEnergyAndBlackout();
    void foldGrowth();
    void foldTrainCosts();
    void foldRaidGradient();
    void foldReplayDeterministic();
    void simulationProgression();
    void energySustainability();
    void foldMagpieEconomy();
    void foldMagpieRaid();
};

void TstWarren::rngDeterminism()
{
    Rng a(42), b(42);
    for (int i = 0; i < 100; ++i) QCOMPARE(a.next(), b.next());
    QCOMPARE(Rng::mix(1, 2), Rng::mix(1, 2));
    QVERIFY(Rng::mix(1, 2) != Rng::mix(2, 1));
}

void TstWarren::storeRoundtrip()
{
    EventStore store(QStringLiteral("t_rt"));
    QVERIFY(store.open(QStringLiteral(":memory:")));
    QVERIFY(store.bootstrap(kSalt));
    QCOMPARE(store.installSalt(), kSalt);
    QVERIFY(store.appendEvent("tap", 123, "{\"n\":1}") > 0);
    QCOMPARE(store.events().size(), 1);
    QVERIFY(store.clearAll());
    QCOMPARE(store.eventCount(), 0);
    QCOMPARE(store.installSalt(), kSalt);   // salt survives a wipe
}

void TstWarren::foldTapAndArrive()
{
    QVector<Event> v;
    v << arrive() << tap(5);
    GameState s = fold(v, kSalt);
    QVERIFY(s.arrived);
    QCOMPARE(s.res[Food], kStartFood + 5 * kDigFood);
}

void TstWarren::foldAssignClamped()
{
    QVector<Event> v;
    v << arrive() << assign(Forage, 100);   // only kStartPopulation workers exist
    GameState s = fold(v, kSalt);
    QCOMPARE(s.assigned[Forage], kStartPopulation);
    QCOMPARE(idleWorkers(s), 0);
    v << assign(Forage, -2);
    s = fold(v, kSalt);
    QCOMPARE(s.assigned[Forage], kStartPopulation - 2);
}

void TstWarren::foldBuildCostAndGate()
{
    // Stage 0 cannot build (buildings unlock at stage 1).
    QVector<Event> v;
    v << arrive();
    v << ev("tick", json({{"ms", 200000.0}, {"active", true}, {"at", 2000.0}})); // some materials? none yet
    // give materials by forcing stage 1 first: grow population to 6 via a big fed tick
    // (assign foragers, tick)
    v.clear();
    v << arrive() << assign(Forage, kStartPopulation) << tap(200) << tick(600000, 700000);
    GameState s = fold(v, kSalt);
    QVERIFY(s.stage >= 1);                       // grew to >=6 and advanced

    // now gather materials and open a construction site
    v << assign(Gather, 3) << tick(600000, 1400000);
    s = fold(v, kSalt);
    QVERIFY(s.res[Materials] > kBld[Burrow].baseCost);
    const double before = s.res[Materials];
    v << build(Burrow, 1500000);
    s = fold(v, kSalt);
    QCOMPARE(s.buildings[Burrow], 0);            // paid, but not built yet
    QCOMPARE(s.siteBld, int(Burrow));
    QVERIFY(s.res[Materials] < before);

    // a second site cannot open while one is active
    const double mats = s.res[Materials];
    v << build(Granary, 1500001);
    s = fold(v, kSalt);
    QCOMPARE(s.siteBld, int(Burrow));
    QCOMPARE(s.res[Materials], mats);

    // no builders, no progress
    v << tick(300000, 1800000);
    s = fold(v, kSalt);
    QCOMPARE(s.buildings[Burrow], 0);

    // builders finish it
    v << assign(Forage, -2, 1800001) << assign(Build, 2, 1800002) << tick(300000, 2100000);
    s = fold(v, kSalt);
    QCOMPARE(s.buildings[Burrow], 1);
    QCOMPARE(s.siteBld, -1);
}

void TstWarren::foldStageAdvance()
{
    // Each gate advances exactly one stage; any event runs the check.
    GameState s;
    s.arrived = true;
    s.population = kGatePopulation;
    applyEvent(s, tap(0, 5000), kSalt);
    QCOMPARE(s.stage, 1);
    s.buildingsBuilt = kGateBuildings;
    applyEvent(s, tap(0, 6000), kSalt);
    QCOMPARE(s.stage, 2);
    s.goldEarned = kGateGoldEarned;
    applyEvent(s, tap(0, 7000), kSalt);
    QCOMPARE(s.stage, 3);
    s.unitsTrained = kGateUnitsTrained;
    applyEvent(s, tap(0, 8000), kSalt);
    QCOMPARE(s.stage, 4);
    s.raidsWon = kGateRaidsWon;
    applyEvent(s, tap(0, 9000), kSalt);
    QCOMPARE(s.stage, 5);
}

void TstWarren::foldEnergyAndBlackout()
{
    // Energy is optional infrastructure: nothing until a trading post, then boost vs blackout.
    GameState s;
    s.stage = 2;
    s.population = 6;
    s.assigned[Forage] = 6;
    QCOMPARE(energyMult(s), 1.0);                 // no trading post yet
    QCOMPARE(energyDrain(s), 0.0);
    s.buildings[TradingPost] = 1;
    QCOMPARE(energyMult(s), kBlackout);           // electrified but empty
    QVERIFY(energyDrain(s) > 0.0);
    s.res[Energy] = 50.0;
    QCOMPARE(energyMult(s), kEnergyBonus);        // powered
}

void TstWarren::foldGrowth()
{
    QVector<Event> v;
    v << arrive() << assign(Forage, kStartPopulation) << tap(100) << tick(1200000, 2000000);
    GameState s = fold(v, kSalt);
    QVERIFY(s.population > kStartPopulation);     // fed and housed -> grew
    QVERIFY(s.population <= housingCap(s));
}

void TstWarren::foldTrainCosts()
{
    GameState s;
    s.stage = 3;
    s.buildings[Barracks] = 1;
    s.population = 10;
    s.res[Gold] = 1000;
    s.res[Materials] = 1000;
    Event t = train(Militia, 2, 5000);
    applyEvent(s, t, kSalt);
    QCOMPARE(s.units[Militia], 2);
    QCOMPARE(s.unitsTrained, 2);
    QCOMPARE(s.population, 8);                    // two workers became soldiers
    // Prices climb per unit: first at base, second dearer by costGrowth.
    const double expGold = 1000 - kUnit[Militia].costGold * (1.0 + kUnit[Militia].costGrowth);
    QVERIFY(std::fabs(s.res[Gold] - expGold) < 1e-6);
}

void TstWarren::foldRaidGradient()
{
    // A strong army against a weak target: a win. Deterministic given salt + raid counter.
    GameState s;
    s.stage = 4;
    s.units[Militia] = 20;                        // power 100 vs cache defence 18
    Event r = raidEv(0, 100000);
    applyEvent(s, r, kSalt);
    QVERIFY(s.lastRaidOutcome != 0);
    QVERIFY(s.raidsWon >= 1 || s.lastRaidOutcome == 3);
    // strong enough that it is a win, not a defeat
    QVERIFY(s.lastRaidOutcome == 1 || s.lastRaidOutcome == 2);
    QVERIFY(totalUnits(s) < 20);                  // some casualties

    // A hopeless attack loses and grants intel.
    GameState w;
    w.stage = 5;
    w.units[Militia] = 1;                         // power 5 vs fort defence 16000
    Event r2 = raidEv(5, 200000);
    applyEvent(w, r2, kSalt);
    QCOMPARE(w.lastRaidOutcome, 3);
    QVERIFY(w.intel[5] > 0.0);
}

void TstWarren::foldReplayDeterministic()
{
    QVector<Event> v;
    v << arrive() << assign(Forage, 4) << tap(50) << tick(600000, 700000)
      << assign(Gather, 2) << tick(600000, 1400000) << build(Burrow, 1500000)
      << tick(600000, 2100000);
    GameState a = fold(v, kSalt);
    GameState b = fold(v, kSalt);
    QCOMPARE(a.stage, b.stage);
    QCOMPARE(a.population, b.population);
    QCOMPARE(a.res[Food], b.res[Food]);
    QCOMPARE(a.res[Materials], b.res[Materials]);
    QCOMPARE(a.buildingsBuilt, b.buildingsBuilt);
    QCOMPARE(a.lastSeenMs, b.lastSeenMs);
}

// A greedy bot plays the staged progression at fold level; the build fails if the mid-game is
// unreachable. Prints the timeline into the CI log.
void TstWarren::simulationProgression()
{
    GameState s;
    QVector<Event> log;
    qint64 t = 1000;
    auto push = [&](const Event& e) { log.append(e); applyEvent(s, log.last(), kSalt); };

    auto rebalance = [&](int f, int g, int m, int b) {
        // issue deltas to reach a target distribution (remove first, then add)
        int tgt[JobCount] = { f, g, m, b };
        for (int j = 0; j < JobCount; ++j)
            if (tgt[j] < s.assigned[j]) push(assign(j, tgt[j] - s.assigned[j], t));
        for (int j = 0; j < JobCount; ++j)
            if (tgt[j] > s.assigned[j]) push(assign(j, tgt[j] - s.assigned[j], t));
    };

    push(arrive(t));
    for (int i = 0; i < 60; ++i) push(tap(1, t));   // dig to bootstrap food

    const qint64 step = Q_INT64_C(60000);           // one simulated minute
    int lastStage = -1;
    qint64 stageAtMin[kStageCount];
    for (int k = 0; k < kStageCount; ++k) stageAtMin[k] = -1;
    for (int i = 0; i < 4000 && s.stage < 5; ++i) {
        t += step;
        push(tick(step, t));

        // keep at least half foraging so nobody starves; split the rest, keep builders on site
        int p = s.population;
        int foragers = (p + 1) / 2;
        int rest = p - foragers;
        int builders = 0, gatherers = 0, miners = 0;
        if (s.stage >= 1 && rest > 0) builders = rest >= 3 ? 2 : 1;
        rest -= builders;
        if (s.stage >= 2) { gatherers = (rest + 1) / 2; miners = rest - gatherers; }
        else gatherers = rest;
        rebalance(foragers, gatherers, miners, s.stage >= 1 ? builders : 0);

        // open a site when free. A competent player beelines the gate-critical building (trading
        // post to earn, barracks to muster) and saves for it; otherwise builds cheapest useful first.
        if (s.siteBld < 0) {
            int want = -1;
            if (s.stage >= 3 && s.buildings[Barracks] == 0) want = Barracks;
            else if (s.stage >= 2 && s.buildings[TradingPost] == 0) want = TradingPost;
            if (want >= 0) {
                if (s.res[Materials] >= buildCost(s, want, 1)) push(build(want, t));
            } else {
                for (int b = 0; b < BldCount; ++b) {
                    if (s.stage < kBld[b].unlockStage) continue;
                    if (s.res[Materials] >= buildCost(s, b, 1) * 1.2) {
                        push(build(b, t));
                        break;
                    }
                }
            }
        }
        // keep the lights on
        if (s.stage >= 2 && s.buildings[TradingPost] >= 1 && s.res[Energy] < energyCap(s) * 0.3
            && s.res[Gold] > 200) {
            push(buyenergy(energyCap(s) - s.res[Energy], t));
        }
        // train a small force once there is a barracks
        if (s.buildings[Barracks] >= 1 && s.res[Gold] > kUnit[Militia].costGold * 2
            && s.res[Materials] > kUnit[Militia].costMaterials * 2 && s.population > 6) {
            push(train(Militia, 1, t));
        }
        // raid the cache whenever ready and we have troops
        if (s.stage >= 4 && totalUnits(s) >= 6 && raidReady(s, 0, t))
            push(raidEv(0, t));

        if (s.stage != lastStage) {
            const qint64 minute = (t - 1000) / 60000;
            if (s.stage >= 0 && s.stage < kStageCount) stageAtMin[s.stage] = minute;
            lastStage = s.stage;
            qInfo("sim: reached stage %d at minute %lld (pop %d, gold %.0f, units %d, events %d)",
                  s.stage, static_cast<long long>(minute), s.population,
                  s.res[Gold], totalUnits(s), log.size());
        }
    }

    qInfo("sim: final stage %d, pop %d, buildings %d, units trained %d, raids won %d, events %d",
          s.stage, s.population, totalBuildings(s), s.unitsTrained, s.raidsWon, log.size());

    // The greedy bot must walk the whole staged reveal, not just reach the raids: a full run to
    // stage 5 proves no gate soft-locks under the current balance.
    QVERIFY2(s.stage >= 5, "the greedy bot should reach the endgame (stage 5) within the horizon");
    QVERIFY(s.population <= housingCap(s));

    // No single stage should be a marathon: each transition lands within a generous budget of the
    // previous one. Catches a gate that technically clears but takes implausibly long.
    for (int k = 1; k <= 5; ++k) {
        QVERIFY2(stageAtMin[k] >= 0, "every stage up to 5 must be reached");
        const qint64 prev = stageAtMin[k - 1] < 0 ? 0 : stageAtMin[k - 1];
        QVERIFY2(stageAtMin[k] - prev <= 600, "no stage should take longer than 10 simulated hours");
    }

    // Determinism: replaying the whole log lands on the same state.
    GameState again = fold(log, kSalt);
    QCOMPARE(again.stage, s.stage);
    QCOMPARE(again.population, s.population);
    QCOMPARE(again.raidsWon, s.raidsWon);
}

void TstWarren::energySustainability()
{
    // A representative stage-2 colony: a trading post and a handful of miners. Keeping the lights
    // on must be payable from mining alone, so an active player is never stuck in the dark.
    GameState s;
    s.stage = 2;
    s.population = 10;
    s.buildings[TradingPost] = 1;
    s.buildings[Granary] = 1;
    s.buildings[Workshop] = 1;
    s.buildings[MineShaft] = 1;
    s.assigned[MineJob] = 3;
    s.res[Energy] = energyCap(s);

    // Gold minted per second must cover the gold spent per second on energy drain.
    const double goldPerSec = production(s, MineJob);
    const double energyCostPerSec = energyDrain(s) * kEnergyPrice;
    QVERIFY2(goldPerSec >= energyCostPerSec,
             "mining income must outpace the cost of sustaining energy at stage 2");

    // A full tank should last long enough that topping up is not a chore.
    const double tankSeconds = energyCap(s) / energyDrain(s);
    QVERIFY2(tankSeconds >= 300.0, "a full energy tank should last at least five minutes");
}

void TstWarren::foldMagpieEconomy()
{
    // The magpie (faction 1) is asymmetric: forages to eat, but loots materials and gold rather
    // than working the land, never breeds, and rests its stamina back into the res[Energy] slot.
    QVector<Event> v;
    v << arriveF(1) << assign(Forage, 1) << assign(Gather, 1) << assign(MineJob, 1)
      << tick(60000, 61000);
    GameState s = fold(v, kSalt);
    QCOMPARE(s.faction, 1);
    QVERIFY(!canBuild(s));                            // cannot construct
    QVERIFY(s.res[Food] > kStartFood);               // foraging still feeds the flock
    QCOMPARE(s.res[Materials], 0.0);                 // does not gather from the ground
    QCOMPARE(s.res[Gold], 0.0);                      // does not mine
    QVERIFY(s.res[Energy] > 0.0);                    // stamina rests back up
    QCOMPARE(s.population, kStartPopulation);        // no breeding
    QCOMPARE(housingCap(s), kMagpieHousingBase);     // housing from territory held (none yet)

    // A build order is a no-op for a faction that cannot build.
    v << build(Burrow, 62000) << tick(1000, 63000);
    GameState s2 = fold(v, kSalt);
    QCOMPARE(s2.siteBld, -1);
    QCOMPARE(s2.buildings[Burrow], 0);
}

void TstWarren::foldMagpieRaid()
{
    // The whole flock raids: power scales with numbers, stamina is spent, birds fall, and a win
    // brings loot, territory, and recruits. No units, no barracks.
    GameState s;
    s.faction = 1;
    s.stage = 1;                       // raids open early for the magpie
    s.population = 12;                 // flock power 48 vs cache defence 18 -> a decisive win
    s.res[Energy] = kStaminaCap;       // full stamina
    QVERIFY(raidReady(s, 0, 100000));
    applyEvent(s, raidEv(0, 100000), kSalt);
    QCOMPARE(s.lastRaidOutcome, 1);                  // decisive at this power ratio
    QVERIFY(s.res[Energy] < kStaminaCap);            // stamina spent
    QCOMPARE(s.raidsWon, 1);
    QVERIFY(s.territory >= 1);                        // ground taken
    QVERIFY(s.res[Gold] > 0.0);                      // loot
    QVERIFY(s.population >= 1);                       // never wiped to zero
    QVERIFY(s.stage >= 2);                            // raid gate advanced the reveal
}

QTEST_GUILESS_MAIN(TstWarren)
#include "tst_main.moc"
