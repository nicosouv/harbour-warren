// The pure projection: current state = fold of the event log through applyEvent(). Deterministic
// and unit-tested — no I/O, no clock, no globals. Events carry their own timestamps in the
// payload; `salt` is the per-install seed for raid rolls.
#ifndef WARREN_STATEPROJECTION_H
#define WARREN_STATEPROJECTION_H

#include "GameState.h"
#include "EventStore.h"

namespace warren {

// Derived quantities, all pure.
int    housingCap(const GameState& s);
double foodCap(const GameState& s);
double energyCap(const GameState& s);
int    totalBuildings(const GameState& s);
int    totalUnits(const GameState& s);
int    idleWorkers(const GameState& s);
double territoryMult(const GameState& s);
double energyMult(const GameState& s);           // production factor from energy infrastructure
double perWorker(const GameState& s, int job);   // per-worker yield of a job, all bonuses applied
double production(const GameState& s, int job);  // assigned workers * perWorker
double foodConsumption(const GameState& s);
double energyDrain(const GameState& s);
double netFood(const GameState& s);
double buildCost(const GameState& s, int bld, int n);
double armyPower(const GameState& s);
bool   targetUnlocked(const GameState& s, int t);
qint64 raidCooldownLeft(const GameState& s, int t, qint64 nowMs);
bool   raidReady(const GameState& s, int t, qint64 nowMs);

// Fold one event into the state (in place). Invalid/unaffordable events degrade to no-ops so a
// replayed log can never diverge.
void applyEvent(GameState& s, const Event& e, quint64 salt);
GameState fold(const QVector<Event>& events, quint64 salt);

} // namespace warren

#endif // WARREN_STATEPROJECTION_H
