import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string cli: "$HOME/.local/bin/cachy-mode"
    property var st: ({})
    property bool switching: false
    property string pending: ""          // mode being switched to, for instant UI feedback
    readonly property bool gaming: pending ? pending === "gaming" : st.mode === "gaming"

    // Mode palettes: gaming = violet→magenta, dev = sky→teal
    readonly property color accentA: gaming ? "#7c3aed" : "#0284c7"
    readonly property color accentB: gaming ? "#db2777" : "#0d9488"
    readonly property var segColors: ["#a78bfa", "#38bdf8", "#34d399", "#fbbf24", "#f472b6"]

    Plasmoid.icon: gaming ? "input-gaming" : "applications-development"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    // Bright monochrome tray icon, tinted like the other tray entries
    compactRepresentation: MouseArea {
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.fill: parent
            source: root.icon(root.gaming ? "gaming" : "dev")
            isMask: true
            color: Kirigami.Theme.textColor
            active: parent.containsMouse
        }
    }
    toolTipMainText: gaming ? "Gaming mode" : "Dev mode"
    toolTipSubText: st.gpu ? `VRAM ${gb(st.gpu.used)} / ${gb(st.gpu.total)} GB · ${st.gpu.temp}°C` : ""

    function icon(mode) { return Qt.resolvedUrl(`../icons/${mode}.svg`) }
    function gb(mb) { return (mb / 1024).toFixed(1) }
    function run(args) { exec.connectSource(`${cli} ${args}`) }
    function refresh() { run("status --json") }
    function switchTo(mode, extra) {
        if (switching || (mode === st.mode && !extra)) return
        switching = true; pending = mode
        run(mode + (extra ? " " + extra : ""))
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source.endsWith("status --json")) {
                try { root.st = JSON.parse(data.stdout) } catch (e) {}
            } else {
                root.switching = false; root.pending = ""
                root.refresh()
            }
        }
    }

    Timer {
        interval: root.expanded ? 2000 : 15000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // ── reusable pieces ────────────────────────────────────────────────
    component Tile: Rectangle {
        radius: 12
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.05)
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
    }
    component Caption: PlasmaComponents3.Label {
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1
        opacity: 0.55
    }
    component Metric: ColumnLayout {
        property string caption
        property string value
        property string unit
        spacing: 2
        Caption { text: parent.caption }
        RowLayout {
            spacing: 3
            PlasmaComponents3.Label {
                text: parent.parent.value
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.7
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            PlasmaComponents3.Label {
                text: parent.parent.unit
                opacity: 0.55
                Layout.alignment: Qt.AlignBaseline
            }
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: col.implicitHeight + Kirigami.Units.largeSpacing * 2

        ColumnLayout {
            id: col
            anchors { fill: parent; margins: Kirigami.Units.largeSpacing }
            spacing: Kirigami.Units.largeSpacing

            // ── hero ───────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: hero.implicitHeight + Kirigami.Units.gridUnit * 1.4
                radius: 16
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: root.accentA; Behavior on color { ColorAnimation { duration: 400 } } }
                    GradientStop { position: 1; color: root.accentB; Behavior on color { ColorAnimation { duration: 400 } } }
                }

                // top gloss for depth, same radius so nothing pokes past the corners
                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.16) }
                        GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0) }
                    }
                }

                RowLayout {
                    id: hero
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Kirigami.Units.gridUnit * 0.9 }
                    spacing: Kirigami.Units.largeSpacing

                    Rectangle {
                        implicitWidth: Kirigami.Units.iconSizes.large + Kirigami.Units.largeSpacing
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: Qt.rgba(1, 1, 1, 0.18)
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.medium; height: width
                            source: root.icon(root.gaming ? "gaming" : "dev")
                            color: "white"; isMask: true
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PlasmaComponents3.Label {
                            text: root.switching ? "Switching…" : (root.gaming ? "Gaming" : "Dev")
                            color: "white"
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.9
                            font.weight: Font.Bold
                        }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            color: "white"; opacity: 0.85
                            elide: Text.ElideRight
                            text: (root.st.x3d === "cache" ? "V-cache CCD" : "Frequency CCD") + "  ·  " + (root.st.profile ?? "…")
                        }
                    }
                    Rectangle {
                        visible: root.st.auto_triggered === true
                        radius: height / 2
                        implicitHeight: autoLbl.implicitHeight + 6
                        implicitWidth: autoLbl.implicitWidth + 16
                        color: Qt.rgba(1, 1, 1, 0.22)
                        PlasmaComponents3.Label {
                            id: autoLbl; anchors.centerIn: parent
                            text: "AUTO"; color: "white"; font.weight: Font.DemiBold
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize; font.letterSpacing: 1
                        }
                    }
                }
            }

            // ── segmented mode switch ──────────────────────────────────
            Tile {
                Layout.fillWidth: true
                implicitHeight: Kirigami.Units.gridUnit * 2.4
                radius: height / 2

                Rectangle {
                    id: thumb
                    width: parent.width / 2 - 6; height: parent.height - 6
                    y: 3; x: root.gaming ? 3 : parent.width / 2 + 3
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: root.accentA; Behavior on color { ColorAnimation { duration: 400 } } }
                        GradientStop { position: 1; color: root.accentB; Behavior on color { ColorAnimation { duration: 400 } } }
                    }
                    Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                }

                Repeater {
                    model: [{ mode: "gaming", label: "Gaming" }, { mode: "dev", label: "Dev" }]
                    MouseArea {
                        required property var modelData
                        required property int index
                        x: index * parent.width / 2; width: parent.width / 2; height: parent.height
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.switching
                        onClicked: root.switchTo(modelData.mode)
                        readonly property bool on: (modelData.mode === "gaming") === root.gaming
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon {
                                source: root.icon(modelData.mode)
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium; implicitHeight: implicitWidth
                                isMask: true
                                color: parent.parent.on ? "white" : Kirigami.Theme.textColor
                                opacity: parent.parent.on || parent.parent.containsMouse ? 1 : 0.6
                            }
                            PlasmaComponents3.Label {
                                text: modelData.label
                                font.weight: Font.DemiBold
                                color: parent.parent.on ? "white" : Kirigami.Theme.textColor
                                opacity: parent.parent.on || parent.parent.containsMouse ? 1 : 0.6
                            }
                        }
                    }
                }
            }

            // ── busy / game banners ────────────────────────────────────
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: (root.st.comfy_queue ?? 0) > 0 && !root.gaming
                type: Kirigami.MessageType.Warning
                text: `ComfyUI has ${root.st.comfy_queue} job(s) queued. Gaming waits for them.`
                actions: [ Kirigami.Action {
                    text: "Force"; icon.name: "process-stop"
                    onTriggered: root.switchTo("gaming", "--force")
                } ]
            }
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: !!root.st.game
                type: Kirigami.MessageType.Positive
                icon.source: root.icon("gaming")
                text: root.st.game ? `Playing ${root.st.game.name}` : ""
            }

            // ── VRAM: ring + per-process bar ───────────────────────────
            Tile {
                Layout.fillWidth: true
                implicitHeight: vramRow.implicitHeight + Kirigami.Units.largeSpacing * 2

                RowLayout {
                    id: vramRow
                    anchors { fill: parent; margins: Kirigami.Units.largeSpacing }
                    spacing: Kirigami.Units.largeSpacing * 1.5

                    Canvas {
                        id: ring
                        implicitWidth: Kirigami.Units.gridUnit * 4; implicitHeight: implicitWidth
                        property real value: root.st.gpu ? root.st.gpu.used / Math.max(1, root.st.gpu.total) : 0
                        property color cA: root.accentA
                        property color cB: root.accentB
                        Behavior on value { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                        onValueChanged: requestPaint()
                        onCAChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d"), lw = width * 0.1, r = width / 2 - lw
                            const a0 = 0.75 * Math.PI, span = 1.5 * Math.PI
                            ctx.reset(); ctx.lineWidth = lw; ctx.lineCap = "round"
                            ctx.strokeStyle = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                            ctx.beginPath(); ctx.arc(width / 2, height / 2, r, a0, a0 + span); ctx.stroke()
                            const g = ctx.createLinearGradient(0, height, width, 0)
                            g.addColorStop(0, cA); g.addColorStop(1, cB)
                            ctx.strokeStyle = g
                            ctx.beginPath(); ctx.arc(width / 2, height / 2, r, a0, a0 + span * Math.max(0.01, value)); ctx.stroke()
                        }
                        PlasmaComponents3.Label {
                            anchors.centerIn: parent
                            text: Math.round(ring.value * 100) + "%"
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }

                    ColumnLayout {
                        id: bar
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        readonly property var procs: (root.st.vram ?? []).slice(0, 5)
                        readonly property real total: root.st.gpu ? Math.max(1, root.st.gpu.total) : 1

                        Metric {
                            caption: "VRAM"
                            value: root.st.gpu ? root.gb(root.st.gpu.used) : "–"
                            unit: root.st.gpu ? `/ ${root.gb(root.st.gpu.total)} GB` : ""
                        }
                        Item {
                            id: track
                            Layout.fillWidth: true
                            implicitHeight: 8
                            Rectangle {
                                anchors.fill: parent; radius: 4
                                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
                            }
                            Row {
                                anchors.fill: parent
                                spacing: 2
                                Repeater {
                                    model: bar.procs
                                    Rectangle {
                                        required property var modelData
                                        required property int index
                                        height: track.height; radius: 4
                                        width: Math.max(4, track.width * modelData.mb / bar.total - 2)
                                        color: root.segColors[index % root.segColors.length]
                                        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing
                            Repeater {
                                model: bar.procs
                                RowLayout {
                                    required property var modelData
                                    required property int index
                                    spacing: 5
                                    Rectangle { implicitWidth: 7; implicitHeight: 7; radius: 3.5; color: root.segColors[index % root.segColors.length] }
                                    PlasmaComponents3.Label { text: modelData.name; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
                                    PlasmaComponents3.Label { text: root.gb(modelData.mb); opacity: 0.55; font.pixelSize: Kirigami.Theme.smallFont.pixelSize; font.features: { "tnum": 1 } }
                                }
                            }
                        }
                    }
                }
            }

            // ── GPU stats ──────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: [
                        { caption: "Temp",  value: root.st.gpu ? root.st.gpu.temp : "–",  unit: "°C" },
                        { caption: "Power", value: root.st.gpu ? root.st.gpu.power : "–", unit: "W" },
                        { caption: "Load",  value: root.st.gpu ? root.st.gpu.util : "–",  unit: "%" }
                    ]
                    Tile {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: m.implicitHeight + Kirigami.Units.largeSpacing * 2
                        Metric {
                            id: m
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Kirigami.Units.largeSpacing }
                            caption: modelData.caption; value: modelData.value; unit: modelData.unit
                        }
                    }
                }
            }

            // ── services ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: root.st.services ?? []
                    Tile {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: svcRow.implicitHeight + Kirigami.Units.smallSpacing * 3
                        radius: height / 2
                        RowLayout {
                            id: svcRow
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing
                            Rectangle {
                                implicitWidth: 8; implicitHeight: 8; radius: 4
                                color: modelData.active ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                                SequentialAnimation on opacity {
                                    running: modelData.active; loops: Animation.Infinite
                                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                                }
                            }
                            PlasmaComponents3.Label {
                                text: modelData.name
                                font.weight: Font.DemiBold
                            }
                            PlasmaComponents3.Label {
                                text: modelData.active ? "running" : "stopped"
                                opacity: 0.55
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            }
                        }
                    }
                }
            }

            // ── auto-switch ────────────────────────────────────────────
            Tile {
                Layout.fillWidth: true
                implicitHeight: autoRow.implicitHeight + Kirigami.Units.largeSpacing * 2
                RowLayout {
                    id: autoRow
                    anchors { fill: parent; margins: Kirigami.Units.largeSpacing }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PlasmaComponents3.Label { text: "Auto-switch"; font.weight: Font.DemiBold }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: "Gaming while a Steam game runs, back to Dev when it exits"
                            wrapMode: Text.Wrap; opacity: 0.55
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        }
                    }
                    PlasmaComponents3.Switch {
                        checked: !!root.st.auto
                        onToggled: root.run("auto " + (checked ? "on" : "off"))
                    }
                }
            }
        }
    }
}
