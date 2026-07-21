import QtQuick 2.6
import Sailfish.Silica 1.0

// The warren, in validated pixel sprites: a mound with burrow holes, buildings on the field,
// chibi badgers at work. Goes dark when the energy runs out — and everyone stops working.
Item {
    id: view

    property int population: 4
    property int stage: 0
    property var counts: ({})
    property bool blackout: false

    property int frame: 0

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
        var out = []
        var defs = [
            { key: "burrow", cap: 4 }, { key: "granary", cap: 3 }, { key: "workshop", cap: 3 },
            { key: "mineshaft", cap: 2 }, { key: "tradingpost", cap: 2 }, { key: "barracks", cap: 2 }
        ]
        for (var d = 0; d < defs.length; d++) {
            var n = shown(counts[defs[d].key], defs[d].cap)
            for (var i = 0; i < n; i++)
                out.push({ key: defs[d].key, idx: i, kind: d })
        }
        return out
    }

    Timer {
        interval: 800
        running: view.visible && Qt.application.active && !view.blackout
        repeat: true
        onTriggered: view.frame = (view.frame + 1) % 2
    }

    // Sky and ground.
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

    // Buildings, from the validated sprite set.
    Repeater {
        model: view.buildingModel()
        Image {
            source: Qt.resolvedUrl("../images/bld-" + modelData.key + ".png")
            smooth: false
            width: view.width * 0.14
            height: width * (sourceSize.height / Math.max(1, sourceSize.width))
            x: view.width * (0.05 + 0.82 * view.jitter(modelData.kind * 17 + modelData.idx * 7 + 3, 1))
            y: view.height * (0.55 + 0.30 * view.jitter(modelData.kind * 29 + modelData.idx * 11 + 5, 1))
        }
    }

    // Chibi badgers at work; frozen in the dark.
    Repeater {
        model: Math.min(12, view.population)
        Image {
            source: Qt.resolvedUrl("../images/badger-front.png")
            smooth: false
            width: view.width * 0.075
            height: width
            x: view.width * (0.04 + 0.88 * view.jitter(index * 13 + 1, 1))
              + (view.frame === 0 || view.blackout ? 0 : (index % 2 === 0 ? 3 : -3))
            y: view.height * (0.58 + 0.30 * view.jitter(index * 31 + 2, 1))
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
