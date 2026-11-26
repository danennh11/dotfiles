import QtQuick
import Ryoku.Ui.Singletons

// The still Settings -> App Launcher shows for Deck. No shell services here:
// it only draws the pane with a few made-up rows.
Item {
    id: root
    implicitWidth: 720
    implicitHeight: 250
    property var settings
    signal editRequested(string key, var value)

    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property color pillBg: Tokens.role("primaryContainer", "#054b71")
    readonly property color pillFg: Tokens.role("onPrimaryContainer", "#cce5ff")
    readonly property color accent: Tokens.role("primary", "#98ccf9")
    readonly property color outline: Tokens.role("outlineVariant", "#42474e")

    Rectangle {
        anchors.centerIn: parent
        width: 520
        height: 214
        radius: Tokens.radius
        color: Tokens.role("surfaceContainerLow", Tokens.paperLift)
        border.width: Tokens.border
        border.color: root.outline
        clip: true

        Rectangle { width: 3; height: parent.height; color: root.accent }

        Column {
            x: 19
            y: 14
            width: parent.width - 33
            spacing: 9

            Item {
                width: parent.width
                height: 18
                Rectangle {
                    width: tag.implicitWidth + 16
                    height: 18
                    radius: 9
                    color: root.pillBg
                    Text {
                        id: tag
                        anchors.centerIn: parent
                        text: "launch"
                        color: root.pillFg
                        font.family: root.mono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⏎ open · C-j/k move · esc close"
                    color: Tokens.inkFaint
                    font.family: root.mono
                    font.pixelSize: 10
                }
            }

            Item {
                width: parent.width
                height: 20
                Text { text: "λ"; color: root.accent; font.family: root.mono; font.pixelSize: 15; font.weight: Font.Bold }
                Text { x: 20; text: "co"; color: Tokens.ink; font.family: root.mono; font.pixelSize: 15 }
                Rectangle { x: 39; y: 2; width: 8; height: 17; color: root.accent; opacity: 0.85 }
                Text {
                    anchors.right: parent.right
                    text: "4/143"
                    color: Tokens.inkFaint
                    font.family: root.mono
                    font.pixelSize: 12
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.outline; opacity: 0.7 }

            Repeater {
                model: [
                    { n: "Code", g: "Text Editor", on: true },
                    { n: "Color Picker", g: "Pick colours", on: false },
                    { n: "Console", g: "Terminal", on: false },
                    { n: "Contacts", g: "Address book", on: false }
                ]
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 26
                    radius: 13
                    color: modelData.on ? root.pillBg : "transparent"
                    Text {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.on ? "›" : ""
                        color: root.pillFg
                        font.family: root.mono
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                    Rectangle { x: 26; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 4; color: root.accent; opacity: 0.6 }
                    Text {
                        x: 52
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.n + "   " + modelData.g
                        color: modelData.on ? root.pillFg : Tokens.ink
                        font.family: root.mono
                        font.pixelSize: 12
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "M-" + (index + 1)
                        color: modelData.on ? root.pillFg : Tokens.inkFaint
                        font.family: root.mono
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}
