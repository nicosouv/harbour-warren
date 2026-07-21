import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"

CoverBackground {
    id: cover

    function buildingCounts() {
        var c = {}
        var b = Game.buildings
        for (var i = 0; i < b.length; i++) c[b[i].key] = b[i].count
        return c
    }

    VillageView {
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: label.top }
        population: Game.population
        stage: Game.stage
        counts: buildingCounts()
        blackout: Game.blackout
    }

    Label {
        id: label
        anchors { bottom: parent.bottom; bottomMargin: Theme.paddingMedium; horizontalCenter: parent.horizontalCenter }
        text: Game.population + " " + qsTr("badgers")
        font.pixelSize: Theme.fontSizeSmall
        font.family: "Monospace"
        color: Theme.rgba(Theme.primaryColor, 0.6)
    }
}
