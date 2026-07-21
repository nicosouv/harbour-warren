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

    // Announce every birth: population only rises through breeding here, so a jump means new badgers.
    property int lastPop: -1
    Connections {
        target: Game
        onStateChanged: {
            if (page.lastPop >= 0 && Game.population > page.lastPop) {
                birthToast.delta = Game.population - page.lastPop
                birthAnim.restart()
                app.buzz()
            }
            page.lastPop = Game.population
        }
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
    function fmtEta(sec) {
        var s = Math.ceil(sec)
        if (s >= 60) return Math.floor(s / 60) + " min " + (s % 60) + " s"
        return s + " s"
    }
    // The current stage's exit condition, spelled out so nobody is left tapping Scavenge forever.
    function goalText() {
        var k = Game.goalKind
        if (k === "") return ""
        var c = Game.goalCurrent, t = Game.goalTarget
        var tail = " (" + Math.min(c, t) + "/" + t + ")"
        if (k === "population") return qsTr("Grow the colony to %1 badgers").arg(t) + tail
        if (k === "buildings") return qsTr("Raise %1 buildings").arg(t) + tail
        if (k === "gold") return qsTr("Earn %1 gold").arg(t) + tail
        if (k === "units") return qsTr("Train %1 soldiers").arg(t) + tail
        if (k === "raids") return qsTr("Win a raid") + tail
        return ""
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
        spacing: Theme.paddingSmall
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            // No reliable notch detection on Sailfish: shift for everyone, adjustable in Settings.
            topMargin: Theme.paddingLarge
                       + (Game.notchMargin === 1 ? Theme.paddingLarge * 2
                          : Game.notchMargin === 2 ? Theme.paddingLarge * 4 : 0)
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Stage") + " " + Game.stage + " · " + stageName(Game.stage)
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text.length > 0
            text: page.goalText()
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.highlightColor
            horizontalAlignment: Text.AlignHCenter
        }
        // Reproduction: fed and housed badgers breed on their own. Show it happening so "grow the
        // colony" is never a mystery — you can watch the next badger coming.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Game.growing
            spacing: Theme.paddingSmall
            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: Qt.resolvedUrl("../images/badger-front.png")
                smooth: false; width: Theme.iconSizeExtraSmall * 0.7; height: width
                fillMode: Image.PreserveAspectFit
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.itemSizeHuge; height: 5; radius: 2
                color: Theme.rgba(Theme.primaryColor, 0.15)
                Rectangle {
                    width: parent.width * Game.broodProgress; height: parent.height; radius: 2
                    color: "#7fae5a"
                    Behavior on width { NumberAnimation { duration: 400 } }
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("breeding")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
            }
        }
        // Not growing yet at the start: point at the actual lever — food, from foragers.
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: Game.stage === 0 && !Game.growing && Game.population < Game.housingCap
            text: qsTr("Assign badgers to forage: well fed, the colony breeds on its own.")
            font.pixelSize: Theme.fontSizeExtraSmall
            color: "#c0a24a"
        }

        // Breathing room between the objective block and the resource bar.
        Item { width: 1; height: Theme.paddingMedium }

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
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: Theme.paddingLarge }
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
                    starving: Game.starving
                    siteBld: Game.buildSite
                    siteProgress: Game.buildProgress
                    ambiance: Game.ambiance
                    reduceFx: Game.reduceFx
                }

                // A birth is announced right on the village: a new badger, unmistakably.
                Row {
                    id: birthToast
                    property int delta: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.5
                    spacing: Theme.paddingSmall
                    opacity: 0
                    Label { anchors.verticalCenter: parent.verticalCenter; text: "+" + birthToast.delta; color: "#9fd06a"; font.pixelSize: Theme.fontSizeMedium; font.bold: true }
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: Qt.resolvedUrl("../images/badger-front.png")
                        smooth: false; width: Theme.iconSizeSmall; height: width
                        fillMode: Image.PreserveAspectFit
                    }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: qsTr("a new badger"); color: Theme.primaryColor; font.pixelSize: Theme.fontSizeSmall }
                }
                ParallelAnimation {
                    id: birthAnim
                    NumberAnimation { target: birthToast; property: "y"; from: birthToast.parent.height * 0.5; to: birthToast.parent.height * 0.24; duration: 1400; easing.type: Easing.OutQuad }
                    SequentialAnimation {
                        NumberAnimation { target: birthToast; property: "opacity"; to: 1; duration: 220 }
                        PauseAnimation { duration: 800 }
                        NumberAnimation { target: birthToast; property: "opacity"; to: 0; duration: 380 }
                    }
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

                // The reward floats up showing exactly what turned up: an apple, or a log of wood.
                Row {
                    id: floatReward
                    property bool wasMat: false
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    opacity: 0
                    Label { text: "+1"; color: Theme.highlightColor; font.pixelSize: Theme.fontSizeMedium }
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: Qt.resolvedUrl(floatReward.wasMat ? "../images/res-materials.png" : "../images/res-food.png")
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
                    onClicked: { Game.tap(); floatReward.wasMat = Game.lastTapMat; app.buzz(); digPulse.restart(); floatAnim.restart() }
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

            // A site with no builders never finishes — say so, right under the header.
            Label {
                visible: Game.stage >= 1 && Game.buildSite >= 0 && Game.builders <= 0
                x: Theme.horizontalPageMargin
                width: col.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("You need at least one builder to construct a building.")
                font.pixelSize: Theme.fontSizeExtraSmall
                color: "#c0603a"
            }

            Repeater {
                model: Game.buildings
                BackgroundItem {
                    width: col.width
                    height: Theme.itemSizeMedium
                    enabled: modelData.affordable || modelData.damaged
                    onClicked: {
                        if (modelData.damaged) Game.repairBuilding(modelData.index)
                        else Game.build(modelData.index)
                        app.buzz()
                    }

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
                            visible: !modelData.site && !modelData.damaged
                            text: page.bldEffect(modelData.key)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                            truncationMode: TruncationMode.Fade
                            width: parent.width
                        }
                        Label {
                            visible: modelData.damaged
                            text: qsTr("Damaged") + " · " + qsTr("repair") + " " + Game.fmt(modelData.repairCost)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: "#c0603a"
                        }
                        Label {
                            visible: modelData.site
                            text: qsTr("Under construction") + " · " + Math.round(modelData.progress * 100) + "%"
                                  + (Game.builders > 0 && Game.buildEtaSec > 0
                                     ? " · " + page.fmtEta(Game.buildEtaSec)
                                     : (Game.builders <= 0 ? " · " + qsTr("stalled") : ""))
                                  + (Game.powered ? " · " + qsTr("energy +25%")
                                     : (Game.blackout ? " · " + qsTr("blackout −30%") : ""))
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Game.builders > 0 ? Theme.highlightColor : "#c0603a"
                        }
                        Rectangle {
                            visible: modelData.site
                            width: parent.width; height: 4; radius: 1
                            color: Theme.rgba(Theme.primaryColor, 0.15)
                            Rectangle {
                                width: parent.width * modelData.progress; height: parent.height; radius: 1
                                color: Theme.highlightColor
                                // Glide across the one-second gap between ticks: a continuous fill.
                                Behavior on width { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
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
            SectionHeader { visible: Game.energyActive; text: qsTr("Energy") }
            // No trading post yet: energy matters now, but you can't buy any until you build one.
            BackgroundItem {
                visible: Game.energyActive && !Game.tradingUnlocked
                width: parent.width
                height: Theme.itemSizeMedium
                enabled: false
                Image {
                    id: enHintIcon
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    source: Qt.resolvedUrl("../images/res-energy.png")
                    smooth: false
                    width: Theme.iconSizeMedium; height: width
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.5
                }
                Label {
                    anchors { left: enHintIcon.right; leftMargin: Theme.paddingMedium; right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                    text: qsTr("Build a trading post to buy energy and power the colony.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryColor
                }
            }
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
                    Label {
                        text: Game.powered ? qsTr("Powered: +25% production and building")
                              : Game.blackout ? qsTr("Blackout: −30% production and building")
                              : qsTr("Keep it powered: +25% production and building")
                        color: Game.powered ? "#3ab5a6" : Game.blackout ? "#c0603a" : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        width: parent.width
                        truncationMode: TruncationMode.Fade
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
                        anchors { left: unitIcon.right; leftMargin: Theme.paddingMedium; right: trainBtn.left; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                        Label {
                            width: parent.width
                            truncationMode: TruncationMode.Fade
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
                    IconButton {
                        id: trainBtn
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                        icon.source: "image://theme/icon-m-add"
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
                        anchors { left: foxIcon.right; leftMargin: Theme.paddingMedium; right: raidBtn.left; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                        Label { text: app.targetName(modelData.key); truncationMode: TruncationMode.Fade; width: parent.width }
                        Label {
                            width: parent.width
                            truncationMode: TruncationMode.Fade
                            text: modelData.ready
                                  ? qsTr("defence") + " " + Game.fmt(modelData.defense)
                                    + (modelData.intelPct > 0 ? "  ·  " + qsTr("intel") + " +" + modelData.intelPct.toFixed(0) + "%" : "")
                                  : qsTr("ready in") + " " + fmtCooldown(modelData.cooldownLeft)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: modelData.ready ? Theme.secondaryColor : "#c0a24a"
                        }
                    }
                    IconButton {
                        id: raidBtn
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                        icon.source: "image://theme/icon-m-right"
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
