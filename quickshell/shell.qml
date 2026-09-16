import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    // Palette pulled from assets/wallpaper.jpg (deep space navy, nebula
    // blue/purple, warm cloud orange, coral planet surface). Keep in sync
    // with the `colors` let-binding in home.nix.
    readonly property color colorBg: "#0a0e1a"
    readonly property color colorSurface: "#1a1b26"
    readonly property color colorBorder: "#292e42"
    readonly property color colorText: "#c0caf5"
    readonly property color colorMuted: "#565f89"
    readonly property color colorBlue: "#7aa2f7"
    readonly property color colorOrange: "#ff9e64"
    readonly property color colorPink: "#f7768e"

    // Awesome has no native IPC (unlike i3), so its rc.lua pushes per-screen
    // tag state to this file (keyed by output name) whenever it changes.
    // Used as a fallback below when I3's IPC isn't connected.
    FileView {
        id: awesomeTagsFile
        path: "/home/mike/.cache/awesome/tags.json"
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

    // Fire-and-forget helper for clicking an Awesome-sourced workspace pill.
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

            Item {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                // --- Left: workspaces ---
                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: I3.workspaces.length > 0 ? I3.workspaces : (root.awesomeTags[bar.screen.name] || [])

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
                                    if (modelData.activate) {
                                        modelData.activate();
                                    } else {
                                        awesomeViewTag.command = [
                                            "/home/mike/.config/quickshell/awesome-view-tag.sh",
                                            bar.screen.name,
                                            modelData.name
                                        ];
                                        awesomeViewTag.running = true;
                                    }
                                }
                            }
                        }
                    }
                }

                // --- Center: clock / date ---
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

                // --- Right: audio + system tray ---
                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    // Audio (default sink volume)
                    Item {
                        id: audioWidget
                        implicitWidth: volumeText.implicitWidth + 8
                        implicitHeight: 22

                        property var sink: Pipewire.defaultAudioSink

                        PwObjectTracker {
                            objects: [ Pipewire.defaultAudioSink ]
                        }

                        Text {
                            id: volumeText
                            anchors.centerIn: parent
                            color: root.colorText
                            font.pixelSize: 13
                            text: {
                                const sink = audioWidget.sink;
                                if (!sink || !sink.ready || !sink.audio) return "--";
                                if (sink.audio.muted) return "🔇";
                                return "🔊 " + Math.round(sink.audio.volume * 100) + "%";
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            onClicked: {
                                const sink = audioWidget.sink;
                                if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
                            }
                            onWheel: (wheel) => {
                                const sink = audioWidget.sink;
                                if (!sink || !sink.audio) return;
                                const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                sink.audio.volume = Math.max(0, Math.min(1.5, sink.audio.volume + step));
                            }
                        }
                    }

                    // System tray
                    RowLayout {
                        spacing: 6

                        Repeater {
                            model: SystemTray.items

                            Item {
                                width: 20
                                height: 20

                                Image {
                                    anchors.fill: parent
                                    source: modelData.icon
                                    sourceSize: Qt.size(20, 20)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                                            modelData.display(bar, mouse.x, mouse.y);
                                        } else {
                                            modelData.activate();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: 2
                color: root.colorOrange
                opacity: 0.7
            }
        }
    }
}
