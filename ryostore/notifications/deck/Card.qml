pragma ComponentBehavior: Bound

// Deck: a terminal-pane notification card.
// The app name rides in a dark-blue pill like the starship path pill, the
// summary reads like a command after a λ prompt, a thin edge marks the card
// (red when urgent) and a hairline drains along the foot while it waits.
// Every colour is a Material role from the live palette, so it follows the
// wallpaper.

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Ryoku.Ui.Singletons
import shell.services

Item {
    id: root

    required property var notification
    property real us: 1
    property int lifespanMs: 0
    property string position: "Right"
    property bool showImages: true

    // ── palette (Material roles from the live scheme) ─────────────────────
    readonly property bool urgent: root.notification?.urgency === NotificationUrgency.Critical
    readonly property color surface: Tokens.role("surfaceContainerLow", Tokens.paperLift)
    readonly property color pillBg: root.urgent
        ? Tokens.role("errorContainer", "#93000a")
        : Tokens.role("primaryContainer", "#054b71")
    readonly property color pillFg: root.urgent
        ? Tokens.role("onErrorContainer", "#ffdad6")
        : Tokens.role("onPrimaryContainer", "#cce5ff")
    readonly property color accent: root.urgent
        ? Tokens.role("error", "#ffb4ab")
        : Tokens.role("primary", "#98ccf9")
    readonly property color outline: Tokens.role("outlineVariant", "#42474e")

    readonly property string monoFamily: "JetBrainsMono Nerd Font"
    readonly property real pad: Tokens.s3 * us
    readonly property real edge: 3 * us

    // ── notification data ─────────────────────────────────────────────────
    readonly property var visibleActions: {
        const source = root.notification?.actions || [];
        const result = [];
        for (let i = 0; i < source.length; ++i) {
            const candidate = source[i];
            if (candidate && candidate.identifier !== "default"
                    && String(candidate.text || "").length > 0)
                result.push(candidate);
        }
        return result;
    }
    readonly property var defaultAction: {
        const source = root.notification?.actions || [];
        for (let i = 0; i < source.length; ++i) {
            if (source[i] && source[i].identifier === "default")
                return source[i];
        }
        return null;
    }
    readonly property string pictureSource: root.showImages
        ? String(root.notification?.image || "") : ""
    readonly property string iconSource: {
        const raw = String(root.notification?.appIcon || "");
        if (raw === "")
            return "";
        return raw.indexOf("/") >= 0 || raw.indexOf(":") >= 0 ? raw : Icons.path(raw, true);
    }
    readonly property string bodyText: String(root.notification?.body || "")
    readonly property bool counting: root.lifespanMs > 0 && !Tokens.reduceMotion

    implicitHeight: frame.implicitHeight

    function invokeAndDismiss(action): void {
        if (action && typeof action.invoke === "function")
            action.invoke();
        Notifs.dismiss(root.notification);
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        implicitHeight: content.implicitHeight + root.pad * 2 + drain.height
        radius: Tokens.radius * root.us
        color: root.surface
        border.width: Tokens.border
        border.color: cardHover.hovered ? root.accent : root.outline
        clip: true

        Behavior on border.color {
            enabled: !Tokens.reduceMotion
            ColorAnimation { duration: Tokens.snap }
        }

        // left edge: the pane's accent rail
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.edge
            color: root.accent
        }

        HoverHandler { id: cardHover }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: root.pad + root.edge
            anchors.rightMargin: root.pad
            anchors.topMargin: root.pad
            spacing: Tokens.s2 * root.us

            // header: [ icon appName ] ·········· time  ×
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.s2 * root.us

                Rectangle {
                    id: pill
                    Layout.maximumWidth: content.width * 0.62
                    implicitWidth: pillRow.implicitWidth + Tokens.s3 * root.us
                    implicitHeight: pillRow.implicitHeight + Tokens.s1 * root.us
                    radius: height / 2
                    color: root.pillBg

                    RowLayout {
                        id: pillRow
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, pill.width - Tokens.s3 * root.us)
                        spacing: Tokens.s1 * root.us

                        Image {
                            Layout.preferredWidth: 14 * root.us
                            Layout.preferredHeight: 14 * root.us
                            visible: root.iconSource !== "" && status === Image.Ready
                            source: root.iconSource
                            sourceSize.width: 28
                            sourceSize.height: 28
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: (root.urgent ? "! " : "")
                                + (root.notification?.appName || I18n.tr("Notification"))
                            color: root.pillFg
                            font.family: root.monoFamily
                            font.pixelSize: Tokens.fMicro * root.us
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Notifs.timeLabel(root.notification)
                    color: Tokens.inkFaint
                    font.family: root.monoFamily
                    font.pixelSize: Tokens.fMicro * root.us
                }

                Rectangle {
                    Layout.preferredWidth: 22 * root.us
                    Layout.preferredHeight: 22 * root.us
                    radius: width / 2
                    color: closeHover.hovered ? Tokens.tint10 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: closeHover.hovered ? root.accent : Tokens.inkDim
                        font.family: root.monoFamily
                        font.pixelSize: Tokens.fBody * root.us
                    }
                    HoverHandler { id: closeHover }
                    TapHandler { onTapped: Notifs.dismiss(root.notification) }
                }
            }

            // body: optional picture, then  λ summary  and the message
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.s3 * root.us

                Image {
                    Layout.preferredWidth: visible ? 48 * root.us : 0
                    Layout.preferredHeight: visible ? 48 * root.us : 0
                    Layout.alignment: Qt.AlignTop
                    visible: root.pictureSource !== "" && status !== Image.Error
                    source: root.pictureSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.s1 * root.us

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.s2 * root.us

                        Text {
                            Layout.alignment: Qt.AlignTop
                            text: "λ"
                            color: root.accent
                            font.family: root.monoFamily
                            font.pixelSize: Tokens.fBody * root.us
                            font.weight: Font.Bold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.notification?.summary || ""
                            color: Tokens.ink
                            font.family: root.monoFamily
                            font.pixelSize: Tokens.fBody * root.us
                            font.weight: Font.Bold
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: lambdaWidth.width + Tokens.s2 * root.us
                        visible: root.bodyText.length > 0
                        text: root.bodyText
                        textFormat: Text.StyledText
                        color: Tokens.inkDim
                        linkColor: root.accent
                        font.family: root.monoFamily
                        font.pixelSize: Tokens.fSmall * root.us
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: 6
                        elide: Text.ElideRight
                    }

                    // width of the λ column, so the body lines up under the summary
                    TextMetrics {
                        id: lambdaWidth
                        text: "λ"
                        font.family: root.monoFamily
                        font.pixelSize: Tokens.fBody * root.us
                        font.weight: Font.Bold
                    }
                }

                TapHandler {
                    enabled: root.defaultAction !== null
                    onTapped: root.invokeAndDismiss(root.defaultAction)
                }
            }

            // actions: tmux-pane-title style tabs
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.s1 * root.us
                spacing: Tokens.s2 * root.us
                visible: root.visibleActions.length > 0

                Repeater {
                    model: root.visibleActions

                    delegate: Rectangle {
                        id: actionTab
                        required property var modelData
                        readonly property bool lit: tabHover.hovered || tabTap.pressed

                        implicitWidth: Math.min(tabLabel.implicitWidth + Tokens.s4 * root.us,
                            content.width)
                        implicitHeight: 26 * root.us
                        radius: height / 2
                        color: actionTab.lit ? root.pillBg : "transparent"
                        border.width: Tokens.border
                        border.color: actionTab.lit ? root.pillBg : root.accent

                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - Tokens.s3 * root.us)
                            horizontalAlignment: Text.AlignHCenter
                            text: actionTab.modelData.text
                            color: actionTab.lit ? root.pillFg : root.accent
                            font.family: root.monoFamily
                            font.pixelSize: Tokens.fMicro * root.us
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        HoverHandler { id: tabHover }
                        TapHandler {
                            id: tabTap
                            onTapped: root.invokeAndDismiss(actionTab.modelData)
                        }
                    }
                }
            }
        }

        // foot: the hairline that drains while the popup waits
        Rectangle {
            id: drain
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: root.edge
            height: root.counting ? Math.max(2, 2 * root.us) : 0
            width: (parent.width - root.edge) * drainState.remaining
            color: root.accent
            opacity: 0.85
            visible: root.counting

            QtObject {
                id: drainState
                property real remaining: 1
            }

            NumberAnimation {
                id: drainAnim
                target: drainState
                property: "remaining"
                from: 1
                to: 0
                duration: Math.max(1, root.lifespanMs)
                running: root.counting
                easing.type: Easing.Linear
            }
        }
    }
}
