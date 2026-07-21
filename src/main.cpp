#include <QtQuick>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QScopedPointer>
#include <QTranslator>
#include <QLocale>
#include <QSettings>
#include <QDBusConnection>
#include <QDBusMessage>
#include <sailfishapp.h>

#include "Activator.h"
#include "engine/AppId.h"
#include "engine/WarrenController.h"

int main(int argc, char* argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));

    // Single instance. Own harbour.warren up front; if it is already taken, another copy is
    // running — ask it to come forward and quit, so a notification never opens a second warren.
    QDBusConnection bus = QDBusConnection::sessionBus();
    const QString kService = QStringLiteral("harbour.warren");
    if (!bus.registerService(kService)) {
        bus.call(QDBusMessage::createMethodCall(kService, QStringLiteral("/"),
                                                kService, QStringLiteral("openApp")));
        return 0;
    }

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

    // Handle the notification's raise request in this instance.
    Activator activator(view.data());
    bus.registerObject(QStringLiteral("/"), &activator, QDBusConnection::ExportAllSlots);

    return app->exec();
}
