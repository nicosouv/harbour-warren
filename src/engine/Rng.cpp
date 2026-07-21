#include "Rng.h"

namespace warren {

quint64 Rng::next()
{
    quint64 z = (m_state += Q_UINT64_C(0x9E3779B97F4A7C15));
    z = (z ^ (z >> 30)) * Q_UINT64_C(0xBF58476D1CE4E5B9);
    z = (z ^ (z >> 27)) * Q_UINT64_C(0x94D049BB133111EB);
    return z ^ (z >> 31);
}

double Rng::nextDouble()
{
    return (next() >> 11) * (1.0 / 9007199254740992.0); // 2^53
}

quint32 Rng::nextBounded(quint32 bound)
{
    if (bound == 0)
        return 0;
    const quint32 threshold = (0u - bound) % bound;
    for (;;) {
        const quint32 r = static_cast<quint32>(next());
        if (r >= threshold)
            return r % bound;
    }
}

quint64 Rng::mix(quint64 a, quint64 b)
{
    Rng r(a ^ (b * Q_UINT64_C(0x9E3779B97F4A7C15)));
    return r.next();
}

} // namespace warren
