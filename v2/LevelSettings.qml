import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Column {
  id: root
  property var stats
  property int selectedStage: 0
  property int selectedCount: 6
  property bool applied: false
  readonly property var lists: [Model.LETTERS,Model.PATTERNS,Model.NUMBERS,Model.SYMBOLS,[]]
  readonly property var stageNames: ["Letters","Common patterns","Numbers","Punctuation & symbols","Mixed fluency"]
  readonly property int minimum: selectedStage===0 ? 6 : 1
  readonly property int maximum: lists[selectedStage].length
  signal levelSelected(int stage, int count)
  spacing: Style.space(14)
  function sync() {
    var info=Model.stageInfo(stats)
    selectedStage=Math.max(0,stageNames.indexOf(info.name))
    selectedCount=info.active.length
    applied=false
  }
  onVisibleChanged: if(visible && stats) sync()
  Component.onCompleted: if(stats) sync()
  Text { text: "SET YOUR PRACTICE LEVEL"; color: Color.foreground; font.pixelSize: Style.font.body }
  Text {
    width: parent.width
    text: "Already know more keys? Choose a stage and how many items to include. Earlier stages become available immediately; the trainer keeps working on your weaker keys from here."
    wrapMode: Text.WordWrap; color: Color.muted; font.pixelSize: Style.font.body
  }
  Flow {
    width: parent.width; spacing: Style.space(6)
    Repeater {
      model: ["Letters","Patterns","Numbers","Symbols","All keys"]
      delegate: WidgetButton {
        required property string modelData
        required property int index
        text: modelData; active: root.selectedStage===index
        onPressed: {
          root.selectedStage=index
          var fields=["unlockedLetters","unlockedPatterns","unlockedNumbers","unlockedSymbols"]
          root.selectedCount=index<4 ? Math.max(root.minimum,Number(root.stats[fields[index]])||root.minimum) : 0
          root.applied=false
        }
      }
    }
  }
  Row {
    visible: root.selectedStage<4
    spacing: Style.space(12)
    WidgetButton { text: "−"; interactive: root.selectedCount>root.minimum; dimmed: !interactive; onPressed: { root.selectedCount--; root.applied=false } }
    Text { text: root.selectedCount + " / " + root.maximum; color: Color.foreground; font.family: "monospace"; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
    WidgetButton { text: "+"; interactive: root.selectedCount<root.maximum; dimmed: !interactive; onPressed: { root.selectedCount++; root.applied=false } }
    WidgetButton { text: "Include all"; onPressed: { root.selectedCount=root.maximum;root.applied=false } }
  }
  Text {
    width: parent.width
    text: root.selectedStage===4 ? "All letters, patterns, numbers and symbols will be available." : (root.selectedStage>0 ? "All earlier stages, plus:\n" : "Included letters:\n") + root.lists[root.selectedStage].slice(0,root.selectedCount).join("  ")
    color: Color.accent; font.family: "monospace"; font.pixelSize: Style.font.body; wrapMode: Text.Wrap
  }
  Text { width: parent.width; text: "Applying replaces the current exercise. Your daily totals, accuracy history and key measurements are kept. Code mode continues to use all characters in its snippets."; wrapMode: Text.WordWrap; color: Color.muted; font.pixelSize: Style.font.caption }
  WidgetButton { text: root.applied ? "✓ Level applied" : "Apply level"; active: root.applied; onPressed: { root.levelSelected(root.selectedStage,root.selectedCount); root.applied=true } }
}
