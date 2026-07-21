import QtQuick 2.6
import Sailfish.Silica 1.0

// The warren, in validated pixel sprites: a textured mound with burrow holes, buildings on the
// field, chibi badgers scratching at the earth. Goes dark when the energy runs out — and everyone
// stops working and starts complaining.
Item {
    id: view

    property int population: 4
    property int stage: 0
    property var counts: ({})
    property bool blackout: false
    property bool starving: false
    property int siteBld: -1
    property real siteProgress: 0

    property var siteKeys: ["burrow", "granary", "workshop", "mineshaft", "tradingpost", "barracks"]

    // Deterministic layout helper (no flicker between paints).
    function jitter(seed, span) {
        var x = Math.sin(seed * 127.1) * 43758.5453
        return (x - Math.floor(x)) * span
    }
    function shown(n, cap) {
        if (!n || n <= 0) return 0
        return Math.min(cap, 1 + Math.floor(Math.log(n) / Math.LN2 / 1.1))
    }
    function buildingModel() {
        // Slot-based layout: tidy rows instead of a random scatter.
        var out = []
        var defs = [
            { key: "burrow", cap: 4 }, { key: "granary", cap: 3 }, { key: "workshop", cap: 3 },
            { key: "mineshaft", cap: 2 }, { key: "tradingpost", cap: 2 }, { key: "barracks", cap: 2 }
        ]
        var slot = 0
        for (var d = 0; d < defs.length; d++) {
            var n = shown(counts[defs[d].key], defs[d].cap)
            for (var i = 0; i < n; i++) {
                out.push({ key: defs[d].key, slot: slot, kind: d })
                slot++
            }
        }
        return out
    }
    function slotX(slot) { return 0.03 + (slot % 9) * 0.107 + jitter(slot * 3 + 1, 0.02) }
    function slotY(slot) { return slot % 9 < 5 ? 0.52 : 0.74 }

    // Which badgers pipe up, and what they say. Only a fraction speak, so it reads as chatter.
    function speaks(index) {
        if (view.blackout) return index % 4 === 0
        if (view.starving) return index % 3 === 0
        return false
    }
    function bubbleText(index) {
        if (view.blackout) {
            var dark = [qsTr("Good night."), qsTr("Whoa, pitch black in here."), qsTr("Who didn't pay the bill?")]
            return dark[index % dark.length]
        }
        if (view.starving) return qsTr("We're hungry.")
        return ""
    }

    // Sky and ground base.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#252a36" }
            GradientStop { position: 0.42; color: "#2e3442" }
            GradientStop { position: 0.421; color: "#4a3d30" }
            GradientStop { position: 1.0; color: "#3a2f26" }
        }
    }

    // The mound with the main burrow mouth.
    Rectangle {
        width: parent.width * 0.5; height: parent.height * 0.22
        radius: height
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.height * 0.48 }
        color: "#54452f"
    }
    Rectangle {
        width: parent.width * 0.09; height: parent.height * 0.10
        radius: width / 2
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.height * 0.5 }
        color: "#120f14"
    }

    // Painted-once texture: dirt speckle, pebbles, grass tufts on the field, faint stars in the sky.
    // Deterministic LCG so the grain never shimmers between repaints.
    Canvas {
        id: texture
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var horizon = height * 0.42
            var seed = 20260721
            function rnd() { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff }

            // Dirt grain across the field.
            for (var i = 0; i < 260; i++) {
                var x = rnd() * width
                var y = horizon + rnd() * (height - horizon)
                var s = 1 + rnd() * 2
                ctx.fillStyle = rnd() < 0.5 ? "rgba(28,20,12,0.35)" : "rgba(122,98,62,0.28)"
                ctx.fillRect(x, y, s, s)
            }
            // Scattered pebbles.
            for (i = 0; i < 22; i++) {
                x = rnd() * width
                y = horizon + rnd() * (height - horizon)
                s = 2 + rnd() * 2
                ctx.fillStyle = "rgba(150,140,128,0.25)"
                ctx.beginPath(); ctx.arc(x, y, s, 0, 6.283); ctx.fill()
            }
            // Grass tufts near the horizon.
            for (i = 0; i < 46; i++) {
                x = rnd() * width
                y = horizon + rnd() * (height - horizon) * 0.5
                var h = 2 + rnd() * 4
                ctx.strokeStyle = rnd() < 0.5 ? "rgba(78,96,54,0.5)" : "rgba(96,116,66,0.45)"
                ctx.lineWidth = 1
                ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + (rnd() - 0.5) * 3, y - h); ctx.stroke()
            }
            // Faint stars in the sky band.
            for (i = 0; i < 28; i++) {
                x = rnd() * width
                y = rnd() * horizon * 0.9
                ctx.fillStyle = "rgba(200,205,225," + (0.15 + rnd() * 0.3).toFixed(2) + ")"
                ctx.fillRect(x, y, 1, 1)
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    // Buildings, from the validated sprite set — smaller, in tidy rows.
    Repeater {
        model: view.buildingModel()
        Image {
            source: Qt.resolvedUrl("../images/bld-" + modelData.key + ".png")
            smooth: false
            width: view.width * 0.082
            height: width * (sourceSize.height / Math.max(1, sourceSize.width))
            x: view.width * view.slotX(modelData.slot)
            y: view.height * view.slotY(modelData.slot)
        }
    }

    // The active construction site: a ghost of what is coming, with its progress.
    Item {
        visible: view.siteBld >= 0
        x: view.width * 0.44
        y: view.height * 0.62
        width: view.width * 0.082
        height: width
        Image {
            anchors.fill: parent
            source: view.siteBld >= 0
                    ? Qt.resolvedUrl("../images/bld-" + view.siteKeys[view.siteBld] + ".png") : ""
            smooth: false
            fillMode: Image.PreserveAspectFit
            opacity: 0.4
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.bottom; topMargin: 2 }
            height: 3
            color: Qt.rgba(1, 1, 1, 0.15)
            Rectangle {
                width: parent.width * view.siteProgress; height: parent.height
                color: "#e0b23a"
            }
        }
    }

    // Chibi badgers at work — small, muted, scratching the earth; frozen and grumbling in the dark.
    Repeater {
        model: Math.min(14, view.population)
        Item {
            id: badger
            width: view.width * 0.040
            height: width
            x: view.width * (0.04 + 0.88 * view.jitter(index * 13 + 1, 1))
            y: view.height * (0.60 + 0.30 * view.jitter(index * 31 + 2, 1))
            z: 2

            Image {
                id: spr
                anchors.fill: parent
                source: Qt.resolvedUrl("../images/badger-front.png")
                smooth: false
                opacity: 0.7
                transformOrigin: Item.Bottom
            }

            // A fleck of dirt kicked up on each strike.
            Rectangle {
                id: fleck
                width: 2; height: 2; radius: 1
                color: "#33261a"
                x: -1; y: badger.height * 0.55
                opacity: 0
            }
            SequentialAnimation {
                id: fleckAnim
                ParallelAnimation {
                    NumberAnimation { target: fleck; property: "y"; from: badger.height * 0.55; to: badger.height * 0.2; duration: 220 }
                    NumberAnimation { target: fleck; property: "x"; from: -1; to: -5; duration: 220 }
                    SequentialAnimation {
                        NumberAnimation { target: fleck; property: "opacity"; to: 0.8; duration: 60 }
                        NumberAnimation { target: fleck; property: "opacity"; to: 0; duration: 170 }
                    }
                }
            }

            // The scratch loop: lean in, strike, settle — staggered so the colony isn't in lockstep.
            SequentialAnimation {
                running: view.visible && Qt.application.active && !view.blackout && !view.starving
                loops: Animation.Infinite
                onRunningChanged: if (!running) spr.rotation = 0
                PauseAnimation { duration: (index % 5) * 130 }
                NumberAnimation { target: spr; property: "rotation"; to: -9; duration: 160; easing.type: Easing.OutQuad }
                ScriptAction { script: fleckAnim.restart() }
                NumberAnimation { target: spr; property: "rotation"; to: 4; duration: 110; easing.type: Easing.InQuad }
                NumberAnimation { target: spr; property: "rotation"; to: 0; duration: 200 }
                PauseAnimation { duration: 300 + (index % 3) * 170 }
            }

            // Speech bubble — hunger, or grumbling in the blackout. Blinks in like chatter.
            Rectangle {
                id: bubble
                visible: index < 8 && view.speaks(index)
                color: Qt.rgba(0.96, 0.95, 0.9, 0.92)
                radius: 3
                width: bubbleLbl.width + 8
                height: bubbleLbl.height + 4
                anchors.horizontalCenter: spr.horizontalCenter
                y: -height - 2
                opacity: 0
                z: 5
                Label {
                    id: bubbleLbl
                    anchors.centerIn: parent
                    text: view.bubbleText(index)
                    color: "#2a2018"
                    font.pixelSize: Math.max(9, view.width * 0.030)
                }
                SequentialAnimation on opacity {
                    running: bubble.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: (index % 4) * 650 }
                    NumberAnimation { to: 1; duration: 200 }
                    PauseAnimation { duration: 1900 }
                    NumberAnimation { to: 0; duration: 300 }
                    PauseAnimation { duration: 1500 }
                }
            }
        }
    }

    // The dark: energy at zero. Nobody works in the dark.
    Rectangle {
        anchors.fill: parent
        color: "#05060c"
        opacity: view.blackout ? 0.62 : 0
        Behavior on opacity { NumberAnimation { duration: 900 } }
    }
    Rectangle {
        // a thin moon, only in the dark
        width: view.width * 0.06; height: width; radius: width / 2
        x: view.width * 0.78; y: view.height * 0.09
        color: "#d8d8e8"
        opacity: view.blackout ? 0.8 : 0
        Behavior on opacity { NumberAnimation { duration: 900 } }
    }
}
