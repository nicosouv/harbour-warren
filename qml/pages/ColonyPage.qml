import QtQuick 2.6
import Sailfish.Silica 1.0
import "../components"

Page {
    id: page

    // Swipe left for the stats page, the Silica way.
    onStatusChanged: {
        if (status === PageStatus.Active)
            pageStack.pushAttached(Qt.resolvedUrl("StatsPage.qml"))
    }

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
    // What each job pays out, and what each building is for — no guessing.
    function jobIcon(key) {
        if (key === "forage") return "../images/res-food.png"
        if (key === "gather") return "../images/res-materials.png"
        if (key === "mine") return "../images/res-gold.png"
        return "../images/dig.png"   // builders carry the shovel
    }
    function unitDesc(key) {
        if (key === "militia") return qsTr("Cheap and fragile — the most power per gold.")
        return qsTr("Five times the punch per badger — saves your population.")
    }
    function bldEffect(key) {
        if (key === "burrow") return qsTr("+3 housing")
        if (key === "granary") return qsTr("more food storage, better foraging")
        if (key === "workshop") return qsTr("better gathering")
        if (key === "mineshaft") return qsTr("better mining")
        if (key === "tradingpost") return qsTr("buy energy; powers the colony")
        if (key === "barracks") return qsTr("train soldiers")
        return ""
    }

    // Fixed resource header — pixel icons, shifted clear of any camera notch.
    Column {
        id: header
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            // No reliable notch detection on Sailfish: shift for everyone, adjustable in Settings.
            topMargin: Theme.paddingMedium
                       + (Game.notchMargin === 1 ? Theme.paddingLarge * 2
                          : Game.notchMargin === 2 ? Theme.paddingLarge * 4 : 0)
        }

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
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: Qt.resolvedUrl("../images/res-" + modelData.key + ".png")
                        smooth: false
                        width: Theme.iconSizeExtraSmall; height: width
                        fillMode: Image.PreserveAspectFit
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Label {
                            text: Game.fmt(modelData.value)
                                  + (modelData.rate !== 0 ? " (" + (modelData.rate > 0 ? "+" : "") + Game.fmt(modelData.rate) + ")" : "")
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: "Monospace"
                            color: modelData.low ? "#c0603a" : Theme.primaryColor
                        }
                        // Capacity gauge (food, energy): watch the energy drain toward the dark.
                        Rectangle {
                            visible: modelData.cap >= 0
                            width: Theme.itemSizeLarge * 0.8; height: 4; radius: 1
                            color: Theme.rgba(Theme.primaryColor, 0.15)
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, modelData.value / Math.max(1, modelData.cap)))
                                height: parent.height; radius: 1
                                color: modelData.key === "energy"
                                       ? (modelData.low ? "#c0603a" : "#3ab5a6")
                                       : app.resColor(modelData.key)
                                Behavior on width { NumberAnimation { duration: 400 } }
                            }
                        }
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
            MenuItem {
                text: qsTr("New game")
                onClicked: newGameRemorse.execute(qsTr("Starting over"), function() { Game.newGame() })
            }
        }
        RemorsePopup { id: newGameRemorse }

        Column {
            id: col
            width: page.width

            // The warren, front and centre.
            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: Theme.itemSizeHuge * 2.2
                radius: Theme.paddingMedium
                color: "#20242e"
                clip: true
                VillageView {
                    anchors.fill: parent
                    population: Game.population
                    stage: Game.stage
                    counts: buildingCounts()
                    blackout: Game.blackout
                    siteBld: Game.buildSite
                    siteProgress: Game.buildProgress
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

            // Scavenge: rummage the ground for food — the icon says exactly what you get.
            Rectangle {
                id: digBtn
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.5
                height: Theme.itemSizeMedium
                radius: Theme.paddingMedium
                color: Theme.rgba("#4a3d30", digArea.pressed ? 1.0 : 0.75)
                border.color: "#6a5a40"
                border.width: 2

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.paddingMedium
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: Qt.resolvedUrl("../images/dig.png")
                        smooth: false
                        width: Theme.iconSizeSmall; height: width
                        fillMode: Image.PreserveAspectFit
                        rotation: digArea.pressed ? -18 : 0
                        Behavior on rotation { NumberAnimation { duration: 90 } }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Scavenge")
                        font.pixelSize: Theme.fontSizeLarge
                    }
                }

                // The reward floats up: +1 food, no ambiguity.
                Row {
                    id: floatReward
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    opacity: 0
                    Label { text: "+1"; color: Theme.highlightColor; font.pixelSize: Theme.fontSizeMedium }
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: Qt.resolvedUrl("../images/res-food.png")
                        smooth: false
                        width: Theme.iconSizeExtraSmall; height: width
                        fillMode: Image.PreserveAspectFit
                    }
                }
                ParallelAnimation {
                    id: floatAnim
                    NumberAnimation { target: floatReward; property: "y"; from: 0; to: -Theme.itemSizeSmall; duration: 500 }
                    SequentialAnimation {
                        NumberAnimation { target: floatReward; property: "opacity"; to: 1; duration: 80 }
                        NumberAnimation { target: floatReward; property: "opacity"; to: 0; duration: 400 }
                    }
                }

                MouseArea {
                    id: digArea
                    anchors.fill: parent
                    onClicked: { Game.tap(); app.buzz(); digPulse.restart(); floatAnim.restart() }
                }
                SequentialAnimation {
                    id: digPulse
                    NumberAnimation { target: digBtn; property: "scale"; to: 0.96; duration: 40 }
                    NumberAnimation { target: digBtn; property: "scale"; to: 1.0; duration: 90 }
                }
            }

            // Workers ----------------------------------------------------------------
            SectionHeader { text: qsTr("Badgers") + " · " + Game.idleWorkers + "/" + Game.population + " " + qsTr("idle") }

            Repeater {
                model: Game.jobs
                ListItem {
                    visible: modelData.visible
                    contentHeight: modelData.visible ? Theme.itemSizeSmall : 0

                    Row {
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.paddingSmall
                        Label { anchors.verticalCenter: parent.verticalCenter; text: app.jobName(modelData.key) }
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            source: Qt.resolvedUrl(page.jobIcon(modelData.key))
                            smooth: false
                            width: Theme.iconSizeExtraSmall * 0.8; height: width
                            fillMode: Image.PreserveAspectFit
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.assigned
                                  + (modelData.key === "build"
                                     ? (Game.buildSite >= 0 ? " · " + Math.round(Game.buildProgress * 100) + "%" : "")
                                     : " · +" + Game.fmt(modelData.perSec * modelData.assigned) + "/s")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }
                    }
                    Row {
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                        spacing: Theme.paddingMedium
                        IconButton {
                            icon.source: "image://theme/icon-m-remove"
                            enabled: modelData.assigned > 0
                            onClicked: { Game.assign(modelData.index, -1); app.buzz() }
                        }
                        IconButton {
                            icon.source: "image://theme/icon-m-add"
                            enabled: Game.idleWorkers > 0
                            onClicked: { Game.assign(modelData.index, 1); app.buzz() }
                        }
                    }
                }
            }

            // Buildings: sprite, cost with icon, and what it actually does. -----------
            SectionHeader { visible: Game.stage >= 1; text: qsTr("Buildings") }

            Repeater {
                model: Game.buildings
                BackgroundItem {
                    width: col.width
                    height: Theme.itemSizeMedium
                    enabled: modelData.affordable
                    onClicked: { Game.build(modelData.index); app.buzz() }

                    Image {
                        id: bldIcon
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        source: Qt.resolvedUrl("../images/bld-" + modelData.key + ".png")
                        smooth: false
                        width: Theme.iconSizeMedium; height: width
                        fillMode: Image.PreserveAspectFit
                        opacity: modelData.affordable ? 1.0 : 0.5
                    }
                    Column {
                        anchors { left: bldIcon.right; leftMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                        width: parent.width * 0.45
                        Label {
                            text: app.bldName(modelData.key) + (modelData.count > 0 ? "  ×" + modelData.count : "")
                            color: modelData.affordable || modelData.site ? Theme.primaryColor : Theme.secondaryColor
                            truncationMode: TruncationMode.Fade
                            width: parent.width
                        }
                        Label {
                            visible: !modelData.site
                            text: page.bldEffect(modelData.key)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                            truncationMode: TruncationMode.Fade
                            width: parent.width
                        }
                        Label {
                            visible: modelData.site
                            text: qsTr("Under construction") + " · " + Math.round(modelData.progress * 100) + "%"
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.highlightColor
                        }
                        Rectangle {
                            visible: modelData.site
                            width: parent.width; height: 4; radius: 1
                            color: Theme.rgba(Theme.primaryColor, 0.15)
                            Rectangle {
                                width: parent.width * modelData.progress; height: parent.height; radius: 1
                                color: Theme.highlightColor
                                Behavior on width { NumberAnimation { duration: 400 } }
                            }
                        }
                    }
                    Row {
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                        spacing: Theme.paddingSmall
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            source: Qt.resolvedUrl("../images/res-materials.png")
                            smooth: false
                            width: Theme.iconSizeExtraSmall * 0.8; height: width
                            fillMode: Image.PreserveAspectFit
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Game.fmt(modelData.cost)
                            font.family: "Monospace"
                            color: modelData.affordable ? "#b0895a" : Theme.secondaryColor
                        }
                    }
                }
            }

            // Energy: the bar drains toward the dark. ---------------------------------
            SectionHeader { visible: Game.tradingUnlocked; text: qsTr("Energy") }
            BackgroundItem {
                visible: Game.tradingUnlocked
                width: parent.width
                height: Theme.itemSizeMedium
                onClicked: { Game.buyEnergy(); app.buzz() }

                Image {
                    id: enIcon
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    source: Qt.resolvedUrl("../images/res-energy.png")
                    smooth: false
                    width: Theme.iconSizeMedium; height: width
                    fillMode: Image.PreserveAspectFit
                }
                Column {
                    anchors { left: enIcon.right; leftMargin: Theme.paddingMedium; right: fillLbl.left; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                    spacing: Theme.paddingSmall
                    Label {
                        text: Game.blackout ? qsTr("The lights are out.") : qsTr("Buy energy with gold")
                        color: Game.blackout ? "#c0603a" : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Rectangle {
                        width: parent.width; height: 6; radius: 2
                        color: Theme.rgba(Theme.primaryColor, 0.15)
                        Rectangle {
                            property var er: {
                                var rs = Game.resources
                                for (var i = 0; i < rs.length; i++) if (rs[i].key === "energy") return rs[i]
                                return { value: 0, cap: 1 }
                            }
                            width: parent.width * Math.max(0, Math.min(1, er.value / Math.max(1, er.cap)))
                            height: parent.height; radius: 2
                            color: Game.blackout ? "#c0603a" : "#3ab5a6"
                            Behavior on width { NumberAnimation { duration: 400 } }
                        }
                    }
                }
                Label {
                    id: fillLbl
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
                    height: Game.barracksUnlocked ? Theme.itemSizeMedium : 0
                    Image {
                        id: unitIcon
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        source: Qt.resolvedUrl("../images/badger-front.png")
                        smooth: false
                        width: Theme.iconSizeMedium; height: width
                        fillMode: Image.PreserveAspectFit
                    }
                    Column {
                        anchors { left: unitIcon.right; leftMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                        width: parent.width * 0.45
                        Label {
                            text: app.unitName(modelData.key) + "  ×" + modelData.count
                                  + "  ·  " + qsTr("power") + " " + Game.fmt(modelData.power)
                        }
                        Label {
                            text: page.unitDesc(modelData.key)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                            truncationMode: TruncationMode.Fade
                            width: parent.width
                        }
                        Row {
                            spacing: Theme.paddingSmall
                            Image { anchors.verticalCenter: parent.verticalCenter; source: Qt.resolvedUrl("../images/res-gold.png"); smooth: false; width: Theme.iconSizeExtraSmall * 0.7; height: width; fillMode: Image.PreserveAspectFit }
                            Label { anchors.verticalCenter: parent.verticalCenter; text: Game.fmt(modelData.costGold); font.pixelSize: Theme.fontSizeExtraSmall; color: Theme.secondaryColor }
                            Image { anchors.verticalCenter: parent.verticalCenter; source: Qt.resolvedUrl("../images/res-materials.png"); smooth: false; width: Theme.iconSizeExtraSmall * 0.7; height: width; fillMode: Image.PreserveAspectFit }
                            Label { anchors.verticalCenter: parent.verticalCenter; text: Game.fmt(modelData.costMaterials); font.pixelSize: Theme.fontSizeExtraSmall; color: Theme.secondaryColor }
                            Image { anchors.verticalCenter: parent.verticalCenter; source: Qt.resolvedUrl("../images/badger-front.png"); smooth: false; width: Theme.iconSizeExtraSmall * 0.7; height: width; fillMode: Image.PreserveAspectFit }
                            Label { anchors.verticalCenter: parent.verticalCenter; text: "" + modelData.costPop; font.pixelSize: Theme.fontSizeExtraSmall; color: Theme.secondaryColor }
                        }
                    }
                    Button {
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                        preferredWidth: Theme.buttonWidthSmall
                        text: qsTr("Train")
                        enabled: modelData.affordable
                        onClicked: { Game.train(modelData.index, 1); app.buzz() }
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
                    Image {
                        id: foxIcon
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        source: Qt.resolvedUrl("../images/fox-side.png")
                        smooth: false
                        width: Theme.iconSizeMedium; height: width * 0.6
                        fillMode: Image.PreserveAspectFit
                    }
                    Column {
                        anchors { left: foxIcon.right; leftMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                        width: parent.width * 0.45
                        Label { text: app.targetName(modelData.key); truncationMode: TruncationMode.Fade; width: parent.width }
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
                        onClicked: { Game.raid(modelData.index); app.buzz() }
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }
        }

        VerticalScrollDecorator { }
    }
}
