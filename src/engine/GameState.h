// The projection target: a plain value struct, no behaviour. Produced only by folding the event
// log (see StateProjection); nothing writes it directly.
#ifndef WARREN_GAMESTATE_H
#define WARREN_GAMESTATE_H

#include "Balance.h"

namespace warren {

struct GameState {
    bool   arrived = false;         // player stepped past the intro
    int    stage = 0;               // A Dark Room reveal (0..5), monotonic

    double res[Balance::ResCount] = { Balance::kStartFood, 0.0, 0.0, 0.0 };

    int    population = Balance::kStartPopulation;   // assignable workers
    int    assigned[Balance::JobCount] = { 0, 0, 0 };
    double brood = 0.0;             // population growth accumulator

    int    buildings[Balance::BldCount] = { 0, 0, 0, 0, 0, 0 };
    int    buildingsBuilt = 0;      // lifetime count (stage gate)

    int    siteBld = -1;            // the single construction site (-1: none)
    double siteProgress = 0.0;      // work points delivered by builders

    int    tapsTotal = 0;           // absurd-stats fodder
    int    energyBuys = 0;
    int    raidsLost = 0;

    // Events -----------------------------------------------------------------------------------
    int    eventActive = -1;        // the event currently offered (-1: none)
    int    eventsSeen = 0;          // total events fired (seeds the roll)
    qint64 lastEventMs = 0;         // global cooldown anchor
    int    eventLevel[Balance::EventCount] = {};   // escalation level per event
    qint64 eventLastMs[Balance::EventCount] = {};  // per-event cooldown anchor

    quint32 damaged = 0;            // bitmask over buildings whose bonus is suspended (storm)

    // Temporary modifiers, expired lazily at each event's instant.
    double modProdFactor = 1.0;   qint64 modProdUntil = 0;
    double modDrainFactor = 1.0;  qint64 modDrainUntil = 0;

    int    units[Balance::UnitCount] = { 0, 0 };
    int    unitsTrained = 0;        // lifetime (stage gate)

    double goldEarned = 0.0;        // lifetime (stage gate)

    int    territory = 0;           // permanent yield bonus source
    int    raidsWon = 0;
    int    raidCount = 0;           // seeds the deterministic roll
    double intel[Balance::kTargetCount] = { 0, 0, 0, 0, 0, 0 };
    qint64 lastRaidMs = 0;

    qint64 lastSeenMs = 0;          // latest instant seen in any payload (offline accrual)

    // Transient record of the last resolved raid, for the UI to replay (not persisted meaning).
    int    lastRaidTarget = -1;
    int    lastRaidOutcome = 0;     // 0 none, 1 decisive, 2 costly, 3 defeat
    int    lastRaidCommitted = 0;
    int    lastRaidLosses = 0;
};

} // namespace warren

#endif // WARREN_GAMESTATE_H
