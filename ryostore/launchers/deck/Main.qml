pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import shell.services
import Ryoku.Ui.Singletons
import "lib/match.js" as Match

// Deck: a terminal-pane launcher. A dark-blue pill names the pane, you type
// after a λ like a shell prompt, an fzf-style count sits at the end of the line,
// and results are rows you walk with the arrows or vim keys. Same language as
// the Deck notification card and the Command Deck; every colour is a Material
// role from the live palette.
Scope {
    id: root

    // ── the contract the shell's launcher host drives ───────────────────
    property bool openRequested: false
    readonly property bool shown: root.openRequested
    property string monitor: ""

    function show(mon) {
        root.monitor = mon || "";
        root.query = "";
        root.selected = 0;
        root.openRequested = true;
    }
    function hide() {
        root.openRequested = false;
    }
    function toggle(mon) {
        root.openRequested ? root.hide() : root.show(mon);
    }
    function stateDump() {
        return { open: root.openRequested, query: root.query, selected: root.selected,
                 resultCount: root.results.length, total: root.total };
    }

    // ── state ──────────────────────────────────────────────────────────
    property string query: ""
    property int selected: 0
    // apps opened this session, newest first; they rise when the query is empty
    property var recent: []

    readonly property var apps: DesktopEntries.applications.values
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < root.apps.length; i++)
            if (!root.apps[i].noDisplay) n++;
        return n;
    }
    readonly property var results: Match.results(root.apps, root.query,
        cfg.pinnedApps, root.recent, cfg.hiddenApps)

    // the output the host named, else the focused one
    readonly property var output: {
        const screens = Quickshell.screens;
        const wanted = root.monitor.length > 0 ? root.monitor : Wm.focusedOutput;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === wanted)
                return screens[i];
        return screens.length > 0 ? screens[0] : null;
    }

    function move(step) {
        if (root.results.length === 0)
            return;
        root.selected = (root.selected + step + root.results.length) % root.results.length;
    }

    function launch(row) {
        if (!row || !row.entry)
            return;
        const id = String(row.entry.id || "");
        const next = [id];
        for (let i = 0; i < root.recent.length && next.length < 20; i++)
            if (root.recent[i] !== id)
                next.push(root.recent[i]);
        root.recent = next;
        root.hide();
        AppLaunch.run(row.entry, null);
    }

    // ── palette ────────────────────────────────────────────────────────
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property color surface: Tokens.role("surfaceContainerLow", Tokens.paperLift)
    readonly property color pillBg: Tokens.role("primaryContainer", "#054b71")
    readonly property color pillFg: Tokens.role("onPrimaryContainer", "#cce5ff")
    readonly property color accent: Tokens.role("primary", "#98ccf9")
    readonly property color outline: Tokens.role("outlineVariant", "#42474e")

    // Settings -> App Launcher writes these; read live, never written here
    FileView {
        id: cfgFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/launcher.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: cfg
            property var hiddenApps: []
            property var pinnedApps: []
        }
    }

    LazyLoader {
        active: root.shown && root.output !== null

        PanelWindow {
            id: win
            screen: root.output
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "launcher"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // a light dim behind the pane; a click on it closes the launcher
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.22
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }

            Rectangle {
                id: pane
                readonly property real pad: Tokens.s4
                width: Math.min(Tokens.px(620), win.width - Tokens.s4 * 4)
                height: body.implicitHeight + pane.pad * 2
                x: Math.round((win.width - width) / 2)
                y: Math.round(win.height * 0.2) + (pane.entered ? 0 : Tokens.px(10))
                radius: Tokens.radius
                color: Qt.alpha(root.surface, 0.9)
                border.width: Tokens.border
                border.color: root.outline
                clip: true
                opacity: pane.entered ? 1 : 0

                property bool entered: false
                Component.onCompleted: pane.entered = true
                Behavior on opacity {
                    enabled: !Tokens.reduceMotion
                    NumberAnimation { duration: Tokens.dur(140); easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    enabled: !Tokens.reduceMotion
                    NumberAnimation { duration: Tokens.dur(180); easing.type: Easing.OutCubic }
                }

                // swallow clicks so they do not reach the close area
                MouseArea { anchors.fill: parent }

                // the pane's accent rail
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: Tokens.px(3)
                    color: root.accent
                }

                Column {
                    id: body
                    anchors {
                        left: parent.left; right: parent.right; top: parent.top
                        leftMargin: pane.pad + Tokens.px(3); rightMargin: pane.pad; topMargin: pane.pad
                    }
                    spacing: Tokens.s3

                    // header: [ launch ] ············ ⏎ open · esc close
                    Item {
                        width: parent.width
                        height: pill.height

                        Rectangle {
                            id: pill
                            width: pillText.implicitWidth + Tokens.s4
                            height: pillText.implicitHeight + Tokens.s1 * 1.5
                            radius: height / 2
                            color: root.pillBg
                            Text {
                                id: pillText
                                anchors.centerIn: parent
                                text: "launch"
                                color: root.pillFg
                                font.family: root.mono
                                font.pixelSize: Tokens.fMicro
                                font.weight: Font.Bold
                            }
                        }
                        Text {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: "⏎ open · C-j/k move · esc close"
                            color: Tokens.inkFaint
                            font.family: root.mono
                            font.pixelSize: Tokens.fMicro
                        }
                    }

                    // prompt: λ query ············· 12/143
                    Item {
                        width: parent.width
                        height: field.implicitHeight

                        Text {
                            id: lambda
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: "λ"
                            color: root.accent
                            font.family: root.mono
                            font.pixelSize: Tokens.fValue
                            font.weight: Font.Bold
                        }
                        Text {
                            id: count
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: root.results.length + "/" + root.total
                            color: Tokens.inkFaint
                            font.family: root.mono
                            font.pixelSize: Tokens.fSmall
                        }
                        TextInput {
                            id: field
                            anchors {
                                left: lambda.right; leftMargin: Tokens.s3
                                right: count.left; rightMargin: Tokens.s3
                                verticalCenter: parent.verticalCenter
                            }
                            focus: true
                            clip: true
                            color: Tokens.ink
                            selectionColor: root.pillBg
                            selectedTextColor: root.pillFg
                            font.family: root.mono
                            font.pixelSize: Tokens.fValue
                            Component.onCompleted: field.forceActiveFocus()
                            onTextEdited: {
                                root.query = text;
                                root.selected = 0;
                            }

                            cursorDelegate: Rectangle {
                                width: Math.max(2, field.font.pixelSize * 0.55)
                                color: root.accent
                                opacity: 0.85
                                SequentialAnimation on opacity {
                                    running: !Tokens.reduceMotion
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.15; duration: 530 }
                                    NumberAnimation { to: 0.85; duration: 530 }
                                }
                            }

                            Keys.onPressed: event => {
                                const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                                const alt = (event.modifiers & Qt.AltModifier) !== 0;
                                const k = event.key;
                                if (k === Qt.Key_Escape) {
                                    root.hide();
                                } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                                    root.launch(root.results[root.selected]);
                                } else if (k === Qt.Key_Down || k === Qt.Key_Tab
                                        || (ctrl && (k === Qt.Key_J || k === Qt.Key_N))) {
                                    root.move(1);
                                } else if (k === Qt.Key_Up || k === Qt.Key_Backtab
                                        || (ctrl && (k === Qt.Key_K || k === Qt.Key_P))) {
                                    root.move(-1);
                                } else if (k === Qt.Key_PageDown) {
                                    root.selected = Math.min(root.results.length - 1, root.selected + list.rows);
                                } else if (k === Qt.Key_PageUp) {
                                    root.selected = Math.max(0, root.selected - list.rows);
                                } else if (ctrl && k === Qt.Key_U) {
                                    field.text = "";
                                    root.query = "";
                                    root.selected = 0;
                                } else if (alt && k >= Qt.Key_1 && k <= Qt.Key_9) {
                                    root.launch(root.results[list.firstVisible + (k - Qt.Key_1)]);
                                } else {
                                    return;
                                }
                                event.accepted = true;
                            }
                        }
                        Text {
                            // starts after the block cursor so the cursor never covers a letter
                            anchors {
                                left: field.left; leftMargin: field.font.pixelSize * 0.75
                                verticalCenter: parent.verticalCenter
                            }
                            visible: field.text.length === 0
                            text: "search apps…"
                            color: Tokens.inkFaint
                            font: field.font
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: root.outline
                        opacity: 0.7
                    }

                    // results
                    ListView {
                        id: list
                        readonly property int rows: 8
                        readonly property real rowH: Tokens.rowH
                        readonly property int firstVisible: Math.max(0, Math.floor(contentY / rowH))
                        width: parent.width
                        height: root.results.length === 0 ? empty.implicitHeight
                            : Math.min(root.results.length, list.rows) * list.rowH
                        clip: true
                        interactive: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.results
                        currentIndex: root.selected
                        highlightFollowsCurrentItem: false
                        onCurrentIndexChanged: list.positionViewAtIndex(currentIndex, ListView.Contain)

                        Text {
                            id: empty
                            visible: root.results.length === 0
                            topPadding: Tokens.s2
                            bottomPadding: Tokens.s2
                            text: "no match for \"" + root.query + "\""
                            color: Tokens.inkDim
                            font.family: root.mono
                            font.pixelSize: Tokens.fSmall
                        }

                        delegate: Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool current: row.index === root.selected
                            readonly property int slot: row.index - list.firstVisible
                            width: list.width
                            height: list.rowH

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: row.current ? root.pillBg
                                    : (hover.hovered ? Qt.alpha(root.pillBg, 0.35) : "transparent")
                            }

                            Text {
                                id: marker
                                anchors { left: parent.left; leftMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
                                width: Tokens.px(10)
                                text: row.current ? "›" : (row.modelData.pinned ? "•" : "")
                                color: row.current ? root.pillFg : root.accent
                                font.family: root.mono
                                font.pixelSize: Tokens.fRow
                                font.weight: Font.Bold
                            }
                            IconImage {
                                id: icon
                                anchors { left: marker.right; leftMargin: Tokens.s2; verticalCenter: parent.verticalCenter }
                                implicitSize: Tokens.px(20)
                                source: Icons.path(row.modelData.entry.icon, "application-x-executable")
                            }
                            Text {
                                id: name
                                anchors { left: icon.right; leftMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
                                width: Math.min(implicitWidth, row.width * 0.5)
                                text: row.modelData.entry.name
                                color: row.current ? root.pillFg : Tokens.ink
                                font.family: root.mono
                                font.pixelSize: Tokens.fRow
                                font.weight: row.current ? Font.Bold : Font.Normal
                                elide: Text.ElideRight
                            }
                            Text {
                                anchors {
                                    left: name.right; leftMargin: Tokens.s3
                                    right: key.left; rightMargin: Tokens.s3
                                    verticalCenter: parent.verticalCenter
                                }
                                text: row.modelData.entry.genericName || row.modelData.entry.comment || ""
                                color: row.current ? Qt.alpha(root.pillFg, 0.7) : Tokens.inkFaint
                                font.family: root.mono
                                font.pixelSize: Tokens.fSmall
                                elide: Text.ElideRight
                            }
                            // Alt+N opens the Nth visible row, like a tmux window index
                            Text {
                                id: key
                                anchors { right: parent.right; rightMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
                                text: row.slot >= 0 && row.slot < 9 ? "M-" + (row.slot + 1) : ""
                                color: row.current ? root.pillFg : Tokens.inkFaint
                                font.family: root.mono
                                font.pixelSize: Tokens.fMicro
                            }

                            HoverHandler { id: hover }
                            TapHandler {
                                onTapped: root.launch(row.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
