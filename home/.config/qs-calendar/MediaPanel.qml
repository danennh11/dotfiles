// Now Playing + equalizer panel for qs-calendar.
//   player:    Quickshell MPRIS (first playing player, else the first one)
//   output:    PipeWire default sink
//   equalizer: Ryoku's own `ryoku-eq` CLI; state read from
//              ~/.config/ryoku/equalizer.json, so it stays in sync with qsbar.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

PanelWindow {
    id: panel
    required property var pal

    property bool shown: false
    signal opening()
    function open() { opening(); eq.reload(); shown = true }
    function close() { shown = false }

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-media"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real reveal: shown ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: panel.shown ? 200 : 140; easing.type: panel.shown ? Easing.OutCubic : Easing.InCubic } }
    visible: shown || reveal > 0.001

    // ── player ──
    readonly property var players: Mpris.players.values
    readonly property var player: {
        const ps = players
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
        return ps.length > 0 ? ps[0] : null
    }
    readonly property bool playing: player ? player.isPlaying : false

    Timer {   // MPRIS position is polled, not pushed
        interval: 1000; repeat: true
        running: panel.shown && panel.playing
        onTriggered: if (panel.player) panel.player.positionChanged()
    }
    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0
        sec = Math.floor(sec)
        const m = Math.floor(sec / 60), s = sec % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    // ── output device ──
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property string sinkName: {
        const n = Pipewire.defaultAudioSink
        if (!n) return "no output"
        return n.description || n.nickname || n.name || "output"
    }

    // ── equalizer (ryoku-eq) ──
    QtObject {
        id: eq
        readonly property var labels: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
        readonly property var presets: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
        readonly property int range: 12
        property var gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        property string preset: "Flat"
        property bool on: false
        function ingest(t) {
            let d
            try { d = JSON.parse(t) } catch (e) { return }
            const g = []
            for (let i = 1; i <= 10; i++) g.push(Number(d["b" + i]) || 0)
            gains = g
            preset = "" + (d.preset || "Flat")
            on = d.on === true
        }
        function reload() { eqFile.reload() }
        function run(args) { Quickshell.execDetached(["ryoku-eq"].concat(args)) }
        function setBand(i, db) {
            const g = gains.slice(); g[i] = db; gains = g; preset = "Custom"
            run(["set-band", "" + (i + 1), "" + db])
        }
        function setPreset(name) { preset = name; run(["preset", name]) }
        function setOn(v) { on = v; run([v ? "on" : "off"]) }
    }
    FileView {
        id: eqFile
        path: Quickshell.env("HOME") + "/.config/ryoku/equalizer.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: eq.ingest(text())
    }

    // click outside the card closes
    MouseArea { anchors.fill: parent; onClicked: panel.close() }

    Rectangle {
        id: card
        width: 540
        height: col.implicitHeight + 48
        x: Math.round((parent.width - width) / 2)
        y: 45 - 6 * (1 - panel.reveal)       // qsbar: 33px bar + gaps
        opacity: panel.reveal
        radius: 20
        color: pal.surface
        border.color: pal.line
        border.width: 1

        focus: panel.shown
        Keys.onEscapePressed: panel.close()
        Keys.onSpacePressed: if (panel.player && panel.player.canTogglePlaying) panel.player.togglePlaying()
        Connections { target: panel; function onShownChanged() { if (panel.shown) card.forceActiveFocus() } }

        MouseArea { anchors.fill: parent }   // keep clicks inside

        Column {
            id: col
            x: 24; y: 22
            width: parent.width - 48
            spacing: 16

            // header
            Item {
                width: parent.width; height: 22
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NOW PLAYING"; color: pal.text
                    font.family: pal.mono; font.pixelSize: 15; font.letterSpacing: 4
                }
                Text {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? pal.text : pal.faint; font.pixelSize: 14
                    MouseArea { id: closeMa; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: panel.close() }
                }
            }
            Rectangle { width: parent.width; height: 1; color: pal.line }

            // ── now playing ──
            Row {
                width: parent.width
                spacing: 20

                Item {
                    id: discBox
                    width: 150; height: 150

                    Canvas {   // dashed outer ring
                        anchors.fill: parent
                        property color c: pal.accent
                        onCChanged: requestPaint()
                        onPaint: {
                            const g = getContext("2d")
                            g.reset()
                            g.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.55)
                            g.lineWidth = 2
                            g.setLineDash([3, 3])
                            g.beginPath()
                            g.arc(width / 2, height / 2, width / 2 - 2, 0, Math.PI * 2)
                            g.stroke()
                        }
                    }
                    Item {
                        id: disc
                        anchors.centerIn: parent
                        width: 130; height: 130
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 12000
                            loops: Animation.Infinite
                            running: panel.shown && panel.playing
                        }
                        ClippingRectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.04)
                            Image {
                                anchors.fill: parent
                                source: panel.player && panel.player.trackArtUrl ? panel.player.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 260; sourceSize.height: 260
                            }
                        }
                        Repeater {   // vinyl grooves
                            model: 4
                            Rectangle {
                                anchors.centerIn: parent
                                width: 120 - index * 22; height: width; radius: width / 2
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.05)
                            }
                        }
                        Rectangle {   // label + spindle
                            anchors.centerIn: parent
                            width: 34; height: 34; radius: 17
                            color: pal.surface
                            border.width: 2; border.color: pal.accent
                            Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: pal.faint }
                        }
                    }
                }

                Column {
                    width: parent.width - discBox.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        width: parent.width
                        text: panel.player && panel.player.trackTitle ? panel.player.trackTitle : "No song playing"
                        color: pal.text; font.family: pal.mono; font.pixelSize: 17
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: !panel.player ? "no active player"
                              : (panel.player.trackArtist || panel.player.identity || "")
                        color: pal.dim; font.family: pal.mono; font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    Rectangle {   // output device chip
                        width: Math.min(parent.width, chip.implicitWidth + 20); height: 26; radius: 8
                        color: "transparent"; border.width: 1; border.color: pal.line
                        Text {
                            id: chip
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.parent.width - 20)
                            text: "󰓃 " + panel.sinkName
                            color: pal.dim; font.family: pal.mono; font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    // progress
                    Item {
                        width: parent.width; height: 22
                        visible: panel.player !== null && panel.player.lengthSupported && panel.player.length > 0
                        Rectangle {
                            id: track
                            anchors.top: parent.top; anchors.topMargin: 4
                            width: parent.width; height: 4; radius: 2
                            color: Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.1)
                            Rectangle {
                                height: parent.height; radius: 2; color: pal.accent
                                width: panel.player && panel.player.length > 0
                                       ? parent.width * Math.min(1, panel.player.position / panel.player.length) : 0
                            }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                enabled: panel.player && panel.player.canSeek
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: (m) => panel.player.position = Math.max(0, Math.min(1, (m.x - 6) / track.width)) * panel.player.length
                            }
                        }
                        Text {
                            anchors.left: parent.left; anchors.bottom: parent.bottom
                            text: panel.player ? panel.fmt(panel.player.position) : ""
                            color: pal.faint; font.family: pal.mono; font.pixelSize: 10
                        }
                        Text {
                            anchors.right: parent.right; anchors.bottom: parent.bottom
                            text: panel.player ? panel.fmt(panel.player.length) : ""
                            color: pal.faint; font.family: pal.mono; font.pixelSize: 10
                        }
                    }

                    // transport
                    Row {
                        spacing: 10
                        visible: panel.player !== null
                        Repeater {
                            model: [
                                { g: "󰒮", act: "prev" },
                                { g: panel.playing ? "󰏤" : "󰐊", act: "toggle" },
                                { g: "󰒭", act: "next" }
                            ]
                            Rectangle {
                                required property var modelData
                                readonly property bool main: modelData.act === "toggle"
                                width: main ? 44 : 36; height: width; radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: main ? pal.accent : (btnMa.containsMouse ? Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.08) : "transparent")
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.g
                                    color: parent.main ? pal.onAccent : pal.text
                                    font.family: pal.mono; font.pixelSize: parent.main ? 20 : 17
                                }
                                MouseArea {
                                    id: btnMa
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const p = panel.player
                                        if (!p) return
                                        if (parent.modelData.act === "prev" && p.canGoPrevious) p.previous()
                                        else if (parent.modelData.act === "next" && p.canGoNext) p.next()
                                        else if (parent.modelData.act === "toggle" && p.canTogglePlaying) p.togglePlaying()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: pal.line }

            // ── equalizer ──
            Item {
                width: parent.width; height: 28
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "EQUALIZER"; color: pal.text
                    font.family: pal.mono; font.pixelSize: 13; font.letterSpacing: 3
                }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: eq.preset; color: pal.dim; font.family: pal.mono; font.pixelSize: 12
                    }
                    Rectangle {
                        width: 60; height: 28; radius: 8
                        color: eq.on ? pal.secondary : "transparent"
                        border.width: 1.5
                        border.color: eq.on || onMa.containsMouse ? pal.accent : pal.line
                        Text {
                            anchors.centerIn: parent
                            text: eq.on ? "ON" : "OFF"
                            color: eq.on ? pal.accent : pal.faint
                            font.family: pal.mono; font.pixelSize: 12; font.letterSpacing: 1
                        }
                        MouseArea { id: onMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: eq.setOn(!eq.on) }
                    }
                }
            }

            Row {
                id: bands
                width: parent.width
                Repeater {
                    model: 10
                    Item {
                        id: band
                        required property int index
                        width: bands.width / 10; height: 190
                        property bool dragging: false
                        property int dragDb: 0
                        readonly property int db: dragging ? dragDb : (eq.gains[index] || 0)
                        readonly property real frac: (db + eq.range) / (2 * eq.range)

                        Timer {   // debounce live updates while dragging
                            id: push; interval: 90
                            onTriggered: eq.setBand(band.index, band.dragDb)
                        }

                        Rectangle {
                            id: rail
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 8; width: 14; height: 150; radius: 7
                            color: "transparent"
                            border.width: 1; border.color: pal.line
                            Rectangle {   // fill from bottom
                                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                width: 8; radius: 4
                                anchors.bottomMargin: 3
                                height: Math.max(0, (parent.height - 6) * band.frac)
                                color: eq.on ? pal.accent : Qt.rgba(pal.accent.r, pal.accent.g, pal.accent.b, 0.35)
                            }
                            Rectangle {   // knob
                                width: 20; height: 20; radius: 10
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: (parent.height - 6) * (1 - band.frac) + 3 - height / 2
                                color: pal.surface
                                border.width: 2.5
                                border.color: eq.on ? pal.accent : Qt.rgba(pal.accent.r, pal.accent.g, pal.accent.b, 0.5)
                            }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                function setFrom(y) {
                                    const t = 1 - Math.max(0, Math.min(1, (y - 8 - 3) / (rail.height - 6)))
                                    band.dragDb = Math.round(t * 2 * eq.range - eq.range)
                                    push.restart()
                                }
                                onPressed: (m) => { band.dragging = true; setFrom(m.y) }
                                onPositionChanged: (m) => setFrom(m.y)
                                onReleased: { push.stop(); eq.setBand(band.index, band.dragDb); band.dragging = false }
                                onWheel: (w) => { band.dragDb = Math.max(-eq.range, Math.min(eq.range, band.db + (w.angleDelta.y > 0 ? 1 : -1))); eq.setBand(band.index, band.dragDb) }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: band.dragging ? (band.db > 0 ? "+" : "") + band.db : eq.labels[band.index]
                            color: band.dragging ? pal.accent : pal.dim
                            font.family: pal.mono; font.pixelSize: 11
                        }
                    }
                }
            }

            Grid {
                columns: 4
                spacing: 10
                width: parent.width
                Repeater {
                    model: eq.presets
                    Rectangle {
                        required property string modelData
                        readonly property bool active: eq.preset === modelData
                        width: (col.width - 30) / 4; height: 34; radius: 8
                        color: active ? pal.secondary : (preMa.containsMouse ? Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.05) : "transparent")
                        border.width: active ? 1.5 : 1
                        border.color: active ? pal.accent : pal.line
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: parent.active ? pal.accent : pal.text
                            font.family: pal.mono; font.pixelSize: 13
                        }
                        MouseArea { id: preMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: eq.setPreset(parent.modelData) }
                    }
                }
            }
        }
    }
}
