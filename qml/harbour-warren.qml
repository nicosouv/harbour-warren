import QtQuick 2.6
import Sailfish.Silica 1.0
import QtGraphicalEffects 1.0
import "pages"
import "cover"

ApplicationWindow {
    id: app

    function resName(key) {
        if (key === "food") return qsTr("Food")
        if (key === "materials") return qsTr("Materials")
        if (key === "gold") return qsTr("Gold")
        if (key === "energy") return qsTr("Energy")
        return key
    }
    function resColor(key) {
        if (key === "food") return "#7da33f"
        if (key === "materials") return "#b0895a"
        if (key === "gold") return "#e0b23a"
        if (key === "energy") return "#3ab5a6"
        return "#999999"
    }
    function jobName(key) {
        if (key === "forage") return qsTr("Forage")
        if (key === "gather") return qsTr("Gather")
        if (key === "mine") return qsTr("Mine")
        return key
    }
    function bldName(key) {
        if (key === "burrow") return qsTr("Burrow")
        if (key === "granary") return qsTr("Granary")
        if (key === "workshop") return qsTr("Workshop")
        if (key === "mineshaft") return qsTr("Mine shaft")
        if (key === "tradingpost") return qsTr("Trading post")
        if (key === "barracks") return qsTr("Barracks")
        return key
    }
    function unitName(key) {
        if (key === "militia") return qsTr("Militia")
        if (key === "veteran") return qsTr("Veteran")
        return key
    }
    function targetName(key) {
        if (key === "cache") return qsTr("Abandoned cache")
        if (key === "foragers") return qsTr("Rival foragers")
        if (key === "mill") return qsTr("The old mill")
        if (key === "warren") return qsTr("A rival warren")
        if (key === "keep") return qsTr("The stone keep")
        if (key === "fort") return qsTr("The border fort")
        return key
    }

    function narrationText(key) {
        if (key === "stage1") return qsTr("Materials. Because a hole in the ground wasn't ambitious enough.")
        if (key === "stage2") return qsTr("Gold and a power bill. Congratulations, you've invented civilisation.")
        if (key === "stage3") return qsTr("A barracks. Nothing says 'thriving community' like weapons.")
        if (key === "stage4") return qsTr("Neighbours. With things you don't have yet. We'll fix that.")
        if (key === "stage5") return qsTr("Veterans and bigger targets. The ambition is almost touching.")
        if (key === "first_build") return qsTr("Your first building. It won't last, but well done.")
        if (key === "first_gold") return qsTr("Gold. Now you have something worth losing.")
        if (key === "blackout") return qsTr("The lights are off. The genius who managed the budget was you, correct?")
        if (key === "first_unit") return qsTr("You armed a badger. This ends one of two ways.")
        if (key === "first_territory") return qsTr("You took someone's land. They were probably using it.")
        return ""
    }
    function narrationButton(key) {
        if (key === "stage1") return qsTr("Dig on.")
        if (key === "stage2") return qsTr("Wonderful.")
        if (key === "stage3") return qsTr("Naturally.")
        if (key === "stage4") return qsTr("We shall.")
        if (key === "stage5") return qsTr("Onward.")
        if (key === "first_build") return qsTr("Thanks.")
        if (key === "first_gold") return qsTr("Lovely.")
        if (key === "blackout") return qsTr("…Yes.")
        if (key === "first_unit") return qsTr("Onward.")
        if (key === "first_territory") return qsTr("Probably.")
        return qsTr("Onward.")
    }
    function raidOutcomeText(outcome) {
        if (outcome === 1) return qsTr("A decisive victory. Try not to let it go to your head.")
        if (outcome === 2) return qsTr("A victory. Most of them even came back.")
        if (outcome === 3) return qsTr("A rout. But the important thing is you tried, apparently.")
        return ""
    }

    initialPage: Component { ColonyPage { } }
    cover: Component { CoverPage { } }
    allowedOrientations: defaultAllowedOrientations

    function maybeNarrate() {
        if (narrator.line !== "" || battle.visible || welcome.visible || !Game.arrived)
            return
        var key = Game.pendingNarration
        if (key !== "") {
            narrator.key = key
            narrator.line = narrationText(key)
            narrator.button = narrationButton(key)
        }
    }

    Component.onCompleted: maybeNarrate()

    Connections {
        target: Qt.application
        onActiveChanged: {
            if (!Qt.application.active) Game.flushNow()
            else app.maybeNarrate()
        }
    }
    Connections {
        target: Game
        onStateChanged: app.maybeNarrate()
        onRaidResolved: battle.play(target, outcome, committed, losses)
    }

    // A frosted backdrop reused by every overlay: the page behind, blurred and dimmed.
    Component {
        id: backdrop
        Item {
            property bool active: false
            ShaderEffectSource {
                id: grab; anchors.fill: parent; sourceItem: pageStack
                live: active && !Game.reduceFx; hideSource: false; visible: false
            }
            FastBlur { anchors.fill: parent; source: grab; radius: 48; visible: !Game.reduceFx }
            Rectangle { anchors.fill: parent; color: "#101218"; opacity: Game.reduceFx ? 0.97 : 0.5 }
        }
    }

    // The narrator's card: a dry remark you have to acknowledge.
    Item {
        id: narrator
        property string key: ""
        property string line: ""
        property string button: ""
        anchors.fill: parent
        z: 8000
        visible: line !== ""

        Loader { anchors.fill: parent; sourceComponent: backdrop; onLoaded: item.active = Qt.binding(function(){ return narrator.visible }) }
        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: narrCol.height + 2 * Theme.paddingLarge
            color: Theme.rgba("#0e1016", 0.9)
            scale: narrator.visible ? 1 : 0.9
            opacity: narrator.visible ? 1 : 0
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Column {
                id: narrCol
                anchors { top: parent.top; topMargin: Theme.paddingLarge
                          left: parent.left; right: parent.right
                          leftMargin: Theme.horizontalPageMargin; rightMargin: Theme.horizontalPageMargin }
                spacing: Theme.paddingMedium
                Label {
                    width: parent.width; wrapMode: Text.Wrap; text: narrator.line
                    font.pixelSize: Theme.fontSizeMedium; font.italic: true; color: Theme.primaryColor
                }
                Button {
                    anchors.right: parent.right; text: narrator.button
                    onClicked: { Game.ackNarration(); narrator.line = ""; app.maybeNarrate() }
                }
            }
        }
    }

    // Coming back after a while: the colony reports, unimpressed.
    Item {
        id: welcome
        anchors.fill: parent
        z: 8500
        visible: Game.welcomePending && Game.arrived
        function dur(ms) {
            var d = Math.floor(ms / 86400000), h = Math.floor((ms % 86400000) / 3600000), m = Math.floor((ms % 3600000) / 60000)
            if (d >= 1) return d + " j " + h + " h"
            if (h >= 1) return h + " h " + m + " min"
            return m + " min"
        }
        Loader { anchors.fill: parent; sourceComponent: backdrop; onLoaded: item.active = Qt.binding(function(){ return welcome.visible }) }
        MouseArea { anchors.fill: parent }
        Column {
            anchors.centerIn: parent
            width: parent.width - 4 * Theme.horizontalPageMargin
            spacing: Theme.paddingLarge
            scale: welcome.visible ? 1 : 0.9
            opacity: welcome.visible ? 1 : 0
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 250 } }
            Label {
                width: parent.width; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                text: qsTr("The colony carried on without you. Try not to take it personally.")
                font.pixelSize: Theme.fontSizeLarge; color: Theme.highlightColor
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: welcome.dur(Game.welcomeMs) + (Game.welcomeGold > 0 ? "   ·   +" + Game.fmt(Game.welcomeGold) + " " + qsTr("Gold") : "")
                      + (Game.welcomePop > 0 ? "   ·   +" + Game.welcomePop + " " + qsTr("badgers") : "")
                font.pixelSize: Theme.fontSizeSmall; color: Theme.secondaryColor
            }
            Button { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Back to it."); onClicked: Game.ackWelcome() }
        }
    }

    // The raid, shown: two ranks meet, some don't come back.
    Item {
        id: battle
        anchors.fill: parent
        z: 8600
        visible: false
        property int outcome: 0
        property int committed: 0
        property int losses: 0
        property real clash: 0
        function play(target, oc, comm, loss) {
            outcome = oc; committed = comm; losses = loss
            clash = 0; resultLabel.visible = false; visible = true; anim.restart()
        }
        Loader { anchors.fill: parent; sourceComponent: backdrop; onLoaded: item.active = Qt.binding(function(){ return battle.visible }) }
        MouseArea { anchors.fill: parent }

        Row {
            id: attackers
            anchors { verticalCenter: parent.verticalCenter; verticalCenterOffset: -Theme.itemSizeSmall }
            x: parent.width * 0.12 + battle.clash * parent.width * 0.24
            spacing: 3
            Repeater {
                model: Math.min(24, battle.committed)
                Rectangle {
                    width: Theme.paddingMedium; height: Theme.paddingLarge; radius: 1; color: "#2b2b30"
                    opacity: (index >= Math.min(24, battle.committed) - Math.round(battle.losses * 24 / Math.max(1, battle.committed)) && battle.clash >= 1) ? 0.12 : 1
                    Rectangle { width: parent.width; height: 3; color: "#e6e0d4"; anchors.top: parent.top }
                    Behavior on opacity { NumberAnimation { duration: 400 } }
                }
            }
        }
        Row {
            id: defenders
            anchors { verticalCenter: parent.verticalCenter; verticalCenterOffset: Theme.itemSizeSmall }
            x: parent.width * 0.88 - width - battle.clash * parent.width * 0.24
            spacing: 3
            layoutDirection: Qt.RightToLeft
            Repeater { model: 14; Rectangle { width: Theme.paddingMedium; height: Theme.paddingLarge; radius: 1; color: "#7a3a3a" } }
        }
        SequentialAnimation {
            id: anim
            NumberAnimation { target: battle; property: "clash"; from: 0; to: 1; duration: 900; easing.type: Easing.InCubic }
            ScriptAction { script: resultLabel.visible = true }
        }
        Column {
            anchors { bottom: parent.bottom; bottomMargin: Theme.itemSizeLarge; horizontalCenter: parent.horizontalCenter }
            width: parent.width - 4 * Theme.horizontalPageMargin
            spacing: Theme.paddingLarge
            Label {
                id: resultLabel; visible: false
                width: parent.width; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                text: app.raidOutcomeText(battle.outcome)
                font.pixelSize: Theme.fontSizeMedium; font.italic: true
                color: battle.outcome === 3 ? "#c0603a" : Theme.highlightColor
            }
            Button {
                visible: resultLabel.visible; anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Continue")
                onClicked: { battle.visible = false; app.maybeNarrate() }
            }
        }
    }

    // First launch: the narrator sets expectations low.
    Rectangle {
        id: intro
        anchors.fill: parent
        z: 9000
        color: "#161a20"
        opacity: Game.arrived ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 1000 } }
        MouseArea { anchors.fill: parent }
        Column {
            anchors.centerIn: parent
            width: parent.width - 4 * Theme.horizontalPageMargin
            spacing: Theme.paddingLarge
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Warren"; font.pixelSize: Theme.fontSizeHuge; color: Theme.highlightColor }
            Label {
                width: parent.width; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                text: qsTr("You have four badgers and a hole in the ground. Make something of it, or don't. I'll be here either way.")
                font.pixelSize: Theme.fontSizeMedium; font.italic: true; color: Theme.primaryColor
            }
            Button { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Start digging"); onClicked: Game.arrive() }
        }
    }
}
