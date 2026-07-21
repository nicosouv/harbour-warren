// The engine's one and only source of "now". Injectable so tests pin time; no other engine code
// calls wall-clock time directly, and events carry their own timestamps so the fold stays pure.
#ifndef WARREN_CLOCK_H
#define WARREN_CLOCK_H

#include <QDateTime>

namespace warren {

class Clock {
public:
    virtual ~Clock() = default;
    virtual qint64 nowMs() const = 0;
};

class SystemClock : public Clock {
public:
    qint64 nowMs() const override { return QDateTime::currentMSecsSinceEpoch(); }
};

class FixedClock : public Clock {
public:
    explicit FixedClock(qint64 ms) : m_now(ms) {}
    qint64 nowMs() const override { return m_now; }
    void set(qint64 ms) { m_now = ms; }
    void advanceMs(qint64 ms) { m_now += ms; }
private:
    qint64 m_now;
};

} // namespace warren

#endif // WARREN_CLOCK_H
