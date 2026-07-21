import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: page.width

            PageHeader { title: qsTr("Settings") }

            ComboBox {
                label: qsTr("Language")
                description: qsTr("Takes effect after restarting the app.")
                currentIndex: Game.language === "en" ? 1 : Game.language === "fr" ? 2 : 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("System default") }
                    MenuItem { text: "English" }
                    MenuItem { text: "Français" }
                }
                onCurrentIndexChanged: Game.language = currentIndex === 1 ? "en" : currentIndex === 2 ? "fr" : ""
            }

            SectionHeader { text: qsTr("Data") }

            ListItem {
                contentHeight: Theme.itemSizeSmall
                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Clear all data")
                }
                RemorseItem { id: clearRemorse }
                onClicked: clearRemorse.execute(parent, qsTr("Clearing all data"), function() { Game.clearData() })
            }

            SectionHeader { text: qsTr("About") }
            DetailItem { label: qsTr("Version"); value: Game.appVersion }
        }

        VerticalScrollDecorator { }
    }
}
