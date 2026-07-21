import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"

Page {
    id: page

    function stageName(s) {
        if (s === 0) return qsTr("Founding")
        if (s === 1) return qsTr("Shelter")
        if (s === 2) return qsTr("Depths")
        if (s === 3) return qsTr("Muster")
        if (s === 4) return qsTr("The raids")
        return qsTr("Escalation")
    }
    function fmtCooldown(ms) {
        var h = Math.floor(ms / 3600000), m = Math.ceil((ms % 3600000) / 60000)
        if (h >= 1) return h + " h " + m + " min"
        return Math.max(1, Math.ceil(ms / 60000)) + " min"
    }
    function buildingCounts() {
        var c = {}
        var b = Game.buildings
        for (var i = 0; i < b.length; i++) c[b[i].key] = b[i].count
        return c
    }

    // Fixed resource header — the numbers never leave the screen.
    Column {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: Theme.paddingMedium }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Stage") + " " + Game.stage + " · " + stageName(Game.stage)
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
        }

        Flow {
            width: parent.width - 2 * Theme.horizontalPageMargin
            x: Theme.horizontalPageMargin
            spacing: Theme.paddingLarge

            Repeater {
                model: Game.resources
                Row {
                    visible: modelData.visible
                    spacing: Theme.paddingSmall
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Theme.paddingSmall; height: Theme.paddingSmall; radius: 2; color: app.resColor(modelData.key) }
                    Label {
                        text: Game.fmt(modelData.value)
                              + (modelData.cap >= 0 ? "/" + Game.fmt(modelData.cap) : "")
                              + (modelData.rate !== 0 ? " (" + (modelData.rate > 0 ? "+" : "") + Game.fmt(modelData.rate) + ")" : "")
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: "Monospace"
                        color: modelData.low ? "#c0603a" : Theme.primaryColor
                    }
                }
            }
        }
    }

    SilicaFlickable {
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: Theme.paddingSmall }
        clip: true
        contentHeight: col.height

        PullDownMenu {
            MenuItem { text: qsTr("Settings"); onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml")) }
        }

        Column {
            id: col
            width: page.width

            VillageView {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: Theme.itemSizeHuge * 1.5
                population: Game.population
                stage: Game.stage
                counts: buildingCounts()
            }

            // Manual dig — the only thing to do at the very start, and always a fallback.
            Item { width: 1; height: Theme.paddingMedium }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Dig")
                onClicked: Game.tap()
            }

            // Workers ----------------------------------------------------------------
            SectionHeader { text: qsTr("Badgers") + " · " + Game.idleWorkers + "/" + Game.population + " " + qsTr("idle") }

            Repeater {
                model: Game.jobs
                ListItem {
                    visible: modelData.visible
                    contentHeight: modelData.visible ? Theme.itemSizeSmall : 0

                    Label {
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.42
                        text: app.jobName(modelData.key)
                    }
                    Label {
                        anchors { verticalCenter: parent.verticalCenter; horizontalCenter: parent.horizontalCenter }
                        text: modelData.assigned + "  ·  +" + Game.fmt(modelData.perSec * modelData.assigned) + "/s"
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }
                    Row {
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                        spacing: Theme.paddingMedium
                        IconButton {
                            icon.source: "image://theme/icon-m-remove"
                            enabled: modelData.assigned > 0
                            onClicked: Game.assign(modelData.index, -1)
                        }
                        IconButton {
                            icon.source: "image://theme/icon-m-add"
                            enabled: Game.idleWorkers > 0
                            onClicked: Game.assign(modelData.index, 1)
                        }
                    }
                }
            }

            // Buildings --------------------------------------------------------------
            SectionHeader { visible: Game.stage >= 1; text: qsTr("Buildings") }

            Repeater {
                model: Game.buildings
                BackgroundItem {
                    width: col.width
                    height: Theme.itemSizeSmall
                    enabled: modelData.affordable
                    onClicked: Game.build(modelData.index)
                    Label {
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.55
                        text: app.bldName(modelData.key) + (modelData.count > 0 ? "  ×" + modelData.count : "")
                        color: modelData.affordable ? Theme.primaryColor : Theme.secondaryColor
                    }
                    Label {
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                        text: Game.fmt(modelData.cost)
                        font.family: "Monospace"
                        color: modelData.affordable ? "#b0895a" : Theme.secondaryColor
                    }
                }
            }

            // Energy -----------------------------------------------------------------
            SectionHeader { visible: Game.tradingUnlocked; text: qsTr("Energy") }
            BackgroundItem {
                visible: Game.tradingUnlocked
                width: parent.width
                height: Theme.itemSizeSmall
                onClicked: Game.buyEnergy()
                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: Game.blackout ? qsTr("The lights are out.") : qsTr("Buy energy with gold")
                    color: Game.blackout ? "#c0603a" : Theme.primaryColor
                }
                Label {
                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                    text: qsTr("Fill up")
                    color: Theme.highlightColor
                }
            }

            // Barracks ---------------------------------------------------------------
            SectionHeader { visible: Game.barracksUnlocked; text: qsTr("Muster") + " · " + qsTr("power") + " " + Game.fmt(Game.armyPower) }
            Repeater {
                model: Game.units
                Item {
                    visible: Game.barracksUnlocked
                    width: col.width
                    height: Game.barracksUnlocked ? Theme.itemSizeSmall : 0
                    Column {
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.5
                        Label { text: app.unitName(modelData.key) + "  ×" + modelData.count }
                        Label {
                            text: Game.fmt(modelData.costGold) + " " + qsTr("gold") + " · " + Game.fmt(modelData.costMaterials) + " " + qsTr("mat") + " · " + modelData.costPop + " " + qsTr("badger")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }
                    }
                    Button {
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                        preferredWidth: Theme.buttonWidthSmall
                        text: qsTr("Train")
                        enabled: modelData.affordable
                        onClicked: Game.train(modelData.index, 1)
                    }
                }
            }

            // Raids ------------------------------------------------------------------
            SectionHeader { visible: Game.raidsUnlocked; text: qsTr("Raids") }
            Repeater {
                model: Game.targets
                Item {
                    visible: Game.raidsUnlocked
                    width: col.width
                    height: Game.raidsUnlocked ? Theme.itemSizeMedium : 0
                    Column {
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.55
                        Label { text: app.targetName(modelData.key) }
                        Label {
                            text: qsTr("defence") + " " + Game.fmt(modelData.defense)
                                  + (modelData.intelPct > 0 ? "  ·  " + qsTr("intel") + " +" + modelData.intelPct.toFixed(0) + "%" : "")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }
                    }
                    Button {
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                        preferredWidth: Theme.buttonWidthSmall
                        text: modelData.ready ? qsTr("Raid") : fmtCooldown(modelData.cooldownLeft)
                        enabled: modelData.ready && Game.totalUnits > 0
                        onClicked: Game.raid(modelData.index)
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }
        }

        VerticalScrollDecorator { }
    }
}
