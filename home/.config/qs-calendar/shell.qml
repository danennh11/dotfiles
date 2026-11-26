// qs-calendar: calendar + todo panel, a standalone Quickshell config.
// Lives outside Ryoku's shell tree, so Ryoku updates never touch it.
//
//   run:     qs -p ~/.config/qs-calendar -d
//   toggle:  qs ipc -p ~/.config/qs-calendar call calendar toggle
//            (SUPER+C runs ~/.local/bin/calendar-panel, which does this)
//   data:    ~/.local/share/qs-calendar/todos.json
//   colours: ~/.cache/ryoku/colors.json (Ryoku's live palette, follows wallpaper)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: shell

    // ── palette (Ryoku/matugen roles, fallbacks = current dark blue scheme) ──
    QtObject {
        id: pal
        property var c: ({})
        function get(k, d) { return c[k] !== undefined ? c[k] : d }
        readonly property color surface:   get("surface", "#101418")
        readonly property color tile:      get("surfaceContainerLow", "#181c20")
        readonly property color tileHi:    get("surfaceContainerHigh", "#272a2e")
        readonly property color line:      get("outlineVariant", "#42474e")
        readonly property color text:      get("onSurface", "#e0e2e8")
        readonly property color dim:       get("onSurfaceVariant", "#c2c7ce")
        readonly property color faint:     get("outline", "#8c9198")
        readonly property color accent:    get("primary", "#98ccf9")
        readonly property color onAccent:  get("onPrimary", "#003351")
        readonly property color danger:    get("error", "#ffb4ab")
        readonly property string mono: "JetBrainsMono Nerd Font"
        readonly property color secondary: get("secondaryContainer", "#394857")
    }
    FileView {
        path: Quickshell.env("HOME") + "/.cache/ryoku/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { pal.c = JSON.parse(text()) } catch (e) {} }
    }

    // ── todo store ──
    QtObject {
        id: store
        property var items: []      // [{id, text, date: "YYYY-MM-DD", done, created}]
        property bool ready: false

        function save() {
            todoFile.setText(JSON.stringify({ version: 1, items: items }, null, 2))
        }
        function forDay(key) {
            return items.filter(t => t.date === key)
                        .sort((a, b) => (a.done - b.done) || (a.created - b.created))
        }
        function openCount(key) {
            let n = 0
            for (const t of items) if (t.date === key && !t.done) n++
            return n
        }
        function add(textIn, key) {
            const t = textIn.trim()
            if (t === "") return
            items = items.concat([{ id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
                                    text: t, date: key, done: false, created: Date.now() }])
            save()
        }
        function toggle(id) {
            items = items.map(t => t.id === id ? Object.assign({}, t, { done: !t.done }) : t)
            save()
        }
        function remove(id) {
            items = items.filter(t => t.id !== id)
            save()
        }
    }
    FileView {
        id: todoFile
        path: Quickshell.env("HOME") + "/.local/share/qs-calendar/todos.json"
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text())
                store.items = Array.isArray(d.items) ? d.items : []
            } catch (e) { store.items = [] }
            store.ready = true
        }
        onLoadFailed: { store.items = []; store.ready = true }
    }

    // ── date helpers ──
    function pad(n) { return n < 10 ? "0" + n : String(n) }
    function keyOf(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property var palRef: pal

    // ── state ──
    property bool shown: false
    property int monthOffset: 0
    property date selected: new Date()

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor
        return mon ? Quickshell.screens.find(x => x.name === mon.name) : null
    }
    function open() {
        media.close()
        const s = focusedScreen()
        if (s) win.screen = s
        monthOffset = 0
        selected = new Date()
        shown = true
    }
    function close() { shown = false }

    IpcHandler {
        target: "calendar"
        function toggle(): void { if (shell.shown) shell.close(); else shell.open() }
        function open(): void { shell.open() }
        function close(): void { shell.close() }
    }

    // ── Now Playing + equalizer panel (MediaPanel.qml) ──
    MediaPanel {
        id: media
        pal: shell.palRef
        onOpening: { shell.close(); const s = shell.focusedScreen(); if (s) media.screen = s }
    }
    IpcHandler {
        target: "media"
        function toggle(): void { if (media.shown) media.close(); else media.open() }
        function open(): void { media.open() }
        function close(): void { media.close() }
    }

    PanelWindow {
        id: win
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-calendar"
        WlrLayershell.keyboardFocus: shell.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property real reveal: shell.shown ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: shell.shown ? 200 : 140; easing.type: shell.shown ? Easing.OutCubic : Easing.InCubic } }
        visible: shell.shown || reveal > 0.001

        // click outside the card closes
        MouseArea { anchors.fill: parent; onClicked: shell.close() }

        Rectangle {
            id: card
            readonly property int barH: 39          // qsbar: 33px bar + 6px gap
            width: 916
            height: 404
            x: Math.round((parent.width - width) / 2)
            y: barH + 6 - 6 * (1 - win.reveal)
            opacity: win.reveal
            radius: 20
            color: pal.surface
            border.color: pal.line
            border.width: 1

            focus: shell.shown
            Keys.onEscapePressed: shell.close()
            onVisibleChanged: if (visible) input.forceActiveFocus()
            Connections {
                target: shell
                function onShownChanged() { if (shell.shown) input.forceActiveFocus() }
            }

            // swallow clicks so they do not reach the close-area
            MouseArea { anchors.fill: parent }

            Row {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 24

                // ─────────────── calendar ───────────────
                Rectangle {
                    id: calTile
                    width: 380
                    height: parent.height
                    radius: 16
                    color: pal.tile
                    border.color: Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.07)

                    readonly property date first: {
                        const n = clock.date
                        return new Date(n.getFullYear(), n.getMonth() + shell.monthOffset, 1)
                    }
                    readonly property var cells: {
                        const f = first
                        const lead = (f.getDay() + 6) % 7            // Monday first
                        const days = new Date(f.getFullYear(), f.getMonth() + 1, 0).getDate()
                        const total = Math.ceil((lead + days) / 7) * 7   // only the weeks needed
                        const out = []
                        for (let i = 0; i < total; i++)
                            out.push(new Date(f.getFullYear(), f.getMonth(), 1 - lead + i))
                        return out
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 10

                        Item {
                            width: parent.width; height: 28
                            Text {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                text: "‹"; color: pal.dim; font.family: pal.mono; font.pixelSize: 22
                                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: shell.monthOffset-- }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: calTile.first.toLocaleDateString(Qt.locale("en_US"), "MMMM   yyyy").toUpperCase()
                                color: pal.text; font.family: pal.mono; font.pixelSize: 15; font.letterSpacing: 4
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { shell.monthOffset = 0; shell.selected = new Date() } }
                            }
                            Text {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: "›"; color: pal.dim; font.family: pal.mono; font.pixelSize: 22
                                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: shell.monthOffset++ }
                            }
                        }

                        Grid {
                            columns: 7
                            width: parent.width
                            Repeater {
                                model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                                Item {
                                    width: calTile.width / 7 - 44 / 7; height: 24
                                    Text {
                                        anchors.centerIn: parent; text: modelData
                                        color: pal.faint; font.family: pal.mono; font.pixelSize: 10; font.letterSpacing: 1.5
                                    }
                                }
                            }
                        }

                        Grid {
                            columns: 7
                            width: parent.width
                            Repeater {
                                model: calTile.cells
                                Item {
                                    id: cell
                                    readonly property date d: modelData
                                    readonly property string k: shell.keyOf(d)
                                    readonly property bool inMonth: d.getMonth() === calTile.first.getMonth()
                                    readonly property bool isToday: k === shell.keyOf(clock.date)
                                    readonly property bool isSel: k === shell.keyOf(shell.selected)
                                    readonly property bool weekend: d.getDay() === 0 || d.getDay() === 6
                                    readonly property int open: store.openCount(k)
                                    width: calTile.width / 7 - 44 / 7; height: Math.min(46, (calTile.height - 116) / (calTile.cells.length / 7))

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 36; height: 36; radius: 18
                                        color: cell.isToday ? pal.accent
                                             : (hover.containsMouse ? Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.06) : "transparent")
                                        border.width: cell.isSel && !cell.isToday ? 1.5 : 0
                                        border.color: pal.accent
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: cell.d.getDate()
                                        font.family: pal.mono; font.pixelSize: 15
                                        color: cell.isToday ? pal.onAccent
                                             : !cell.inMonth ? Qt.rgba(pal.faint.r, pal.faint.g, pal.faint.b, 0.45)
                                             : cell.weekend ? pal.accent : pal.text
                                    }
                                    Rectangle {
                                        visible: cell.open > 0
                                        width: 4; height: 4; radius: 2
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                                        color: cell.isToday ? pal.text : pal.accent
                                    }
                                    MouseArea {
                                        id: hover
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { shell.selected = cell.d; input.forceActiveFocus() }
                                    }
                                }
                            }
                        }
                    }
                }

                // ─────────────── todo ───────────────
                Rectangle {
                    id: todoTile
                    width: parent.width - calTile.width - parent.spacing
                    height: parent.height
                    radius: 16
                    color: pal.tile
                    border.color: Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.07)

                    readonly property string selKey: shell.keyOf(shell.selected)
                    readonly property var list: store.forDay(selKey)
                    readonly property int remaining: list.filter(t => !t.done).length

                    Item {
                        anchors.fill: parent
                        anchors.margins: 22

                        // header
                        Column {
                            id: head
                            width: parent.width
                            spacing: 4
                            Text {
                                text: shell.selected.toLocaleDateString(Qt.locale("en_US"), "dddd")
                                color: pal.text; font.family: pal.mono; font.pixelSize: 24
                            }
                            Text {
                                text: shell.selected.toLocaleDateString(Qt.locale("en_US"), "MMMM d")
                                      + "   ·   " + (todoTile.list.length === 0 ? "no tasks"
                                      : todoTile.remaining === 0 ? "all done"
                                      : todoTile.remaining + " to do")
                                color: pal.faint; font.family: pal.mono; font.pixelSize: 12; font.letterSpacing: 1
                            }
                        }

                        // list
                        ListView {
                            id: listView
                            anchors.top: head.bottom; anchors.topMargin: 16
                            anchors.bottom: inputBox.top; anchors.bottomMargin: 12
                            width: parent.width
                            clip: true
                            spacing: 4
                            model: todoTile.list
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                id: row
                                required property var modelData
                                width: listView.width
                                height: 40
                                radius: 10
                                color: rowHover.containsMouse ? Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.05) : "transparent"

                                MouseArea {
                                    id: rowHover
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: store.toggle(row.modelData.id)
                                }

                                Rectangle {
                                    id: box
                                    anchors.left: parent.left; anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18; height: 18; radius: 5
                                    color: row.modelData.done ? pal.accent : "transparent"
                                    border.width: row.modelData.done ? 0 : 1.5
                                    border.color: pal.faint
                                    Text {
                                        anchors.centerIn: parent; visible: row.modelData.done
                                        text: "✓"; color: pal.onAccent; font.pixelSize: 13; font.bold: true
                                    }
                                }
                                Text {
                                    anchors.left: box.right; anchors.leftMargin: 12
                                    anchors.right: del.left; anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: row.modelData.text
                                    elide: Text.ElideRight
                                    font.family: pal.mono; font.pixelSize: 14
                                    font.strikeout: row.modelData.done
                                    color: row.modelData.done ? pal.faint : pal.text
                                }
                                Text {
                                    id: del
                                    anchors.right: parent.right; anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "✕"
                                    visible: rowHover.containsMouse || delArea.containsMouse
                                    color: delArea.containsMouse ? pal.danger : pal.faint
                                    font.pixelSize: 13
                                    MouseArea {
                                        id: delArea
                                        anchors.fill: parent; anchors.margins: -8
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: store.remove(row.modelData.id)
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: todoTile.list.length === 0
                                text: "Nothing planned. Type below to add a task."
                                color: pal.faint; font.family: pal.mono; font.pixelSize: 12
                            }
                        }

                        // input
                        Rectangle {
                            id: inputBox
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 44
                            radius: 12
                            color: Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.04)
                            border.width: 1
                            border.color: input.activeFocus ? Qt.rgba(pal.accent.r, pal.accent.g, pal.accent.b, 0.6) : pal.line

                            Text {
                                id: plus
                                anchors.left: parent.left; anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: "+"; color: pal.accent; font.family: pal.mono; font.pixelSize: 18
                            }
                            TextInput {
                                id: input
                                anchors.left: plus.right; anchors.leftMargin: 10
                                anchors.right: parent.right; anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                color: pal.text; selectionColor: pal.accent; selectedTextColor: pal.onAccent
                                font.family: pal.mono; font.pixelSize: 14
                                clip: true
                                Keys.onEscapePressed: shell.close()
                                onAccepted: { store.add(text, todoTile.selKey); text = "" }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: input.text === ""
                                    text: "Add a task for " + shell.selected.toLocaleDateString(Qt.locale("en_US"), "MMM d") + "…"
                                    color: pal.faint; font: input.font
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
