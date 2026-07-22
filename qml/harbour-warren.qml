import QtQuick 2.6
import Sailfish.Silica 1.0
import QtGraphicalEffects 1.0
import Nemo.Notifications 1.0
import Nemo.DBus 2.0
import "pages"
import "cover"
import "components"

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
        if (key === "build") return qsTr("Build")
        return key
    }
    function bldName(key) {
        if (key === "burrow") return qsTr("Burrow")
        if (key === "granary") return qsTr("Granary")
        if (key === "workshop") return qsTr("Workshop")
        if (key === "mineshaft") return qsTr("Mine shaft")
        if (key === "tradingpost") return qsTr("Trading post")
        if (key === "barracks") return qsTr("Barracks")
        if (key === "watchtower") return qsTr("Watchtower")
        if (key === "watermill") return qsTr("Watermill")
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

    // --- Narrator quips: short, recurring, non-blocking. One line picked at random per key. ------
    function quipText(key) {
        var pool = []
        if (key === "assign") pool = [
            qsTr("Another badger put to work. You are basically a manager now."),
            qsTr("You reassigned a badger. It had dreams, probably."),
            qsTr("Micromanaging holes. A noble calling.")]
        else if (key === "build") pool = [
            qsTr("Another building. Napoleon thought that would be enough too."),
            qsTr("Construction begins. The badgers pretend to know how.")]
        else if (key === "train") pool = [
            qsTr("You armed another badger. What could possibly go wrong."),
            qsTr("One more soldier. The forage rota will miss them.")]
        else if (key === "buyenergy") pool = [
            qsTr("You bought electricity. It costs money, like everything you love."),
            qsTr("Power purchased. The lights thank you, briefly.")]
        else if (key === "scavenge") pool = [
            qsTr("You scratch the dirt. It scratches back, metaphorically."),
            qsTr("More rummaging. Dust, mostly."),
            qsTr("Digging with intent. The intent is unclear.")]
        else if (key === "grow") pool = [
            qsTr("A new badger. More opinions to ignore."),
            qsTr("The colony grew. So did the food bill.")]
        else if (key === "blackout") pool = [
            qsTr("The lights went out. Just like your plans.")]
        else if (key === "powered") pool = [
            qsTr("Power is back. Try to keep it that way.")]
        else if (key === "housing_full") pool = [
            qsTr("The burrows are full. Build another, or stop breeding.")]
        else if (key === "idle") pool = [
            qsTr("There are idle badgers and a shiny button. Coincidence?")]
        if (pool.length === 0) return ""
        return pool[Math.floor(Math.random() * pool.length)]
    }
    // Enqueue a quip for the floating toast, honouring the Settings toggle.
    function quip(key) {
        if (!Game.narrator) return
        var t = quipText(key)
        if (t.length > 0) narratorToast.push(t)
    }

    // --- Events -----------------------------------------------------------------------------
    property var eventKeys: ["storm", "rats", "wanderer", "rain", "merchant",
                             "transformer", "collapse", "tax", "scouts", "feast", "counterraid"]
    function evName(k) {
        if (k === "storm") return qsTr("The storm")
        if (k === "rats") return qsTr("Rats in the granary")
        if (k === "wanderer") return qsTr("The wandering badger")
        if (k === "rain") return qsTr("Pouring rain")
        if (k === "merchant") return qsTr("The raccoon merchant")
        if (k === "transformer") return qsTr("The transformer")
        if (k === "collapse") return qsTr("Collapse in the mine")
        if (k === "tax") return qsTr("The tax collector")
        if (k === "scouts") return qsTr("Foxes on the prowl")
        if (k === "feast") return qsTr("A feast is demanded")
        if (k === "counterraid") return qsTr("The foxes strike back")
        return k
    }
    function evBody(k) {
        if (k === "storm") return qsTr("The wind spent the night redecorating. A building lost its roof. The badgers study the hole with great interest and no initiative.")
        if (k === "rats") return qsTr("Rats found the granary. They left a note: \"thanks\".")
        if (k === "wanderer") return qsTr("A stranger waits at the entrance with a suitcase and an opinion about your gate.")
        if (k === "rain") return qsTr("It's raining like the sky has a grudge. The foragers are unhappy.")
        if (k === "merchant") return qsTr("A raccoon in a coat unfolds a stall. He says \"friend price\". You are not friends.")
        if (k === "transformer") return qsTr("The transformer is making a noise like a badger with a cold. That is not a good sign.")
        if (k === "collapse") return qsTr("A gallery caved in. A miner taps out a rhythm behind the rubble. A rather good rhythm.")
        if (k === "tax") return qsTr("A badger in a suit is counting your granaries. He has a stamp. You have a problem.")
        if (k === "scouts") return qsTr("Foxes prowl by the gate. They are counting your granaries. Out loud.")
        if (k === "feast") return qsTr("The colony demands a feast. Banners have been painted. With your paint.")
        if (k === "counterraid") return qsTr("The foxes came back with torches and a grudge. They remember the ground you took. So, apparently, do their cousins.")
        return ""
    }
    function evA(k) {
        if (k === "storm") return qsTr("Repair it")
        if (k === "rats") return qsTr("Set traps")
        if (k === "wanderer") return qsTr("Welcome him")
        if (k === "rain") return qsTr("Carry on")
        if (k === "merchant") return qsTr("Accept")
        if (k === "transformer") return qsTr("Repair it")
        if (k === "collapse") return qsTr("Dig him out")
        if (k === "tax") return qsTr("Pay up")
        if (k === "scouts") return qsTr("Pay them off")
        if (k === "feast") return qsTr("Hold the feast")
        if (k === "counterraid") return qsTr("Defend the warren")
        return qsTr("Yes")
    }
    function evB(k) {
        if (k === "storm") return qsTr("Leave it")
        if (k === "rats") return qsTr("Share, then")
        if (k === "wanderer") return qsTr("Refuse")
        if (k === "rain") return qsTr("Everyone inside")
        if (k === "merchant") return qsTr("Refuse")
        if (k === "transformer") return qsTr("Wait it out")
        if (k === "collapse") return qsTr("Seal the gallery")
        if (k === "tax") return qsTr("Lose the records")
        if (k === "scouts") return qsTr("Ignore them")
        if (k === "feast") return qsTr("Refuse")
        if (k === "counterraid") return qsTr("Pay the tribute")
        return qsTr("No")
    }
    function evReact(k, opt) {
        if (k === "storm") return opt === 0 ? qsTr("Fixed. Nature takes note, and will try again.") : qsTr("A building open to the sky. Architecturally daring.")
        if (k === "rats") return opt === 0 ? qsTr("The traps work. So do the rats, elsewhere.") : qsTr("You now feed two colonies. Only one pays the power bill.")
        if (k === "wanderer") return opt === 0 ? qsTr("One more mouth. He says he \"brings experience\".") : qsTr("He left for the foxes. No hard feelings, surely.")
        if (k === "rain") return opt === 0 ? qsTr("Soaked but productive. Well — soaked.") : qsTr("A break. The word will set a precedent.")
        if (k === "merchant") return opt === 0 ? qsTr("He smiled a lot. So did you. One of you was right.") : qsTr("He left. His coat is worth more than your trading post.")
        if (k === "transformer") return opt === 0 ? qsTr("Fixed. The noise has been promoted to \"purring\".") : qsTr("It did not pass. It never passes.")
        if (k === "collapse") return opt === 0 ? qsTr("Saved. He swore never to return to the mine. He returned the next day.") : qsTr("A \"management decision\". That is the term you will use.")
        if (k === "tax") return opt === 0 ? qsTr("Stamped receipt. You now officially fund something, somewhere.") : qsTr("The records are \"at a cousin's\". The collector has cousins too.")
        if (k === "scouts") return opt === 0 ? qsTr("They took the coin and left. Cheaper than a fight, worse for the pride.") : qsTr("They came. You were warned. By me. Just now.")
        if (k === "feast") return opt === 0 ? qsTr("They ate very well. They are already talking about the next one.") : qsTr("The word \"tyrant\" was used. Twice. Well enunciated.")
        if (k === "counterraid") {
            if (opt !== 0) return qsTr("You paid for the peace. The word \"protection money\" is so vulgar.")
            return Game.lastEventResult === 1
                ? qsTr("Repelled. The gate held better than the badgers did. They will come back with friends.")
                : qsTr("They left served. Your stores are lighter and your pride is a rumour.")
        }
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

    // Haptics, isolated: if Nemo.Ngf is missing the Loader errors and buzz() is a no-op.
    Loader { id: hapticsLoader; source: Qt.resolvedUrl("components/Haptics.qml") }
    function buzz() {
        if (Game.haptics && hapticsLoader.status === Loader.Ready && hapticsLoader.item)
            hapticsLoader.item.play()
    }

    // Tapping any notification opens (or raises) the app, via D-Bus.
    DBusAdaptor {
        service: "harbour.warren"
        iface: "harbour.warren"
        path: "/"
        function openApp() {
            app.activate()
        }
    }
    property var notifAction: [ {
        "name": "default",
        "service": "harbour.warren",
        "path": "/",
        "iface": "harbour.warren",
        "method": "openApp"
    } ]

    // Opt-in: tell the chief when a raid target is ready while the app is in the background.
    Notification {
        id: raidNotif
        appName: "Warren"
        summary: qsTr("A raid target is ready")
        remoteActions: app.notifAction
    }
    // On by default: the colony went dark. That one you want to know about.
    Notification {
        id: energyNotif
        appName: "Warren"
        summary: qsTr("The power is out")
        body: qsTr("Nobody is working. Naturally.")
        remoteActions: app.notifAction
    }
    property bool wasAnyRaidReady: false
    property bool wasBlackout: false
    Connections {
        target: Game
        onLiveChanged: {
            var any = false
            var ts = Game.targets
            for (var i = 0; i < ts.length; i++) if (ts[i].ready) { any = true; break }
            if (any && !app.wasAnyRaidReady && !Qt.application.active
                && Game.notifyRaids && Game.raidsUnlocked)
                raidNotif.publish()
            app.wasAnyRaidReady = any

            if (Game.blackout && !app.wasBlackout && !Qt.application.active && Game.notifyEnergy)
                energyNotif.publish()
            if (Game.blackout && !app.wasBlackout) app.quip("blackout")
            else if (!Game.blackout && app.wasBlackout && Game.powered) app.quip("powered")
            app.wasBlackout = Game.blackout
        }
    }

    function maybeNarrate() {
        if (narrator.line !== "" || battle.visible || welcome.visible || !Game.arrived
            || Game.eventActive >= 0)
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
            FastBlur { anchors.fill: parent; source: grab; radius: 64; visible: !Game.reduceFx }
            Rectangle { anchors.fill: parent; color: "#101218"; opacity: Game.reduceFx ? 0.97 : 0.78 }
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
        property real meleeP: 0        // 0..1: the brawl itself
        property int shownAtt: Math.min(12, committed)
        property int deadAtt: Math.round(losses * shownAtt / Math.max(1, committed))
        property int deadDef: outcome === 3 ? 2 : (outcome === 1 ? 9 : 6)
        function play(target, oc, comm, loss) {
            outcome = oc; committed = comm; losses = loss
            clash = 0; meleeP = 0; resultLabel.visible = false; visible = true; anim.restart()
        }
        Loader { anchors.fill: parent; sourceComponent: backdrop; onLoaded: item.active = Qt.binding(function(){ return battle.visible }) }
        MouseArea { anchors.fill: parent }

        // Your badgers (left, striped faces) charge the foxes (right). No doubt who is who.
        Column {
            anchors { verticalCenter: parent.verticalCenter; verticalCenterOffset: -Theme.itemSizeSmall * 1.2; left: parent.left; leftMargin: Theme.horizontalPageMargin }
            spacing: Theme.paddingSmall
            Label { text: qsTr("Your badgers"); font.pixelSize: Theme.fontSizeExtraSmall; color: Theme.secondaryColor }
        }
        Column {
            anchors { verticalCenter: parent.verticalCenter; verticalCenterOffset: Theme.itemSizeSmall * 1.6; right: parent.right; rightMargin: Theme.horizontalPageMargin }
            Label { text: qsTr("The enemy"); font.pixelSize: Theme.fontSizeExtraSmall; color: "#d8935a" }
        }
        Row {
            id: attackers
            anchors { verticalCenter: parent.verticalCenter; verticalCenterOffset: -Theme.itemSizeSmall * 0.5 }
            x: parent.width * 0.06 + battle.clash * parent.width * 0.22
              + (battle.meleeP > 0 && battle.meleeP < 1 ? Math.sin(battle.meleeP * 34) * 7 : 0)
            spacing: 4
            Repeater {
                model: battle.shownAtt
                Image {
                    // The last ones in line fall one by one as the brawl progresses.
                    property bool fallen: index >= battle.shownAtt
                                          - Math.round(battle.deadAtt * battle.meleeP)
                    source: Qt.resolvedUrl("images/badger-side.png")
                    smooth: false
                    mirror: true   // face the enemy
                    width: Theme.iconSizeSmall * 1.1; height: width * 0.85
                    fillMode: Image.PreserveAspectFit
                    rotation: fallen ? 95 : (battle.meleeP > 0 && battle.meleeP < 1
                                             ? Math.sin(battle.meleeP * 40 + index) * 8 : 0)
                    opacity: fallen ? 0.25 : 1
                    Behavior on rotation { NumberAnimation { duration: 250 } }
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }
        }
        Row {
            id: defenders
            anchors { verticalCenter: parent.verticalCenter; verticalCenterOffset: Theme.itemSizeSmall * 0.7 }
            x: parent.width * 0.94 - width - battle.clash * parent.width * 0.22
              - (battle.meleeP > 0 && battle.meleeP < 1 ? Math.sin(battle.meleeP * 34) * 7 : 0)
            spacing: 4
            Repeater {
                model: 10
                Image {
                    property bool fallen: index < Math.round(battle.deadDef * battle.meleeP)
                    source: Qt.resolvedUrl("images/fox-side.png")
                    smooth: false
                    width: Theme.iconSizeSmall * 1.2; height: width * 0.5
                    fillMode: Image.PreserveAspectFit
                    rotation: fallen ? -95 : (battle.meleeP > 0 && battle.meleeP < 1
                                              ? Math.sin(battle.meleeP * 40 + index + 3) * 8 : 0)
                    opacity: fallen ? 0.25 : 1
                    Behavior on rotation { NumberAnimation { duration: 250 } }
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }
        }
        // Sparks where the lines meet.
        Repeater {
            model: 5
            Rectangle {
                width: 6; height: 6
                color: "#f0ece0"
                visible: battle.meleeP > 0.05 && battle.meleeP < 0.95
                x: battle.width * (0.42 + 0.16 * ((index * 29) % 10) / 10)
                  + Math.sin(battle.meleeP * 50 + index * 2) * 10
                y: battle.height * 0.5 + Math.cos(battle.meleeP * 44 + index * 3) * 26
                opacity: 0.4 + 0.6 * Math.abs(Math.sin(battle.meleeP * 30 + index))
            }
        }
        SequentialAnimation {
            id: anim
            NumberAnimation {
                target: battle; property: "clash"; from: 0; to: 1
                duration: Game.fastBattle ? 220 : 800
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: battle; property: "meleeP"; from: 0; to: 1
                duration: Game.fastBattle ? 400 : 1500
            }
            ScriptAction {
                script: {
                    resultLabel.visible = true
                    if (battle.outcome === 1 || battle.outcome === 2) confettiFx.burst()
                }
            }
        }
        Confetti { id: confettiFx; anchors.fill: parent }

        Column {
            anchors { bottom: parent.bottom; bottomMargin: Theme.itemSizeLarge; horizontalCenter: parent.horizontalCenter }
            width: parent.width - 4 * Theme.horizontalPageMargin
            spacing: Theme.paddingMedium
            Label {
                visible: resultLabel.visible
                anchors.horizontalCenter: parent.horizontalCenter
                text: battle.outcome === 3 ? qsTr("DEFEAT") : qsTr("VICTORY")
                font.pixelSize: Theme.fontSizeExtraLarge
                font.bold: true
                color: battle.outcome === 3 ? "#c0603a" : "#e0b23a"
            }
            Label {
                id: resultLabel; visible: false
                width: parent.width; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                text: app.raidOutcomeText(battle.outcome)
                font.pixelSize: Theme.fontSizeMedium; font.italic: true
                color: Theme.secondaryHighlightColor
            }
            Button {
                visible: resultLabel.visible; anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Continue")
                onClicked: { battle.visible = false; app.maybeNarrate() }
            }
        }
    }

    // Events: a choice, then the narrator's verdict. Blurred, unmissable.
    Item {
        id: eventOverlay
        anchors.fill: parent
        z: 8700
        property int curEv: -1
        property int chosenOpt: 0
        property bool reacting: false
        visible: Game.eventActive >= 0 || reacting

        function choose(opt) {
            curEv = Game.eventActive
            chosenOpt = opt
            Game.chooseEvent(opt)
            reacting = true
        }

        Loader { anchors.fill: parent; sourceComponent: backdrop; onLoaded: item.active = Qt.binding(function(){ return eventOverlay.visible }) }
        MouseArea { anchors.fill: parent }

        // Phase 1: the situation and the two choices.
        Column {
            anchors.centerIn: parent
            width: parent.width - 3 * Theme.horizontalPageMargin
            spacing: Theme.paddingLarge
            visible: Game.eventActive >= 0 && !eventOverlay.reacting
            Label {
                width: parent.width; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                text: Game.eventActive >= 0 ? app.evName(app.eventKeys[Game.eventActive]) : ""
                font.pixelSize: Theme.fontSizeLarge; font.bold: true; color: Theme.highlightColor
            }
            Label {
                width: parent.width; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                text: Game.eventActive >= 0 ? app.evBody(app.eventKeys[Game.eventActive]) : ""
                font.pixelSize: Theme.fontSizeMedium; font.italic: true; color: Theme.primaryColor
            }
            Item { width: 1; height: Theme.paddingMedium }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: Game.eventActive >= 0 ? app.evA(app.eventKeys[Game.eventActive]) : ""
                onClicked: eventOverlay.choose(0)
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: Game.eventActive >= 0 ? app.evB(app.eventKeys[Game.eventActive]) : ""
                onClicked: eventOverlay.choose(1)
            }
        }

        // Phase 2: the narrator's dry verdict.
        Column {
            anchors.centerIn: parent
            width: parent.width - 3 * Theme.horizontalPageMargin
            spacing: Theme.paddingLarge
            visible: eventOverlay.reacting
            Label {
                width: parent.width; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                text: eventOverlay.curEv >= 0 ? app.evReact(app.eventKeys[eventOverlay.curEv], eventOverlay.chosenOpt) : ""
                font.pixelSize: Theme.fontSizeMedium; font.italic: true; color: Theme.primaryColor
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Continue")
                onClicked: { eventOverlay.reacting = false; app.maybeNarrate() }
            }
        }
    }

    // The narrator's quips: a brief, non-blocking toast. Never captures input, never gates play.
    // Lines queue up (max 3) and each shows for a few seconds, so nothing floods the screen.
    Item {
        id: narratorToast
        property var queue: []
        property string current: ""
        z: 7000
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Theme.itemSizeLarge }
        width: Math.min(parent.width - 2 * Theme.horizontalPageMargin, Theme.buttonWidthLarge * 1.4)
        height: toastLbl.height + 2 * Theme.paddingMedium
        visible: current !== "" && !narrator.visible && !eventOverlay.visible
                 && !battle.visible && !welcome.visible && !intro.visible

        function push(text) {
            if (queue.length < 3) queue.push(text)
            if (current === "") next()
        }
        function next() {
            if (queue.length === 0) { current = ""; return }
            current = queue.shift()
            life.restart()
        }
        SequentialAnimation {
            id: life
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 220 }
            PauseAnimation { duration: 3200 }
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 320 }
            ScriptAction { script: narratorToast.next() }
        }
        Rectangle {
            id: card
            anchors.fill: parent
            radius: Theme.paddingMedium
            color: Theme.rgba("#0e1016", 0.88)
            border.color: Theme.rgba(Theme.highlightColor, 0.35); border.width: 1
            opacity: 0
            Label {
                id: toastLbl
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                          leftMargin: Theme.paddingLarge; rightMargin: Theme.paddingLarge }
                text: narratorToast.current
                wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeSmall; font.italic: true; color: Theme.primaryColor
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
