#include <QtQuick>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QScopedPointer>
#include <QTranslator>
#include <QLocale>
#include <QSettings>
#include <sailfishapp.h>

#include "engine/AppId.h"
#include "engine/WarrenController.h"

int main(int argc, char* argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));

    QSettings settings(QLatin1String(warren::AppId::kOrganization),
                       QLatin1String(warren::AppId::kApplication));
    const QString chosen = settings.value(QStringLiteral("language")).toString();
    const QString locale = chosen.isEmpty() ? QLocale::system().name() : chosen;

    QTranslator translator;
    const QString trDir = SailfishApp::pathTo(QStringLiteral("translations")).toLocalFile();
    if (translator.load(QStringLiteral("harbour-warren-") + locale, trDir)
        || translator.load(QStringLiteral("harbour-warren-") + locale.left(2), trDir)) {
        app->installTranslator(&translator);
    }

    warren::WarrenController controller;

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->rootContext()->setContextProperty(QStringLiteral("Game"), &controller);
    view->setSource(SailfishApp::pathTo(QStringLiteral("qml/harbour-warren.qml")));
    view->show();

    return app->exec();
}
