import QtQuick
import qs.Commons

Item {
  id: root
  property color selectedColor: "#80a8db"
  property real hue: 0.58
  property real saturation: 0.4
  property real brightness: 0.85
  readonly property color previewColor: Qt.hsva(hue,saturation,brightness,1)
  signal chosen(string value)
  implicitHeight: Style.space(146)
  function sync() {
    if (shadeMouse.pressed || hueMouse.pressed) return
    if (selectedColor.hsvHue >= 0) hue=selectedColor.hsvHue
    saturation=selectedColor.hsvSaturation
    brightness=selectedColor.hsvValue
  }
  function setShade(x,y) {
    saturation=Math.max(0,Math.min(1,x/shade.width))
    brightness=1-Math.max(0,Math.min(1,y/shade.height))
  }
  function setHue(x) { hue=Math.max(0,Math.min(0.9999,x/spectrum.width)) }
  function commit() { chosen(previewColor.toString()) }
  onSelectedColorChanged: sync()
  Component.onCompleted: sync()
  Column {
    width: Math.min(root.width*0.6,Style.space(280))
    spacing: Style.space(10)
    Rectangle {
      id: shade
      width: parent.width; height: Style.space(104)
      color: Qt.hsva(root.hue,1,1,1)
      Rectangle {
        anchors.fill: parent
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0; color: "white" }
          GradientStop { position: 1; color: "transparent" }
        }
      }
      Rectangle {
        anchors.fill: parent
        gradient: Gradient {
          GradientStop { position: 0; color: "transparent" }
          GradientStop { position: 1; color: "black" }
        }
      }
      Rectangle {
        x: root.saturation*(parent.width-width); y: (1-root.brightness)*(parent.height-height)
        width: Style.space(10); height: width; radius: width/2
        color: "transparent"; border.color: "white"; border.width: 2
        Rectangle { anchors.fill: parent; anchors.margins: -1; radius: width/2; color: "transparent"; border.color: "#444444" }
      }
      MouseArea {
        id: shadeMouse
        anchors.fill: parent
        onPressed: function(mouse) { root.setShade(mouse.x,mouse.y) }
        onPositionChanged: function(mouse) { if (pressed) root.setShade(mouse.x,mouse.y) }
        onReleased: root.commit()
        onCanceled: root.sync()
      }
    }
    Rectangle {
      id: spectrum
      width: parent.width; height: Style.space(22); radius: Style.space(3)
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "#ff0000" }
        GradientStop { position: 0.167; color: "#ffff00" }
        GradientStop { position: 0.333; color: "#00ff00" }
        GradientStop { position: 0.5; color: "#00ffff" }
        GradientStop { position: 0.667; color: "#0000ff" }
        GradientStop { position: 0.833; color: "#ff00ff" }
        GradientStop { position: 1; color: "#ff0000" }
      }
      Rectangle {
        x: root.hue*(parent.width-width); width: Style.space(5); height: parent.height
        color: "transparent"; border.color: "white"; border.width: 2
      }
      MouseArea {
        id: hueMouse
        anchors.fill: parent
        onPressed: function(mouse) { root.setHue(mouse.x) }
        onPositionChanged: function(mouse) { if (pressed) root.setHue(mouse.x) }
        onReleased: root.commit()
        onCanceled: root.sync()
      }
    }
  }
  Column {
    x: Math.min(root.width*0.6,Style.space(280))+Style.space(16)
    width: Math.max(0,root.width-x)
    spacing: Style.space(8)
    Text { text: "Custom colour"; color: Color.foreground; font.pixelSize: Style.font.body }
    Rectangle { width: Style.space(48); height: width; radius: Style.space(6); color: root.previewColor; border.color: Color.muted }
    Text { width: parent.width; text: "Choose a hue below, then drag above for a lighter, darker or softer shade."; wrapMode: Text.WordWrap; color: Color.muted; font.pixelSize: Style.font.caption }
  }
}
