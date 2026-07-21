// Thin QObject facade exposed to QML. Owns storage + clock, appends events, folds them into the
// in-memory projection, shows a live value between materialised ticks, and drives the cynical
// narrator. All game state changes go through the append-only log.
#ifndef WARREN_WARRENCONTROLLER_H
#define WARREN_WARRENCONTROLLER_H

#include <QObject>
#include <QSettings>
#include <QTimer>
#include <QVariantList>
#include <QVector>
#include "EventStore.h"
#include "GameState.h"
#include "Clock.h"

namespace warren {

class WarrenController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(bool reduceFx READ reduceFx WRITE setReduceFx NOTIFY prefsChanged)
    Q_PROPERTY(int notchMargin READ notchMargin WRITE setNotchMargin NOTIFY prefsChanged)
    Q_PROPERTY(bool notifyRaids READ notifyRaids WRITE setNotifyRaids NOTIFY prefsChanged)
    Q_PROPERTY(bool haptics READ haptics WRITE setHaptics NOTIFY prefsChanged)
    Q_PROPERTY(bool fastBattle READ fastBattle WRITE setFastBattle NOTIFY prefsChanged)
    Q_PROPERTY(bool fullNumbers READ fullNumbers WRITE setFullNumbers NOTIFY prefsChanged)
    Q_PROPERTY(bool notifyEnergy READ notifyEnergy WRITE setNotifyEnergy NOTIFY prefsChanged)
    Q_PROPERTY(int ambiance READ ambiance WRITE setAmbiance NOTIFY prefsChanged)
    Q_PROPERTY(int buildSite READ buildSite NOTIFY stateChanged)
    Q_PROPERTY(double buildProgress READ buildProgress NOTIFY liveChanged)
    Q_PROPERTY(int eventActive READ eventActiveQ NOTIFY stateChanged)
    Q_PROPERTY(int eventLevel READ eventLevelQ NOTIFY stateChanged)
    Q_PROPERTY(bool lastTapMat READ lastTapMat NOTIFY liveChanged)
    Q_PROPERTY(int builders READ builders NOTIFY stateChanged)
    Q_PROPERTY(double buildEtaSec READ buildEtaSec NOTIFY liveChanged)

    Q_PROPERTY(bool arrived READ arrived NOTIFY stateChanged)
    Q_PROPERTY(int stage READ stage NOTIFY stateChanged)
    // The next milestone that lifts the current stage — shown so the player is never guessing.
    Q_PROPERTY(QString goalKind READ goalKind NOTIFY stateChanged)
    Q_PROPERTY(int goalCurrent READ goalCurrent NOTIFY stateChanged)
    Q_PROPERTY(int goalTarget READ goalTarget NOTIFY stateChanged)

    Q_PROPERTY(QVariantList resources READ resources NOTIFY liveChanged)
    Q_PROPERTY(int population READ population NOTIFY stateChanged)
    Q_PROPERTY(int idleWorkers READ idleWorkersQ NOTIFY stateChanged)
    Q_PROPERTY(int housingCap READ housingCapQ NOTIFY stateChanged)
    Q_PROPERTY(QVariantList jobs READ jobs NOTIFY stateChanged)
    Q_PROPERTY(QVariantList buildings READ buildings NOTIFY liveChanged)

    Q_PROPERTY(bool energyActive READ energyActive NOTIFY stateChanged)
    Q_PROPERTY(bool tradingUnlocked READ tradingUnlocked NOTIFY stateChanged)
    Q_PROPERTY(bool blackout READ blackout NOTIFY liveChanged)
    Q_PROPERTY(bool starving READ starving NOTIFY liveChanged)
    Q_PROPERTY(bool growing READ growing NOTIFY liveChanged)
    Q_PROPERTY(double broodProgress READ broodProgress NOTIFY liveChanged)

    Q_PROPERTY(bool barracksUnlocked READ barracksUnlocked NOTIFY stateChanged)
    Q_PROPERTY(bool raidsUnlocked READ raidsUnlocked NOTIFY stateChanged)
    Q_PROPERTY(QVariantList units READ unitsList NOTIFY liveChanged)
    Q_PROPERTY(QVariantList targets READ targets NOTIFY liveChanged)
    Q_PROPERTY(double armyPower READ armyPowerQ NOTIFY stateChanged)
    Q_PROPERTY(int totalUnits READ totalUnitsQ NOTIFY stateChanged)
    Q_PROPERTY(int territory READ territory NOTIFY stateChanged)

    // Pixel village view inputs.
    Q_PROPERTY(int buildingsTotal READ buildingsTotal NOTIFY stateChanged)

    // Narration + welcome recap.
    Q_PROPERTY(QString pendingNarration READ pendingNarration NOTIFY stateChanged)
    Q_PROPERTY(bool welcomePending READ welcomePending NOTIFY stateChanged)
    Q_PROPERTY(double welcomeMs READ welcomeMs NOTIFY stateChanged)
    Q_PROPERTY(double welcomeGold READ welcomeGold NOTIFY stateChanged)
    Q_PROPERTY(int welcomePop READ welcomePop NOTIFY stateChanged)

public:
    explicit WarrenController(QObject* parent = nullptr);
    ~WarrenController() override;

    QString appVersion() const;
    QString language() const;
    void setLanguage(const QString& code);
    bool reduceFx() const;
    void setReduceFx(bool on);
    int notchMargin() const;
    void setNotchMargin(int level);
    bool notifyRaids() const;
    void setNotifyRaids(bool on);
    bool haptics() const;
    void setHaptics(bool on);
    bool fastBattle() const;
    void setFastBattle(bool on);
    bool fullNumbers() const;
    void setFullNumbers(bool on);
    bool notifyEnergy() const;
    void setNotifyEnergy(bool on);
    int ambiance() const;
    void setAmbiance(int mode);
    int buildSite() const;
    double buildProgress() const;
    int eventActiveQ() const;
    int eventLevelQ() const;
    bool lastTapMat() const;
    int builders() const;
    double buildEtaSec() const;

    bool arrived() const;
    int stage() const;
    QString goalKind() const;
    int goalCurrent() const;
    int goalTarget() const;

    QVariantList resources() const;
    int population() const;
    int idleWorkersQ() const;
    int housingCapQ() const;
    QVariantList jobs() const;
    QVariantList buildings() const;

    bool energyActive() const;
    bool tradingUnlocked() const;
    bool blackout() const;
    bool starving() const;
    bool growing() const;
    double broodProgress() const;

    bool barracksUnlocked() const;
    bool raidsUnlocked() const;
    QVariantList unitsList() const;
    QVariantList targets() const;
    double armyPowerQ() const;
    int totalUnitsQ() const;
    int territory() const;
    int buildingsTotal() const;

    QString pendingNarration() const;
    bool welcomePending() const;
    double welcomeMs() const;
    double welcomeGold() const;
    int welcomePop() const;

    // Formatting helper for QML.
    Q_INVOKABLE QString fmt(double value) const;

    // Stats: a downsampled time-series for a metric (population/gold/materials/food/army/territory).
    Q_INVOKABLE QVariantList series(const QString& key) const;   // [{ t, v }]
    // Records / leaderboard: personal bests with the timestamp they were set.
    Q_INVOKABLE QVariantList records() const;                     // [{ key, value, at }]
    Q_INVOKABLE QVariantList sillyStats() const;                  // [{ key, value }] — the absurd ones
    Q_INVOKABLE QVariantList globalStats() const;                 // all-time accumulators across runs
    Q_INVOKABLE void newGame();                                   // fresh run; keeps records & globals
    Q_INVOKABLE double playtimeMs() const;
    Q_INVOKABLE int eventCount() const;

    // Actions — each flushes pending accrual, then appends exactly one event.
    Q_INVOKABLE void arrive();
    Q_INVOKABLE void tap();
    Q_INVOKABLE void assign(int job, int delta);
    Q_INVOKABLE void build(int b);
    Q_INVOKABLE void buyEnergy();          // fill to cap with available gold
    Q_INVOKABLE void train(int u, int n);
    Q_INVOKABLE void raid(int t);
    Q_INVOKABLE void flushNow();
    Q_INVOKABLE void chooseEvent(int opt);
    Q_INVOKABLE void repairBuilding(int b);
    Q_INVOKABLE void ackNarration();
    Q_INVOKABLE void ackWelcome();
    Q_INVOKABLE void clearData();

signals:
    void stateChanged();
    void liveChanged();
    void languageChanged();
    void prefsChanged();
    void raidResolved(int target, int outcome, int committed, int losses);

private:
    struct Sample { qint64 t; int pop; double gold; double mat; double food; double army; int terr; };

    void appendAndApply(const QString& kind, const QString& payload);
    void appendSimple(const QString& kind, qint64 at);
    double liveRes(int res) const;
    double capOf(int res) const;
    double rateOf(int res) const;
    bool beatSeen(const QString& key) const;
    void onUiTick();
    void recordSample(qint64 t);
    void updateRecords(qint64 now);
    void bumpRecord(const QString& key, double value, qint64 now);

    SystemClock m_clock;
    EventStore  m_store;
    QSettings   m_settings;
    GameState   m_state;
    quint64     m_salt = 0;

    qint64 m_lastFlushMs = 0;
    int    m_pendingTaps = 0;
    QTimer m_uiTimer;

    bool   m_lastTapMat = false;
    bool   m_welcomePending = false;
    double m_welcomeMs = 0.0;
    double m_welcomeGold = 0.0;
    int    m_welcomePop = 0;

    QVector<Sample> m_hist;
    qint64 m_firstTs = 0;
};

} // namespace warren

#endif // WARREN_WARRENCONTROLLER_H
