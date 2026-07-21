#include "WarrenController.h"
#include "AppId.h"
#include "Balance.h"
#include "Rng.h"
#include "StateProjection.h"

#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QStandardPaths>
#include <QVariantMap>
#include <cmath>

namespace warren {

using namespace Balance;

WarrenController::WarrenController(QObject* parent)
    : QObject(parent)
    , m_settings(QLatin1String(AppId::kOrganization), QLatin1String(AppId::kApplication))
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    m_store.open(dir + QLatin1String("/") + QLatin1String(AppId::kDatabaseFile));

    const quint64 entropy = Rng::mix(static_cast<quint64>(m_clock.nowMs()),
                                     reinterpret_cast<quintptr>(this));
    m_store.bootstrap(entropy != 0 ? entropy : Q_UINT64_C(0xC0FFEE));
    m_salt = m_store.installSalt();

    m_state = fold(m_store.events(), m_salt);

    const qint64 now = m_clock.nowMs();
    if (m_state.lastSeenMs > 0 && now - m_state.lastSeenMs > 5000) {
        qint64 ms = now - m_state.lastSeenMs;
        if (ms > kOfflineCapMs) ms = kOfflineCapMs;
        const double goldBefore = m_state.res[Gold];
        const int popBefore = m_state.population;
        QJsonObject p;
        p.insert(QLatin1String("ms"), static_cast<double>(ms));
        p.insert(QLatin1String("active"), false);
        p.insert(QLatin1String("at"), static_cast<double>(now));
        appendAndApply(QLatin1String("tick"),
                       QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
        m_welcomeGold = m_state.res[Gold] - goldBefore;
        m_welcomePop = m_state.population - popBefore;
        m_welcomeMs = static_cast<double>(ms);
        m_welcomePending = ms > kWelcomeMs;
    }
    m_lastFlushMs = now;

    connect(&m_uiTimer, &QTimer::timeout, this, &WarrenController::onUiTick);
    m_uiTimer.start(1000);
}

WarrenController::~WarrenController()
{
    flushNow();
}

QString WarrenController::appVersion() const
{
#ifdef APP_VERSION
    return QLatin1String(APP_VERSION);
#else
    return QLatin1String("dev");
#endif
}

QString WarrenController::language() const
{
    return m_settings.value(QStringLiteral("language")).toString();
}

void WarrenController::setLanguage(const QString& code)
{
    if (language() == code) return;
    m_settings.setValue(QStringLiteral("language"), code);
    emit languageChanged();
}

bool WarrenController::reduceFx() const
{
    return m_settings.value(QStringLiteral("reduceFx"), false).toBool();
}

void WarrenController::setReduceFx(bool on)
{
    m_settings.setValue(QStringLiteral("reduceFx"), on);
    emit prefsChanged();
}

bool WarrenController::arrived() const { return m_state.arrived; }
int WarrenController::stage() const { return m_state.stage; }
int WarrenController::population() const { return m_state.population; }
int WarrenController::idleWorkersQ() const { return warren::idleWorkers(m_state); }
int WarrenController::housingCapQ() const { return warren::housingCap(m_state); }
bool WarrenController::energyActive() const { return m_state.stage >= 2; }
bool WarrenController::tradingUnlocked() const { return m_state.buildings[TradingPost] >= 1; }
bool WarrenController::barracksUnlocked() const { return m_state.buildings[Barracks] >= 1; }
bool WarrenController::raidsUnlocked() const { return m_state.stage >= 4; }
double WarrenController::armyPowerQ() const { return warren::armyPower(m_state); }
int WarrenController::totalUnitsQ() const { return warren::totalUnits(m_state); }
int WarrenController::territory() const { return m_state.territory; }
int WarrenController::buildingsTotal() const { return warren::totalBuildings(m_state); }
bool WarrenController::welcomePending() const { return m_welcomePending; }
double WarrenController::welcomeMs() const { return m_welcomeMs; }
double WarrenController::welcomeGold() const { return m_welcomeGold; }
int WarrenController::welcomePop() const { return m_welcomePop; }

double WarrenController::capOf(int res) const
{
    if (res == Food) return foodCap(m_state);
    if (res == Energy) return energyCap(m_state);
    return -1.0; // uncapped
}

double WarrenController::rateOf(int res) const
{
    if (res == Food) return netFood(m_state);
    if (res == Materials) return production(m_state, Gather);
    if (res == Gold) return production(m_state, MineJob);
    if (res == Energy) return -energyDrain(m_state);
    return 0.0;
}

double WarrenController::liveRes(int res) const
{
    const qint64 now = m_clock.nowMs();
    double secs = (now - m_lastFlushMs) / 1000.0;
    if (secs < 0) secs = 0;
    double v = m_state.res[res] + rateOf(res) * secs;
    if (res == Food) {
        const int pt = m_pendingTaps;
        v += kDigFood * pt;
    }
    const double cap = capOf(res);
    if (v < 0) v = 0;
    if (cap >= 0 && v > cap) v = cap;
    return v;
}

bool WarrenController::blackout() const
{
    return m_state.stage >= 2 && liveRes(Energy) <= 0.0;
}

QVariantList WarrenController::resources() const
{
    static const char* const keys[ResCount] = { "food", "materials", "gold", "energy" };
    QVariantList out;
    for (int r = 0; r < ResCount; ++r) {
        bool visible = true;
        if (r == Materials) visible = m_state.stage >= 1;
        else if (r == Gold || r == Energy) visible = m_state.stage >= 2;
        QVariantMap m;
        m.insert(QStringLiteral("key"), QLatin1String(keys[r]));
        m.insert(QStringLiteral("value"), liveRes(r));
        m.insert(QStringLiteral("rate"), rateOf(r));
        m.insert(QStringLiteral("cap"), capOf(r));
        m.insert(QStringLiteral("visible"), visible);
        m.insert(QStringLiteral("low"), (r == Energy && liveRes(r) <= 0.0 && m_state.stage >= 2));
        out.append(m);
    }
    return out;
}

QVariantList WarrenController::jobs() const
{
    static const char* const keys[JobCount] = { "forage", "gather", "mine" };
    QVariantList out;
    for (int j = 0; j < JobCount; ++j) {
        bool visible = true;
        if (j == Gather) visible = m_state.stage >= 1;
        else if (j == MineJob) visible = m_state.stage >= 2;
        QVariantMap m;
        m.insert(QStringLiteral("index"), j);
        m.insert(QStringLiteral("key"), QLatin1String(keys[j]));
        m.insert(QStringLiteral("assigned"), m_state.assigned[j]);
        m.insert(QStringLiteral("perSec"), perWorker(m_state, j));
        m.insert(QStringLiteral("visible"), visible);
        out.append(m);
    }
    return out;
}

QVariantList WarrenController::buildings() const
{
    QVariantList out;
    for (int b = 0; b < BldCount; ++b) {
        if (m_state.stage < kBld[b].unlockStage) continue;
        const double cost = buildCost(m_state, b, 1);
        QVariantMap m;
        m.insert(QStringLiteral("index"), b);
        m.insert(QStringLiteral("key"), QLatin1String(kBld[b].id));
        m.insert(QStringLiteral("count"), m_state.buildings[b]);
        m.insert(QStringLiteral("cost"), cost);
        m.insert(QStringLiteral("affordable"), liveRes(Materials) >= cost);
        out.append(m);
    }
    return out;
}

QVariantList WarrenController::unitsList() const
{
    QVariantList out;
    for (int u = 0; u < UnitCount; ++u) {
        if (m_state.stage < kUnit[u].unlockStage) continue;
        const UnitDef& d = kUnit[u];
        QVariantMap m;
        m.insert(QStringLiteral("index"), u);
        m.insert(QStringLiteral("key"), QLatin1String(d.id));
        m.insert(QStringLiteral("count"), m_state.units[u]);
        m.insert(QStringLiteral("costGold"), d.costGold);
        m.insert(QStringLiteral("costMaterials"), d.costMaterials);
        m.insert(QStringLiteral("costPop"), d.costPop);
        m.insert(QStringLiteral("power"), d.power);
        const bool afford = liveRes(Gold) >= d.costGold && liveRes(Materials) >= d.costMaterials
                            && m_state.population >= d.costPop && m_state.buildings[Barracks] >= 1;
        m.insert(QStringLiteral("affordable"), afford);
        out.append(m);
    }
    return out;
}

QVariantList WarrenController::targets() const
{
    const qint64 now = m_clock.nowMs();
    QVariantList out;
    for (int t = 0; t < kTargetCount; ++t) {
        if (!targetUnlocked(m_state, t)) continue;
        QVariantMap m;
        m.insert(QStringLiteral("index"), t);
        m.insert(QStringLiteral("key"), QLatin1String(kTarget[t].id));
        m.insert(QStringLiteral("defense"), kTarget[t].defense);
        m.insert(QStringLiteral("ready"), raidReady(m_state, t, now));
        m.insert(QStringLiteral("cooldownLeft"),
                 static_cast<double>(raidCooldownLeft(m_state, t, now)));
        m.insert(QStringLiteral("cooldownTotal"), static_cast<double>(kTarget[t].cooldownMs));
        m.insert(QStringLiteral("intelPct"), m_state.intel[t] * 100.0);
        out.append(m);
    }
    return out;
}

QString WarrenController::fmt(double value) const
{
    static const char* const kSuffix[] = { "", " k", " M", " B", " T", " P", " E" };
    double a = value < 0 ? -value : value;
    int i = 0;
    while (a >= 1000.0 && i < 6) { a /= 1000.0; value /= 1000.0; ++i; }
    QLocale loc;
    if (i == 0) return loc.toString(value, 'f', value < 100 && value != std::floor(value) ? 1 : 0);
    return loc.toString(value, 'f', 2) + QLatin1String(kSuffix[i]);
}

void WarrenController::appendAndApply(const QString& kind, const QString& payload)
{
    const qint64 now = m_clock.nowMs();
    const qint64 seq = m_store.appendEvent(kind, now, payload);
    if (seq < 0) return;
    Event e;
    e.seq = seq;
    e.tsMs = now;
    e.kind = kind;
    e.payload = payload;
    applyEvent(m_state, e, m_salt);
}

void WarrenController::appendSimple(const QString& kind, qint64 at)
{
    QJsonObject p;
    p.insert(QLatin1String("at"), static_cast<double>(at));
    appendAndApply(kind, QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
}

void WarrenController::flushNow()
{
    const qint64 now = m_clock.nowMs();
    const qint64 ms = now - m_lastFlushMs;
    if (ms >= 1000) {
        QJsonObject p;
        p.insert(QLatin1String("ms"), static_cast<double>(ms));
        p.insert(QLatin1String("active"), true);
        p.insert(QLatin1String("at"), static_cast<double>(now));
        appendAndApply(QLatin1String("tick"),
                       QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
        m_lastFlushMs = now;
    }
    if (m_pendingTaps > 0) {
        QJsonObject p;
        p.insert(QLatin1String("n"), m_pendingTaps);
        p.insert(QLatin1String("at"), static_cast<double>(now));
        appendAndApply(QLatin1String("tap"),
                       QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
        m_pendingTaps = 0;
    }
    emit stateChanged();
    emit liveChanged();
}

void WarrenController::onUiTick()
{
    if (m_clock.nowMs() - m_lastFlushMs >= kFlushMs)
        flushNow();
    emit liveChanged();
}

void WarrenController::arrive()
{
    if (m_state.arrived) return;
    appendSimple(QLatin1String("arrive"), m_clock.nowMs());
    emit stateChanged();
    emit liveChanged();
}

void WarrenController::tap()
{
    m_pendingTaps += 1;
    emit liveChanged();
}

void WarrenController::assign(int job, int delta)
{
    if (job < 0 || job >= JobCount) return;
    flushNow();
    QJsonObject p;
    p.insert(QLatin1String("j"), job);
    p.insert(QLatin1String("d"), delta);
    p.insert(QLatin1String("at"), static_cast<double>(m_clock.nowMs()));
    appendAndApply(QLatin1String("assign"),
                   QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
    emit stateChanged();
    emit liveChanged();
}

void WarrenController::build(int b)
{
    if (b < 0 || b >= BldCount) return;
    flushNow();
    if (m_state.res[Materials] < buildCost(m_state, b, 1)) return;
    QJsonObject p;
    p.insert(QLatin1String("b"), b);
    p.insert(QLatin1String("n"), 1);
    p.insert(QLatin1String("at"), static_cast<double>(m_clock.nowMs()));
    appendAndApply(QLatin1String("build"),
                   QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
    emit stateChanged();
    emit liveChanged();
}

void WarrenController::buyEnergy()
{
    flushNow();
    if (m_state.stage < 2 || m_state.buildings[TradingPost] < 1) return;
    const double room = energyCap(m_state) - m_state.res[Energy];
    const double affordable = m_state.res[Gold] / kEnergyPrice;
    double amount = room < affordable ? room : affordable;
    if (amount <= 0.0) return;
    QJsonObject p;
    p.insert(QLatin1String("e"), amount);
    p.insert(QLatin1String("at"), static_cast<double>(m_clock.nowMs()));
    appendAndApply(QLatin1String("buyenergy"),
                   QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
    emit stateChanged();
    emit liveChanged();
}

void WarrenController::train(int u, int n)
{
    if (u < 0 || u >= UnitCount || n < 1) return;
    flushNow();
    QJsonObject p;
    p.insert(QLatin1String("u"), u);
    p.insert(QLatin1String("n"), n);
    p.insert(QLatin1String("at"), static_cast<double>(m_clock.nowMs()));
    appendAndApply(QLatin1String("train"),
                   QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
    emit stateChanged();
    emit liveChanged();
}

void WarrenController::raid(int t)
{
    if (t < 0 || t >= kTargetCount) return;
    flushNow();
    if (!raidReady(m_state, t, m_clock.nowMs())) return;
    const int countBefore = m_state.raidCount;
    QJsonObject p;
    p.insert(QLatin1String("t"), t);
    p.insert(QLatin1String("at"), static_cast<double>(m_clock.nowMs()));
    appendAndApply(QLatin1String("raid"),
                   QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
    if (m_state.raidCount > countBefore) {
        emit raidResolved(m_state.lastRaidTarget, m_state.lastRaidOutcome,
                          m_state.lastRaidCommitted, m_state.lastRaidLosses);
    }
    emit stateChanged();
    emit liveChanged();
}

bool WarrenController::beatSeen(const QString& key) const
{
    return m_settings.value(QStringLiteral("narr/b_") + key).toBool();
}

QString WarrenController::pendingNarration() const
{
    if (!m_state.arrived) return QString();
    for (int k = 1; k <= 5; ++k) {
        if (m_state.stage >= k && !beatSeen(QStringLiteral("stage%1").arg(k)))
            return QStringLiteral("stage%1").arg(k);
    }
    if (m_state.buildingsBuilt >= 1 && !beatSeen(QStringLiteral("first_build")))
        return QStringLiteral("first_build");
    if (m_state.goldEarned > 0.0 && !beatSeen(QStringLiteral("first_gold")))
        return QStringLiteral("first_gold");
    if (m_state.stage >= 2 && m_state.res[Energy] <= 0.0 && !beatSeen(QStringLiteral("blackout")))
        return QStringLiteral("blackout");
    if (m_state.unitsTrained >= 1 && !beatSeen(QStringLiteral("first_unit")))
        return QStringLiteral("first_unit");
    if (m_state.territory >= 1 && !beatSeen(QStringLiteral("first_territory")))
        return QStringLiteral("first_territory");
    return QString();
}

void WarrenController::ackNarration()
{
    const QString pending = pendingNarration();
    if (pending.isEmpty()) return;
    m_settings.setValue(QStringLiteral("narr/b_") + pending, true);
    emit stateChanged();
}

void WarrenController::ackWelcome()
{
    if (!m_welcomePending) return;
    m_welcomePending = false;
    emit stateChanged();
}

void WarrenController::clearData()
{
    m_store.clearAll();
    m_state = GameState();
    m_pendingTaps = 0;
    m_welcomePending = false;
    m_settings.remove(QStringLiteral("narr"));
    m_lastFlushMs = m_clock.nowMs();
    emit stateChanged();
    emit liveChanged();
}

} // namespace warren
