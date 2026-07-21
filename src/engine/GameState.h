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
