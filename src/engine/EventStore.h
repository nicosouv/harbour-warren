// The single source of truth: an append-only event log over SQLite. Never UPDATE/DELETE rows in
// `events` — current state is a fold of this log. Owns install_meta (the per-install salt that
// seeds every deterministic roll). The only erasure is clearAll (Settings > clear data).
#ifndef WARREN_EVENTSTORE_H
#define WARREN_EVENTSTORE_H

#include <QString>
#include <QVector>
#include <QtGlobal>

namespace warren {

struct Event {
    qint64  seq = 0;
    qint64  tsMs = 0;
    QString kind;
    QString payload;
};

class EventStore {
public:
    explicit EventStore(const QString& connectionName = QStringLiteral("warren_main"));
    ~EventStore();

    bool open(const QString& path);
    void close();
    bool isOpen() const;

    bool bootstrap(quint64 saltIfNew);
    quint64 installSalt() const;

    qint64 appendEvent(const QString& kind, qint64 tsMs, const QString& payload);
    QVector<Event> events() const;
    int eventCount() const;
    bool clearAll();

private:
    bool exec(const QString& sql);
    QString m_connectionName;
    bool    m_open = false;
};

} // namespace warren

#endif // WARREN_EVENTSTORE_H
