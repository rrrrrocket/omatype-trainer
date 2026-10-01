import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.rrrrrocket.omatype-trainer"
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() {
    if (!panelLoader.item) {
      console.warn("omatype-trainer click received before Panel.qml loaded")
      return
    }
    console.log("omatype-trainer icon pressed; panel opened:", opened)
    if (opened) close(); else open()
  }
  function inject() {
    if (!panelLoader.item) return
    panelLoader.item.bar = bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: inject()
  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.inject(); Qt.callLater(root.inject) }
    onStatusChanged: if (status === Loader.Error) console.warn("omatype-trainer Panel.qml failed to load")
  }
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "⌨"
    slotSize: Style.bar.iconSlot
    fontSize: Style.bar.iconFont
    tooltipText: "omatype-trainer — click to practise"
    onPressed: function(button) { root.togglePanel() }
    Rectangle {
      visible: panelLoader.item ? panelLoader.item.dueToday : true
      width: Style.space(6); height: width; radius: width / 2
      color: Color.urgent; anchors.right: parent.right; anchors.top: parent.top
    }
  }
}
