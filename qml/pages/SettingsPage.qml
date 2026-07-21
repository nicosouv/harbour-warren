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

            SectionHeader { text: qsTr("Display") }

            ComboBox {
                label: qsTr("Top margin (camera notch)")
                description: qsTr("Shifts the header clear of a front camera, e.g. on the Jolla C2.")
                currentIndex: Game.notchMargin
                menu: ContextMenu {
                    MenuItem { text: qsTr("None") }
                    MenuItem { text: qsTr("Small") }
                    MenuItem { text: qsTr("Large") }
                }
                onCurrentIndexChanged: Game.notchMargin = currentIndex
            }

            ComboBox {
                label: qsTr("Village ambiance")
                description: qsTr("An animated day/night cycle, or a fixed time of day.")
                currentIndex: Game.ambiance
                menu: ContextMenu {
                    MenuItem { text: qsTr("Day/night cycle") }
                    MenuItem { text: qsTr("Dawn") }
                    MenuItem { text: qsTr("Dusk") }
                    MenuItem { text: qsTr("Night") }
                }
                onCurrentIndexChanged: Game.ambiance = currentIndex
            }

            TextSwitch {
                text: qsTr("Reduce visual effects")
                description: qsTr("Freezes the day/night cycle and badger animations.")
                checked: Game.reduceFx
                onCheckedChanged: Game.reduceFx = checked
            }

            TextSwitch {
                text: qsTr("Full numbers")
                description: qsTr("1,234,567 instead of 1.23 M")
                checked: Game.fullNumbers
                onCheckedChanged: Game.fullNumbers = checked
            }

            SectionHeader { text: qsTr("Gameplay") }

            TextSwitch {
                text: qsTr("Fast battle animation")
                checked: Game.fastBattle
                onCheckedChanged: Game.fastBattle = checked
            }

            TextSwitch {
                text: qsTr("Haptic feedback")
                checked: Game.haptics
                onCheckedChanged: Game.haptics = checked
            }

            TextSwitch {
                text: qsTr("Notify when a raid is ready")
                checked: Game.notifyRaids
                onCheckedChanged: Game.notifyRaids = checked
            }

            TextSwitch {
                text: qsTr("Notify when the power runs out")
                checked: Game.notifyEnergy
                onCheckedChanged: Game.notifyEnergy = checked
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
