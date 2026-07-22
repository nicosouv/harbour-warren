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
            { key: "mineshaft", cap: 2 }, { key: "tradingpost", cap: 2 }, { key: "barracks", cap: 2 },
            { key: "watchtower", cap: 2 }, { key: "watermill", cap: 1 }
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

    property var siteKeys: ["burrow", "granary", "workshop", "mineshaft", "tradingpost", "barracks",
                            "watchtower", "watermill"]

    // Chatter pools. Non-deterministic on purpose — pure cosmetics, never touches game state.
    readonly property var darkLines: [
        qsTr("Good night."), qsTr("Whoa, pitch black in here."), qsTr("Who didn't pay the bill?"),
        qsTr("Is it night already?"), qsTr("I can't see my paws."), qsTr("Someone light a candle."),
        qsTr("Cosy. Terrifying, but cosy."), qsTr("I stubbed a claw.")
    ]
    readonly property var hungerLines: [
        qsTr("We're hungry."), qsTr("My stomach is filing a complaint."), qsTr("Is it dinner yet?"),
        qsTr("I'd trade gold for a berry."), qsTr("Rationing. Again."), qsTr("I ate a pebble. No regrets.")
    ]
    readonly property var idleLines: [
        qsTr("Another day of digging."), qsTr("I dug a hole. Apparently it matters."),
        qsTr("Is this a career?"), qsTr("Found a rock. Riveting."),
        qsTr("Morale is a concept, I'm told."), qsTr("The narrator is watching, isn't he?"),
        qsTr("Nice weather for holes."), qsTr("I'd like a raise. In berries.")
    ]
    function pickPhrase() {
        if (view.blackout) return view.darkLines[Math.floor(Math.random() * view.darkLines.length)]
        if (view.starving) return view.hungerLines[Math.floor(Math.random() * view.hungerLines.length)]
        if (Math.random() < 0.14) return view.idleLines[Math.floor(Math.random() * view.idleLines.length)]
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

    // How golden the hour is (dawn/dusk), and how "cloud-friendly" the daylight is.
    property real golden: Math.max(0, 1 - Math.min(Math.abs(view.phase - 0.13),
                                                    Math.abs(view.phase - 0.68)) * 7)
    property real cloudDay: Math.max(0, Math.min(1, view.sky.day * 1.3))

    // Warm band hugging the horizon at dawn and dusk.
    Rectangle {
        width: parent.width
        y: parent.height * view.horizon - height
        height: parent.height * 0.18
        opacity: view.golden * 0.7
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: "#e8a05a" }
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

    // A shared wing-flap for the flock.
    property real birdFlap: 0
    SequentialAnimation on birdFlap {
        running: view.visible && Qt.application.active && !view.reduceFx
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 160 }
        NumberAnimation { to: 0; duration: 160 }
    }

    // A shared breeze, -1..1, gently swaying the greenery.
    property real wind: 0
    SequentialAnimation on wind {
        running: view.visible && Qt.application.active && !view.reduceFx
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 1900; easing.type: Easing.InOutSine }
        NumberAnimation { to: -1; duration: 2300; easing.type: Easing.InOutSine }
    }

    // Cloud shape: a lumpy pixel puff, reused for both depth layers.
    Component {
        id: cloudPuff
        Item {
            property color cc: "#eef2f8"
            Rectangle { x: parent.width * 0.15; y: parent.height * 0.35; width: parent.width * 0.70; height: parent.height * 0.55; radius: height / 2; color: parent.cc; antialiasing: false }
            Rectangle { x: 0;                   y: parent.height * 0.45; width: parent.width * 0.50; height: parent.height * 0.50; radius: height / 2; color: parent.cc; antialiasing: false }
            Rectangle { x: parent.width * 0.35; y: parent.height * 0.08; width: parent.width * 0.45; height: parent.height * 0.55; radius: height / 2; color: parent.cc; antialiasing: false }
            Rectangle { x: parent.width * 0.55; y: parent.height * 0.40; width: parent.width * 0.40; height: parent.height * 0.50; radius: height / 2; color: parent.cc; antialiasing: false }
        }
    }

    // FAR clouds: slow, pale, drift BEHIND the sun (declared before it).
    Repeater {
        model: [ { y: 0.07, w: 0.20, dur: 92000, delay: 0 },
                 { y: 0.15, w: 0.15, dur: 108000, delay: 26000 },
                 { y: 0.04, w: 0.24, dur: 100000, delay: 58000 } ]
        Item {
            width: view.width * modelData.w; height: width * 0.5
            y: view.height * modelData.y
            opacity: 0.30 * view.cloudDay
            Loader { anchors.fill: parent; sourceComponent: cloudPuff; onLoaded: item.cc = "#e4eaf3" }
            SequentialAnimation on x {
                running: view.visible && Qt.application.active && !view.reduceFx
                loops: Animation.Infinite
                PauseAnimation { duration: modelData.delay }
                NumberAnimation { from: -view.width * modelData.w * 1.6; to: view.width * 1.12; duration: modelData.dur }
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

    // NEAR clouds: bigger, faster, drift IN FRONT of the sun (declared after it).
    Repeater {
        model: [ { y: 0.19, w: 0.30, dur: 62000, delay: 14000 },
                 { y: 0.27, w: 0.23, dur: 54000, delay: 42000 } ]
        Item {
            width: view.width * modelData.w; height: width * 0.5
            y: view.height * modelData.y
            opacity: 0.5 * view.cloudDay
            Loader { anchors.fill: parent; sourceComponent: cloudPuff; onLoaded: item.cc = "#f3f6fb" }
            SequentialAnimation on x {
                running: view.visible && Qt.application.active && !view.reduceFx
                loops: Animation.Infinite
                PauseAnimation { duration: modelData.delay }
                NumberAnimation { from: -view.width * modelData.w * 1.6; to: view.width * 1.12; duration: modelData.dur }
            }
        }
    }

    // A simple flock crossing the daytime sky now and then.
    Item {
        id: flock
        width: view.width * 0.16; height: view.height * 0.05
        y: view.height * 0.17
        opacity: Math.max(0, view.sky.day - 0.2) * 1.3
        Repeater {
            model: [ { dx: 0.0, dy: 0.10 }, { dx: 0.36, dy: 0.42 }, { dx: 0.66, dy: 0.0 } ]
            Item {
                x: flock.width * modelData.dx; y: flock.height * modelData.dy
                width: view.width * 0.022; height: width * 0.6
                Rectangle { width: parent.width * 0.52; height: Math.max(1, parent.height * 0.18); color: "#2b2b32"; antialiasing: false
                    x: 0; y: parent.height * 0.5; transformOrigin: Item.Right; rotation: -20 + view.birdFlap * 32 }
                Rectangle { width: parent.width * 0.52; height: Math.max(1, parent.height * 0.18); color: "#2b2b32"; antialiasing: false
                    x: parent.width * 0.48; y: parent.height * 0.5; transformOrigin: Item.Left; rotation: 20 - view.birdFlap * 32 }
            }
        }
        SequentialAnimation on x {
            running: view.visible && Qt.application.active && !view.reduceFx
            loops: Animation.Infinite
            NumberAnimation { from: -flock.width; to: view.width + flock.width; duration: 21000 }
            PauseAnimation { duration: 28000 }
        }
    }

    // Fixed mountains: three silhouette planes for depth — far range tall and hazy, near hills low
    // and dark. They don't move; the layering IS the parallax. The sun and moon set behind them.
    // Canvas content is repainted whenever the view returns to screen, or Sailfish drops its backing
    // when the app is minimised and the mountains vanish until something forces a repaint.
    Canvas {
        id: mountains
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        onPaint: {
            var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
            var g = height * view.horizon
            function ridge(color, base, amp, ph) {
                ctx.fillStyle = color
                ctx.beginPath(); ctx.moveTo(0, g + 4)
                for (var x = 0; x <= width; x += 3) {
                    var u = x / width
                    var hy = g - base * height
                             - amp * height * (0.5 + 0.5 * Math.sin(2 * Math.PI * u * 2 + ph))
                             - amp * 0.5 * height * (0.5 + 0.5 * Math.sin(2 * Math.PI * u * 5 + ph * 1.7))
                    ctx.lineTo(x, hy)
                }
                ctx.lineTo(width, g + 4); ctx.closePath(); ctx.fill()
            }
            ridge("#3c4a5e", 0.15, 0.10, 0.0)   // far range, hazy
            ridge("#313c4d", 0.08, 0.13, 1.3)   // mid
            ridge("#262d3a", 0.02, 0.16, 2.7)   // near hills, darker
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Component.onCompleted: requestPaint()
        Connections {
            target: Qt.application
            onActiveChanged: if (Qt.application.active) mountains.requestPaint()
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
    // Ground texture: dirt grain, pebbles, grass tufts. Painted once.
    Canvas {
        id: groundTex
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
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
            // A dense, short carpet of grass across the whole field. Painted once, so a big count is
            // free: many tufts, each only a few pixels tall, for a lush ground without long blades.
            for (i = 0; i < 900; i++) {
                x = rnd() * width; y = g + rnd() * (height - g); var h = 1 + rnd() * 2.5
                ctx.strokeStyle = rnd() < 0.5 ? "rgba(78,96,54,0.55)" : "rgba(96,116,66,0.5)"
                ctx.lineWidth = 1
                var blades = 2 + Math.floor(rnd() * 3)
                for (var bld = 0; bld < blades; bld++) {
                    ctx.beginPath(); ctx.moveTo(x + (rnd() - 0.5) * 3, y)
                    ctx.lineTo(x + (rnd() - 0.5) * 3, y - h * (0.7 + rnd() * 0.5)); ctx.stroke()
                }
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Component.onCompleted: requestPaint()
        Connections {
            target: Qt.application
            onActiveChanged: if (Qt.application.active) groundTex.requestPaint()
        }
    }

    // Greenery: wind-swayed trees and a fringe of grass. Pure decoration — no collision.
    Repeater {
        model: [ { x: 0.03, y: 0.50, s: 1.0 },  { x: 0.15, y: 0.47, s: 0.7 },
                 { x: 0.33, y: 0.485, s: 0.62 }, { x: 0.48, y: 0.46, s: 0.8 },
                 { x: 0.63, y: 0.50, s: 0.66 },  { x: 0.79, y: 0.475, s: 0.9 },
                 { x: 0.90, y: 0.52, s: 0.72 },  { x: 0.97, y: 0.49, s: 0.6 } ]
        Item {
            x: view.width * modelData.x; y: view.height * modelData.y
            width: view.width * 0.05 * modelData.s; height: width * 2.1
            Rectangle {   // trunk
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.5; width: Math.max(2, parent.width * 0.16); height: parent.height * 0.5
                color: "#5a4632"; antialiasing: false
            }
            Item {        // foliage leans in the breeze
                width: parent.width; height: parent.height * 0.62
                transformOrigin: Item.Bottom
                rotation: view.wind * 4 * modelData.s
                Rectangle { x: parent.width*0.20; y: parent.height*0.30; width: parent.width*0.60; height: parent.height*0.60; radius: width/2; color: "#4c6a3c"; antialiasing: false }
                Rectangle { x: parent.width*0.05; y: parent.height*0.42; width: parent.width*0.50; height: parent.height*0.50; radius: width/2; color: "#3f5a33"; antialiasing: false }
                Rectangle { x: parent.width*0.42; y: parent.height*0.10; width: parent.width*0.50; height: parent.height*0.55; radius: width/2; color: "#557040"; antialiasing: false }
            }
        }
    }
    // Animated blades on top of the carpet — short and many, swaying in the breeze.
    Repeater {
        model: 120
        Rectangle {
            width: 2; height: view.height * (0.012 + 0.016 * view.jitter(index * 17 + 2, 1))
            antialiasing: false
            color: index % 2 === 0 ? "#4e6036" : "#5f7444"
            x: view.width * (0.01 + 0.98 * view.jitter(index * 29 + 4, 1))
            y: view.height * (0.5 + 0.44 * view.jitter(index * 13 + 6, 1))
            transformOrigin: Item.Bottom
            rotation: view.wind * (6 + (index % 3) * 3)
        }
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
            Rectangle {
                width: parent.width * view.siteProgress; height: parent.height; color: "#e0b23a"
                Behavior on width { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
            }
        }
    }

    // Chibi badgers: grounded, muted, scratching the earth; new ones pop into being.
    Repeater {
        model: Math.min(14, view.population)
        Item {
            id: badger
            width: view.width * 0.036; height: width
            x: view.width * (0.04 + 0.88 * view.jitter(index * 13 + 1, 1))
            y: view.height * (0.60 + 0.30 * view.jitter(index * 31 + 2, 1))
            z: 2
            transform: Translate { id: wander }

            // Idle wander: a gentle side-to-side shuffle so the colony never looks frozen.
            SequentialAnimation {
                running: view.visible && Qt.application.active && !view.reduceFx
                loops: Animation.Infinite
                PauseAnimation { duration: 400 + (index % 6) * 320 }
                NumberAnimation { target: wander; property: "x"; to: view.width * 0.013; duration: 1500; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 500 + (index % 4) * 260 }
                NumberAnimation { target: wander; property: "x"; to: -view.width * 0.013; duration: 1700; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 300 }
                NumberAnimation { target: wander; property: "x"; to: 0; duration: 1300; easing.type: Easing.InOutSine }
            }

            // Blocky pixel badger, built from flat rectangles to match the rest of the scene
            // (trees, clouds) instead of a smooth sprite: a white striped face over a grey body.
            Item {
                id: spr
                anchors.fill: parent
                opacity: 0.85
                property color furC: "#7f8590"
                property color darkC: "#2b2e36"
                property color faceC: "#d9dade"
                transform: [
                    Translate { id: dig },
                    Rotation { id: lean; origin.x: spr.width / 2; origin.y: spr.height }
                ]
                Rectangle { x: parent.width*0.10; y: parent.height*0.08; width: parent.width*0.20; height: parent.height*0.16; color: spr.darkC; antialiasing: false }
                Rectangle { x: parent.width*0.70; y: parent.height*0.08; width: parent.width*0.20; height: parent.height*0.16; color: spr.darkC; antialiasing: false }
                Rectangle { x: parent.width*0.18; y: parent.height*0.16; width: parent.width*0.64; height: parent.height*0.40; color: spr.faceC; antialiasing: false }
                Rectangle { x: parent.width*0.28; y: parent.height*0.16; width: parent.width*0.12; height: parent.height*0.40; color: spr.darkC; antialiasing: false }
                Rectangle { x: parent.width*0.60; y: parent.height*0.16; width: parent.width*0.12; height: parent.height*0.40; color: spr.darkC; antialiasing: false }
                Rectangle { x: parent.width*0.44; y: parent.height*0.44; width: parent.width*0.12; height: parent.height*0.10; color: spr.darkC; antialiasing: false }
                Rectangle { x: parent.width*0.14; y: parent.height*0.54; width: parent.width*0.72; height: parent.height*0.34; color: spr.furC; antialiasing: false }
                Rectangle { x: parent.width*0.20; y: parent.height*0.86; width: parent.width*0.18; height: parent.height*0.12; color: spr.darkC; antialiasing: false }
                Rectangle { x: parent.width*0.62; y: parent.height*0.86; width: parent.width*0.18; height: parent.height*0.12; color: spr.darkC; antialiasing: false }
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

            // Speech: each badger pipes up on its own irregular beat, so the colony chatters
            // unevenly instead of in chorus. A pool of lines; hunger and the dark override idle.
            property string bubbleMsg: ""
            Timer {
                interval: 3000 + Math.floor(Math.random() * 7000)
                repeat: true
                running: index < 7 && view.visible && Qt.application.active
                onTriggered: {
                    interval = 2500 + Math.floor(Math.random() * 7000)
                    if (badger.bubbleMsg.length === 0) {
                        var m = view.pickPhrase()
                        if (m.length > 0) { badger.bubbleMsg = m; bubbleHide.restart() }
                    }
                }
            }
            Timer { id: bubbleHide; interval: 2700; onTriggered: badger.bubbleMsg = "" }
            Rectangle {
                id: bubble
                visible: badger.bubbleMsg.length > 0
                color: Qt.rgba(0.97, 0.96, 0.91, 0.94); radius: 4
                width: bubbleLbl.width + 12; height: bubbleLbl.height + 7
                anchors.horizontalCenter: spr.horizontalCenter
                y: -height - 3; z: 5
                opacity: badger.bubbleMsg.length > 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                scale: badger.bubbleMsg.length > 0 ? 1 : 0.6
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                Label {
                    id: bubbleLbl; anchors.centerIn: parent
                    text: badger.bubbleMsg; color: "#241d15"
                    font.pixelSize: Math.max(11, view.width * 0.038)
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
