import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons

// AETHER media centre (any MPRIS player: Spotify, browsers, VLC, mpv…).
//
//   bar:   only what is playing right now: note + title (+N when several
//          play at once); hover reveals ◀ ❚❚ ▶. Nothing playing: a dim note.
//          left = panel · right = play/pause · middle = next · scroll = prev/next
//   panel: one card per open player, each with artwork, title, artist,
//          app, its own ◀ ❚❚ ▶ and a seekable progress bar; "Pause all";
//          "Open Spotify" when Spotify is not running.
//
// Players are read straight from MPRIS: a replacement bar such as aether.bar
// is not handed Omarchy's media service.
BarWidget {
  id: root
  moduleName: "omarchy.media"

  // ---------------------------------------------------------------- players
  readonly property var allPlayers: Mpris.players ? Mpris.players.values : []
  // Stable order (as MPRIS lists them), so cards do not jump when one pauses.
  readonly property var players: allPlayers.filter(usable)
  readonly property var playingPlayers: players.filter(function(p) { return p.isPlaying })
  property string lastKey: ""   // most recently playing player, for resume

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
  function appName(p) {
    var name = p ? String(p.identity || p.desktopEntry || "Player") : ""
    return name.replace(/^Google /, "")
  }
  function act(p, action) {
    if (!p) return
    if (action === "previous" && p.canGoPrevious) p.previous()
    else if (action === "next" && p.canGoNext) p.next()
    else if (action === "playPause") {
      if (p.canTogglePlaying) p.togglePlaying()
      else if (p.isPlaying && p.canPause) p.pause()
      else if (p.canPlay) p.play()
    }
  }
  function pauseAll() {
    var list = playingPlayers.slice()
    for (var i = 0; i < list.length; i++) if (list[i].canPause) list[i].pause()
  }
  function formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0) return "0:00"
    var s = Math.floor(seconds)
    var m = Math.floor(s / 60)
    var h = Math.floor(m / 60)
    var ss = String(s % 60).padStart(2, "0")
    return h > 0 ? h + ":" + String(m % 60).padStart(2, "0") + ":" + ss : m + ":" + ss
  }

  // The bar follows what is playing (Spotify first if several are).
  readonly property var nowPlaying: preferred(playingPlayers)
  onNowPlayingChanged: if (nowPlaying) lastKey = keyOf(nowPlaying)
  // Bar clicks with nothing playing act on the last player, so right-click resumes it.
  readonly property var barTarget: nowPlaying || (lastKey && byKey(players, lastKey)) || preferred(players)
  readonly property bool playing: nowPlaying !== null
  readonly property string title: nowPlaying ? (nowPlaying.trackTitle || nowPlaying.trackArtist || "") : ""
  readonly property bool spotifyOpen: allPlayers.some(isSpotify)
  readonly property real maxLabelWidth: Number(setting("maxWidth", 160))

  // ------------------------------------------------------------- appearance
  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property color secondary: Qt.rgba(fg.r, fg.g, fg.b, 0.62)
  readonly property color muted: Qt.rgba(fg.r, fg.g, fg.b, 0.38)
  readonly property color text: Color.popups.text
  readonly property color text2: Qt.rgba(text.r, text.g, text.b, 0.62)
  readonly property color text3: Qt.rgba(text.r, text.g, text.b, 0.40)
  readonly property color accent: Color.accent
  readonly property bool hovered: hover.hovered || controlsHover.hovered

  property bool popupOpen: false
  function close() { popupOpen = false }

  implicitWidth: root.vertical ? barSize : row.implicitWidth + Style.space(12)
  implicitHeight: barSize

  Behavior on implicitWidth {
    enabled: !root.vertical
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  HoverHandler { id: hover }

  // -------------------------------------------------------------------- bar
  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "󰝚"
      color: root.playing ? root.accent : root.muted
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.icon
      Behavior on color { ColorAnimation { duration: 160 } }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.playing && !root.vertical
      width: Math.min(root.maxLabelWidth, implicitWidth)
      textFormat: Text.PlainText
      text: root.title
      elide: Text.ElideRight
      color: root.fg
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
    }

    // "+1" when more than one thing is playing.
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.playingPlayers.length > 1 && !root.vertical
      width: countText.implicitWidth + Style.space(8)
      height: countText.implicitHeight + Style.space(2)
      radius: height / 2
      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
      Text {
        id: countText
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: "+" + (root.playingPlayers.length - 1)
        color: root.accent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    // Inline transport for the playing media, revealed on hover.
    Row {
      id: controls
      anchors.verticalCenter: parent.verticalCenter
      visible: width > 0
      width: root.playing && root.hovered && !root.vertical ? implicitWidth : 0
      clip: true
      spacing: Style.space(2)
      opacity: width > 0 ? 1 : 0
      Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 140 } }

      HoverHandler { id: controlsHover }

      Repeater {
        model: [
          { glyph: "󰒮", action: "previous" },
          { glyph: "󰏤", action: "playPause" },
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
          color: tap.containsMouse ? root.accent : root.secondary
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          Behavior on color { ColorAnimation { duration: 120 } }

          MouseArea {
            id: tap
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.act(root.nowPlaying, parent.modelData.action)
          }
        }
      }
    }
  }

  // Icon + title area; the transport buttons sit above it.
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
      else if (mouse.button === Qt.RightButton) root.act(root.barTarget, "playPause")
      else root.act(root.barTarget, "next")
    }
    onWheel: function(wheel) {
      if (wheel.angleDelta.y > 0) root.act(root.barTarget, "previous")
      else if (wheel.angleDelta.y < 0) root.act(root.barTarget, "next")
    }
    onEntered: {
      if (!root.bar) return
      var n = root.players.length
      var tip = root.playing
        ? root.title + (root.nowPlaying.trackArtist ? " — " + root.nowPlaying.trackArtist : "") + "  ·  " + root.appName(root.nowPlaying)
        : (n ? n + (n === 1 ? " player, paused" : " players, all paused") : "No media")
      root.bar.showTooltip(root, tip)
    }
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // MPRIS does not push playback position; refresh once a second, only while
  // the panel is open and something is playing.
  Timer {
    interval: 1000
    repeat: true
    running: root.popupOpen && root.playing
    onTriggered: {
      var list = root.playingPlayers
      for (var i = 0; i < list.length; i++) list[i].positionChanged()
    }
  }

  // ------------------------------------------------------------------ panel
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(panel.implicitHeight, Style.space(520))

    Column {
      id: panel
      anchors.fill: parent
      spacing: Style.space(10)

      // Header: summary + Pause all.
      Item {
        width: parent.width
        height: Math.max(headerText.implicitHeight, pauseAll.implicitHeight)

        Column {
          id: headerText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(1)

          Text {
            textFormat: Text.PlainText
            text: "Media"
            color: root.text
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }
          Text {
            textFormat: Text.PlainText
            text: {
              var n = root.players.length, k = root.playingPlayers.length
              if (!n) return "Nothing open"
              return n + (n === 1 ? " source" : " sources") + "  ·  " + (k ? k + " playing" : "all paused")
            }
            color: root.text3
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Button {
          id: pauseAll
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          visible: root.playingPlayers.length > 0
          text: root.playingPlayers.length > 1 ? "Pause all" : "Pause"
          iconText: "󰏤"
          foreground: root.text
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.space(3)
          fontSize: Style.font.bodySmall
          iconSize: Style.font.bodySmall
          onClicked: root.pauseAll()
        }
      }

      // One card per player; scrolls past ~4 cards.
      Flickable {
        id: list
        width: parent.width
        height: Math.min(cards.implicitHeight, Style.space(400))
        contentHeight: cards.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        visible: root.players.length > 0

        Column {
          id: cards
          width: list.width
          spacing: Style.space(8)

          Repeater {
            model: root.players
            delegate: Rectangle {
              id: card
              required property var modelData
              readonly property var p: modelData
              readonly property bool isPlaying: p !== null && p.isPlaying
              readonly property real length: p && p.lengthSupported ? p.length : 0
              readonly property real position: p && p.positionSupported ? p.position : 0

              width: cards.width
              height: cardBody.implicitHeight + Style.space(20)
              radius: Style.space(12)
              color: isPlaying ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.07)
                : (cardHover.hovered ? Qt.rgba(1, 1, 1, 0.035) : Qt.rgba(1, 1, 1, 0.02))
              border.width: 1
              border.color: isPlaying ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35) : Color.popups.border
              Behavior on color { ColorAnimation { duration: 160 } }
              Behavior on border.color { ColorAnimation { duration: 160 } }

              HoverHandler { id: cardHover }

              Column {
                id: cardBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Row {
                  width: parent.width
                  spacing: Style.space(10)

                  // Artwork (or a note), with a small "playing" equaliser.
                  Rectangle {
                    id: art
                    width: Style.space(44)
                    height: Style.space(44)
                    radius: Style.space(8)
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
                      sourceSize.width: 96
                      sourceSize.height: 96
                      source: card.p && card.p.trackArtUrl ? card.p.trackArtUrl : ""
                      visible: status === Image.Ready
                    }
                    Text {
                      anchors.centerIn: parent
                      visible: !artImage.visible
                      textFormat: Text.PlainText
                      text: root.isSpotify(card.p) ? "" : "󰝚"
                      color: card.isPlaying ? root.accent : root.text3
                      font.family: Style.font.family
                      font.pixelSize: Style.font.heading
                    }

                    Row {
                      visible: card.isPlaying
                      anchors.right: parent.right
                      anchors.bottom: parent.bottom
                      anchors.margins: Style.space(4)
                      spacing: 2
                      Repeater {
                        model: 3
                        Rectangle {
                          required property int index
                          width: 2
                          height: 4
                          radius: 1
                          anchors.bottom: parent.bottom
                          color: root.accent
                          SequentialAnimation on height {
                            running: card.isPlaying && root.popupOpen
                            loops: Animation.Infinite
                            NumberAnimation { to: 10 - index * 2; duration: 380 + index * 90; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 3; duration: 380 + index * 90; easing.type: Easing.InOutSine }
                          }
                        }
                      }
                    }
                  }

                  // Title / artist / app.
                  Column {
                    width: parent.width - art.width - transport.width - Style.space(20)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Text {
                      width: parent.width
                      textFormat: Text.PlainText
                      text: card.p ? (card.p.trackTitle || card.p.trackArtist || "Unknown") : ""
                      color: root.text
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: card.isPlaying
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      visible: text !== ""
                      textFormat: Text.PlainText
                      text: card.p && card.p.trackTitle ? (card.p.trackArtist || "") : ""
                      color: root.text2
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      textFormat: Text.PlainText
                      text: root.appName(card.p) + (card.isPlaying ? "  ·  playing" : "  ·  paused")
                      color: card.isPlaying ? root.accent : root.text3
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }

                  // Per-player transport.
                  Row {
                    id: transport
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Repeater {
                      model: [
                        { glyph: "󰒮", action: "previous", big: false },
                        { glyph: card.isPlaying ? "󰏤" : "󰐊", action: "playPause", big: true },
                        { glyph: "󰒭", action: "next", big: false }
                      ]

                      Rectangle {
                        id: btn
                        required property var modelData
                        readonly property bool can: !card.p ? false
                          : modelData.action === "previous" ? card.p.canGoPrevious
                          : modelData.action === "next" ? card.p.canGoNext
                          : (card.p.canTogglePlaying || card.p.canPlay || card.p.canPause)
                        width: modelData.big ? Style.space(30) : Style.space(24)
                        height: width
                        radius: width / 2
                        color: modelData.big
                          ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, btnArea.containsMouse ? 0.24 : 0.14)
                          : (btnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                        opacity: can ? 1.0 : 0.35
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                          anchors.centerIn: parent
                          textFormat: Text.PlainText
                          text: btn.modelData.glyph
                          color: btn.modelData.big ? root.accent : (btnArea.containsMouse ? root.accent : root.text2)
                          font.family: Style.font.family
                          font.pixelSize: btn.modelData.big ? Style.font.icon : Style.font.bodySmall
                        }
                        MouseArea {
                          id: btnArea
                          anchors.fill: parent
                          enabled: btn.can
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.act(card.p, btn.modelData.action)
                        }
                      }
                    }
                  }
                }

                // Seekable progress, when the player reports a length.
                Item {
                  width: parent.width
                  height: Style.space(12)
                  visible: card.length > 0

                  Text {
                    id: elapsed
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: root.formatTime(card.position)
                    color: root.text3
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                  Text {
                    id: total
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: root.formatTime(card.length)
                    color: root.text3
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }

                  Item {
                    id: seekArea
                    anchors.left: elapsed.right
                    anchors.right: total.left
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    readonly property real frac: card.length > 0 ? Math.max(0, Math.min(1, card.position / card.length)) : 0

                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width
                      height: 3
                      radius: 1.5
                      color: Qt.rgba(1, 1, 1, 0.08)
                      Rectangle {
                        width: seekArea.frac * parent.width
                        height: parent.height
                        radius: parent.radius
                        color: card.isPlaying ? root.accent : root.text3
                      }
                    }
                    Rectangle {
                      visible: seek.containsMouse
                      x: seekArea.frac * seekArea.width - width / 2
                      anchors.verticalCenter: parent.verticalCenter
                      width: 9
                      height: 9
                      radius: 4.5
                      color: Color.foreground
                      border.width: 2
                      border.color: root.accent
                    }
                    MouseArea {
                      id: seek
                      anchors.fill: parent
                      hoverEnabled: true
                      enabled: card.p !== null && card.p.canSeek
                      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                      onClicked: function(mouse) {
                        if (card.p && card.length > 0)
                          card.p.position = Math.max(0, Math.min(1, mouse.x / width)) * card.length
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Empty state.
      Column {
        width: parent.width
        visible: root.players.length === 0
        spacing: Style.space(6)
        topPadding: Style.space(6)
        bottomPadding: Style.space(2)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: "󰝚"
          color: root.text3
          font.family: Style.font.family
          font.pixelSize: Style.font.displayLarge
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: "No media open"
          color: root.text2
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      // Quick access to Spotify when it is not running.
      Button {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !root.spotifyOpen
        text: "Open Spotify"
        iconText: ""
        foreground: root.text
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        onClicked: {
          if (root.bar) root.bar.run("omarchy-launch-or-focus spotify")
          root.popupOpen = false
        }
      }
    }
  }
}
