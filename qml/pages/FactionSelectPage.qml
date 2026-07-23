import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"

// New game: pick a faction. Reached from the pull-down menu; starting one wipes the current run.
Page {
    id: page
    allowedOrientations: Orientation.All

    property var factions: [
        { idx: 0, key: "badger", name: qsTr("Badgers"),
          tag: qsTr("Build, mine, and raise an army. The baseline faction.") },
        { idx: 1, key: "magpie", name: qsTr("Magpies"),
          tag: qsTr("Cannot build. A flock of thieves that lives by raiding.") },
        { idx: 2, key: "ant", name: qsTr("Ants"),
          tag: qsTr("A vast swarm. Breeds fast; feed the queen to hold it together.") }
    ]

    RemorsePopup { id: rem }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height

        Column {
            id: col
            width: page.width

            PageHeader { title: qsTr("Choose a faction") }

            Repeater {
                model: page.factions
                BackgroundItem {
                    width: col.width
                    height: Theme.itemSizeLarge
                    onClicked: rem.execute(qsTr("Starting a new game"), function() {
                        Game.newGame(modelData.idx)
                        pageStack.pop()
                    })

                    Loader {
                        id: critter
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.iconSizeMedium; height: width
                        sourceComponent: modelData.key === "magpie" ? magpieC
                                         : modelData.key === "ant" ? antC : badgerC
                    }
                    Column {
                        anchors { left: critter.right; leftMargin: Theme.paddingLarge
                                  right: parent.right; rightMargin: Theme.horizontalPageMargin
                                  verticalCenter: parent.verticalCenter }
                        Label { text: modelData.name; font.pixelSize: Theme.fontSizeLarge; color: Theme.primaryColor }
                        Label {
                            text: modelData.tag; width: parent.width; wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontSizeExtraSmall; color: Theme.secondaryColor
                        }
                    }
                }
            }
        }
        VerticalScrollDecorator { }
    }

    Component { id: badgerC; PixelBadger {} }
    Component { id: magpieC; PixelMagpie {} }
    Component { id: antC; PixelAnt {} }
}
