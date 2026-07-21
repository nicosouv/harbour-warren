#ifndef WARREN_ACTIVATOR_H
#define WARREN_ACTIVATOR_H

#include <QObject>
#include <QQuickView>

// Raises the running window when the notification's D-Bus action fires. It is registered on the
// session bus in main() the moment the app owns harbour.warren, so a tapped notification always
// reaches the live instance instead of spawning a second one.
class Activator : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "harbour.warren")
public:
    explicit Activator(QQuickView* view, QObject* parent = nullptr)
        : QObject(parent), m_view(view) {}

public slots:
    void openApp()
    {
        if (!m_view) return;
        m_view->showFullScreen();
        m_view->raise();
        m_view->requestActivate();
    }

private:
    QQuickView* m_view;
};

#endif // WARREN_ACTIVATOR_H
