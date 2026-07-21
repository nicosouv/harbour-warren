import QtQuick 2.6

// A cheap, joyful confetti burst for victories. Call burst().
Item {
    id: confetti

    property var colors: ["#e0b23a", "#2a9d8f", "#c0392b", "#e8dfc8", "#7da33f", "#9a8fc0"]
    property bool running: false

    function burst() {
        running = false
        running = true
        stopTimer.restart()
    }

    Timer { id: stopTimer; interval: 2600; onTriggered: confetti.running = false }

    Repeater {
        model: 36
        Rectangle {
            width: 8; height: 14
            radius: 2
            color: confetti.colors[index % confetti.colors.length]
            visible: confetti.running
            x: confetti.width * ((index * 37) % 100) / 100
            rotation: (index * 47) % 360

            NumberAnimation on y {
                running: confetti.running
                from: -30 - ((index * 53) % 120)
                to: confetti.height + 30
                duration: 1600 + ((index * 97) % 900)
                easing.type: Easing.InQuad
            }
            NumberAnimation on rotation {
                running: confetti.running
                from: (index * 47) % 360
                to: ((index * 47) % 360) + (index % 2 === 0 ? 540 : -540)
                duration: 2200
            }
        }
    }
}
