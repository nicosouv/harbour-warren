#include "EventStore.h"
#include "AppId.h"

#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QVariant>
#include <QDebug>

namespace warren {

EventStore::EventStore(const QString& connectionName)
    : m_connectionName(connectionName)
{
}

EventStore::~EventStore()
{
    close();
}

bool EventStore::open(const QString& path)
{
    close();
    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connectionName);
    db.setDatabaseName(path);
    if (!db.open()) {
        qWarning() << "EventStore: failed to open" << path << db.lastError().text();
        return false;
    }
    QSqlQuery(db).exec(QStringLiteral("PRAGMA foreign_keys = ON"));
    QSqlQuery(db).exec(QStringLiteral("PRAGMA journal_mode = WAL"));
    m_open = true;
    return true;
}

void EventStore::close()
{
    if (QSqlDatabase::contains(m_connectionName)) {
        {
            QSqlDatabase db = QSqlDatabase::database(m_connectionName, false);
            if (db.isOpen())
                db.close();
        }
        QSqlDatabase::removeDatabase(m_connectionName);
    }
    m_open = false;
}

bool EventStore::isOpen() const
{
    return m_open;
}

bool EventStore::exec(const QString& sql)
{
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    QSqlQuery q(db);
    if (!q.exec(sql)) {
        qWarning() << "EventStore: SQL failed" << sql << q.lastError().text();
        return false;
    }
    return true;
}

bool EventStore::bootstrap(quint64 saltIfNew)
{
    if (!m_open)
        return false;

    bool ok = true;
    ok &= exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS events ("
        " seq     INTEGER PRIMARY KEY AUTOINCREMENT,"
        " ts      INTEGER NOT NULL,"
        " kind    TEXT    NOT NULL,"
        " payload TEXT    NOT NULL)"));
    ok &= exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS install_meta ("
        " id           INTEGER PRIMARY KEY CHECK (id = 1),"
        " install_salt INTEGER NOT NULL,"
        " schema_ver   INTEGER NOT NULL)"));
    if (!ok)
        return false;

    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO install_meta (id, install_salt, schema_ver) VALUES (1, ?, ?)"));
    q.addBindValue(static_cast<qint64>(saltIfNew));
    q.addBindValue(AppId::kSchemaVersion);
    if (!q.exec()) {
        qWarning() << "EventStore: install_meta seed failed" << q.lastError().text();
        return false;
    }
    return true;
}

quint64 EventStore::installSalt() const
{
    if (!m_open)
        return 0;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    QSqlQuery q(db);
    if (q.exec(QStringLiteral("SELECT install_salt FROM install_meta WHERE id = 1")) && q.next())
        return static_cast<quint64>(q.value(0).toLongLong());
    return 0;
}

qint64 EventStore::appendEvent(const QString& kind, qint64 tsMs, const QString& payload)
{
    if (!m_open)
        return -1;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    QSqlQuery q(db);
    q.prepare(QStringLiteral("INSERT INTO events (ts, kind, payload) VALUES (?, ?, ?)"));
    q.addBindValue(tsMs);
    q.addBindValue(kind);
    q.addBindValue(payload);
    if (!q.exec()) {
        qWarning() << "EventStore: append failed" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toLongLong();
}

QVector<Event> EventStore::events() const
{
    QVector<Event> out;
    if (!m_open)
        return out;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral("SELECT seq, ts, kind, payload FROM events ORDER BY seq"))) {
        qWarning() << "EventStore: read failed" << q.lastError().text();
        return out;
    }
    while (q.next()) {
        Event e;
        e.seq     = q.value(0).toLongLong();
        e.tsMs    = q.value(1).toLongLong();
        e.kind    = q.value(2).toString();
        e.payload = q.value(3).toString();
        out.append(e);
    }
    return out;
}

int EventStore::eventCount() const
{
    if (!m_open)
        return 0;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    QSqlQuery q(db);
    if (q.exec(QStringLiteral("SELECT COUNT(*) FROM events")) && q.next())
        return q.value(0).toInt();
    return 0;
}

bool EventStore::clearAll()
{
    if (!m_open)
        return false;
    return exec(QStringLiteral("DELETE FROM events"));
}

} // namespace warren
