TEMPLATE = app
TARGET = tst_warren

QT += core sql testlib
QT -= gui
CONFIG += c++17 console testcase
CONFIG -= app_bundle

INCLUDEPATH += ../src

SOURCES += tst_main.cpp \
    ../src/engine/Rng.cpp \
    ../src/engine/EventStore.cpp \
    ../src/engine/StateProjection.cpp

HEADERS += ../src/engine/AppId.h \
    ../src/engine/Balance.h \
    ../src/engine/Clock.h \
    ../src/engine/Rng.h \
    ../src/engine/EventStore.h \
    ../src/engine/GameState.h \
    ../src/engine/StateProjection.h
