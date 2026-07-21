// Deterministic, seedable PRNG (splitmix64). ALL randomness goes through this — raids especially,
// so a shown battle matches its computed result. Seeds are derived (install_salt + a counter).
#ifndef WARREN_RNG_H
#define WARREN_RNG_H

#include <QtGlobal>

namespace warren {

class Rng {
public:
    explicit Rng(quint64 seed) : m_state(seed) {}
    quint64 next();
    double nextDouble();               // uniform [0, 1)
    quint32 nextBounded(quint32 bound);
    static quint64 mix(quint64 a, quint64 b);
private:
    quint64 m_state;
};

} // namespace warren

#endif // WARREN_RNG_H
