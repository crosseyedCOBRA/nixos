import Quickshell
import Quickshell.I3
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 30
            color: "#1a1b26"

            I3 {
                id: i3
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                // --- Workspaces ---
                RowLayout {
                    spacing: 4

                    Repeater {
                        model: i3.workspaces

                        Rectangle {
                            width: 28
                            height: 22
                            radius: 4
                            color: modelData.focused ? "#7aa2f7"
                                : modelData.urgent ? "#f7768e"
                                : "#292e42"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                color: modelData.focused ? "#1a1b26" : "#c0caf5"
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: modelData.activate()
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // --- Clock / date ---
                Text {
                    id: clock
                    color: "#c0caf5"
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

                Item { Layout.fillWidth: true }

                // --- System tray ---
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
    }
}
