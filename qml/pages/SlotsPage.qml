import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"

// The save slots: resume an existing game, or start a fresh one in an empty (or overwritten) slot.
Page {
    id: page
    allowedOrientations: Orientation.All
    property var home: null          // the colony page, to return to once a slot is active

    property var slotList: Game.saveSlots()
    onStatusChanged: if (status === PageStatus.Active) slotList = Game.saveSlots()

    function factionName(f) {
        return f === 1 ? qsTr("Magpies") : f === 2 ? qsTr("Ants")
             : f === 3 ? qsTr("Rabbits") : qsTr("Badgers")
    }
    function critterOf(f) { return f === 1 ? magpieC : f === 2 ? antC : f === 3 ? rabbitC : badgerC }
    function pickFaction(slot) {
        pageStack.push(Qt.resolvedUrl("FactionSelectPage.qml"), { slot: slot, home: page.home })
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height

        Column {
            id: col
            width: page.width
            PageHeader { title: qsTr("Games") }

            Repeater {
                model: page.slotList
                ListItem {
                    width: col.width
                    contentHeight: Theme.itemSizeLarge
                    onClicked: {
                        if (modelData.exists) { Game.switchSlot(modelData.index)
                            if (page.home) pageStack.pop(page.home); else pageStack.pop() }
                        else pickFaction(modelData.index)
                    }
                    menu: Component {
                        ContextMenu {
                            MenuItem {
                                text: modelData.exists ? qsTr("Start over") : qsTr("New game")
                                onClicked: pickFaction(modelData.index)
                            }
                        }
                    }
                    Loader {
                        id: cr
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.iconSizeMedium; height: width
                        sourceComponent: modelData.exists ? critterOf(modelData.faction) : emptyC
                    }
                    Column {
                        anchors { left: cr.right; leftMargin: Theme.paddingLarge
                                  right: parent.right; rightMargin: Theme.horizontalPageMargin
                                  verticalCenter: parent.verticalCenter }
                        Label {
                            text: qsTr("Slot") + " " + (modelData.index + 1)
                                  + (modelData.active ? "  ·  " + qsTr("current") : "")
                            font.pixelSize: Theme.fontSizeLarge
                            color: modelData.active ? Theme.highlightColor : Theme.primaryColor
                        }
                        Label {
                            text: modelData.exists
                                  ? factionName(modelData.faction) + "  ·  " + qsTr("stage") + " " + modelData.stage
                                  : qsTr("Empty. Tap to start.")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
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
    Component { id: emptyC; Item {} }
}
