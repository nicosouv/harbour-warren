import QtQuick 2.6
import Sailfish.Silica 1.0

// The warren under a living sky: an animated day/night cycle (or a pinned ambiance) painted as
// cheap colour bands, with a sun and moon crossing overhead and stars at night. Buildings and
// chibi badgers stay on the ground — the horizon is fixed, so nobody ends up in the sky. Badgers
// scratch at the earth; new ones pop into being. Goes dark when the energy runs out.
Item {
    id: view

    property int population: 4
    property int stage: 0
    property var counts: ({})
    property bool blackout: false
    property bool starving: false
    property int siteBld: -1
    property real siteProgress: 0
    property int ambiance: 0        // 0 cycle / 1 dawn / 2 dusk / 3 night
    property bool reduceFx: false

    readonly property real horizon: 0.42

    // Cycle position 0..1. Animated when ambiance is the cycle; pinned otherwise.
    property real phase: 0.15
    readonly property real fixedPhase: ambiance === 1 ? 0.13 : ambiance === 2 ? 0.68
                                     : ambiance === 3 ? 0.90 : 0.25

    // Full day/night loop in ten minutes. Stepped by a slow timer, not a per-frame animation:
    // the sky moves gently and old hardware isn't recomputing colour bands sixty times a second.
    readonly property real cycleMs: 600000
    Timer {
        interval: 2000; repeat: true
        running: view.ambiance === 0 && !view.reduceFx && view.visible && Qt.application.active
        onTriggered: view.phase = (view.phase + interval / view.cycleMs) % 1
    }
    // When not cycling, sit on the chosen ambiance.
    Binding {
        target: view; property: "phase"; value: view.fixedPhase
        when: view.ambiance !== 0 || view.reduceFx
    }

    // Sky keyframes: [phase, topRGB, botRGB, daylight 0..1]. Interpolated for the current phase.
    readonly property var skyKeys: [
        [0.00, [0x14,0x18,0x26], [0x24,0x2a,0x38], 0.00],  // deep night
        [0.13, [0x3a,0x3a,0x54], [0xc7,0x86,0x5a], 0.30],  // dawn
        [0.25, [0x3c,0x63,0x9e], [0x9d,0xc0,0xdc], 1.00],  // clear day
        [0.55, [0x3c,0x63,0x9e], [0x9d,0xc0,0xdc], 1.00],  // day
        [0.68, [0x2b,0x2f,0x45], [0x53,0x44,0x50], 0.32],  // dusk / twilight
        [0.82, [0x14,0x18,0x26], [0x24,0x2a,0x38], 0.00],  // night
        [1.00, [0x14,0x18,0x26], [0x24,0x2a,0x38], 0.00]
    ]
    function mixByte(a, b, t) { return Math.round(a + (b - a) * t) }
    // The interpolated sky for the current phase: { top:[r,g,b], bot:[r,g,b], day:0..1 }.
    // Binding re-evaluates whenever phase changes (computeSky reads phase).
    property var sky: computeSky(phase)
    function computeSky(p) {
        var k = skyKeys
        for (var i = 0; i < k.length - 1; i++) {
            if (p >= k[i][0] && p <= k[i + 1][0]) {
                var span = k[i + 1][0] - k[i][0]
                var t = span > 0 ? (p - k[i][0]) / span : 0
                var top = [], bot = []
                for (var c = 0; c < 3; c++) {
                    top.push(mixByte(k[i][1][c], k[i + 1][1][c], t))
                    bot.push(mixByte(k[i][2][c], k[i + 1][2][c], t))
                }
                return { top: top, bot: bot, day: k[i][3] + (k[i + 1][3] - k[i][3]) * t }
            }
        }
        return { top: k[0][1], bot: k[0][2], day: k[0][3] }
    }

    function jitter(seed, span) {
        var x = Math.sin(seed * 127.1) * 43758.5453
        return (x - Math.floor(x)) * span
    }
    function shown(n, cap) {
        if (!n || n <= 0) return 0
        return Math.min(cap, 1 + Math.floor(Math.log(n) / Math.LN2 / 1.1))
    }
    function buildingModel() {
        var out = []
        var defs = [
            { key: "burrow", cap: 4 }, { key: "granary", cap: 3 }, { key: "workshop", cap: 3 },
            { key: "mineshaft", cap: 2 }, { key: "tradingpost", cap: 2 }, { key: "barracks", cap: 2 }
        ]
        var slot = 0
        for (var d = 0; d < defs.length; d++) {
            var n = shown(counts[defs[d].key], defs[d].cap)
            for (var i = 0; i < n; i++) { out.push({ key: defs[d].key, slot: slot }); slot++ }
        }
        return out
    }
    function slotX(slot) { return 0.03 + (slot % 9) * 0.107 + jitter(slot * 3 + 1, 0.02) }
    function slotY(slot) { return slot % 9 < 5 ? 0.52 : 0.74 }

    property var siteKeys: ["burrow", "granary", "workshop", "mineshaft", "tradingpost", "barracks"]

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

    // --- Sky: cheap animated gradient made of horizontal bands ------------------------------
    Column {
        width: parent.width
        height: parent.height * view.horizon
        Repeater {
            model: 12
            Rectangle {
                width: view.width
                height: view.height * view.horizon / 12
                color: {
                    var f = index / 11
                    return Qt.rgba(view.mixByte(view.sky.top[0], view.sky.bot[0], f) / 255,
                                   view.mixByte(view.sky.top[1], view.sky.bot[1], f) / 255,
                                   view.mixByte(view.sky.top[2], view.sky.bot[2], f) / 255, 1)
                }
            }
        }
    }

    // Stars: fixed field, fading in as daylight drops.
    Item {
        anchors.fill: parent
        opacity: Math.max(0, 1 - view.sky.day * 1.5)
        Repeater {
            model: 34
            Rectangle {
                width: index % 7 === 0 ? 2 : 1; height: width
                color: "#cdd2e6"
                x: view.width * view.jitter(index * 7 + 3, 1)
                y: view.height * view.horizon * view.jitter(index * 11 + 5, 0.95)
            }
        }
    }

    // Sun by day, moon by night: one body arcing over each half of the cycle.
    Item {
        id: body
        property real half: (view.phase * 2) % 1
        property bool isSun: view.phase < 0.5
        width: view.width * 0.075; height: width
        x: view.width * (0.1 + 0.8 * half) - width / 2
        y: view.height * (0.34 - 0.22 * Math.sin(half * Math.PI)) - height / 2
        Rectangle {
            anchors.fill: parent; radius: width / 2
            color: body.isSun ? "#ffd98a" : "#dcdcec"
        }
        Rectangle {   // crescent bite for the moon
            visible: !body.isSun
            width: parent.width; height: parent.height; radius: width / 2
            x: parent.width * 0.28
            color: {
                var f = 0.15
                return Qt.rgba(view.mixByte(view.sky.top[0], view.sky.bot[0], f) / 255,
                               view.mixByte(view.sky.top[1], view.sky.bot[1], f) / 255,
                               view.mixByte(view.sky.top[2], view.sky.bot[2], f) / 255, 1)
            }
        }
    }

    // --- Ground -----------------------------------------------------------------------------
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        y: parent.height * view.horizon
        height: parent.height * (1 - view.horizon)
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#4a3d30" }
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
    // Ground texture: dirt grain, pebbles, grass tufts. Painted once.
    Canvas {
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var g = height * view.horizon
            var seed = 20260721
            function rnd() { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff }
            for (var i = 0; i < 240; i++) {
                var x = rnd() * width, y = g + rnd() * (height - g), s = 1 + rnd() * 2
                ctx.fillStyle = rnd() < 0.5 ? "rgba(28,20,12,0.35)" : "rgba(122,98,62,0.28)"
                ctx.fillRect(x, y, s, s)
            }
            for (i = 0; i < 20; i++) {
                x = rnd() * width; y = g + rnd() * (height - g); s = 2 + rnd() * 2
                ctx.fillStyle = "rgba(150,140,128,0.22)"
                ctx.beginPath(); ctx.arc(x, y, s, 0, 6.283); ctx.fill()
            }
            for (i = 0; i < 42; i++) {
                x = rnd() * width; y = g + rnd() * (height - g) * 0.5; var h = 2 + rnd() * 4
                ctx.strokeStyle = rnd() < 0.5 ? "rgba(78,96,54,0.5)" : "rgba(96,116,66,0.45)"
                ctx.lineWidth = 1
                ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + (rnd() - 0.5) * 3, y - h); ctx.stroke()
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    // Night falls on the ground too: a soft darkening that tracks daylight.
    Rectangle {
        anchors.fill: parent
        color: "#0b0d16"
        opacity: (1 - view.sky.day) * 0.4
    }

    // Buildings, tidy rows.
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

    // Construction site ghost with progress.
    Item {
        visible: view.siteBld >= 0
        x: view.width * 0.44; y: view.height * 0.62
        width: view.width * 0.082; height: width
        Image {
            anchors.fill: parent
            source: view.siteBld >= 0 ? Qt.resolvedUrl("../images/bld-" + view.siteKeys[view.siteBld] + ".png") : ""
            smooth: false; fillMode: Image.PreserveAspectFit; opacity: 0.4
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.bottom; topMargin: 2 }
            height: 3; color: Qt.rgba(1, 1, 1, 0.15)
            Rectangle { width: parent.width * view.siteProgress; height: parent.height; color: "#e0b23a" }
        }
    }

    // Chibi badgers: grounded, muted, scratching the earth; new ones pop into being.
    Repeater {
        model: Math.min(14, view.population)
        Item {
            id: badger
            width: view.width * 0.040; height: width
            x: view.width * (0.04 + 0.88 * view.jitter(index * 13 + 1, 1))
            y: view.height * (0.60 + 0.30 * view.jitter(index * 31 + 2, 1))
            z: 2

            Image {
                id: spr
                anchors.fill: parent
                source: Qt.resolvedUrl("../images/badger-front.png")
                smooth: false
                opacity: 0.7
                transform: [
                    Translate { id: dig },
                    Rotation { id: lean; origin.x: spr.width / 2; origin.y: spr.height }
                ]
            }

            // A newborn pops in with a little bounce so the arrival is unmistakable in the village.
            scale: 0
            Component.onCompleted: spawn.start()
            SequentialAnimation {
                id: spawn
                NumberAnimation { target: badger; property: "scale"; from: 0; to: 1.18; duration: 220; easing.type: Easing.OutBack }
                NumberAnimation { target: badger; property: "scale"; to: 1.0; duration: 130 }
            }

            // Dirt flecks kicked up on each strike.
            Rectangle {
                id: fleck
                width: 2; height: 2; radius: 1; color: "#33261a"
                x: badger.width * 0.5; y: badger.height * 0.7; opacity: 0
            }
            SequentialAnimation {
                id: fleckAnim
                ParallelAnimation {
                    NumberAnimation { target: fleck; property: "y"; from: badger.height * 0.7; to: badger.height * 0.35; duration: 200 }
                    NumberAnimation { target: fleck; property: "x"; from: badger.width * 0.5; to: badger.width * 0.5 + 5; duration: 200 }
                    SequentialAnimation {
                        NumberAnimation { target: fleck; property: "opacity"; to: 0.85; duration: 50 }
                        NumberAnimation { target: fleck; property: "opacity"; to: 0; duration: 160 }
                    }
                }
            }

            // Digging: quick bursts of head-dips toward the ground, then a rest. Not a wobble.
            SequentialAnimation {
                running: view.visible && Qt.application.active && !view.blackout && !view.starving && !view.reduceFx
                loops: Animation.Infinite
                onRunningChanged: if (!running) { dig.y = 0; lean.angle = 0 }
                PauseAnimation { duration: 200 + (index % 5) * 150 }
                SequentialAnimation {
                    loops: 3
                    ParallelAnimation {
                        NumberAnimation { target: dig; property: "y"; to: badger.height * 0.16; duration: 105; easing.type: Easing.OutQuad }
                        NumberAnimation { target: lean; property: "angle"; to: 7; duration: 105 }
                        ScriptAction { script: fleckAnim.restart() }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: dig; property: "y"; to: 0; duration: 150; easing.type: Easing.OutQuad }
                        NumberAnimation { target: lean; property: "angle"; to: 0; duration: 150 }
                    }
                }
                PauseAnimation { duration: 650 + (index % 4) * 220 }
            }

            // Speech: hunger, or grumbling in the dark. Blinks in like chatter.
            Rectangle {
                id: bubble
                visible: index < 8 && view.speaks(index)
                color: Qt.rgba(0.96, 0.95, 0.9, 0.92); radius: 3
                width: bubbleLbl.width + 8; height: bubbleLbl.height + 4
                anchors.horizontalCenter: spr.horizontalCenter
                y: -height - 2; opacity: 0; z: 5
                Label {
                    id: bubbleLbl; anchors.centerIn: parent
                    text: view.bubbleText(index); color: "#2a2018"
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

    // The dark: energy at zero. Nobody works in the dark, on top of everything.
    Rectangle {
        anchors.fill: parent
        color: "#05060c"
        opacity: view.blackout ? 0.62 : 0
        Behavior on opacity { NumberAnimation { duration: 900 } }
    }
}
