import QtQuick 2.6
import Sailfish.Silica 1.0

// The faction's recharge mechanic, surfaced as one titled panel with four faces: the badger's
// bought energy, the ant queen's pheromone, the rabbit warren's vigilance, the magpie roost's
// stamina. Every faction page drops this in. Needs `app` for buzz/quip; reads Game directly.
Column {
    id: panel
    property var app
    property int faction: Game.faction

    // The recharge pool always lives in the Energy slot (index 3) of the resource list.
    property var rech: (Game.resources && Game.resources.length > 3)
                       ? Game.resources[3] : ({ value: 0, cap: 1, rate: 0, key: "energy", low: false })
    property real value: rech.value
    property real cap: rech.cap > 0 ? rech.cap : 1
    property real rate: rech.rate                 // per second: < 0 drains, > 0 rests back
    property color tint: app ? app.accent() : "#c9a24a"
    property bool tapsToRecharge: faction === 2 || faction === 3   // ant/rabbit act by tapping
    // Seconds until the pool hits the penalty floor (for the "time left" hint).
    property real etaSec: faction === 0 ? Game.energyEtaSec : (rate < 0 ? value / (-rate) : 0)

    spacing: Theme.paddingSmall

    function fmtEta(sec) {
        var s = Math.ceil(sec)
        if (s >= 3600) return Math.floor(s / 3600) + " h " + Math.floor((s % 3600) / 60) + " min"
        if (s >= 60) return Math.floor(s / 60) + " min"
        return s + " s"
    }
    function title() {
        return faction === 1 ? qsTr("The roost")
             : faction === 2 ? qsTr("The queen")
             : faction === 3 ? qsTr("The watch")
             : qsTr("Energy")
    }
    function statusLine() {
        if (faction === 0) return Game.blackout ? qsTr("The lights are out.")
                                : (Game.energyEtaSec > 0 ? fmtEta(Game.energyEtaSec) + " " + qsTr("left") : "")
        if (value <= 0)
            return faction === 2 ? qsTr("The queen has gone quiet.")
                 : faction === 3 ? qsTr("Unwatched: predators are circling.")
                 : qsTr("Spent.")
        if (rate < 0 && etaSec > 0) return fmtEta(etaSec) + " " + qsTr("left")
        return ""
    }
    function effectLine() {
        if (faction === 0) return Game.powered ? qsTr("Powered: +25% production and building")
                                : Game.blackout ? qsTr("Blackout: −30% production and building")
                                : qsTr("Keep it powered: +25% production and building")
        if (faction === 2) return value <= 0 ? qsTr("−40% production until she is fed")
                                : qsTr("Feed the queen to keep production at 100%")
        if (faction === 3) return value <= 0 ? qsTr("The warren is being culled")
                                : qsTr("A posted watch keeps predators off")
        return value < panel.cap * 0.3 ? qsTr("Too tired to raid at full strength")
                                       : qsTr("Rested: ready to raid")
    }

    // Badger with no trading post: energy matters but there is nothing to buy from yet.
    SectionHeader { text: panel.title() }

    BackgroundItem {
        visible: Game.buysEnergy && Game.energyActive && !Game.tradingUnlocked
        width: parent.width; height: Theme.itemSizeMedium; enabled: false
        Image {
            id: hintIcon
            x: Theme.horizontalPageMargin; anchors.verticalCenter: parent.verticalCenter
            source: Qt.resolvedUrl("../images/res-energy.png"); smooth: false
            width: Theme.iconSizeMedium; height: width; fillMode: Image.PreserveAspectFit; opacity: 0.5
        }
        Label {
            anchors { left: hintIcon.right; leftMargin: Theme.paddingMedium; right: parent.right
                      rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
            text: qsTr("Build a trading post to buy energy and power the colony.")
            wrapMode: Text.WordWrap; font.pixelSize: Theme.fontSizeSmall; color: Theme.secondaryColor
        }
    }

    // The live panel: icon, status + effect + gauge, and an action on the right.
    BackgroundItem {
        // Badger shows it once a trading post exists; tap-recharge factions always show it; the
        // magpie's stamina just displays (it rests on its own, no button).
        visible: panel.tapsToRecharge || panel.faction === 1
                 || (Game.buysEnergy && Game.tradingUnlocked)
        width: parent.width; height: Theme.itemSizeLarge
        enabled: panel.tapsToRecharge || (panel.faction === 0 && Game.tradingUnlocked)
        onClicked: {
            if (panel.tapsToRecharge) { Game.tap(); if (app) { app.buzz(); app.quip(panel.faction === 2 ? "feedqueen" : "watch") } }
            else if (panel.faction === 0) { Game.buyEnergy(); if (app) { app.buzz(); app.quip("buyenergy") } }
        }

        Image {
            id: pIcon
            x: Theme.horizontalPageMargin; anchors.verticalCenter: parent.verticalCenter
            source: Qt.resolvedUrl("../images/res-" + panel.rech.key + ".png"); smooth: false
            width: Theme.iconSizeMedium; height: width; fillMode: Image.PreserveAspectFit
        }
        Column {
            anchors { left: pIcon.right; leftMargin: Theme.paddingMedium
                      right: actionCol.left; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
            spacing: 2
            Label {
                visible: text.length > 0
                width: parent.width; truncationMode: TruncationMode.Fade
                text: panel.statusLine()
                font.pixelSize: Theme.fontSizeSmall
                color: panel.value <= 0 ? "#c0603a" : Theme.primaryColor
            }
            Label {
                width: parent.width; truncationMode: TruncationMode.Fade
                text: panel.effectLine()
                font.pixelSize: Theme.fontSizeExtraSmall
                color: (panel.faction === 0 && Game.powered) ? "#3ab5a6"
                     : panel.value <= 0 ? "#c0603a" : Theme.secondaryColor
            }
            Rectangle {
                width: parent.width; height: 6; radius: 2
                color: Theme.rgba(Theme.primaryColor, 0.15)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, panel.value / panel.cap))
                    height: parent.height; radius: 2
                    color: panel.value <= 0 ? "#c0603a" : panel.tint
                    Behavior on width { NumberAnimation { duration: 400 } }
                }
            }
        }
        Column {
            id: actionCol
            anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
            spacing: 2
            // The badger buys with gold; ant/rabbit tap; the magpie just rests (no action shown).
            Label {
                anchors.right: parent.right
                visible: panel.faction !== 1
                text: panel.faction === 2 ? qsTr("Feed the queen")
                    : panel.faction === 3 ? qsTr("Post a lookout")
                    : qsTr("Fill up")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
            }
            Row {
                anchors.right: parent.right
                spacing: 3
                visible: panel.faction === 0 && Game.energyFillCost > 0
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: Qt.resolvedUrl("../images/res-gold.png")
                    smooth: false; width: Theme.iconSizeExtraSmall * 0.7; height: width
                    fillMode: Image.PreserveAspectFit
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Game.fmt(Game.energyFillCost)
                    font.pixelSize: Theme.fontSizeExtraSmall; font.family: "Monospace"
                    color: Theme.secondaryColor
                }
            }
        }
    }
}
