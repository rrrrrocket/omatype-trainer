import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root
  property var stats
  property bool levelMode: false
  signal levelSelected(int stage, int count)
  signal settingChanged(string name, var value)
  signal previewSound(string name)
  spacing: Style.space(14)
  Text { text: "SETTINGS"; color: Color.foreground; font.pixelSize: Style.font.title }
  Text { width: parent.width; text: root.levelMode ? "Choose your starting point, then select Apply level." : "Saved automatically. Keyboard choices control this trainer’s preview and finger guidance."; wrapMode: Text.WordWrap; color: Color.muted; font.pixelSize: Style.font.caption }
  Row {
    spacing: Style.space(12)
    WidgetButton { text: "Appearance & sound"; active: !root.levelMode; onPressed: root.levelMode=false }
    WidgetButton { text: "Practice level"; active: root.levelMode; onPressed: root.levelMode=true }
  }
  LevelSettings {
    visible: root.levelMode
    width: parent.width
    stats: root.stats
    onLevelSelected: function(stage,count) { root.levelSelected(stage,count) }
  }
  Column {
    visible: !root.levelMode
    width: parent.width
    spacing: Style.space(14)
  Repeater {
    model: [
      {title:"KEYBOARD SIZE", key:"keyboardSize", choices:[{label:"60%",value:"60"},{label:"80% · TKL",value:"80"},{label:"90% · Compact",value:"90"},{label:"100% · Full",value:"100"}]},
      {title:"KEYBOARD LAYOUT", key:"keyboardLayout", choices:[{label:"US · ANSI",value:"us-ansi"},{label:"US · ISO",value:"us-iso"},{label:"UK · ISO",value:"uk-iso"}]},
      {title:"KEYBOARD COLOUR", key:"keyboardColor", choices:[{label:"Finger colours",value:"fingers"},{label:"Graphite",value:"#363b44"},{label:"Ivory",value:"#eee6d5"},{label:"Rose",value:"#d988a1"},{label:"Mint",value:"#8ec9ac"},{label:"Blue",value:"#80a8db"}]},
      {title:"SOUND THEME", key:"soundTheme", choices:[{label:"Classic",value:"classic"},{label:"Chiptune",value:"chiptune"},{label:"Laser",value:"laser"},{label:"Mechanical",value:"mechanical"},{label:"Bubble",value:"bubble"},{label:"Glass",value:"glass"},{label:"Marimba",value:"marimba"}]},
      {title:"CODE LANGUAGE", key:"codeLanguage", choices:[{label:"HTML",value:"html"},{label:"CSS",value:"css"},{label:"JavaScript",value:"javascript"},{label:"Python",value:"python"}]}
    ]
    delegate: Column {
      id: group
      required property var modelData
      width: root.width
      spacing: Style.space(4)
      Text { text: group.modelData.title; color: Color.muted; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
      Flow {
        width: parent.width
        spacing: Style.space(4)
        Repeater {
          model: group.modelData.choices
          delegate: WidgetButton {
            required property var modelData
            text: (root.stats[group.modelData.key]===modelData.value ? "● " : "○ ") + modelData.label
            active: root.stats[group.modelData.key]===modelData.value
            onPressed: root.settingChanged(group.modelData.key,modelData.value)
          }
        }
      }
    }
  }
  ColourPicker {
    width: parent.width
    selectedColor: root.stats.keyboardColor === "fingers" ? "#80a8db" : root.stats.keyboardColor
    onChosen: function(value) { root.settingChanged("keyboardColor",value) }
  }
  Flow {
    width: parent.width; spacing: Style.space(6)
    WidgetButton { text: root.stats.soundMuted ? "Unmute" : "Mute"; onPressed: root.settingChanged("soundMuted",!root.stats.soundMuted) }
    Repeater {
      model: [{label:"Test key",value:"key"},{label:"Test success",value:"body"},{label:"Test failure",value:"failure"},{label:"Test unlock",value:"unlock"}]
      delegate: WidgetButton {
        required property var modelData
        text: modelData.label; dimmed: root.stats.soundMuted; interactive: !root.stats.soundMuted
        onPressed: root.previewSound(modelData.value)
      }
    }
  }
  Text { width: parent.width; text: "Code mode uses the selected language immediately, including punctuation and capital letters. Turn it on from the practice screen."; wrapMode: Text.WordWrap; color: Color.muted; font.pixelSize: Style.font.caption }
  }
}
