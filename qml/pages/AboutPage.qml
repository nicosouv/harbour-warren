import QtQuick 2.6
import Sailfish.Silica 1.0

// A plain, honest about page. No secrets, no theme: just what the game is, who made it, and a
// heart for the platform it was built on.
Page {
    id: page
    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + footer.height + Theme.paddingLarge

        Column {
            id: column
            width: page.width
            spacing: Theme.paddingMedium

            PageHeader { title: qsTr("About") }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall

                Label {
                    text: "Warren"
                    font.pixelSize: Theme.fontSizeExtraLarge
                    color: Theme.highlightColor
                }
                Label {
                    text: qsTr("Version") + " " + Game.appVersion
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryColor
                }
                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: qsTr("A colony idle game. Grow a warren, forage, build, keep the lights on, "
                             + "raise an army and raid your neighbours, while a narrator judges every move.")
                    font.pixelSize: Theme.fontSizeSmall
                }
                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: qsTr("Fully offline: no ads, no account, no telemetry.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryColor
                }
            }

            DetailItem { label: qsTr("Author"); value: "Nicolas Souveton" }
            DetailItem { label: qsTr("License"); value: "MIT" }

            ListItem {
                contentHeight: Theme.itemSizeSmall
                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    truncationMode: TruncationMode.Fade
                    text: qsTr("Source code")
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                onClicked: Qt.openUrlExternally("https://github.com/nicosouv/harbour-warren")
            }
        }

        // Pinned at the foot: the sign-off.
        Column {
            id: footer
            anchors { top: column.bottom; topMargin: Theme.paddingExtraLarge
                      horizontalCenter: parent.horizontalCenter }
            spacing: Theme.paddingSmall
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.RichText
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Made with %1 for Sailfish OS").arg("<font color=\"#e0405a\">♥</font>")
                font.pixelSize: Theme.fontSizeMedium
            }
        }

        VerticalScrollDecorator { }
    }
}
