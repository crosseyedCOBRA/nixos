import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    // Colors from the current wallpaper: awesome-colors renders them into
    // this file with matugen (template: ../awesome/matugen/templates/
    // colors.json) and the bar repaints as soon as it changes. Until it
    // exists, the fixed palette from assets/wallpaper.jpg.
    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.cache/awesome/colors.json"
        watchChanges: true
        onFileChanged: this.reload()
    }
    readonly property var themeColors: {
        try {
            return JSON.parse(colorsFile.text());
        } catch (e) {
            return {};
        }
    }
    readonly property color colorBg: themeColors.bg || "#0a0e1a"
    readonly property color colorSurface: themeColors.surface || "#1a1b26"
    readonly property color colorBorder: themeColors.outline || "#292e42"
    readonly property color colorText: themeColors.text || "#c0caf5"
    readonly property color colorMuted: themeColors.muted || "#565f89"
    readonly property color colorBlue: themeColors.accent || "#7aa2f7"
    readonly property color colorOrange: themeColors.accent2 || "#ff9e64"
    readonly property color colorPink: themeColors.urgent || "#f7768e"

    // CPU, memory, CPU temperature and network state, like waybar's
    // modules in the Hyprland session: one small read every 2s, shared by
    // every bar. CPU is the busy share of the time since the last read.
    property int cpuPercent: 0
    property int memPercent: 0
    property int tempC: 0
    property bool online: false
    property var prevCpu: null

    function parseStats(out) {
        const lines = out.trim().split("\n");
        const cpu = lines[0].trim().split(/\s+/).slice(1).map(Number);
        const idle = cpu[3] + cpu[4];
        const total = cpu.reduce((a, b) => a + b, 0);
        if (root.prevCpu && total > root.prevCpu.total)
            root.cpuPercent = Math.round(100 * (1 - (idle - root.prevCpu.idle) / (total - root.prevCpu.total)));
        root.prevCpu = { total: total, idle: idle };

        const kb = name => Number(((lines.find(l => l.startsWith(name)) || "").split(/\s+/))[1] || 0);
        if (kb("MemTotal:") > 0)
            root.memPercent = Math.round(100 * (1 - kb("MemAvailable:") / kb("MemTotal:")));

        const temp = lines.find(l => /^\d+$/.test(l));
        if (temp) root.tempC = Math.round(Number(temp) / 1000);

        root.online = lines.some(l => l.startsWith("connected"));
    }

    Process {
        id: statsProcess
        command: [ "sh", "-c",
            "head -1 /proc/stat;" +
            " grep -E '^(MemTotal|MemAvailable):' /proc/meminfo;" +
            " for h in /sys/class/hwmon/*; do [ \"$(cat $h/name)\" = k10temp ] && cat $h/temp1_input; done;" +
            " nmcli -t -f STATE general" ]
        stdout: StdioCollector {
            onStreamFinished: root.parseStats(this.text)
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statsProcess.running = true
    }

    // Awesome has no native IPC, so its rc.lua pushes per-screen tag state
    // to this file (keyed by output name) whenever it changes.
    FileView {
        id: awesomeTagsFile
        path: Quickshell.env("HOME") + "/.cache/awesome/tags.json"
        watchChanges: true
        onFileChanged: this.reload()
    }
    readonly property var awesomeTags: {
        try {
            return JSON.parse(awesomeTagsFile.text());
        } catch (e) {
            return {};
        }
    }

    // Fire-and-forget helper for clicking a workspace pill.
    Process {
        id: awesomeViewTag
    }

    Variants {
        // HDMI-A-0 mirrors DisplayPort-0 (--same-as in the xrandr setup), so
        // it reports as its own screen too; without this filter it would
        // get a second PanelWindow drawn on top of DisplayPort-0's.
        model: Quickshell.screens.filter(screen => screen.name !== "HDMI-A-0")

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 32
            color: root.colorBg

            // The primary monitor's bar gets the full set of readouts, the
            // others a reduced one -- the same split as waybar's config.
            readonly property bool isPrimary: modelData.name === "DisplayPort-0"

            Item {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                // --- Far left: launcher ---
                Item {
                    id: launcher
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22

                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        source: Qt.resolvedUrl("nix-snowflake-white.svg")
                        sourceSize: Qt.size(16, 16)
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: rofiProcess.running = true
                    }

                    Process {
                        id: rofiProcess
                        command: [ "rofi", "-show", "drun", "-show-icons" ]
                    }
                }

                // --- Left: workspaces ---
                RowLayout {
                    id: workspaces
                    anchors.left: launcher.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: (root.awesomeTags[bar.screen.name] || {}).tags || []

                        Rectangle {
                            width: 28
                            height: 22
                            radius: 4
                            border.width: modelData.focused ? 0 : 1
                            border.color: root.colorBorder
                            color: modelData.focused ? root.colorBlue
                                : modelData.urgent ? root.colorPink
                                : root.colorSurface

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                color: modelData.focused ? root.colorBg : root.colorMuted
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    awesomeViewTag.command = [
                                        Qt.resolvedUrl("awesome-view-tag.sh").toString().replace("file://", ""),
                                        bar.screen.name,
                                        modelData.name
                                    ];
                                    awesomeViewTag.running = true;
                                }
                            }
                        }
                    }
                }

                // --- Layout indicator: this monitor's current layout ---
                Rectangle {
                    id: layoutIndicator
                    anchors.left: workspaces.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 4
                    color: root.colorSurface
                    border.width: 1
                    border.color: root.colorBorder
                    width: layoutLabel.implicitWidth + 12
                    height: 22

                    Text {
                        id: layoutLabel
                        anchors.centerIn: parent
                        text: (root.awesomeTags[bar.screen.name] || {}).layout || ""
                        color: root.colorMuted
                        font.pixelSize: 12
                    }
                }

                // --- Screenshot and clipboard buttons, like waybar's (clipboard
                // on the primary monitor's bar only, as there) ---
                RowLayout {
                    anchors.left: layoutIndicator.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Text {
                        text: String.fromCodePoint(0xf0e51)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        color: root.colorText

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: screenshotProcess.running = true
                        }
                        Process {
                            id: screenshotProcess
                            command: [ "flameshot", "gui" ]
                        }
                    }

                    Text {
                        visible: bar.isPrimary
                        text: String.fromCodePoint(0xed7b)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        color: root.colorText

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: clipboardProcess.running = true
                        }
                        Process {
                            id: clipboardProcess
                            command: [ "clipmenu" ]
                        }
                    }
                }

                // --- Center: clock / date ---
                Item {
                    id: clockArea
                    anchors.centerIn: parent
                    width: clock.implicitWidth
                    height: clock.implicitHeight

                    Text {
                        id: clock
                        anchors.centerIn: parent
                        color: root.colorText
                        font.pixelSize: 13
                        font.bold: true
                        text: Qt.formatDateTime(new Date(), "ddd, MMM dd  HH:mm:ss")

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd, MMM dd  HH:mm:ss")
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: calendarPopup.visible = !calendarPopup.visible
                    }
                }

                // --- Calendar popup (toggled by clicking the clock) ---
                PopupWindow {
                    id: calendarPopup
                    visible: false
                    color: "transparent"
                    implicitWidth: 220
                    implicitHeight: 250

                    anchor {
                        item: clockArea
                        edges: Edges.Bottom
                        gravity: Edges.Bottom
                        margins.top: 6
                    }

                    property date shownMonth: new Date()

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: root.colorSurface
                        border.width: 1
                        border.color: root.colorBorder

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "‹"
                                    color: root.colorText
                                    font.pixelSize: 16

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        onClicked: calendarPopup.shownMonth = new Date(
                                            calendarPopup.shownMonth.getFullYear(),
                                            calendarPopup.shownMonth.getMonth() - 1, 1)
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: Qt.formatDate(calendarPopup.shownMonth, "MMMM yyyy")
                                    color: root.colorText
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    text: "›"
                                    color: root.colorText
                                    font.pixelSize: 16

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        onClicked: calendarPopup.shownMonth = new Date(
                                            calendarPopup.shownMonth.getFullYear(),
                                            calendarPopup.shownMonth.getMonth() + 1, 1)
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Repeater {
                                    model: ["S", "M", "T", "W", "T", "F", "S"]

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData
                                        color: root.colorMuted
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 7
                                rowSpacing: 4
                                columnSpacing: 0

                                Repeater {
                                    model: {
                                        const y = calendarPopup.shownMonth.getFullYear();
                                        const m = calendarPopup.shownMonth.getMonth();
                                        const firstDow = new Date(y, m, 1).getDay();
                                        const daysInMonth = new Date(y, m + 1, 0).getDate();
                                        const cells = [];
                                        for (let i = 0; i < firstDow; i++) cells.push(0);
                                        for (let d = 1; d <= daysInMonth; d++) cells.push(d);
                                        while (cells.length % 7 !== 0) cells.push(0);
                                        return cells;
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 24
                                        radius: 4
                                        readonly property bool isToday: {
                                            if (modelData === 0) return false;
                                            const now = new Date();
                                            return modelData === now.getDate()
                                                && calendarPopup.shownMonth.getMonth() === now.getMonth()
                                                && calendarPopup.shownMonth.getFullYear() === now.getFullYear();
                                        }
                                        color: isToday ? root.colorBlue : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData === 0 ? "" : modelData
                                            color: parent.isToday ? root.colorBg : root.colorText
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // --- Right: system tray + audio (audio stays furthest right) ---
                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    // System tray
                    RowLayout {
                        spacing: 6

                        Repeater {
                            model: SystemTray.items

                            Item {
                                id: trayItem
                                required property var modelData
                                width: 20
                                height: 20

                                Image {
                                    anchors.fill: parent
                                    source: trayItem.modelData.icon
                                    sourceSize: Qt.size(20, 20)
                                }

                                QsMenuOpener {
                                    id: menuOpener
                                    menu: trayItem.modelData.menu
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            if (trayItem.modelData.hasMenu) trayMenu.visible = !trayMenu.visible;
                                        } else if (trayItem.modelData.onlyMenu) {
                                            if (trayItem.modelData.hasMenu) trayMenu.visible = !trayMenu.visible;
                                        } else {
                                            trayItem.modelData.activate();
                                        }
                                    }
                                }

                                // Themed replacement for modelData.display(), which pops
                                // an unstyled native menu — this renders the same DBusMenu
                                // entries ourselves so they pick up the bar's palette.
                                PopupWindow {
                                    id: trayMenu
                                    visible: false
                                    color: "transparent"
                                    implicitWidth: Math.max(140, menuColumn.implicitWidth + 16)
                                    implicitHeight: menuColumn.implicitHeight + 16

                                    anchor {
                                        item: trayItem
                                        edges: Edges.Bottom
                                        gravity: Edges.Bottom
                                        margins.top: 6
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: root.colorSurface
                                        border.width: 1
                                        border.color: root.colorBorder

                                        ColumnLayout {
                                            id: menuColumn
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 2

                                            Repeater {
                                                model: menuOpener.children

                                                Item {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    implicitHeight: modelData.isSeparator ? 9 : 24
                                                    visible: modelData.text !== "" || !modelData.isSeparator

                                                    Rectangle {
                                                        visible: modelData.isSeparator
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        height: 1
                                                        color: root.colorBorder
                                                    }

                                                    Rectangle {
                                                        visible: !modelData.isSeparator
                                                        anchors.fill: parent
                                                        radius: 4
                                                        color: entryMouse.containsMouse && modelData.enabled
                                                            ? root.colorBlue : "transparent"

                                                        Text {
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            anchors.leftMargin: 8
                                                            anchors.rightMargin: 8
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            text: modelData.text
                                                            elide: Text.ElideRight
                                                            opacity: modelData.enabled ? 1 : 0.5
                                                            color: entryMouse.containsMouse && modelData.enabled
                                                                ? root.colorBg : root.colorText
                                                            font.pixelSize: 12
                                                        }

                                                        MouseArea {
                                                            id: entryMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            enabled: modelData.enabled
                                                            onClicked: {
                                                                modelData.triggered();
                                                                trayMenu.visible = false;
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // CPU, memory, temperature (primary bar only) and network
                    Repeater {
                        model: [
                            { glyph: 0xf4bc, value: root.cpuPercent + "%", primaryOnly: true },
                            { glyph: 0xefc5, value: root.memPercent + "%", primaryOnly: true },
                            { glyph: 0xf2c7, value: root.tempC + "°C", primaryOnly: true },
                            { glyph: root.online ? 0xf0201 : 0xf0202,
                              value: root.online ? "Connected" : "Disconnected", primaryOnly: false }
                        ]

                        Text {
                            required property var modelData
                            visible: bar.isPrimary || !modelData.primaryOnly
                            text: String.fromCodePoint(modelData.glyph) + " " + modelData.value
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: root.colorText
                        }
                    }

                    // Audio (default sink volume)
                    Item {
                        id: audioWidget
                        implicitWidth: volumeIcon.implicitWidth + volumeText.implicitWidth + 12
                        implicitHeight: 22

                        property var sink: Pipewire.defaultAudioSink

                        PwObjectTracker {
                            objects: [ Pipewire.defaultAudioSink ]
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                id: volumeIcon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                color: root.colorText
                                text: {
                                    const sink = audioWidget.sink;
                                    if (!sink || !sink.ready || !sink.audio) return "";
                                    if (sink.audio.muted) return "";
                                    return "";
                                }
                            }

                            Text {
                                id: volumeText
                                color: root.colorText
                                font.pixelSize: 13
                                text: {
                                    const sink = audioWidget.sink;
                                    if (!sink || !sink.ready || !sink.audio) return "--";
                                    if (sink.audio.muted) return "muted";
                                    return Math.round(sink.audio.volume * 100) + "%";
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    const sink = audioWidget.sink;
                                    if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
                                } else {
                                    pavucontrolProcess.running = true;
                                }
                            }
                            onWheel: (wheel) => {
                                const sink = audioWidget.sink;
                                if (!sink || !sink.audio) return;
                                const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                sink.audio.volume = Math.max(0, Math.min(1.5, sink.audio.volume + step));
                            }
                        }

                        Process {
                            id: pavucontrolProcess
                            command: [ "pavucontrol" ]
                        }
                    }

                    // Power menu
                    Item {
                        width: 22
                        height: 22

                        Text {
                            anchors.centerIn: parent
                            text: "⏻"
                            color: root.colorText
                            font.pixelSize: 15
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: powerMenuProcess.running = true
                        }

                        Process {
                            id: powerMenuProcess
                            command: [ "power-menu" ]
                        }
                    }
                }
            }
        }
    }
}
