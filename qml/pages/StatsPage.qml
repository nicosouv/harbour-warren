import QtQuick 2.6
import Sailfish.Silica 1.0

// Stats, charts and records — because someone around here likes numbers. Everything is derived
// from the timestamped event log.
Page {
    id: page

    property var recs: Game.records()

    Connections {
        target: Game
        onStateChanged: {
            page.recs = Game.records()
            popChart.requestPaint(); goldChart.requestPaint(); armyChart.requestPaint()
        }
    }

    function stageName(n) {
        if (n === 1) return qsTr("Shelter")
        if (n === 2) return qsTr("Depths")
        if (n === 3) return qsTr("Muster")
        if (n === 4) return qsTr("The raids")
        if (n === 5) return qsTr("Escalation")
        return "" + n
    }
    function recordLabel(key) {
        if (key === "peakPopulation") return qsTr("Peak population")
        if (key === "peakGold") return qsTr("Peak gold")
        if (key === "totalGoldEarned") return qsTr("Total gold earned")
        if (key === "peakTerritory") return qsTr("Territory held")
        if (key === "peakArmyPower") return qsTr("Peak army power")
        if (key === "raidsWon") return qsTr("Raids won")
        if (key === "unitsTrained") return qsTr("Badgers armed")
        if (key === "buildingsBuilt") return qsTr("Buildings raised")
        if (key === "biggestRaidLoot") return qsTr("Biggest haul")
        if (key.indexOf("stage") === 0) return qsTr("Reached") + ": " + stageName(parseInt(key.substring(5), 10))
        return key
    }
    function dur(ms) {
        if (ms <= 0) return "—"
        var d = Math.floor(ms / 86400000), h = Math.floor((ms % 86400000) / 3600000), m = Math.floor((ms % 3600000) / 60000)
        if (d >= 1) return d + " j " + h + " h"
        if (h >= 1) return h + " h " + m + " min"
        return Math.max(1, m) + " min"
    }
    function recordValue(key, v) {
        if (key.indexOf("stage") === 0) return dur(v)
        return Game.fmt(v)
    }

    function drawSeries(canvas, key, color) {
        var ctx = canvas.getContext("2d")
        ctx.clearRect(0, 0, canvas.width, canvas.height)
        var pts = Game.series(key)
        if (pts.length < 2) return
        var minT = pts[0].t, maxT = pts[pts.length - 1].t
        var minV = pts[0].v, maxV = pts[0].v
        for (var i = 0; i < pts.length; i++) { if (pts[i].v < minV) minV = pts[i].v; if (pts[i].v > maxV) maxV = pts[i].v }
        if (maxT - minT <= 0) return
        if (maxV - minV < 1e-9) maxV = minV + 1
        ctx.beginPath()
        for (i = 0; i < pts.length; i++) {
            var px = (pts[i].t - minT) / (maxT - minT) * canvas.width
            var py = canvas.height - 2 - (pts[i].v - minV) / (maxV - minV) * (canvas.height - 4)
            if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
        }
        ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.stroke()
        ctx.lineTo(canvas.width, canvas.height); ctx.lineTo(0, canvas.height); ctx.closePath()
        ctx.fillStyle = Theme.rgba(color, 0.12); ctx.fill()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height

        Column {
            id: col
            width: page.width

            PageHeader { title: qsTr("Records") }

            DetailItem { label: qsTr("Playtime"); value: page.dur(Game.playtimeMs()) }
            DetailItem { label: qsTr("Actions logged"); value: "" + Game.eventCount() }

            SectionHeader { text: qsTr("Population") }
            Canvas {
                id: popChart; x: Theme.horizontalPageMargin
                width: page.width - 2 * Theme.horizontalPageMargin; height: Theme.itemSizeLarge
                onPaint: page.drawSeries(popChart, "population", "#e6e0d4")
            }

            SectionHeader { text: qsTr("Gold") }
            Canvas {
                id: goldChart; x: Theme.horizontalPageMargin
                width: page.width - 2 * Theme.horizontalPageMargin; height: Theme.itemSizeLarge
                onPaint: page.drawSeries(goldChart, "gold", "#e0b23a")
            }

            SectionHeader { text: qsTr("Army power") }
            Canvas {
                id: armyChart; x: Theme.horizontalPageMargin
                width: page.width - 2 * Theme.horizontalPageMargin; height: Theme.itemSizeLarge
                onPaint: page.drawSeries(armyChart, "army", "#b85050")
            }

            SectionHeader { text: qsTr("Best marks") }
            Repeater {
                model: page.recs
                DetailItem {
                    label: page.recordLabel(modelData.key)
                    value: page.recordValue(modelData.key, modelData.value)
                }
            }
            ViewPlaceholder {
                enabled: page.recs.length === 0
                text: qsTr("Nothing to boast about yet.")
            }

            Item { width: 1; height: Theme.paddingLarge }
        }

        VerticalScrollDecorator { }
    }
}
