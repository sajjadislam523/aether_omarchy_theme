import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui

// AETHER lock screen view.
//
// Visual layer only: every property, signal and the password TextInput
// behaviour match Omarchy's LockView, so the unchanged Service.qml (PAM,
// fingerprint, session lock) drives it exactly as before.
Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: "Enter password"
  readonly property int fieldWidth: 300
  readonly property int fieldHeight: 46
  readonly property int outlineThickness: 1
  readonly property int fieldFontSize: 14
  readonly property int passwordDotFontSize: 18
  readonly property int passwordDotLetterSpacing: 4
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property bool typing: passwordInput.text.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha")
    : (typing || authenticatingPassword
      ? Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha")
      : Border.surfaceSpec("lock", "border", Color.lock.border, root.outlineThickness, "border-alpha"))

  // AETHER palette, with fallbacks to the active theme for any other theme.
  readonly property color textPrimary: Color.lock.text
  readonly property color textSecondary: Qt.rgba(textPrimary.r, textPrimary.g, textPrimary.b, 0.6)
  readonly property color textMuted: Qt.rgba(textPrimary.r, textPrimary.g, textPrimary.b, 0.38)
  readonly property color accent: Color.accent
  readonly property color violet: "#9B8CFF"
  readonly property string uiFont: "Adwaita Sans"

  // A dedicated, darker lock wallpaper ships with the theme as lockscreen.png;
  // any other theme falls back to the desktop background (blurred).
  readonly property string themeLockImage: Color.currentThemePath + "/lockscreen.png"
  property bool themeLockMissing: false
  readonly property bool usingThemeLock: !themeLockMissing

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  readonly property var mediaPlayer: {
    var players = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < players.length; i++) {
      if (players[i].isPlaying && players[i].trackTitle) return players[i]
    }
    return null
  }

  Rectangle {
    anchors.fill: parent
    color: "#05070B"

    // ---------- Background ----------
    Image {
      id: wallpaper
      anchors.fill: parent
      source: !root.loadBackground ? ""
        : (root.usingThemeLock ? root.fileUrl(root.themeLockImage) : root.fileUrl(root.backgroundPath))
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
      onStatusChanged: if (status === Image.Error && root.usingThemeLock) root.themeLockMissing = true
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      visible: !root.usingThemeLock
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
      blur: 1.0
      blurMax: 96
      blurMultiplier: 1.2
      brightness: -0.25
    }

    // Atmosphere: two very soft radial glows that breathe over ~14-18s.
    // Opacity-only animation, stopped whenever the lock is hidden.
    Item {
      id: atmosphere
      anchors.fill: parent
      readonly property bool animate: root.loadBackground && root.visible

      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        SequentialAnimation on opacity {
          running: atmosphere.animate
          loops: Animation.Infinite
          NumberAnimation { from: 0.4; to: 1.0; duration: 7000; easing.type: Easing.InOutSine }
          NumberAnimation { from: 1.0; to: 0.4; duration: 7000; easing.type: Easing.InOutSine }
        }
        ShapePath {
          strokeWidth: -1
          fillGradient: RadialGradient {
            centerX: atmosphere.width * 0.3; centerY: atmosphere.height * 0.15
            focalX: centerX; focalY: centerY
            centerRadius: atmosphere.width * 0.55
            GradientStop { position: 0.0; color: Qt.rgba(root.violet.r, root.violet.g, root.violet.b, 0.07) }
            GradientStop { position: 1.0; color: "transparent" }
          }
          PathRectangle { x: 0; y: 0; width: atmosphere.width; height: atmosphere.height }
        }
      }

      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        SequentialAnimation on opacity {
          running: atmosphere.animate
          loops: Animation.Infinite
          NumberAnimation { from: 0.35; to: 0.9; duration: 9000; easing.type: Easing.InOutSine }
          NumberAnimation { from: 0.9; to: 0.35; duration: 9000; easing.type: Easing.InOutSine }
        }
        ShapePath {
          strokeWidth: -1
          fillGradient: RadialGradient {
            centerX: atmosphere.width * 0.5; centerY: atmosphere.height * 0.82
            focalX: centerX; focalY: centerY
            centerRadius: atmosphere.width * 0.45
            GradientStop { position: 0.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.06) }
            GradientStop { position: 1.0; color: "transparent" }
          }
          PathRectangle { x: 0; y: 0; width: atmosphere.width; height: atmosphere.height }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // ---------- Clock ----------
    Column {
      id: clockBlock
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(parent.height * 0.12)
      spacing: Math.round(parent.height * 0.012)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: Qt.formatTime(clock.date, "hh:mm")
        color: root.textPrimary
        font.family: root.uiFont
        font.weight: Font.ExtraLight
        font.pixelSize: Math.round(Math.min(root.height * 0.2, root.width * 0.14))
        font.letterSpacing: -2
        renderType: Text.QtRendering
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: Qt.formatDate(clock.date, "dddd").toUpperCase() + "  •  " + Qt.formatDate(clock.date, "dd MMMM").toUpperCase()
        color: root.textSecondary
        font.family: root.uiFont
        font.weight: Font.Normal
        font.pixelSize: Math.max(12, Math.round(root.height * 0.018))
        font.letterSpacing: 4
      }
    }

    // ---------- Authentication panel ----------
    Rectangle {
      id: panel
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(clockBlock.y + clockBlock.height + parent.height * 0.06)
      width: root.fieldWidth + 56
      height: panelColumn.implicitHeight + 48
      radius: 18
      color: Qt.rgba(Color.lock.background.r, Color.lock.background.g, Color.lock.background.b, 0.42)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.07)

      // Subtle shake on a wrong password.
      transform: Translate { id: shake; x: 0 }
      SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shake; property: "x"; to: -8; duration: 50 }
        NumberAnimation { target: shake; property: "x"; to: 8; duration: 70 }
        NumberAnimation { target: shake; property: "x"; to: -4; duration: 60 }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 60 }
      }
      Connections {
        target: root
        function onFailedAttemptsChanged() { if (root.failedAttempts > 0) shakeAnim.restart() }
      }

      // Glass highlight along the top edge.
      Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 2 * parent.radius
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
      }

      Column {
        id: panelColumn
        anchors.centerIn: parent
        spacing: 14

        // Avatar: ~/.face if present, otherwise the user's initial.
        Rectangle {
          id: avatar
          anchors.horizontalCenter: parent.horizontalCenter
          width: 56
          height: 56
          radius: 28
          color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.08)
          border.width: 1
          border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.typing ? 0.7 : 0.35)
          Behavior on border.color { ColorAnimation { duration: 180 } }

          Image {
            id: face
            anchors.fill: parent
            anchors.margins: 3
            source: "file://" + Quickshell.env("HOME") + "/.face"
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
          }
          MultiEffect {
            anchors.fill: face
            source: face
            visible: face.status === Image.Ready
            maskEnabled: true
            maskSource: faceMask
          }
          Item {
            id: faceMask
            anchors.fill: face
            layer.enabled: true
            visible: false
            Rectangle { anchors.fill: parent; radius: width / 2 }
          }

          Text {
            anchors.centerIn: parent
            visible: face.status !== Image.Ready
            textFormat: Text.PlainText
            text: String(Quickshell.env("USER") || "?").charAt(0).toUpperCase()
            color: root.accent
            font.family: root.uiFont
            font.weight: Font.Light
            font.pixelSize: 24
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: String(Quickshell.env("USER") || "").toUpperCase()
          color: root.textSecondary
          font.family: root.uiFont
          font.weight: Font.Medium
          font.pixelSize: 12
          font.letterSpacing: 3
        }

        BorderSurface {
          id: inputField
          width: root.fieldWidth
          height: root.fieldHeight
          color: Qt.rgba(0, 0, 0, 0.25)
          borderSpec: root.inputBorderSpec
          radius: 12
          clip: true

          TextInput {
            id: passwordInput
            anchors.fill: parent
            anchors.topMargin: inputField.borderTop
            anchors.rightMargin: inputField.borderRight + 16 + root.fingerprintReserve
            anchors.bottomMargin: inputField.borderBottom
            anchors.leftMargin: inputField.borderLeft + 16 + root.fingerprintReserve
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            activeFocusOnPress: true
            clip: true
            enabled: root.inputEnabled && !root.authenticatingPassword
            readOnly: root.authenticatingPassword
            echoMode: TextInput.Password
            passwordCharacter: "●"
            passwordMaskDelay: 0
            color: root.accent
            selectionColor: Color.lock.selection
            selectedTextColor: Color.lock.text
            font.family: Style.font.family
            font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
            font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
            cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
            cursorDelegate: Rectangle {
              width: 1
              color: root.accent
              visible: passwordInput.cursorVisible
            }

            onTextChanged: {
              if (!root.syncingPasswordText) root.passwordTextEdited(text)
              if (text.length > 0) {
                root.wakeRequested()
              }
              if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
            }

            onAccepted: {
              var submitted = root.passwordText
              root.passwordTextEdited("")
              if (submitted.length > 0) root.submitPassword(submitted)
            }

            Keys.onPressed: function(event) {
              root.wakeRequested()
              if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                root.passwordTextEdited("")
                event.accepted = true
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.fill: passwordInput
            text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
            visible: passwordInput.text.length === 0
            color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
            font.family: root.uiFont
            font.pixelSize: root.fieldFontSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }

          Text {
            id: fingerprintIcon
            objectName: "fingerprintIndicator"
            anchors.right: parent.right
            anchors.rightMargin: inputField.borderRight + 16
            anchors.verticalCenter: parent.verticalCenter
            visible: root.fingerprintConfigured
            text: "󰈷"
            color: Color.lock.placeholder
            font.family: Style.font.family
            font.pixelSize: Math.round(root.fieldFontSize * 1.2)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: root.authenticatingPassword ? "UNLOCKING" : "UNLOCK  ⏎"
          color: root.typing || root.authenticatingPassword ? root.accent : root.textMuted
          font.family: root.uiFont
          font.weight: Font.Medium
          font.pixelSize: 11
          font.letterSpacing: 4
          Behavior on color { ColorAnimation { duration: 180 } }
        }
      }
    }

    // ---------- Secondary status ----------
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.round(parent.height * 0.05)
      spacing: 28

      Text {
        readonly property var dev: UPower.displayDevice
        visible: dev !== null && dev.isLaptopBattery
        textFormat: Text.PlainText
        text: {
          if (!dev) return ""
          var pct = Math.round(dev.percentage * 100)
          var charging = dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged
          return (charging ? "󰂄 " : (pct <= 20 ? "󰁺 " : "󰁹 ")) + pct + "%"
        }
        color: dev && Math.round(dev.percentage * 100) <= 15 ? Color.lock.textError : root.textMuted
        font.family: Style.font.family
        font.pixelSize: 12
      }

      Text {
        visible: root.mediaPlayer !== null
        width: Math.min(implicitWidth, 360)
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: root.mediaPlayer ? "󰝚  " + root.mediaPlayer.trackTitle + (root.mediaPlayer.trackArtist ? " — " + root.mediaPlayer.trackArtist : "") : ""
        color: root.textMuted
        font.family: Style.font.family
        font.pixelSize: 12
      }
    }
  }
}
