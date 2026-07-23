// Every tuning constant in one header. Numbers are gameplay balance — expected to move during
// playtests and against the simulation harness; nothing else in the engine hardcodes a curve.
#ifndef WARREN_BALANCE_H
#define WARREN_BALANCE_H

#include <QtGlobal>

namespace warren {
namespace Balance {

// --- Resources -------------------------------------------------------------------------------
enum Res { Food = 0, Materials, Gold, Energy, ResCount };

// --- Factions (asymmetric play). Badger is faction 0 and keeps every current rule; the descriptor
// grows as faction 2 (magpies) lands. See docs-local/FACTIONS.md.
// When a faction becomes selectable (hybrid onboarding, option C in FACTIONS.md).
enum FactionUnlock { FUStart = 0, FUCoreLoop };   // from the start / after the core loop is learnt
// The energy-equivalent each faction must top up. Stored in the res[Energy] slot, read per faction.
enum RechargeMechanic { RMEnergy = 0, RMStamina };
struct FactionDef {
    const char* id;
    bool  canBuild;    // false: no construction — goods come from raiding
    bool  breeds;      // population grows by breeding (else by recruitment)
    bool  worksLand;   // gather/mine jobs produce (else materials & gold come only from raids)
    int   unlockAfter; // FactionUnlock: gates the faction picker in the slot-select screen
    int   recharge;    // RechargeMechanic: what the res[Energy] slot means for this faction
};
static const int kFactionCount = 2;
static const FactionDef kFaction[kFactionCount] = {
    { "badger", true,  true,  true,  FUStart,    RMEnergy  },
    { "magpie", false, false, false, FUCoreLoop, RMStamina },   // can't build; recruits by raiding
};

// --- Magpie (faction 1): raid-centric, no construction, stamina instead of energy. -------------
static const int    kMagpieHousingBase    = 6;
static const int    kMagpieHousingPerTerr = 3;    // the roost widens with each territory taken
static const int    kMagpieRecruitPerWin  = 2;    // birds join the flock after a won raid
static const double kStaminaCap           = 100.0;
static const double kStaminaRegenPerSec   = 0.06; // rest refills the pool
static const double kStaminaRaidCost      = 40.0; // each raid tires the flock
static const double kStaminaLowFactor     = 0.5;  // raid power multiplier when the pool is empty

// --- Jobs (worker assignments). Each job feeds one resource; builders feed the site. ----------
enum Job { Forage = 0, Gather, MineJob, Build, JobCount };
// job -> resource produced (-1: construction work)
static const int kJobResource[JobCount] = { Food, Materials, Gold, -1 };
static const double kJobBase[JobCount]  = { 0.55, 0.32, 0.22, 1.0 };  // per worker per second

// --- Buildings -------------------------------------------------------------------------------
enum Bld { Burrow = 0, Granary, Workshop, MineShaft, TradingPost, Barracks,
           Watchtower, Watermill, BldCount };

struct BldDef {
    const char* id;
    int    resCost;      // which resource pays (always Materials in MVP)
    double baseCost;
    double costGrowth;
    int    unlockStage;  // building becomes buyable at this stage
    double work;         // construction work points (builders deliver kJobBase[Build]/s each)
};
// Cost growth is steep on purpose: materials must never just pile up unspent. Each extra copy of a
// building costs markedly more than the last, so a full granary is always a few builds from empty.
static const BldDef kBld[BldCount] = {
    { "burrow",      Materials,   20.0, 1.27, 1,   90.0 },
    { "granary",     Materials,   45.0, 1.27, 1,  150.0 },
    { "workshop",    Materials,   70.0, 1.28, 1,  210.0 },
    { "mineshaft",   Materials,  120.0, 1.30, 2,  320.0 },
    { "tradingpost", Materials,  180.0, 1.28, 2,  420.0 },
    { "barracks",    Materials,  450.0, 1.32, 3,  900.0 },
    { "watchtower",  Materials,  300.0, 1.26, 4,  600.0 },  // home defence vs counter-raids
    { "watermill",   Materials,  800.0, 1.28, 5, 1200.0 },  // +production to the whole colony
};

// Building effects (per owned unit).
static const int    kHousingBase       = 6;   // must allow reaching the stage-1 population gate
static const int    kHousingPerBurrow  = 3;
static const double kFoodCapBase       = 60.0;
static const double kFoodCapPerGranary = 60.0;
static const double kForageBonusPerGranary   = 0.10;   // +10% forage per granary
static const double kGatherBonusPerWorkshop  = 0.12;
static const double kMineBonusPerShaft       = 0.12;
static const double kEnergyCapBase     = 100.0;
static const double kEnergyCapPerPost  = 120.0;
static const double kWatermillProdBonus  = 0.10;   // +10% to every yield per watermill
static const double kWatchtowerDefense   = 45.0;   // flat defensive power per watchtower
static const double kWatchtowerCdBonus   = 0.15;   // each tower lengthens counter-raid cooldown

// --- Consumption & energy --------------------------------------------------------------------
static const double kFoodPerPop  = 0.06;    // every colonist eats
static const double kFoodPerUnit = 0.16;    // soldiers eat more
static const double kEnergyPerPop = 0.010;  // drain (only from stage 2)
static const double kEnergyPerBld = 0.020;
// Energy is optional infrastructure: a trading post lets you buy it and, while powered, boosts
// production; let it run dry and the lights go out (below baseline). No forced cliff at stage 2.
static const double kEnergyBonus  = 1.25;   // production factor while energy > 0 (with a post)
static const double kBlackout     = 0.70;   // production factor when the post has no energy
static const double kEnergyPrice  = 1.5;    // gold per energy (trading post)
static const double kEnergyGift    = 20.0;  // one-time free charge when the first post is built

// --- Population growth ------------------------------------------------------------------------
// Slowed hard: at 0.02 the colony hit 12 badgers in ~5 min, outrunning the whole event catalogue.
static const double kGrowthRate     = 0.0045; // brood progress per second when fed & housed
static const double kGrowthFoodFloor = 5.0;   // need at least this much food stored to grow

// --- Manual action (Scavenge). Mostly food; every 4th find (from stage 1) turns up materials. --
static const double kDigFood = 1.0;
static const double kDigMat  = 1.0;

// --- Units (army) -----------------------------------------------------------------------------
enum Unit { Militia = 0, Veteran, UnitCount };
struct UnitDef {
    const char* id;
    double costGold;
    double costMaterials;
    int    costPop;      // workers converted to soldiers
    double power;
    double foodUpkeep;   // per second
    int    unlockStage;
    double costGrowth;   // each unit owned makes the next one this much dearer
};
static const UnitDef kUnit[UnitCount] = {
    { "militia", 50.0,  20.0,  1, 5.0,  0.16, 3, 1.15 },
    { "veteran", 320.0, 110.0, 1, 26.0, 0.30, 5, 1.18 },
};

// --- Raid targets -----------------------------------------------------------------------------
struct TargetDef {
    const char* id;
    double defense;
    double lootGold;
    double lootMaterials;
    double lootFood;
    qint64 cooldownMs;
    int    unlockStage;
};
static const int kTargetCount = 6;
static const TargetDef kTarget[kTargetCount] = {
    { "cache",   18.0,   220.0,  120.0,   80.0, Q_INT64_C(1200000), 4 },  // 20 min
    { "foragers",70.0,   700.0,  300.0,  240.0, Q_INT64_C(2700000), 4 },  // 45 min
    { "mill",   280.0,  3200.0, 1400.0,  900.0, Q_INT64_C(5400000), 5 },  // 90 min
    { "warren", 1100.0,12000.0, 5000.0, 3000.0, Q_INT64_C(9000000), 5 },  // 2.5 h
    { "keep",   4200.0,46000.0,18000.0,10000.0, Q_INT64_C(14400000), 5 }, // 4 h
    { "fort",  16000.0,180000.0,70000.0,40000.0, Q_INT64_C(21600000), 5 },// 6 h
};

// Combat resolution.
static const double kLuckBand      = 0.30;  // +/- this on the power/defence score
static const double kDecisiveScore = 1.5;   // >= -> decisive win
static const double kWinScore      = 1.0;   // >= -> costly win, else defeat
static const double kCasualtyDecisive = 0.10;
static const double kCasualtyCostly   = 0.40;
static const double kCasualtyDefeat   = 0.65;
static const double kLootCostlyScale  = 0.6;
static const double kDefeatLossFrac   = 0.10; // fraction of stored gold/materials lost on defeat
static const double kIntelPerDefeat   = 0.15; // +15% effective power vs that target, capped
static const double kIntelCap         = 0.90;
static const double kTerritoryBonus   = 0.08; // +8% to all yields per territory held

// --- Stage gating (the A Dark Room reveal). Advance when the condition for the NEXT stage holds.
static const int kStageCount = 6;   // 0..5
// thresholds indexed by the stage you are LEAVING (0->1 uses [0], etc.)
static const int    kGatePopulation   = 6;      // 0 -> 1
static const int    kGateBuildings    = 3;      // 1 -> 2 (buildings built)
static const double kGateGoldEarned   = 400.0;  // 2 -> 3
static const int    kGateUnitsTrained = 3;      // 3 -> 4
static const int    kGateRaidsWon     = 1;      // 4 -> 5

// --- Ticks ------------------------------------------------------------------------------------
static const qint64 kOfflineCapMs = Q_INT64_C(604800000); // 7 days
static const qint64 kFlushMs      = Q_INT64_C(30000);
static const qint64 kWelcomeMs    = Q_INT64_C(1800000);   // recap shown past 30 min away

// --- Events: recurring, escalating, one at a time (the anti-"nothing left after 5 min"). ------
enum EventId {
    EvStorm = 0, EvRats, EvWanderer, EvRain, EvMerchant,
    EvTransformer, EvCollapse, EvTax, EvScouts, EvFeast, EvCounterRaid,
    EvExodus, EvWoundedVet, EvCult, EvWolves,
    EvMinerStrike, EvCaveIn, EvVein, EvDeserter, EvPrisoners, EvCrate,
    EvArcFoxWar, EvArcRiver, EvArcElder, EventCount
};
struct EventDef {
    const char* id;
    int    tier;         // 1 survival, 2 commerce, 3 war, 4 empire
    qint64 cooldownMs;   // per-event real-time cooldown before it can recur
};
static const EventDef kEvent[EventCount] = {
    { "storm",       1, Q_INT64_C(2700000)  },  // 45 min
    { "rats",        1, Q_INT64_C(3600000)  },  // 60 min
    { "wanderer",    1, Q_INT64_C(2700000)  },
    { "rain",        1, Q_INT64_C(3600000)  },
    { "merchant",    2, Q_INT64_C(2700000)  },
    { "transformer", 2, Q_INT64_C(4500000)  },  // 75 min
    { "collapse",    2, Q_INT64_C(5400000)  },  // 90 min
    { "tax",         2, Q_INT64_C(5400000)  },
    { "scouts",      3, Q_INT64_C(3600000)  },
    { "feast",       4, Q_INT64_C(5400000)  },
    { "counterraid", 3, Q_INT64_C(3600000)  },  // the foxes return the favour
    { "exodus",      4, Q_INT64_C(5400000)  },  // 90 min
    { "woundedvet",  3, Q_INT64_C(3600000)  },  // 60 min
    { "cult",        4, Q_INT64_C(5400000)  },
    { "wolves",      4, Q_INT64_C(7200000)  },  // 2 h, ~seasonal
    { "minerstrike", 2, Q_INT64_C(5400000)  },
    { "cavein",      1, Q_INT64_C(3600000)  },
    { "vein",        2, Q_INT64_C(3600000)  },
    { "deserter",    3, Q_INT64_C(3600000)  },
    { "prisoners",   3, Q_INT64_C(3600000)  },
    { "crate",       3, Q_INT64_C(3600000)  },
    { "arcfoxwar",   3, Q_INT64_C(3600000)  },  // once-per-game arcs (gated by arcDone)
    { "arcriver",    2, Q_INT64_C(3600000)  },
    { "arcelder",    3, Q_INT64_C(3600000)  },
};

// Counter-raid: the foxes hit back once you start taking territory. A defensive battle resolved
// like a raid, but you are the one being scored. Enemy force grows with the territory you hold.
static const double kCounterBaseForce    = 35.0;
static const double kCounterForcePerTerr = 0.40;
static const double kCounterPillageFrac  = 0.20;   // gold & materials lost on a failed defence
static const double kCounterCasualtyWin  = 0.10;   // army fraction lost even when repelled
static const double kCounterCasualtyLoss = 0.35;   // army fraction lost when overrun
static const double kCounterTributeFrac  = 0.15;   // gold paid to buy the peace (option B)
static const qint64 kEventGlobalCd = Q_INT64_C(1200000);  // 20 min between any two events
static const double kEventChance    = 0.5;                // roll per eligible window
static const qint64 kModStormBonusMs = Q_INT64_C(0);     // storm damage lasts until repaired
static const qint64 kModShortMs      = Q_INT64_C(3600000);   // 1 h temporary modifiers
static const qint64 kModFeastMs      = Q_INT64_C(7200000);   // 2 h
static const double kFeastFoodCost   = 0.40;   // fraction of stored food
static const double kFeastProd       = 1.25;
static const double kFeastRefusePenalty = 0.90;
static const double kRatsFoodLoss    = 0.20;
static const double kTaxGoldFrac     = 0.12;
static const double kScoutsLoss      = 0.15;
static const double kMerchantSell    = 0.30;   // sells this fraction of food
static const double kMerchantRate    = 2.5;    // gold per food unit sold

// --- Absurd-statistics counters have no balance knobs; they are free. --------------------------

// --- Starting state ---------------------------------------------------------------------------
static const int    kStartPopulation = 4;
static const double kStartFood       = 25.0;

} // namespace Balance
} // namespace warren

#endif // WARREN_BALANCE_H
