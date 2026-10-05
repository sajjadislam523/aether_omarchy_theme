import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// AETHER workspace indicator.
//   style "dots" (default):  active = cyan pill · occupied = gray dot · empty = dim ring
//   style "numbers":         01 02 03 with the active one in cyan
// Event-driven through Quickshell.Hyprland — no polling.
BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  readonly property string style: String(setting("style", "dots"))
  readonly property color activeColor: Color.accent
  readonly property color occupiedColor: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.55)
  readonly property color emptyColor: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.22)
  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property int slot: style === "numbers" ? Style.space(22) : Style.space(14)

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }
    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  implicitWidth: root.vertical ? root.barSize : flow.implicitWidth + Style.space(6)
  implicitHeight: root.vertical ? flow.implicitHeight + Style.space(6) : root.barSize

  Grid {
    id: flow
    anchors.centerIn: parent
    columns: root.vertical ? 1 : root.workspaceIds().length
    spacing: 0

    Repeater {
      model: root.workspaceIds()

      Item {
        id: cell
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        width: root.vertical ? root.barSize : root.slot + (root.style === "dots" && focused ? Style.space(8) : 0)
        height: root.vertical ? root.slot : root.barSize

        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        // Dots: a capsule that stretches when the workspace is focused.
        Rectangle {
          visible: root.style !== "numbers"
          anchors.centerIn: parent
          height: Style.space(6)
          width: cell.focused ? Style.space(16) : Style.space(6)
          radius: height / 2
          color: cell.focused ? root.activeColor : (cell.occupied ? root.occupiedColor : "transparent")
          border.width: cell.focused || cell.occupied ? 0 : 1
          border.color: root.emptyColor

          Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: 140 } }
        }

        // Numbers: 01 02 03, active one in cyan with a faint underline.
        Text {
          visible: root.style === "numbers"
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: (cell.modelData === 10 ? 10 : cell.modelData).toString().padStart(2, "0")
          color: cell.focused ? root.activeColor : (cell.occupied ? root.occupiedColor : root.emptyColor)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: cell.focused
          Behavior on color { ColorAnimation { duration: 140 } }
        }
        Rectangle {
          visible: root.style === "numbers" && cell.focused
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(4)
          width: Style.space(10)
          height: 1
          color: root.activeColor
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusWorkspace(cell.modelData)
        }
      }
    }
  }

  // Scroll on the indicator to move between workspaces.
  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function(event) {
      if (!root.bar) return
      var step = event.angleDelta.y > 0 ? "e-1" : "e+1"
      root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + step + "\" })"))
    }
  }
}
