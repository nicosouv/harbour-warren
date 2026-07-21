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
        anchors.fill: parent
        opacity: 0.5
        population: Game.population
        stage: Game.stage
        counts: buildingCounts()
        blackout: Game.blackout
        siteBld: Game.buildSite
        siteProgress: Game.buildProgress
    }

    // The numbers that matter, glanceable.
    Column {
        anchors { top: parent.top; topMargin: Theme.paddingLarge; left: parent.left; leftMargin: Theme.paddingLarge }
        spacing: Theme.paddingSmall

        Label {
            text: "Warren"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
        }

        Repeater {
            model: Game.resources
            Row {
                visible: modelData.visible
                spacing: Theme.paddingSmall
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: Qt.resolvedUrl("../images/res-" + modelData.key + ".png")
                    smooth: false
                    width: Theme.iconSizeExtraSmall * 0.8; height: width
                    fillMode: Image.PreserveAspectFit
                }
                Label {
                    text: Game.fmt(modelData.value)
                          + (modelData.rate !== 0 ? " (" + (modelData.rate > 0 ? "+" : "") + Game.fmt(modelData.rate) + ")" : "")
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: "Monospace"
                    color: modelData.low ? "#c0603a" : Theme.primaryColor
                }
            }
        }

        Row {
            spacing: Theme.paddingSmall
            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: Qt.resolvedUrl("../images/badger-front.png")
                smooth: false
                width: Theme.iconSizeExtraSmall * 0.8; height: width
                fillMode: Image.PreserveAspectFit
            }
            Label {
                text: "" + Game.population
                font.pixelSize: Theme.fontSizeSmall
                font.family: "Monospace"
                color: Theme.primaryColor
            }
        }
    }

    // One useful gesture from the couch: keep the lights on.
    CoverActionList {
        enabled: Game.tradingUnlocked
        CoverAction {
            iconSource: "image://theme/icon-cover-refresh"
            onTriggered: Game.buyEnergy()
        }
    }
}
