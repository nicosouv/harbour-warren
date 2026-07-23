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

    m_faction = m_settings.value(QStringLiteral("faction"), 0).toInt();
    m_state = GameState();
    const QVector<Event> events = m_store.events();
    if (!events.isEmpty()) m_firstTs = events.first().tsMs;
    for (int i = 0; i < events.size(); ++i) {
        applyEvent(m_state, events.at(i), m_salt);
        recordSample(events.at(i).tsMs);
    }

    const qint64 now = m_clock.nowMs();
    if (m_firstTs == 0) m_firstTs = now;
    if (m_state.lastSeenMs > 0 && now - m_state.lastSeenMs > 5000) {
        qint64 ms = now - m_state.lastSeenMs;
        if (ms > kOfflineCapMs) ms = kOfflineCapMs;
        const double goldBefore = m_state.res[Gold];
        const double materialsBefore = m_state.res[Materials];
        const double foodBefore = m_state.res[Food];
        const int popBefore = m_state.population;
        QJsonObject p;
        p.insert(QLatin1String("ms"), static_cast<double>(ms));
        p.insert(QLatin1String("active"), false);
        p.insert(QLatin1String("at"), static_cast<double>(now));
        appendAndApply(QLatin1String("tick"),
                       QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
        m_welcomeGold = m_state.res[Gold] - goldBefore;
        m_welcomeMaterials = m_state.res[Materials] - materialsBefore;
        m_welcomeFood = m_state.res[Food] - foodBefore;
        m_welcomePop = m_state.population - popBefore;
        m_welcomeMs = static_cast<double>(ms);
        m_welcomePending = ms > kWelcomeMs;
        if (m_welcomePop > 0) {
            // Absurd-stats fodder: badgers born while you were away.
            const QString k = QStringLiteral("rec/offlineBirths_v");
            m_settings.setValue(k, m_settings.value(k, 0.0).toDouble() + m_welcomePop);
        }
    }
    m_lastFlushMs = now;
    updateRecords(now);

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

int WarrenController::notchMargin() const
{
    // 0 none / 1 small (default, the Jolla C2 camera area) / 2 large
    return m_settings.value(QStringLiteral("notchMargin"), 1).toInt();
}

void WarrenController::setNotchMargin(int level)
{
    if (level < 0) level = 0;
    if (level > 2) level = 2;
    m_settings.setValue(QStringLiteral("notchMargin"), level);
    emit prefsChanged();
}

bool WarrenController::notifyRaids() const
{
    return m_settings.value(QStringLiteral("notifyRaids"), false).toBool();
}

void WarrenController::setNotifyRaids(bool on)
{
    m_settings.setValue(QStringLiteral("notifyRaids"), on);
    emit prefsChanged();
}

bool WarrenController::haptics() const
{
    return m_settings.value(QStringLiteral("haptics"), true).toBool();
}

void WarrenController::setHaptics(bool on)
{
    m_settings.setValue(QStringLiteral("haptics"), on);
    emit prefsChanged();
}

bool WarrenController::narrator() const
{
    return m_settings.value(QStringLiteral("narrator"), true).toBool();
}

void WarrenController::setNarrator(bool on)
{
    m_settings.setValue(QStringLiteral("narrator"), on);
    emit prefsChanged();
}

bool WarrenController::fastBattle() const
{
    return m_settings.value(QStringLiteral("fastBattle"), false).toBool();
}

void WarrenController::setFastBattle(bool on)
{
    m_settings.setValue(QStringLiteral("fastBattle"), on);
    emit prefsChanged();
}

bool WarrenController::notifyEnergy() const
{
    return m_settings.value(QStringLiteral("notifyEnergy"), true).toBool();
}

void WarrenController::setNotifyEnergy(bool on)
{
    m_settings.setValue(QStringLiteral("notifyEnergy"), on);
    emit prefsChanged();
}

int WarrenController::buildSite() const { return m_state.siteBld; }
int WarrenController::eventActiveQ() const { return m_state.eventActive; }
int WarrenController::eventLevelQ() const
{
    return m_state.eventActive >= 0 ? m_state.eventLevel[m_state.eventActive] : 0;
}

void WarrenController::chooseEvent(int opt)
{
    if (m_state.eventActive < 0) return;
    flushNow();
    QJsonObject p;
    p.insert(QLatin1String("ev"), m_state.eventActive);
    p.insert(QLatin1String("opt"), opt);
    p.insert(QLatin1String("at"), static_cast<double>(m_clock.nowMs()));
    appendAndApply(QLatin1String("choose"),
                   QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
    emit stateChanged();
    emit liveChanged();
}

void WarrenController::repairBuilding(int b)
{
    if (b < 0 || b >= Balance::BldCount) return;
    flushNow();
    QJsonObject p;
    p.insert(QLatin1String("b"), b);
    p.insert(QLatin1String("at"), static_cast<double>(m_clock.nowMs()));
    appendAndApply(QLatin1String("repairbld"),
                   QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
    emit stateChanged();
    emit liveChanged();
}

double WarrenController::buildProgress() const
{
    if (m_state.siteBld < 0) return 0.0;
    // Project live between flushes, exactly like resources — otherwise the bar only jumps forward
    // when something forces a flush (e.g. assigning a builder), and looks frozen the rest of the time.
    double prog = m_state.siteProgress;
    const int b = m_state.assigned[Build];
    if (b > 0) {
        const qint64 now = m_clock.nowMs();
        double secs = (now - m_lastFlushMs) / 1000.0;
        if (secs < 0) secs = 0;
        prog += b * kJobBase[Build] * energyMult(m_state) * secs;
    }
    double p = prog / kBld[m_state.siteBld].work;
    if (p > 1.0) p = 1.0;
    if (p < 0.0) p = 0.0;
    return p;
}

QVariantList WarrenController::sillyStats() const
{
    QVariantList out;
    auto add = [&](const char* key, double v) {
        QVariantMap m;
        m.insert(QStringLiteral("key"), QLatin1String(key));
        m.insert(QStringLiteral("value"), v);
        out.append(m);
    };
    add("shovelStrikes", m_state.tapsTotal);
    add("unemployment", m_state.population > 0
        ? 100.0 * warren::idleWorkers(m_state) / m_state.population : 0.0);
    add("gdpPerBadger", m_state.population > 0
        ? m_state.goldEarned / m_state.population : 0.0);
    add("powerBills", m_state.energyBuys);
    add("foxesInconvenienced", m_state.raidsWon);
    add("formativeExperiences", m_state.raidsLost);
    add("offlineBirths", m_settings.value(QStringLiteral("rec/offlineBirths_v"), 0.0).toDouble());
    return out;
}

bool WarrenController::fullNumbers() const
{
    return m_settings.value(QStringLiteral("fullNumbers"), false).toBool();
}

void WarrenController::setFullNumbers(bool on)
{
    m_settings.setValue(QStringLiteral("fullNumbers"), on);
    emit prefsChanged();
}

bool WarrenController::arrived() const { return m_state.arrived; }
int WarrenController::factionQ() const { return m_state.faction; }
int WarrenController::stage() const { return m_state.stage; }
int WarrenController::population() const { return m_state.population; }
int WarrenController::idleWorkersQ() const { return warren::idleWorkers(m_state); }
int WarrenController::housingCapQ() const { return warren::housingCap(m_state); }
QString WarrenController::goalKind() const
{
    if (!warren::worksLand(m_state)) {          // magpie: a raid-driven reveal
        switch (m_state.stage) {
        case 0: return QStringLiteral("population");
        case 1: return QStringLiteral("raids");
        case 2: return QStringLiteral("gold");
        case 3: return QStringLiteral("territory");
        case 4: return QStringLiteral("raids");
        default: return QString();
        }
    }
    switch (m_state.stage) {
    case 0: return QStringLiteral("population");
    case 1: return QStringLiteral("buildings");
    case 2: return QStringLiteral("gold");
    case 3: return QStringLiteral("units");
    case 4: return QStringLiteral("raids");
    default: return QString();
    }
}

int WarrenController::goalCurrent() const
{
    if (!warren::worksLand(m_state)) {
        switch (m_state.stage) {
        case 0: return m_state.population;
        case 1: return m_state.raidsWon;
        case 2: return static_cast<int>(m_state.goldEarned);
        case 3: return m_state.territory;
        case 4: return m_state.raidsWon;
        default: return 0;
        }
    }
    switch (m_state.stage) {
    case 0: return m_state.population;
    case 1: return m_state.buildingsBuilt;
    case 2: return static_cast<int>(m_state.goldEarned);
    case 3: return m_state.unitsTrained;
    case 4: return m_state.raidsWon;
    default: return 0;
    }
}

int WarrenController::goalTarget() const
{
    if (!warren::worksLand(m_state)) {
        switch (m_state.stage) {
        case 0: return kStartPopulation;
        case 1: return 1;
        case 2: return static_cast<int>(kGateGoldEarned);
        case 3: return 1;
        case 4: return 3;
        default: return 0;
        }
    }
    switch (m_state.stage) {
    case 0: return kGatePopulation;
    case 1: return kGateBuildings;
    case 2: return static_cast<int>(kGateGoldEarned);
    case 3: return kGateUnitsTrained;
    case 4: return kGateRaidsWon;
    default: return 0;
    }
}

bool WarrenController::energyActive() const { return m_state.stage >= 2; }
bool WarrenController::tradingUnlocked() const { return m_state.buildings[TradingPost] >= 1; }
double WarrenController::energyFillCost() const
{
    // Gold it would take to top the store off right now — what the Fill up button spends.
    const double room = energyCap(m_state) - liveRes(Energy);
    const double affordable = liveRes(Gold) / kEnergyPrice;
    const double amount = room < affordable ? room : affordable;
    return amount > 0.0 ? amount * kEnergyPrice : 0.0;
}

double WarrenController::energyEtaSec() const
{
    // Seconds until the store runs dry at the current drain (-1 when not draining).
    const double drain = energyDrain(m_state);
    if (drain <= 0.0 || liveRes(Energy) <= 0.0) return -1.0;
    return liveRes(Energy) / drain;
}

bool WarrenController::energyLow() const
{
    return tradingUnlocked() && liveRes(Energy) < energyCap(m_state) * 0.25;
}

bool WarrenController::autoBuyEnergy() const
{
    return m_settings.value(QStringLiteral("autoBuyEnergy"), false).toBool();
}

void WarrenController::setAutoBuyEnergy(bool on)
{
    m_settings.setValue(QStringLiteral("autoBuyEnergy"), on);
    emit prefsChanged();
}
bool WarrenController::barracksUnlocked() const { return m_state.buildings[Barracks] >= 1; }
int WarrenController::trainBatch() const { const int b = m_state.buildings[Barracks]; return b > 1 ? b : 1; }
int WarrenController::lastEventResultQ() const { return m_state.lastEventResult; }
bool WarrenController::raidsUnlocked() const
{
    // Raiding is the magpie's core loop from the start, not a late-game unlock.
    return warren::worksLand(m_state) ? m_state.stage >= 4 : m_state.stage >= 1;
}
bool WarrenController::canBuildQ() const { return warren::canBuild(m_state); }
double WarrenController::armyPowerQ() const { return warren::armyPower(m_state); }
int WarrenController::totalUnitsQ() const { return warren::totalUnits(m_state); }
int WarrenController::raidForceQ() const { return warren::raidForce(m_state); }
int WarrenController::territory() const { return m_state.territory; }
int WarrenController::buildingsTotal() const { return warren::totalBuildings(m_state); }
bool WarrenController::welcomePending() const { return m_welcomePending; }
double WarrenController::welcomeMs() const { return m_welcomeMs; }
double WarrenController::welcomeGold() const { return m_welcomeGold; }
double WarrenController::welcomeMaterials() const { return m_welcomeMaterials; }
double WarrenController::welcomeFood() const { return m_welcomeFood; }
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
    // Only an electrified colony can go dark: no trading post means no lights to lose in the first
    // place. Without this gate you hit stage 2, energy sits at 0, and the whole village blacks out
    // with no way to fix it.
    return m_state.stage >= 2 && m_state.buildings[TradingPost] >= 1 && liveRes(Energy) <= 0.0;
}

bool WarrenController::starving() const
{
    return liveRes(Food) <= 0.5 && netFood(m_state) < 0.0;
}

bool WarrenController::powered() const
{
    // Trading post with energy in the tank: production and construction run 25% faster.
    return m_state.buildings[TradingPost] >= 1 && liveRes(Energy) > 0.0;
}

bool WarrenController::growing() const
{
    return m_state.population < warren::housingCap(m_state) && liveRes(Food) > kGrowthFoodFloor;
}

double WarrenController::broodProgress() const
{
    // 0..1 toward the next badger, projected live like resources. Zero when there is no room.
    if (m_state.population >= warren::housingCap(m_state)) return 0.0;
    double b = m_state.brood;
    if (liveRes(Food) > kGrowthFoodFloor) {
        const qint64 now = m_clock.nowMs();
        double secs = (now - m_lastFlushMs) / 1000.0;
        if (secs < 0) secs = 0;
        b += kGrowthRate * secs;
    }
    b -= std::floor(b);
    if (b < 0.0) b = 0.0;
    if (b > 1.0) b = 1.0;
    return b;
}

int WarrenController::ambiance() const
{
    // 0 animated day/night cycle (default) / 1 dawn / 2 dusk / 3 night
    return m_settings.value(QStringLiteral("ambiance"), 0).toInt();
}

void WarrenController::setAmbiance(int mode)
{
    if (mode < 0) mode = 0;
    if (mode > 3) mode = 3;
    m_settings.setValue(QStringLiteral("ambiance"), mode);
    emit prefsChanged();
}

QVariantList WarrenController::resources() const
{
    // The set is faction-specific: the magpie has no materials, hoards shinies, and spends stamina.
    const bool magpie = !warren::worksLand(m_state);
    static const char* const badgerKeys[ResCount] = { "food", "materials", "gold", "energy" };
    static const char* const magpieKeys[ResCount] = { "food", "materials", "shinies", "stamina" };
    const char* const* keys = magpie ? magpieKeys : badgerKeys;
    QVariantList out;
    for (int r = 0; r < ResCount; ++r) {
        bool visible;
        bool low = false;
        if (magpie) {
            if (r == Materials) visible = false;                  // magpies do not use materials
            else if (r == Gold) visible = m_state.stage >= 1;     // shinies, from pilfering and raids
            else visible = true;                                  // food, stamina
            if (r == Energy) low = liveRes(Energy) < kStaminaRaidCost;
        } else {
            if (r == Materials) visible = m_state.stage >= 1;
            else if (r == Gold || r == Energy) visible = m_state.stage >= 2;
            else visible = true;
            if (r == Energy) low = liveRes(r) <= 0.0 && m_state.stage >= 2;
        }
        QVariantMap m;
        m.insert(QStringLiteral("key"), QLatin1String(keys[r]));
        m.insert(QStringLiteral("value"), liveRes(r));
        m.insert(QStringLiteral("rate"), rateOf(r));
        m.insert(QStringLiteral("cap"), capOf(r));
        m.insert(QStringLiteral("visible"), visible);
        m.insert(QStringLiteral("low"), low);
        out.append(m);
    }
    return out;
}

QVariantList WarrenController::jobs() const
{
    static const char* const keys[JobCount] = { "forage", "gather", "mine", "build" };
    QVariantList out;
    for (int j = 0; j < JobCount; ++j) {
        bool visible = true;
        // A faction that loots instead of working the land has no gatherers, miners, or builders.
        if (j == Gather || j == MineJob) visible = warren::worksLand(m_state) && m_state.stage >= (j == MineJob ? 2 : 1);
        else if (j == Build) visible = warren::canBuild(m_state) && m_state.stage >= 1;
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
    if (!warren::canBuild(m_state)) return out;   // factions that cannot build have no building list
    for (int b = 0; b < BldCount; ++b) {
        if (m_state.stage < kBld[b].unlockStage) continue;
        const double cost = buildCost(m_state, b, 1);
        QVariantMap m;
        m.insert(QStringLiteral("index"), b);
        m.insert(QStringLiteral("key"), QLatin1String(kBld[b].id));
        m.insert(QStringLiteral("count"), m_state.buildings[b]);
        m.insert(QStringLiteral("cost"), cost);
        m.insert(QStringLiteral("affordable"),
                 m_state.siteBld < 0 && liveRes(Materials) >= cost);
        m.insert(QStringLiteral("site"), m_state.siteBld == b);
        // Live progress (projected between flushes), so the bar advances every tick, not every 30 s.
        m.insert(QStringLiteral("progress"), m_state.siteBld == b ? buildProgress() : 0.0);
        m.insert(QStringLiteral("damaged"), bldDamaged(m_state, b));
        m.insert(QStringLiteral("repairCost"), 40.0);
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
        const double cg = warren::unitCostGold(m_state, u);
        const double cm = warren::unitCostMaterials(m_state, u);
        m.insert(QStringLiteral("count"), m_state.units[u]);
        m.insert(QStringLiteral("costGold"), cg);
        m.insert(QStringLiteral("costMaterials"), cm);
        m.insert(QStringLiteral("costPop"), d.costPop);
        m.insert(QStringLiteral("power"), d.power);
        const bool afford = liveRes(Gold) >= cg && liveRes(Materials) >= cm
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
    QLocale loc;
    if (fullNumbers() && (value >= 1000.0 || value <= -1000.0))
        return loc.toString(static_cast<qint64>(value >= 0 ? value + 0.5 : value - 0.5));
    static const char* const kSuffix[] = { "", " k", " M", " B", " T", " P", " E" };
    double a = value < 0 ? -value : value;
    int i = 0;
    while (a >= 1000.0 && i < 6) { a /= 1000.0; value /= 1000.0; ++i; }
    if (i == 0) return loc.toString(value, 'f', value < 100 && value != std::floor(value) ? 1 : 0);
    return loc.toString(value, 'f', 2) + QLatin1String(kSuffix[i]);
}

void WarrenController::recordSample(qint64 t)
{
    Sample s;
    s.t = t;
    s.pop = m_state.population;
    s.gold = m_state.res[Gold];
    s.mat = m_state.res[Materials];
    s.food = m_state.res[Food];
    s.army = armyPower(m_state);
    s.terr = m_state.territory;
    m_hist.append(s);
    if (m_hist.size() > 4000) {
        QVector<Sample> slim;
        slim.reserve(m_hist.size() / 2 + 1);
        for (int i = 0; i < m_hist.size(); i += 2) slim.append(m_hist.at(i));
        m_hist = slim;
    }
}

void WarrenController::bumpRecord(const QString& key, double value, qint64 now)
{
    const QString vk = QStringLiteral("rec/") + key + QStringLiteral("_v");
    if (value > m_settings.value(vk, 0.0).toDouble()) {
        m_settings.setValue(vk, value);
        m_settings.setValue(QStringLiteral("rec/") + key + QStringLiteral("_at"),
                            static_cast<double>(now));
    }
}

void WarrenController::updateRecords(qint64 now)
{
    bumpRecord(QStringLiteral("peakPopulation"), m_state.population, now);
    bumpRecord(QStringLiteral("peakGold"), m_state.res[Gold], now);
    bumpRecord(QStringLiteral("totalGoldEarned"), m_state.goldEarned, now);
    bumpRecord(QStringLiteral("peakTerritory"), m_state.territory, now);
    bumpRecord(QStringLiteral("peakArmyPower"), armyPower(m_state), now);
    bumpRecord(QStringLiteral("raidsWon"), m_state.raidsWon, now);
    bumpRecord(QStringLiteral("unitsTrained"), m_state.unitsTrained, now);
    bumpRecord(QStringLiteral("buildingsBuilt"), m_state.buildingsBuilt, now);
    for (int k = 1; k <= 5; ++k) {
        if (m_state.stage >= k) {
            const QString sk = QStringLiteral("rec/stage%1_at").arg(k);
            if (!m_settings.contains(sk)) m_settings.setValue(sk, static_cast<double>(now));
        }
    }
}

QVariantList WarrenController::series(const QString& key) const
{
    QVariantList out;
    const int n = m_hist.size();
    if (n == 0) return out;
    const int step = n > 120 ? (n + 119) / 120 : 1;
    for (int i = 0; i < n; i += step) {
        const Sample& s = m_hist.at(i);
        double v = 0.0;
        if (key == QLatin1String("population")) v = s.pop;
        else if (key == QLatin1String("gold")) v = s.gold;
        else if (key == QLatin1String("materials")) v = s.mat;
        else if (key == QLatin1String("food")) v = s.food;
        else if (key == QLatin1String("army")) v = s.army;
        else if (key == QLatin1String("territory")) v = s.terr;
        QVariantMap m;
        m.insert(QStringLiteral("t"), static_cast<double>(s.t));
        m.insert(QStringLiteral("v"), v);
        out.append(m);
    }
    return out;
}

QVariantList WarrenController::records() const
{
    static const char* const keys[] = {
        "peakPopulation", "peakGold", "totalGoldEarned", "peakTerritory",
        "peakArmyPower", "raidsWon", "unitsTrained", "buildingsBuilt", "biggestRaidLoot"
    };
    QVariantList out;
    for (int i = 0; i < 9; ++i) {
        const QString k = QLatin1String(keys[i]);
        const double v = m_settings.value(QStringLiteral("rec/") + k + QStringLiteral("_v"), 0.0).toDouble();
        if (v <= 0.0) continue;
        QVariantMap m;
        m.insert(QStringLiteral("key"), k);
        m.insert(QStringLiteral("value"), v);
        m.insert(QStringLiteral("at"),
                 m_settings.value(QStringLiteral("rec/") + k + QStringLiteral("_at"), 0.0).toDouble());
        out.append(m);
    }
    for (int st = 1; st <= 5; ++st) {
        const QString sk = QStringLiteral("rec/stage%1_at").arg(st);
        if (m_settings.contains(sk)) {
            QVariantMap m;
            m.insert(QStringLiteral("key"), QStringLiteral("stage%1_at").arg(st));
            m.insert(QStringLiteral("value"), m_settings.value(sk).toDouble() - m_firstTs);
            m.insert(QStringLiteral("at"), m_settings.value(sk).toDouble());
            out.append(m);
        }
    }
    return out;
}

double WarrenController::playtimeMs() const
{
    return m_firstTs == 0 ? 0.0 : static_cast<double>(m_clock.nowMs() - m_firstTs);
}

int WarrenController::eventCount() const
{
    return m_store.eventCount();
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
    recordSample(now);
    updateRecords(now);
    emit stateChanged();
    emit liveChanged();
}

void WarrenController::onUiTick()
{
    const qint64 now = m_clock.nowMs();
    if (now - m_lastFlushMs >= kFlushMs) {
        flushNow();
    } else if (m_state.arrived) {
        // Bank a birth or a finished building the instant it is due — otherwise the count and the
        // construction bar sit frozen (at the last flush, or at 100%) until the next 30 s flush.
        const double secs = (now - m_lastFlushMs) / 1000.0;
        bool due = false;
        if (secs > 0.0 && growing()) {
            const double bb = m_state.brood + kGrowthRate * secs;
            if (std::floor(bb) >= 1.0) due = true;
        }
        if (!due && m_state.siteBld >= 0 && m_state.assigned[Build] > 0 && buildProgress() >= 1.0)
            due = true;
        if (due) flushNow();
    }

    // Fire an event when the seeded roll and cooldowns allow, and none is active.
    if (m_state.arrived && m_state.eventActive < 0) {
        const int ev = rollEvent(m_state, m_salt, now);
        if (ev >= 0) {
            flushNow();
            QJsonObject p;
            p.insert(QLatin1String("ev"), ev);
            p.insert(QLatin1String("at"), static_cast<double>(now));
            appendAndApply(QLatin1String("event"),
                           QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
            emit stateChanged();
        }
    }

    updateRecords(now);
    emit liveChanged();
}

void WarrenController::arrive()
{
    if (m_state.arrived) return;
    QJsonObject p;
    p.insert(QLatin1String("at"), static_cast<double>(m_clock.nowMs()));
    p.insert(QLatin1String("faction"), m_faction);   // fixed for the life of this game
    appendAndApply(QLatin1String("arrive"),
                   QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
    emit stateChanged();
    emit liveChanged();
}

void WarrenController::tap()
{
    // Predict this find so the floating reward matches what the fold will bank.
    const int idx = m_state.tapsTotal + m_pendingTaps;
    m_lastTapMat = (m_state.stage >= 1 && (idx % 4) == 3);
    m_pendingTaps += 1;
    emit liveChanged();
}

bool WarrenController::lastTapMat() const { return m_lastTapMat; }
int WarrenController::builders() const { return m_state.assigned[Build]; }

double WarrenController::buildEtaSec() const
{
    if (m_state.siteBld < 0) return -1.0;
    const int b = m_state.assigned[Build];
    if (b <= 0) return -1.0;                 // stalled: no builders
    const double rate = b * kJobBase[Build] * energyMult(m_state);
    if (rate <= 0.0) return -1.0;
    const double remaining = kBld[m_state.siteBld].work * (1.0 - buildProgress());
    return remaining / rate;
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
    if (m_state.siteBld >= 0 || m_state.res[Materials] < buildCost(m_state, b, 1)) return;
    QJsonObject p;
    p.insert(QLatin1String("b"), b);
    p.insert(QLatin1String("n"), 1);
    p.insert(QLatin1String("at"), static_cast<double>(m_clock.nowMs()));
    appendAndApply(QLatin1String("build"),
                   QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact)));
    emit stateChanged();
    emit liveChanged();
}

void WarrenController::cancelBuild()
{
    flushNow();
    if (m_state.siteBld < 0) return;
    QJsonObject p;
    p.insert(QLatin1String("at"), static_cast<double>(m_clock.nowMs()));
    appendAndApply(QLatin1String("cancelbuild"),
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
        if (m_state.lastRaidOutcome == 1 || m_state.lastRaidOutcome == 2) {
            const double sc = m_state.lastRaidOutcome == 1 ? 1.0 : kLootCostlyScale;
            bumpRecord(QStringLiteral("biggestRaidLoot"),
                       kTarget[m_state.lastRaidTarget].lootGold * sc, m_clock.nowMs());
        }
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

QVariantList WarrenController::globalStats() const
{
    auto g = [&](const char* k) {
        return m_settings.value(QStringLiteral("glob/") + QLatin1String(k), 0.0).toDouble();
    };
    QVariantList out;
    auto add = [&](const char* key, double v) {
        QVariantMap m;
        m.insert(QStringLiteral("key"), QLatin1String(key));
        m.insert(QStringLiteral("value"), v);
        out.append(m);
    };
    add("runs", g("runs") + 1);   // the current run counts
    add("totalPlaytime", g("playtime") + playtimeMs());
    add("totalGold", g("gold") + m_state.goldEarned);
    add("totalRaids", g("raidsWon") + m_state.raidsWon);
    add("totalTaps", g("taps") + m_state.tapsTotal);
    return out;
}

void WarrenController::newGame(int faction)
{
    flushNow();
    if (faction < 0 || faction >= kFactionCount) faction = 0;
    m_faction = faction;
    m_settings.setValue(QStringLiteral("faction"), faction);
    // Bank this run into the all-time ledger, then start clean. Records (rec/*) survive.
    auto bump = [&](const char* k, double v) {
        const QString key = QStringLiteral("glob/") + QLatin1String(k);
        m_settings.setValue(key, m_settings.value(key, 0.0).toDouble() + v);
    };
    bump("runs", 1);
    bump("playtime", playtimeMs());
    bump("gold", m_state.goldEarned);
    bump("raidsWon", m_state.raidsWon);
    bump("taps", m_state.tapsTotal);

    m_store.clearAll();
    m_state = GameState();
    m_pendingTaps = 0;
    m_welcomePending = false;
    m_hist.clear();
    m_firstTs = m_clock.nowMs();
    m_settings.remove(QStringLiteral("narr"));   // fresh narration for a fresh run
    m_lastFlushMs = m_clock.nowMs();
    emit stateChanged();
    emit liveChanged();
}

void WarrenController::clearData()
{
    m_store.clearAll();
    m_state = GameState();
    m_pendingTaps = 0;
    m_welcomePending = false;
    m_hist.clear();
    m_firstTs = m_clock.nowMs();
    m_settings.remove(QStringLiteral("narr"));
    m_settings.remove(QStringLiteral("rec"));
    m_settings.remove(QStringLiteral("glob"));
    m_lastFlushMs = m_clock.nowMs();
    emit stateChanged();
    emit liveChanged();
}

} // namespace warren
