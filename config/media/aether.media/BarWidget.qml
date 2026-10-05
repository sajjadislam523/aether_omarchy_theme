import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons

// AETHER media controller (any MPRIS player: Spotify, Firefox/Chromium, VLC, mpv…).
//   bar:    note icon + track title; hover reveals ◀ ❚❚ ▶
//   left = panel · right = play/pause · middle = next · scroll = prev/next
//   panel:  artwork, title, artist, source, controls, seekable progress
// With no player left it collapses to a dim note instead of disappearing.
BarWidget {
  id: root
  moduleName: "omarchy.media"

  // Players come straight from MPRIS. (A replacement bar such as aether.bar
  // is not handed Omarchy's media service, so the widget cannot rely on it.)
  readonly property var allPlayers: Mpris.players ? Mpris.players.values : []
  readonly property var sourcePlayers: allPlayers.filter(usable)
  property string pinnedKey: ""      // chosen in the panel
  property string lastKey: ""        // most recently playing player

  function keyOf(p) { return p ? String(p.dbusName || p.identity || "") : "" }
  function usable(p) {
    return p && keyOf(p).toLowerCase().indexOf("playerctld") === -1 && (p.trackTitle || p.trackArtist)
  }
  function isSpotify(p) {
    return (keyOf(p) + " " + String(p.desktopEntry || "")).toLowerCase().indexOf("spotify") !== -1
  }
  function preferred(list) {
    for (var i = 0; i < list.length; i++) if (isSpotify(list[i])) return list[i]
    return list.length ? list[0] : null
  }
  function byKey(list, key) {
    for (var i = 0; i < list.length; i++) if (keyOf(list[i]) === key) return list[i]
    return null
  }

  // pinned → playing (Spotify first) → last playing → Spotify → anything.
  readonly property var playingPlayer: preferred(sourcePlayers.filter(function(p) { return p.isPlaying }))
  onPlayingPlayerChanged: if (playingPlayer) lastKey = keyOf(playingPlayer)
  readonly property var player: (pinnedKey && byKey(sourcePlayers, pinnedKey))
    || playingPlayer || (lastKey && byKey(sourcePlayers, lastKey)) || preferred(sourcePlayers)

  readonly property bool hasMedia: player !== null && (player.trackTitle || player.trackArtist)
  readonly property bool playing: player !== null && player.isPlaying
  readonly property string title: player ? (player.trackTitle || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""
  readonly property string source: player ? (player.identity || player.desktopEntry || "") : ""
  readonly property real maxLabelWidth: Number(setting("maxWidth", 160))

  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property color secondary: Qt.rgba(fg.r, fg.g, fg.b, 0.62)
  readonly property color muted: Qt.rgba(fg.r, fg.g, fg.b, 0.38)
  readonly property bool hovered: hover.hovered || controlsHover.hovered

  property bool popupOpen: false
  function close() { popupOpen = false }

  function act(action) {
    var p = player
    if (!p) return
    if (action === "previous" && p.canGoPrevious) p.previous()
    else if (action === "next" && p.canGoNext) p.next()
    else if (action === "playPause") {
      if (p.canTogglePlaying) p.togglePlaying()
      else if (p.isPlaying && p.canPause) p.pause()
      else if (p.canPlay) p.play()
    }
  }

  function formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0) return "0:00"
    var s = Math.floor(seconds)
    var m = Math.floor(s / 60)
    var h = Math.floor(m / 60)
    var ss = String(s % 60).padStart(2, "0")
    return h > 0 ? h + ":" + String(m % 60).padStart(2, "0") + ":" + ss : m + ":" + ss
  }

  implicitWidth: root.vertical ? barSize : row.implicitWidth + Style.space(12)
  implicitHeight: barSize

  Behavior on implicitWidth {
    enabled: !root.vertical
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  HoverHandler { id: hover }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      id: note
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "󰝚"
      color: root.playing ? Color.accent : (root.hasMedia ? root.secondary : root.muted)
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.icon
      Behavior on color { ColorAnimation { duration: 160 } }
    }

    Text {
      id: label
      anchors.verticalCenter: parent.verticalCenter
      visible: root.hasMedia && !root.vertical
      width: Math.min(root.maxLabelWidth, implicitWidth)
      textFormat: Text.PlainText
      text: root.title || root.artist
      elide: Text.ElideRight
      color: root.playing ? root.fg : root.secondary
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      Behavior on color { ColorAnimation { duration: 160 } }
    }

    // Inline transport, revealed on hover.
    Row {
      id: controls
      anchors.verticalCenter: parent.verticalCenter
      visible: width > 0
      width: root.hasMedia && root.hovered && !root.vertical ? implicitWidth : 0
      clip: true
      spacing: Style.space(2)
      opacity: width > 0 ? 1 : 0
      Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 140 } }

      HoverHandler { id: controlsHover }

      Repeater {
        model: [
          { glyph: "󰒮", action: "previous" },
          { glyph: root.playing ? "󰏤" : "󰐊", action: "playPause" },
          { glyph: "󰒭", action: "next" }
        ]

        Text {
          required property var modelData
          width: Style.space(18)
          height: root.barSize
          textFormat: Text.PlainText
          text: modelData.glyph
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          color: tap.containsMouse ? Color.accent : root.secondary
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          Behavior on color { ColorAnimation { duration: 120 } }

          MouseArea {
            id: tap
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.act(parent.modelData.action)
          }
        }
      }
    }
  }

  // Covers the icon + title; the transport buttons sit above it.
  MouseArea {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: controls.width > 0 ? controls.x + row.x : parent.width
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) root.popupOpen = !root.popupOpen
      else if (mouse.button === Qt.RightButton) root.act("playPause")
      else root.act("next")
    }
    onWheel: function(wheel) {
      if (wheel.angleDelta.y > 0) root.act("previous")
      else if (wheel.angleDelta.y < 0) root.act("next")
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.hasMedia
      ? (root.title + (root.artist ? " — " + root.artist : "") + (root.source ? "  ·  " + root.source : ""))
      : "No media playing")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // MPRIS does not push position updates; poll once a second, but only while
  // the panel is open and something is playing.
  Timer {
    interval: 1000
    repeat: true
    running: root.popupOpen && root.playing
    onTriggered: if (root.player) root.player.positionChanged()
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(300))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(12)

      // Artwork + text.
      Row {
        width: parent.width
        spacing: Style.space(12)

        Rectangle {
          id: art
          width: Style.space(56)
          height: Style.space(56)
          radius: Style.space(10)
          color: Qt.rgba(1, 1, 1, 0.04)
          border.width: 1
          border.color: Color.popups.border
          clip: true

          Image {
            id: artImage
            anchors.fill: parent
            anchors.margins: 1
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
            visible: status === Image.Ready
          }

          Text {
            anchors.centerIn: parent
            visible: !artImage.visible
            text: "󰝚"
            color: root.hasMedia ? Color.accent : root.muted
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.heading
          }
        }

        Column {
          width: parent.width - art.width - Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3)

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.hasMedia ? root.title : "Nothing playing"
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            visible: text !== ""
            textFormat: Text.PlainText
            text: root.hasMedia ? root.artist : "Start a player to see it here"
            color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.62)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            visible: text !== ""
            textFormat: Text.PlainText
            text: root.source
            color: Color.accent
            opacity: 0.8
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
      }

      // Progress (only when the player reports a length).
      Column {
        id: progress
        width: parent.width
        spacing: Style.space(4)
        readonly property real length: root.player && root.player.lengthSupported ? root.player.length : 0
        readonly property real position: root.player && root.player.positionSupported ? root.player.position : 0
        visible: root.hasMedia && length > 0

        Item {
          width: parent.width
          height: Style.space(10)

          Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 3
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.08)

            Rectangle {
              width: progress.length > 0 ? Math.min(1, progress.position / progress.length) * parent.width : 0
              height: parent.height
              radius: parent.radius
              gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Color.accent }
                GradientStop { position: 1.0; color: Qt.lighter(Color.accent, 1.2) }
              }
            }
          }

          Rectangle {
            x: (progress.length > 0 ? Math.min(1, progress.position / progress.length) : 0) * track.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: seek.containsMouse ? 10 : 7
            height: width
            radius: width / 2
            color: Color.foreground
            border.width: 2
            border.color: Color.accent
            Behavior on width { NumberAnimation { duration: 120 } }
          }

          MouseArea {
            id: seek
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.player !== null && root.player.canSeek
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: function(mouse) {
              if (!root.player || progress.length <= 0) return
              root.player.position = Math.max(0, Math.min(1, mouse.x / width)) * progress.length
            }
          }
        }

        Item {
          width: parent.width
          height: elapsed.implicitHeight
          Text {
            id: elapsed
            textFormat: Text.PlainText
            text: root.formatTime(progress.position)
            color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
          Text {
            anchors.right: parent.right
            textFormat: Text.PlainText
            text: root.formatTime(progress.length)
            color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }

      // Transport.
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)
        visible: root.hasMedia

        Button {
          iconText: "󰒮"
          foreground: Color.popups.text
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.player !== null && root.player.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.act("previous")
        }
        Button {
          iconText: root.playing ? "󰏤" : "󰐊"
          foreground: Color.accent
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.player !== null && (root.player.canTogglePlaying || root.player.canPlay || root.player.canPause)
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.act("playPause")
        }
        Button {
          iconText: "󰒭"
          foreground: Color.popups.text
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.player !== null && root.player.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.act("next")
        }
      }

      // Nothing playing: offer Spotify.
      Button {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !root.hasMedia
        text: "Open Spotify"
        iconText: ""
        foreground: Color.popups.text
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        onClicked: {
          if (root.bar) root.bar.run("omarchy-launch-or-focus spotify")
          root.popupOpen = false
        }
      }

      // Several players: pick which one the bar follows.
      PanelSeparator {
        visible: root.sourcePlayers.length > 1
        foreground: Color.popups.text
      }

      Column {
        id: sourceList
        visible: root.sourcePlayers.length > 1
        width: parent.width
        spacing: Style.space(2)

        Repeater {
          model: root.sourcePlayers

          Rectangle {
            id: sourceRow
            required property var modelData
            readonly property var p: modelData
            readonly property bool selected: root.player && p
              && root.keyOf(root.player) === root.keyOf(p)

            width: sourceList.width
            height: Style.space(28)
            radius: Style.space(8)
            color: selected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.10)
              : (rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: sourceRow.p && sourceRow.p.isPlaying ? "󰏤" : "󰐊"
                color: sourceRow.selected ? Color.accent : Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(24)
                textFormat: Text.PlainText
                text: sourceRow.p ? ((sourceRow.p.identity || sourceRow.p.desktopEntry || "Player")
                  + (sourceRow.p.trackTitle ? "  ·  " + sourceRow.p.trackTitle : "")) : ""
                color: sourceRow.selected ? Color.popups.text : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.62)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.pinnedKey = sourceRow.selected ? "" : root.keyOf(sourceRow.p)
            }
          }
        }
      }
    }
  }
}
