import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../Model.js" as Model
import "../Keyboard.js" as Keyboard

Panel {
  id: root
  moduleName: "io.github.rrrrrocket.omatype-trainer"
  ipcTarget: "io.github.rrrrrocket.omatype-trainer"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property var stats: Model.fresh()
  property bool sessionActive: false
  property bool finished: false
  property string sessionDay: ""
  property string today: Qt.formatDate(new Date(), "yyyy-MM-dd")
  property int accountedCorrect: 0
  property int accountedErrors: 0
  property int accountedMs: 0
  property bool sessionCounted: false
  property bool shortcutMode: false
  property bool progressMode: false
  property bool settingsMode: false
  property int shortcutIndex: 0
  property int shortcutReviewed: 0
  readonly property var shortcuts: [
    {group:"VIM", chord:"h  j  k  l", action:"Move left, down, up, right in Normal mode."},
    {group:"VIM", chord:"w  /  b", action:"Jump forward or backward by a word."},
    {group:"VIM", chord:"0  /  $", action:"Jump to the start or end of the line."},
    {group:"VIM", chord:"dd  /  yy  /  p", action:"Delete a line, yank a line, paste."},
    {group:"VIM", chord:"u  /  i  /  Esc", action:"Undo, enter Insert mode, return to Normal mode."},
    {group:"OMARCHY", chord:"Super + Space", action:"Open the Omarchy menu."},
    {group:"OMARCHY", chord:"Super + Enter", action:"Open a terminal."},
    {group:"OMARCHY", chord:"Super + Ctrl + V", action:"Open clipboard history."},
    {group:"OMARCHY", chord:"Super + Ctrl + E", action:"Open emoji picker."},
    {group:"OMARCHY", chord:"Super + Ctrl + R", action:"Set a reminder."},
    {group:"OMARCHY", chord:"Super + Shift + Space", action:"Toggle the top bar."}
  ]
  readonly property var keyboardRows: Keyboard.rows(stats.keyboardSize, stats.keyboardLayout)
  readonly property var unlockGroups: [
    {title:"LETTERS",kind:"letters",keys:"abcdefghijklmnopqrstuvwxyz".split("")},
    {title:"NUMBERS",kind:"numbers",keys:Model.NUMBERS},
    {title:"SYMBOLS",kind:"symbols",keys:Model.SYMBOLS}
  ]
  readonly property var practiceUnlockGroup: {
    var stage=Model.stageInfo(stats).name
    return stage==="Numbers" ? unlockGroups[1] : (stage==="Punctuation & symbols" ? unlockGroups[2] : unlockGroups[0])
  }
  property string lesson: ""
  property var lessonBreaks: []
  readonly property var unlockProgress: Model.unlockProgress(stats)
  FontMetrics { id: lessonMetrics; font.family: "monospace"; font.pixelSize: Style.space(38) }
  property int cursor: 0
  property var charStates: []
  property int correct: 0
  property int errors: 0
  property int bodyCorrect: 0
  property int bodyErrors: 0
  property int bodyStartMs: 0
  property var bodyFeedback: null
  property string unlockKey: ""
  property string unlockKind: "KEY"
  property string pendingSfx: ""
  property bool sfxStopping: false
  property int elapsed: 0
  property int activeMs: 0
  property double lastKeyAt: 0
  property double lastActivityAt: 0
  property date startedAt: new Date()
  property string typedKey: ""
  property real keyUnit: Math.min(Style.space(40), Math.max(1, (content.width - Style.space(24)) / Keyboard.widthUnits(keyboardRows)))
  property real unlockUnit: Math.min(Style.space(22), Math.max(Style.space(12), (content.width - Style.space(100) - Model.SYMBOLS.length * Style.space(3)) / Model.SYMBOLS.length))
  signal keyPressed(string code)
  readonly property bool dueToday: stats.lastDate !== today
  readonly property string target: lesson
  readonly property string focusText: cursor < target.length ? target.charAt(cursor) : ""
  readonly property string fingerText: fingerFor(focusText)
  readonly property int accuracy: correct + errors > 0 ? Math.round(100 * correct / (correct + errors)) : 100
  readonly property int wpm: elapsed > 0 ? Math.round(correct / 5 / (elapsed / 60)) : 0
  readonly property real sessionProgress: dueToday ? Math.min(1, activeMs / (Math.max(1, Number(stats.sessionMinutes || 5)) * 60000)) : 1
  readonly property string activeTimeText: Math.floor(activeMs / 60000) + ":" + ("0" + Math.floor((activeMs % 60000) / 1000)).slice(-2)
  readonly property string coach: Model.weakestSummary(stats)

  function dayString(date) { return Qt.formatDate(date, "yyyy-MM-dd") }
  function previousDay(day) {
    var date=new Date(Number(day.slice(0,4)),Number(day.slice(5,7))-1,Number(day.slice(8,10)),12)
    date.setDate(date.getDate()-1)
    return dayString(date)
  }
  function unlockCount(kind) {
    var stage=Model.stageInfo(stats).name
    if (kind==="letters") return Number(stats.unlockedLetters)||0
    if (kind==="numbers") return stage==="Numbers" || stage==="Punctuation & symbols" || stage==="Mixed fluency" ? Number(stats.unlockedNumbers)||0 : 0
    if (kind==="symbols") return stage==="Punctuation & symbols" || stage==="Mixed fluency" ? Number(stats.unlockedSymbols)||0 : 0
    return 0
  }
  function isUnlockedKey(kind,key) {
    var list=kind==="letters"?Model.LETTERS:(kind==="numbers"?Model.NUMBERS:Model.SYMBOLS)
    return list.indexOf(key)>=0 && list.indexOf(key)<unlockCount(kind)
  }
  function revealUnlock(kind,key) {
    unlockKind=kind
    unlockKey=key
    if (opened) {
      unlockAnimation.restart()
      playSfx("unlock")
    }
  }
  function startPendingSfx() {
    if (sfxStopping || !pendingSfx || stats.soundMuted) return
    sfxProcess.command=["pw-play",Quickshell.env("HOME")+"/.config/omarchy/plugins/io.github.rrrrrocket.omatype-trainer/assets/"+stats.soundTheme+"/"+pendingSfx+".wav"]
    pendingSfx=""
    sfxProcess.running=true
  }
  function playSfx(name) {
    if (stats.soundMuted) return
    pendingSfx=name
    if (sfxStopping) return
    if (sfxProcess.running) {
      sfxStopping=true
      sfxProcess.running=false
    } else startPendingSfx()
  }
  function toggleSound() {
    stats.soundMuted=!stats.soundMuted
    if (stats.soundMuted) {
      pendingSfx=""
      if (sfxProcess.running) { sfxStopping=true; sfxProcess.running=false }
    }
    persist()
  }

  function bodyChange(delta, unit) {
    if (!bodyFeedback || !bodyFeedback.hasPrevious) return ""
    if (delta > 0) return "  ↑ " + delta + unit
    if (delta < 0) return "  ↓ " + Math.abs(delta) + unit
    return "  ="
  }
  function bodyChangeColor(delta) {
    if (!bodyFeedback || !bodyFeedback.hasPrevious || delta === 0) return Color.muted
    return delta > 0 ? "#67a77d" : "#d16a70"
  }

  function lessonMarkup() {
    var out = ""
    var breaks=lessonBreaks.length ? lessonBreaks : Model.balancedBreaks(target)
    for (var i = 0; i < target.length; i++) {
      var ch = target.charAt(i)
      var state = charStates[i] || 0
      var color = state > 0 ? "#f4f5f7" : (state < 0 ? "#ef5964" : "#929ba6")
      var shown = breaks.indexOf(i)>=0 ? "␣" : ch === " " ? " " : ch.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      var token = "<font color=\"" + color + "\">" + shown + "</font>"
      if (i === cursor && !finished) token = "<u>" + token + "</u>"
      out += token + (breaks.indexOf(i)>=0 ? "<br>" : "")
    }
    return out
  }

  function fingerColor(ch) {
    if (stats.keyboardColor !== "fingers") return stats.keyboardColor
    if (ch === "LShift") return "#e06c75"
    if (ch === "RShift") return "#b879a5"
    var f=fingerFor(ch)
    if (f.indexOf("Left pinky")===0) return "#d76b70"
    if (f.indexOf("Left ring")===0) return "#d28a55"
    if (f.indexOf("Left middle")===0) return "#c7b45a"
    if (f.indexOf("Left index")===0) return "#7ea265"
    if (f.indexOf("Right index")===0) return "#5d9b8b"
    if (f.indexOf("Right middle")===0) return "#6486b5"
    if (f.indexOf("Right ring")===0) return "#8877b6"
    if (f.indexOf("Right pinky")===0) return "#b879a5"
    if (f.indexOf("Thumb")===0) return "#9aa5ae"
    return Color.muted
  }
  function heatColor(code) {
    if (!code) return "transparent"
    if (code==="tab" || code==="caps" || code==="backspace" || code==="enter" || code==="LShift" || code==="RShift") return "#282d35"
    var shifted=Keyboard.shifted(stats.keyboardLayout)
    var item=stats.keys[code], pair=stats.keys[shifted[code]]
    if ((!item || !item.total) && (!pair || !pair.total)) return "#603b42"
    var score=item && item.total ? Model.confidence(item) : 1
    if (pair && pair.total) score=Math.min(score,Model.confidence(pair))
    if (score>=1 && (!item || Model.mastered(item)) && (!pair || Model.mastered(pair))) return "#67a77d"
    if (score>=0.75) return "#b9a467"
    return "#d16a70"
  }
  function physicalKey(ch) { return Keyboard.physical(ch,stats.keyboardLayout) }
  function isShifted(ch) { return Keyboard.isShifted(ch,stats.keyboardLayout) }
  function fingerFor(ch) {
    var key=physicalKey(ch)
    if (key==="#" && stats.keyboardLayout==="uk-iso") return "Right pinky"
    if (key==="\\" && stats.keyboardLayout==="uk-iso" || key==="<" && stats.keyboardLayout==="us-iso") return "Left pinky"
    return Model.fingerFor(key)
  }
  function shiftSide(ch) { return fingerFor(ch).indexOf("Left ")===0 ? "RShift" : "LShift" }
  function refocus() {
    Qt.callLater(function() {
      if (settingsMode) settingsPage.forceActiveFocus()
      else if (shortcutMode) shortcutCatcher.forceActiveFocus()
      else if (progressMode) progressCatcher.forceActiveFocus()
      else typingCatcher.forceActiveFocus()
    })
  }
  function toggleSettings() {
    settingsMode=!settingsMode
    lastActivityAt=0; lastKeyAt=0
    if (settingsMode) tick.stop()
    else if (sessionActive && !progressMode && !shortcutMode) tick.start()
    refocus()
  }
  function setSetting(name,value) {
    if (stats[name]===value) return
    checkDayBoundary()
    if (name==="soundMuted" && value) {
      pendingSfx=""
      if (sfxProcess.running) { sfxStopping=true; sfxProcess.running=false }
    }
    stats[name]=value
    stats=Model.normalize(stats)
    if (name==="codeMode" || name==="codeLanguage" && stats.codeMode) {
      bodyCorrect=0; bodyErrors=0; bodyStartMs=activeMs; bodyFeedback=null
      lastActivityAt=0; lastKeyAt=0
      prepareLesson()
    }
    persist()
    if (!settingsMode) refocus()
  }
  function setPracticeLevel(stage,count) {
    checkDayBoundary()
    Model.setPracticeLevel(stats,stage,count)
    stats=Model.normalize(stats)
    bodyCorrect=0; bodyErrors=0; bodyStartMs=activeMs; bodyFeedback=null
    lastActivityAt=0; lastKeyAt=0
    prepareLesson()
    persist()
  }
  function capHighlighted(code) {
    var focus=root.sessionActive?root.focusText:String(root.stats.activeKey||"e")
    return code===physicalKey(focus) || ((isShifted(focus) || (focus >= "A" && focus <= "Z")) && code===shiftSide(focus))
  }

  function prepareLesson() {
    var block=Model.nextPracticeBlock(stats, Math.floor(Math.max(560,content.width-24)/lessonMetrics.advanceWidth("M")))
    lessonBreaks=block.breaks
    lesson=block.text
    stats.activeKey = Model.currentKey(stats)
    cursor = 0
    charStates = []
    finished = false
  }
  function open() {
    checkDayBoundary()
    if (!lesson) prepareLesson()
    controller.show()
    if (sessionActive && !shortcutMode && !progressMode && !settingsMode) tick.start()
    refocus()
  }
  function close() { checkDayBoundary(); tick.stop(); lastActivityAt=0; lastKeyAt=0; persist(); controller.hide() }
  function toggle() { opened ? close() : open() }
  function begin() {
    if (!lesson || finished) prepareLesson()
    charStates = []
    stats.activeKey = Model.currentKey(stats)
    sessionDay=dayString(new Date())
    cursor = 0; correct = 0; errors = 0; bodyCorrect = 0; bodyErrors = 0; bodyStartMs = 0; bodyFeedback = null; elapsed = 0; activeMs = 0; lastActivityAt = 0; finished = false; sessionActive = true; startedAt = new Date()
    accountedCorrect=0; accountedErrors=0; accountedMs=0; sessionCounted=false
    var prior=stats.lastSession
    if (prior && !prior.day && prior.finishedAt && dayString(new Date(prior.finishedAt))===sessionDay) {
      correct=Number(prior.correct)||0
      errors=Number(prior.errors)||0
      activeMs=Number(prior.activeMs)||0
      elapsed=Math.floor(activeMs/1000)
      bodyStartMs=activeMs
      accountedCorrect=correct
      accountedErrors=errors
      accountedMs=activeMs
      sessionCounted=true
    }
    lastKeyAt = 0
    Qt.callLater(function() { typingCatcher.forceActiveFocus() })
    tick.start()
  }
  function handleTypingKey(ch) {
    if (shortcutMode || progressMode || settingsMode || !ch) return
    checkDayBoundary()
    if (!sessionActive) begin()
    record(ch)
  }
  function record(ch) {
    if (!sessionActive || !ch) return
    var stageBefore=Model.stageInfo(stats)
    var countBefore=stageBefore.active.length
    var physical = physicalKey(ch)
    keyPressed(physical)
    if (isShifted(ch) || (ch >= "A" && ch <= "Z")) keyPressed(shiftSide(physical))
    var expected = stats.codeMode ? target.charAt(cursor) : target.charAt(cursor).toLowerCase()
    var actual = stats.codeMode ? ch : ch.toLowerCase(), key = expected
    playSfx(actual === expected ? "key" : "failure")
    var now=Date.now(), gap=Math.max(90,Math.min(5000,now-(lastKeyAt||now))); lastKeyAt=now; lastActivityAt=now
    var item = stats.keys[key] || {correct:0,total:0,avgMs:0,timeSamples:0}; item.total++
    item.avgMs=item.avgMs ? item.avgMs*0.8+gap*0.2 : gap
    item.timeSamples=Number(item.timeSamples||0)+1
    var nextStates = charStates.slice()
    if (actual === expected) { correct++; bodyCorrect++; item.correct++; nextStates[cursor] = nextStates[cursor] < 0 ? -1 : 1 }
    else { errors++; bodyErrors++; nextStates[cursor] = -1 }
    charStates = nextStates
    stats.keys[key] = item
    for (var i=0; i<Model.PATTERNS.length; i++) {
      var p = Model.PATTERNS[i]
      if (cursor >= p.length-1 && target.substr(cursor-p.length+1,p.length).toLowerCase() === p) {
        var pi=stats.patterns[p]||{correct:0,total:0,avgMs:0,timeSamples:0}; pi.total++
        pi.avgMs=pi.avgMs ? pi.avgMs*0.8+gap*0.2 : gap; pi.timeSamples=Number(pi.timeSamples||0)+1
        if (actual === expected) pi.correct++
        stats.patterns[p]=pi
      }
    }
    if (actual === expected) cursor++
    Model.advanceProgress(stats)
    var stageAfter=Model.stageInfo(stats)
    var unlockedThisKey=false
    if (stageAfter.name!==stageBefore.name && stageAfter.active.length>0) {
      revealUnlock(stageAfter.kind==="pattern"?"PATTERN":"KEY",stageAfter.active[0])
      unlockedThisKey=true
    } else if (stageAfter.name===stageBefore.name && stageAfter.active.length>countBefore) {
      revealUnlock(stageAfter.kind==="pattern"?"PATTERN":"KEY",stageAfter.active[stageAfter.active.length-1])
      unlockedThisKey=true
    }
    stats.activeKey = Model.currentKey(stats)
    typedKey = ch
    if (cursor >= target.length) {
      if (!unlockedThisKey) playSfx("body")
      completeBody()
      prepareLesson()
    }
    persist()
  }
  function completeBody() {
    var attempts=bodyCorrect+bodyErrors
    var result={
      accuracy:attempts>0 ? Math.round(100*bodyCorrect/attempts) : 100,
      wpm:Math.round(bodyCorrect/5/(Math.max(1000,activeMs-bodyStartMs)/60000)),
      finishedAt:new Date().toISOString()
    }
    var previous=stats.lastBody
    bodyFeedback={
      accuracy:result.accuracy,
      wpm:result.wpm,
      accuracyDelta:previous ? result.accuracy-Number(previous.accuracy||0) : 0,
      wpmDelta:previous ? result.wpm-Number(previous.wpm||0) : 0,
      hasPrevious:!!previous
    }
    stats.lastBody=result
    stats.lastBodyFeedback=bodyFeedback
    bodyCorrect=0
    bodyErrors=0
    bodyStartMs=activeMs
    lastActivityAt=0
    lastKeyAt=0
  }
  function markDailyGoal() {
    if (!sessionActive || !sessionDay || stats.lastDate===sessionDay || activeMs<Number(stats.sessionMinutes||5)*60000) return
    stats.streak=stats.lastDate===previousDay(sessionDay) ? Number(stats.streak||0)+1 : 1
    stats.lastDate=sessionDay
    persist()
  }
  function checkDayBoundary() {
    today=dayString(new Date())
    if (sessionActive && sessionDay && sessionDay!==today) finalizeDay()
  }
  function finalizeDay() {
    if (!sessionActive) return
    markDailyGoal()
    tick.stop()
    var completedDay=sessionDay
    if (correct+errors>0) {
      var dayEnd=new Date(Number(completedDay.slice(0,4)),Number(completedDay.slice(5,7))-1,Number(completedDay.slice(8,10))+1)
      stats.lastSession={day:completedDay,accuracy:accuracy,wpm:wpm,correct:correct,errors:errors,activeMs:activeMs,goalMet:stats.lastDate===completedDay,finishedAt:dayEnd.toISOString()}
      if (!sessionCounted) stats.sessions=Number(stats.sessions||0)+1
      stats.totalChars=Number(stats.totalChars||0)+Math.max(0,correct+errors-accountedCorrect-accountedErrors)
      stats.correctChars=Number(stats.correctChars||0)+Math.max(0,correct-accountedCorrect)
      stats.totalMs=Number(stats.totalMs||0)+Math.max(0,activeMs-accountedMs)
      stats.bestWpm=Math.max(Number(stats.bestWpm||0),wpm)
    }
    var active=String(stats.activeKey||"f")
    if (correct+errors>0 && active.length === 1) {
      var keyStats=stats.keys[active]||{correct:0,total:0,lastWpm:0}
      keyStats.lastWpm=wpm
      stats.keys[active]=keyStats
    } else if (correct+errors>0 && Model.PATTERNS.indexOf(active) >= 0) {
      var patternStats=stats.patterns[active]||{correct:0,total:0,lastWpm:0}
      patternStats.lastWpm=wpm
      stats.patterns[active]=patternStats
    }
    sessionActive=false
    sessionDay=""
    finished=false
    lastActivityAt=0
    lastKeyAt=0
    persist()
    prepareLesson()
  }
  function persist() {
    stats.sessionDraft=sessionActive ? {sessionDay:sessionDay,lesson:lesson,lessonBreaks:lessonBreaks,cursor:cursor,charStates:charStates,correct:correct,errors:errors,bodyCorrect:bodyCorrect,bodyErrors:bodyErrors,bodyStartMs:bodyStartMs,bodyFeedback:bodyFeedback,activeMs:activeMs,startedAt:startedAt.toISOString(),accountedCorrect:accountedCorrect,accountedErrors:accountedErrors,accountedMs:accountedMs,sessionCounted:sessionCounted} : null
    stats=JSON.parse(JSON.stringify(stats))
    saveFile.setText(JSON.stringify(stats,null,2)+"\n")
  }
  function restoreDraft() {
    var draft=stats.sessionDraft
    if (!draft || !draft.lesson) { bodyFeedback=stats.lastBodyFeedback||null; prepareLesson(); return }
    lessonBreaks=draft.lessonBreaks || Model.balancedBreaks(String(draft.lesson))
    lesson=String(draft.lesson)
    cursor=Math.max(0,Math.min(lesson.length-1,Number(draft.cursor)||0))
    charStates=draft.charStates||[]
    correct=Number(draft.correct)||0
    errors=Number(draft.errors)||0
    activeMs=Number(draft.activeMs)||0
    bodyCorrect=draft.bodyCorrect===undefined ? cursor : Number(draft.bodyCorrect)||0
    bodyErrors=draft.bodyErrors===undefined ? Math.round(errors*cursor/Math.max(1,correct)) : Number(draft.bodyErrors)||0
    bodyStartMs=draft.bodyStartMs===undefined ? Math.max(0,activeMs-Math.round(activeMs*cursor/Math.max(1,correct))) : Number(draft.bodyStartMs)||0
    bodyFeedback=draft.bodyFeedback||stats.lastBodyFeedback||null
    elapsed=Math.floor(activeMs/1000)
    startedAt=new Date(draft.startedAt||Date.now())
    sessionDay=String(draft.sessionDay||dayString(startedAt))
    accountedCorrect=Number(draft.accountedCorrect)||0
    accountedErrors=Number(draft.accountedErrors)||0
    accountedMs=Number(draft.accountedMs)||0
    sessionCounted=!!draft.sessionCounted
    lastActivityAt=0
    sessionActive=true
    finished=false
  }
  function setMinutes(delta) { stats.sessionMinutes=Math.max(1,Math.min(30,Number(stats.sessionMinutes||5)+delta)); markDailyGoal(); persist() }
  Component.onCompleted: loadFile.reload()
  FileView {
    id: loadFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/typing-trainer.json"
    printErrors: false
    onLoaded: { try { root.stats=Model.normalize(JSON.parse(text())); root.shortcutReviewed=Number(root.stats.shortcutReviewed)||0 } catch(e) { root.stats=Model.fresh() }; if (!root.sessionActive) root.restoreDraft(); root.checkDayBoundary(); root.persist() }
    onLoadFailed: { root.stats=Model.fresh(); if (!root.sessionActive) root.prepareLesson() }
  }
  FileView { id: saveFile; path: Quickshell.env("HOME") + "/.local/state/omarchy/typing-trainer.json"; atomicWrites: true; printErrors: false }
  Process {
    id: sfxProcess
    onExited: {
      root.sfxStopping=false
      root.startPendingSfx()
    }
  }
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      if (root.today!==root.dayString(new Date())) root.checkDayBoundary()
    }
  }
  Timer {
    id: tick
    interval: 250
    repeat: true
    onTriggered: {
      root.checkDayBoundary()
      if (!root.sessionActive) return
      if (root.lastActivityAt > 0 && Date.now() - root.lastActivityAt <= 2000) {
        root.activeMs += interval
        root.elapsed = Math.floor(root.activeMs / 1000)
        if (root.activeMs % 1000 === 0) root.persist()
      }
      root.markDailyGoal()
    }
  }
  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: root.settingsMode ? settingsPage : root.shortcutMode ? shortcutCatcher : (root.progressMode ? progressCatcher : typingCatcher)
    contentWidth: fittedContentWidth(Style.space(1080))
    contentHeight: popup.screenH > 0
      ? Math.min(Math.max(content.implicitHeight + popup.verticalContentInset + Style.space(56), Style.space(800)), popup.screenH - Style.space(48))
      : Math.max(content.implicitHeight + popup.verticalContentInset + Style.space(56), Style.space(800))
    gap: Math.max(0, Math.round((popup.screenH - contentHeight) / 2 - popup.barH))
    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: true
      Column {
        id: content
        width: Math.max(0, parent.width - Style.space(96))
        anchors.top: parent.top
        anchors.topMargin: Style.space(28)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(root.progressMode ? 12 : 20)
        Flow {
          width: parent.width
          spacing: Style.space(10)
          Text { text: "omatype-trainer"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.letterSpacing: 1.2; verticalAlignment: Text.AlignVCenter }
          Text { visible: !root.settingsMode; text: root.dueToday ? "TODAY DUE" : "TODAY DONE"; color: root.dueToday ? Color.urgent : Color.muted; font.pixelSize: Style.font.caption }
          WidgetButton { visible: !root.settingsMode && !root.shortcutMode; text: root.progressMode ? "⌨ Practice" : "▤ Progress"; tooltipText: root.progressMode ? "Return to practice" : "View saved progress"; onPressed: { root.progressMode=!root.progressMode; root.lastActivityAt=0; if (root.progressMode) { tick.stop(); progressCatcher.forceActiveFocus() } else { if (root.sessionActive) tick.start(); Qt.callLater(function(){typingCatcher.forceActiveFocus()}) } } }
          WidgetButton { visible: !root.settingsMode; text: root.shortcutMode ? (root.progressMode ? "▤ Progress" : "⌨ Practice") : "⌘ Shortcuts"; tooltipText: root.shortcutMode ? "Return to previous page" : "Shortcut practice"; onPressed: { root.shortcutMode = !root.shortcutMode; if (root.shortcutMode) { tick.stop(); root.lastActivityAt=0; root.lastKeyAt=0; shortcutCatcher.forceActiveFocus() } else { if (root.sessionActive && !root.progressMode) tick.start(); Qt.callLater(function(){if (root.progressMode) progressCatcher.forceActiveFocus(); else typingCatcher.forceActiveFocus()}) } } }
          WidgetButton { visible: !root.settingsMode; text: root.stats.soundMuted ? "♪ Muted" : "♫ Sound"; tooltipText: root.stats.soundMuted ? "Turn typing sounds on" : "Mute typing sounds"; onPressed: { root.toggleSound(); Qt.callLater(function(){ if (root.shortcutMode) shortcutCatcher.forceActiveFocus(); else if (root.progressMode) progressCatcher.forceActiveFocus(); else typingCatcher.forceActiveFocus() }) } }
          WidgetButton { text: root.settingsMode ? "Done" : "⚙ Settings"; onPressed: root.toggleSettings() }
        }
        Settings {
          id: settingsPage
          visible: root.settingsMode
          width: parent.width
          stats: root.stats
          onSettingChanged: function(name,value) { root.setSetting(name,value) }
          onPreviewSound: function(name) { root.playSfx(name) }
          onLevelSelected: function(stage,count) { root.setPracticeLevel(stage,count) }
          Keys.onEscapePressed: root.toggleSettings()
        }
        Row {
          visible: !root.settingsMode && !root.shortcutMode && !root.progressMode
          spacing: Style.space(8)
          WidgetButton { text: "Code mode " + (root.stats.codeMode ? "●" : "○"); active: root.stats.codeMode; tooltipText: "Practise code in your chosen language"; onPressed: root.setSetting("codeMode",!root.stats.codeMode) }
          Text { text: "DAILY GOAL"; color: Color.muted; font.pixelSize: Style.font.caption; verticalAlignment: Text.AlignVCenter }
          WidgetButton { text: "−"; tooltipText: "Shorter session"; onPressed: root.setMinutes(-1) }
          Text { text: root.stats.sessionMinutes + " min"; color: Color.foreground; font.pixelSize: Style.font.body; verticalAlignment: Text.AlignVCenter }
          WidgetButton { text: "+"; tooltipText: "Longer session"; onPressed: root.setMinutes(1) }
          Item { width: Style.space(24); height: 1 }
          Text { text: root.dueToday ? ("ACTIVE  " + root.activeTimeText + " / " + root.stats.sessionMinutes + ":00") : (root.sessionActive ? "GOAL MET  ·  " + root.activeTimeText + " active" : "GOAL MET  ·  keep going"); color: Color.foreground; font.family: "monospace"; font.pixelSize: Style.font.caption; verticalAlignment: Text.AlignVCenter }
        }
        Rectangle {
          visible: !root.settingsMode && !root.shortcutMode && !root.progressMode
          width: parent.width; height: Style.space(6); radius: height / 2
          color: "#303640"
          Rectangle { width: parent.width * root.sessionProgress; height: parent.height; radius: parent.radius; color: Color.accent }
        }
        Column {
          visible: !root.settingsMode && !root.shortcutMode
          width: parent.width
          spacing: Style.space(root.progressMode ? 12 : 14)
          Text {
            id: lessonText
            visible: !root.progressMode
            width: parent.width
            height: Style.space(190)
            textFormat: Text.StyledText
            text: root.target ? root.lessonMarkup() : "A little daily practice builds accuracy, rhythm and confidence."
            wrapMode: Text.NoWrap
            fontSizeMode: Text.Fit
            minimumPixelSize: 8
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Color.foreground
            font.family: "monospace"
            font.pixelSize: Style.space(38)
          }
          Text { visible: !root.progressMode; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.sessionActive ? "“" + (root.focusText === " " ? "SPACE" : root.focusText) + "”  ·  " + root.fingerText : "Type the underlined character to begin"; color: Color.accent; font.pixelSize: Style.font.body; wrapMode: Text.WordWrap }
          Row {
            visible: !root.progressMode
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(3)
            Text { width: Style.space(82); height: Style.space(24); verticalAlignment: Text.AlignVCenter; text: root.practiceUnlockGroup.title + " " + root.unlockCount(root.practiceUnlockGroup.kind) + "/" + root.practiceUnlockGroup.keys.length; color: Color.muted; font.pixelSize: Style.font.caption }
            Repeater {
              model: root.practiceUnlockGroup.keys
              delegate: Rectangle {
                required property var modelData
                property string keyLabel: String(modelData)
                property bool unlocked: root.isUnlockedKey(root.practiceUnlockGroup.kind,keyLabel)
                width: root.unlockUnit; height: Style.space(24); radius: Style.space(2)
                color: unlocked ? "#345e46" : "#303640"
                border.width: Style.space(1)
                border.color: unlocked ? "#67a77d" : "#67717d"
                Text { anchors.centerIn: parent; text: parent.keyLabel; color: parent.unlocked ? "#d8f1df" : "#a5adb6"; font.family: "monospace"; font.pixelSize: Style.font.caption; fontSizeMode: Text.Fit; minimumPixelSize: 8 }
              }
            }
          }
          Column {
            visible: !root.progressMode
            width: parent.width
            spacing: Style.space(5)
            Text {
              width: parent.width
              text: "NEXT UNLOCK  “" + root.unlockProgress.next + "”  ·  " + root.unlockProgress.percent + "%"
              color: Color.accent; font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
              width: parent.width; height: Style.space(7); radius: height/2; color: "#303640"
              Rectangle { width: parent.width*root.unlockProgress.value; height: parent.height; radius: parent.radius; color: Color.accent; Behavior on width { NumberAnimation { duration: 180 } } }
            }
            Text { width: parent.width; text: root.unlockProgress.detail; color: Color.muted; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
          }
          Column {
            visible: root.progressMode
            width: parent.width
            spacing: Style.space(8)
            Text { visible: root.sessionActive; text: "TODAY IN PROGRESS  ·  " + root.activeTimeText + " active  ·  " + root.accuracy + "% accuracy  ·  " + root.wpm + " WPM"; color: Color.accent; font.pixelSize: Style.font.body }
            Text { text: root.stats.lastSession ? "LAST COMPLETED SESSION" : "PROGRESS"; color: Color.muted; font.pixelSize: Style.font.caption; font.letterSpacing: 1.2 }
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(48)
              Column {
                Text { text: root.stats.lastSession ? root.stats.lastSession.accuracy + "%" : "—"; color: Color.foreground; font.pixelSize: Style.space(40); font.family: "monospace"; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "ACCURACY"; color: Color.muted; font.pixelSize: Style.font.caption; anchors.horizontalCenter: parent.horizontalCenter }
              }
              Column {
                Text { text: root.stats.lastSession ? root.stats.lastSession.wpm : "—"; color: Color.foreground; font.pixelSize: Style.space(40); font.family: "monospace"; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "WPM"; color: Color.muted; font.pixelSize: Style.font.caption; anchors.horizontalCenter: parent.horizontalCenter }
              }
            }
            Text { text: root.stats.lastSession ? ((root.stats.lastSession.day ? "Day " + root.stats.lastSession.day : "Completed " + Qt.formatDateTime(new Date(root.stats.lastSession.finishedAt), "d MMM yyyy · h:mm AP")) + " · " + Math.floor(root.stats.lastSession.activeMs / 60000) + "m " + Math.floor((root.stats.lastSession.activeMs % 60000) / 1000) + "s active" + (root.stats.lastSession.day ? (root.stats.lastSession.goalMet ? " · goal met" : " · below daily goal") : "")) : "Your first day's score appears here after midnight. Keep typing as long as you like."; color: Color.muted; font.pixelSize: Style.font.caption }
            Text { text: Number(root.stats.streak||0) + " day streak  ·  best " + Number(root.stats.bestWpm||0) + " WPM"; color: Color.muted; font.pixelSize: Style.font.caption }
            Column {
              width: parent.width
              spacing: Style.space(5)
              Text { text: "KEY UNLOCKS  ·  GREEN AVAILABLE  ·  GREY LOCKED"; color: Color.foreground; font.pixelSize: Style.font.caption; font.letterSpacing: 1.1 }
              Repeater {
                model: root.unlockGroups
                delegate: Row {
                  id: unlockRow
                  required property var modelData
                  property var group: modelData
                  spacing: Style.space(3)
                  Text { width: Style.space(82); height: Style.space(24); verticalAlignment: Text.AlignVCenter; text: unlockRow.group.title + " " + root.unlockCount(unlockRow.group.kind) + "/" + unlockRow.group.keys.length; color: Color.muted; font.pixelSize: Style.font.caption }
                  Repeater {
                    model: unlockRow.group.keys
                    delegate: Rectangle {
                      required property var modelData
                      property string keyLabel: String(modelData)
                      property bool unlocked: root.isUnlockedKey(unlockRow.group.kind,keyLabel)
                      width: root.unlockUnit; height: Style.space(24); radius: Style.space(2)
                      color: unlocked ? "#345e46" : "#303640"
                      border.width: Style.space(1)
                      border.color: unlocked ? "#67a77d" : "#67717d"
                      Text { anchors.centerIn: parent; text: parent.keyLabel; color: parent.unlocked ? "#d8f1df" : "#a5adb6"; font.family: "monospace"; font.pixelSize: Style.font.caption; fontSizeMode: Text.Fit; minimumPixelSize: 8 }
                    }
                  }
                }
              }
            }
            Text { text: "KEY CONFIDENCE"; color: Color.foreground; font.pixelSize: Style.font.body; font.letterSpacing: 1.2 }
            Text { text: "Green confident   ·   Amber improving   ·   Red needs practice   ·   Dark red not measured"; color: Color.muted; font.pixelSize: Style.font.caption }
          }
          Rectangle {
            width: keyboardLayout.implicitWidth + Style.space(20)
            height: keyboardLayout.implicitHeight + Style.space(20)
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Style.cornerRadius
            color: "transparent"
            border.width: Style.space(2)
            border.color: root.stats.keyboardColor === "fingers" ? "#db5964" : root.stats.keyboardColor
            Column {
              id: keyboardLayout
              anchors.centerIn: parent
              spacing: root.keyUnit * 0.15
              Repeater {
                model: root.keyboardRows
                delegate: Row {
                  required property var modelData
                  height: root.keyUnit * 1.12
                  spacing: root.keyUnit * 0.13
                  Repeater {
                    model: modelData
                    delegate: Rectangle {
                      id: cap
                      required property var modelData
                      property var spec: modelData
                      property bool flashing: false
                      width: root.keyUnit * Number(spec[2]||1); height: root.keyUnit * (spec[3] || 1.12); z: spec[3] ? 1 : 0; radius: Style.space(3)
                      color: spec[0] === "" ? "transparent" : (spec[1] ? (root.progressMode ? root.heatColor(spec[1]) : root.fingerColor(spec[1])) : (root.stats.keyboardColor === "fingers" ? "#282d35" : root.stats.keyboardColor))
                      border.width: flashing || (!root.progressMode && spec[1] && root.capHighlighted(spec[1])) ? Style.space(2) : Style.space(1)
                      border.color: flashing || (!root.progressMode && spec[1] && root.capHighlighted(spec[1])) ? Color.foreground : (spec[1] ? "#e2dce3" : (spec[0] === "" ? "transparent" : "#bf6069"))
                      Text { anchors.centerIn: parent; width: parent.width - Style.space(4); horizontalAlignment: Text.AlignHCenter; text: cap.spec[0]; color: Qt.colorEqual(cap.color,"transparent") ? Color.foreground : (0.299*cap.color.r+0.587*cap.color.g+0.114*cap.color.b > 0.53 ? "#15191e" : "#ffffff"); font.family: "monospace"; font.pixelSize: Math.max(Style.font.caption, root.keyUnit * 0.38); minimumPixelSize: 7; fontSizeMode: Text.Fit }
                      SequentialAnimation {
                        id: pressPulse
                        NumberAnimation { target: cap; property: "scale"; to: 0.94; duration: 60 }
                        NumberAnimation { target: cap; property: "scale"; to: 1; duration: 110 }
                      }
                      Timer { id: flashTimer; interval: 170; onTriggered: cap.flashing = false }
                      Connections {
                        target: root
                        function onKeyPressed(code) {
                          if (code === cap.spec[1]) {
                            cap.flashing = true
                            pressPulse.restart()
                            flashTimer.restart()
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        Rectangle {
          visible: !root.settingsMode && root.shortcutMode
          width: parent.width; height: Style.space(126); radius: Style.cornerRadius; color: Color.muted
          Column {
            anchors.fill: parent; anchors.margins: Style.space(14); spacing: Style.space(8)
            Text { text: root.shortcuts[root.shortcutIndex].group + " SHORTCUT · " + (root.shortcutIndex+1) + "/" + root.shortcuts.length; color: Color.foreground; font.pixelSize: Style.font.caption; font.letterSpacing: 1.2 }
            Text { text: root.shortcuts[root.shortcutIndex].chord; color: Color.accent; font.family: "monospace"; font.pixelSize: Style.font.title }
            Text { width: parent.width; text: root.shortcuts[root.shortcutIndex].action; wrapMode: Text.Wrap; color: Color.foreground; font.pixelSize: Style.font.body }
          }
        }
        Row {
          visible: !root.settingsMode && !root.shortcutMode && !root.progressMode
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(36)
          Text { text: "ACCURACY  " + root.accuracy + "%"; color: Color.foreground; font.pixelSize: Style.font.body }
          Text { text: root.wpm + " WPM"; color: Color.foreground; font.pixelSize: Style.font.body }
        }
        Row {
          visible: !root.settingsMode && !root.shortcutMode && !root.progressMode && !!root.bodyFeedback
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(24)
          Text { text: root.bodyFeedback && root.bodyFeedback.hasPrevious ? "LAST TEXT VS PREVIOUS" : "FIRST TEXT"; color: Color.muted; font.pixelSize: Style.font.caption }
          Text { text: root.bodyFeedback ? root.bodyFeedback.accuracy + "% accuracy" + root.bodyChange(root.bodyFeedback.accuracyDelta, " pp") : ""; color: root.bodyFeedback ? root.bodyChangeColor(root.bodyFeedback.accuracyDelta) : Color.muted; font.pixelSize: Style.font.body }
          Text { text: root.bodyFeedback ? root.bodyFeedback.wpm + " WPM" + root.bodyChange(root.bodyFeedback.wpmDelta, "") : ""; color: root.bodyFeedback ? root.bodyChangeColor(root.bodyFeedback.wpmDelta) : Color.muted; font.pixelSize: Style.font.body }
        }
        Text { visible: !root.settingsMode && !root.shortcutMode; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.coach; wrapMode: Text.WordWrap; color: Color.muted; font.pixelSize: Style.font.caption }
        Text { visible: !root.settingsMode && root.progressMode && !root.shortcutMode; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Saved locally · today's unfinished practice resumes when you return."; wrapMode: Text.WordWrap; color: Color.muted; font.pixelSize: Style.font.caption }
        Row {
          visible: !root.settingsMode && root.shortcutMode
          spacing: Style.space(10)
          WidgetButton { text: "Previous"; tooltipText: "Previous shortcut"; onPressed: root.shortcutIndex=(root.shortcutIndex+root.shortcuts.length-1)%root.shortcuts.length }
          WidgetButton { text: "Practised"; tooltipText: "Mark this shortcut practised"; onPressed: { root.shortcutReviewed++; root.shortcutIndex=(root.shortcutIndex+1)%root.shortcuts.length; root.stats.shortcutReviewed=root.shortcutReviewed; root.persist() } }
          WidgetButton { text: "Next"; tooltipText: "Next shortcut"; onPressed: root.shortcutIndex=(root.shortcutIndex+1)%root.shortcuts.length }
          Text { text: "Review these in a terminal or editor, then mark each one practised."; color: Color.foreground; font.pixelSize: Style.font.caption; verticalAlignment: Text.AlignVCenter }
        }
        Item {
          id: typingCatcher
          visible: !root.settingsMode && !root.shortcutMode && !root.progressMode
          width: 1; height: 1; focus: !root.settingsMode && !root.shortcutMode && !root.progressMode
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.close(); event.accepted=true; return }
            if (event.text && event.text.length === 1) { root.handleTypingKey(event.text); event.accepted=true }
          }
        }
        Item {
          id: progressCatcher
          visible: !root.settingsMode && root.progressMode && !root.shortcutMode
          width: 1; height: 1; focus: !root.settingsMode && root.progressMode && !root.shortcutMode
          Keys.onPressed: function(event) { if (event.key === Qt.Key_Escape) { root.close(); event.accepted=true } }
        }
        Item {
          id: shortcutCatcher
          visible: !root.settingsMode && root.shortcutMode
          width: 1; height: 1; focus: !root.settingsMode && root.shortcutMode
          Keys.onPressed: function(event) { if (event.key === Qt.Key_Escape) { root.shortcutMode=false; if (root.sessionActive && !root.progressMode) tick.start(); Qt.callLater(function(){if (root.progressMode) progressCatcher.forceActiveFocus(); else typingCatcher.forceActiveFocus()}); event.accepted=true } }
        }
      }
      Rectangle {
        id: unlockToast
        z: 10
        anchors.centerIn: parent
        width: Style.space(230)
        height: Style.space(154)
        radius: Style.cornerRadius
        color: "#19231e"
        border.color: "#67a77d"
        border.width: Style.space(2)
        opacity: 0
        visible: opacity > 0
        scale: 0.82
        Column {
          anchors.centerIn: parent
          spacing: Style.space(8)
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.unlockKind + " UNLOCKED"; color: "#a6d5b3"; font.pixelSize: Style.font.caption; font.letterSpacing: 1.5 }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.unlockKey.toUpperCase(); color: "#80cf96"; font.family: "monospace"; font.bold: true; font.pixelSize: Style.space(54) }
        }
        SequentialAnimation {
          id: unlockAnimation
          ParallelAnimation {
            NumberAnimation { target: unlockToast; property: "opacity"; from: 0; to: 1; duration: 130 }
            NumberAnimation { target: unlockToast; property: "scale"; from: 0.82; to: 1.08; duration: 130 }
          }
          NumberAnimation { target: unlockToast; property: "scale"; to: 1; duration: 120 }
          PauseAnimation { duration: 1050 }
          NumberAnimation { target: unlockToast; property: "opacity"; to: 0; duration: 220 }
        }
      }
    }
  }
}
