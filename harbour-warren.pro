TARGET = harbour-warren

CONFIG += sailfishapp
CONFIG += c++17

isEmpty(VERSION) {
    VERSION = 0.1.0
}
DEFINES += APP_VERSION=\\\"$$VERSION\\\"

SOURCES += src/main.cpp \
    src/engine/Rng.cpp \
    src/engine/EventStore.cpp \
    src/engine/StateProjection.cpp \
    src/engine/WarrenController.cpp

HEADERS += src/engine/AppId.h \
    src/engine/Balance.h \
    src/engine/Clock.h \
    src/engine/Rng.h \
    src/engine/EventStore.h \
    src/engine/GameState.h \
    src/engine/StateProjection.h \
    src/engine/WarrenController.h

QT += sql

DISTFILES += qml/harbour-warren.qml \
    qml/cover/CoverPage.qml \
    qml/pages/ColonyPage.qml \
    qml/pages/SettingsPage.qml \
    qml/pages/StatsPage.qml \
    qml/components/VillageView.qml \
    rpm/harbour-warren.spec \
    harbour-warren.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

CONFIG += sailfishapp_i18n

TRANSLATIONS += translations/harbour-warren-en.ts \
                translations/harbour-warren-fr.ts
