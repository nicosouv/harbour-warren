import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"

// New game: pick a faction. Reached from the pull-down menu; starting one wipes the current run.
Page {
    id: page
    allowedOrientations: Orientation.All

    property int slot: 0        // which save slot this new game goes into
    property var home: null     // page to return to once a game is started (the colony)

    property var factions: [
        { idx: 0, key: "badger", name: qsTr("Badgers"),
          tag: qsTr("Build, mine, and raise an army. The baseline faction.") },
        { idx: 1, key: "magpie", name: qsTr("Magpies"),
          tag: qsTr("Cannot build. A flock of thieves that lives by raiding.") },
        { idx: 2, key: "ant", name: qsTr("Ants"),
          tag: qsTr("A vast swarm. Breeds fast; feed the queen to hold it together.") },
        { idx: 3, key: "rabbit", name: qsTr("Rabbits"),
          tag: qsTr("Breeds fastest of all, but fragile. Post lookouts or predators cull the warren.") }
    ]

    // Onboarding C: only the badger is available until the core loop (a raid win) is learnt.
    property var defs: Game.factionDefs()
    function isUnlocked(idx) {
        for (var i = 0; i < defs.length; i++) if (defs[i].index === idx) return defs[i].unlocked
        return true
    }

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
                    property bool unlocked: page.isUnlocked(modelData.idx)
                    enabled: unlocked
                    onClicked: rem.execute(qsTr("Starting a new game"), function() {
                        Game.createSlot(page.slot, modelData.idx)
                        if (page.home) pageStack.pop(page.home)
                        else pageStack.pop()
                    })

                    Loader {
                        id: critter
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.iconSizeMedium; height: width
                        opacity: parent.unlocked ? 1.0 : 0.35
                        sourceComponent: modelData.key === "magpie" ? magpieC
                                         : modelData.key === "ant" ? antC
                                         : modelData.key === "rabbit" ? rabbitC : badgerC
                    }
                    Column {
                        anchors { left: critter.right; leftMargin: Theme.paddingLarge
                                  right: parent.right; rightMargin: Theme.horizontalPageMargin
                                  verticalCenter: parent.verticalCenter }
                        Label {
                            text: modelData.name; font.pixelSize: Theme.fontSizeLarge
                            color: parent.parent.unlocked ? Theme.primaryColor : Theme.secondaryColor
                        }
                        Label {
                            text: parent.parent.unlocked ? modelData.tag
                                  : qsTr("Locked. Win a raid as the badgers to unlock.")
                            width: parent.width; wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: parent.parent.unlocked ? Theme.secondaryColor : "#c0a24a"
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
    Component { id: rabbitC; PixelRabbit {} }
}
