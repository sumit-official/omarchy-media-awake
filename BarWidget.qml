import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "org.user.media-awake"

  readonly property var service: bar?.shell?.serviceFor("org.user.media-awake")
  readonly property bool awakeEnabled: service ? service.awakeEnabled : false
  readonly property bool mediaPlaying: service ? service.mediaPlaying : false
  property bool popupOpen: false

  function close() { popupOpen = false }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "☕"
    horizontalMargin: 7.5
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton && root.service) root.service.toggle()
      else root.popupOpen = !root.popupOpen
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(300))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(14)

      Item {
        width: parent.width
        implicitHeight: Math.max(icon.implicitHeight, labels.implicitHeight, enabledSwitch.implicitHeight)

        Text {
          id: icon
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "☕"
          color: root.bar.foreground
          font.pixelSize: Style.font.display
          opacity: root.mediaPlaying ? 1.0 : 0.65
        }

        Column {
          id: labels
          anchors.left: icon.right
          anchors.leftMargin: Style.space(14)
          anchors.right: enabledSwitch.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            text: "Media Awake"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            text: root.mediaPlaying && root.awakeEnabled
              ? "PREVENTING SLEEP"
              : root.awakeEnabled ? "READY" : "DISABLED"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
          }
        }

        ToggleSwitch {
          id: enabledSwitch
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          checked: root.awakeEnabled
          foreground: root.bar.foreground
          onToggled: if (root.service) root.service.toggle()
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.mediaPlaying
          ? "Sleep is blocked while a video or other media is playing."
          : "Sleep will work normally until media starts playing."
        color: Qt.darker(root.bar.foreground, 1.25)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
      }
    }
  }
}
