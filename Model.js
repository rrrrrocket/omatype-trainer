.import "WordGenerator.js" as WordGenerator
// keybr-inspired adaptive practice: confidence per key, a gradually expanding
// active set, and readable lessons biased toward the weakest active key.
var FINGERS = {
  q:"Left pinky", a:"Left pinky", z:"Left pinky", "`":"Left pinky", "1":"Left pinky",
  w:"Left ring", s:"Left ring", x:"Left ring", "2":"Left ring",
  e:"Left middle", d:"Left middle", c:"Left middle", "3":"Left middle",
  r:"Left index", f:"Left index", v:"Left index", t:"Left index", g:"Left index", b:"Left index", "4":"Left index", "5":"Left index",
  y:"Right index", h:"Right index", n:"Right index", u:"Right index", j:"Right index", m:"Right index", "6":"Right index", "7":"Right index",
  i:"Right middle", k:"Right middle", ",":"Right middle", "8":"Right middle",
  o:"Right ring", l:"Right ring", ".":"Right ring", "9":"Right ring",
  p:"Right pinky", ";":"Right pinky", "/":"Right pinky", "0":"Right pinky", "-":"Right pinky", "=":"Right pinky"
}
FINGERS["!"]="Left pinky + Shift"; FINGERS["@"]="Left ring + Shift"; FINGERS["#"]="Left middle + Shift"
FINGERS["$"]="Left index + Shift"; FINGERS["%"]="Left index + Shift"; FINGERS["^"]="Right index + Shift"
FINGERS["&"]="Right index + Shift"; FINGERS["*"]="Right middle + Shift"; FINGERS["("]="Right ring + Shift"
FINGERS[")"]="Right pinky + Shift"; FINGERS["_"]="Right pinky + Shift"; FINGERS["+"]="Right pinky + Shift"
FINGERS["{"]="Right pinky + Shift"; FINGERS["}"]="Right pinky + Shift"; FINGERS[":"]="Right pinky + Shift"
FINGERS["\""]="Right pinky + Shift"; FINGERS["<"]="Right middle + Shift"; FINGERS[">"]="Right ring + Shift"; FINGERS["?"]="Right pinky + Shift"
FINGERS["'"]="Right pinky"; FINGERS["\\"]="Right pinky"
FINGERS["["]="Right pinky"; FINGERS["]"]="Right pinky"
FINGERS["~"]="Left pinky + Shift"; FINGERS["|"]="Right pinky + Shift"
FINGERS.tab="Left pinky"; FINGERS.caps="Left pinky"
FINGERS.backspace="Right pinky"; FINGERS.enter="Right pinky"

// English letter-frequency order. Keybr normally starts with six common
// letters; the user's requested single-key start has been superseded.
var LETTERS = "enitrlsoadchumpygfwvbkxjqz".split("")
var PATTERNS = ["tion", "ther", "that", "with", "ing", "ment", "ould", "ough", "ight", "ance"]
var NUMBERS = "1234567890".split("")
var SYMBOLS = [";", ",", ".", "-", "=", "'", "/", "[", "]", "\\", "`", "!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+", "{", "}", "|", "~", ":", "\"", "<", ">", "?"]
var ACCURACY_GATE = 0.95
var TARGET_WPM = 10
var SAMPLE_GATE = 20

function fingerFor(ch) { return FINGERS[String(ch || "").toLowerCase()] || (ch === " " ? "Thumb (space)" : "") }
function fresh() {
  return {keys:{}, patterns:{}, sessions:0, totalChars:0, correctChars:0, totalMs:0, lastDate:"", streak:0, bestWpm:0, sessionMinutes:5,
    activeKey:"e", startingStage:0, unlockedLetters:6, unlockedPatterns:1, unlockedNumbers:1, unlockedSymbols:1, shortcutReviewed:0,
    lessonSeed:0, recentWords:[], lastSession:null, lastBody:null, lastBodyFeedback:null, sessionDraft:null, soundMuted:false, keyboardSize:"80", keyboardLayout:"us-ansi", keyboardColor:"fingers", soundTheme:"chiptune", soundDefaultsVersion:1, codeMode:false, codeLanguage:"html", codeSeed:0}
}
function normalize(value) {
  var result=fresh()
  if (!value || typeof value !== "object") return result
  for (var key in result) if (value[key] !== undefined) result[key]=value[key]
  result.startingStage=Math.max(0,Math.min(4,Math.floor(Number(result.startingStage)||0)))
  result.keys=value.keys||{}; result.patterns=value.patterns||{}
  result.sessionMinutes=Math.max(1,Math.min(30,Number(result.sessionMinutes)||5))
  result.unlockedLetters=Math.max(6,Math.min(LETTERS.length,Number(result.unlockedLetters)||6))
  result.unlockedPatterns=Math.max(1,Math.min(PATTERNS.length,Number(result.unlockedPatterns)||1))
  result.unlockedNumbers=Math.max(1,Math.min(NUMBERS.length,Number(result.unlockedNumbers)||1))
  result.unlockedSymbols=Math.max(1,Math.min(SYMBOLS.length,Number(result.unlockedSymbols)||1))
  function choice(value, allowed, fallback) { return allowed.indexOf(value)>=0 ? value : fallback }
  result.keyboardSize=choice(String(result.keyboardSize),["60","80","90","100"],"80")
  result.keyboardLayout=choice(result.keyboardLayout,["us-ansi","us-iso","uk-iso"],"us-ansi")
  result.soundTheme=choice(result.soundTheme,["classic","chiptune","laser","mechanical","bubble","glass","marimba"],"chiptune")
  if (!value.soundDefaultsVersion) result.soundTheme="chiptune"
  result.soundDefaultsVersion=1
  result.codeLanguage=choice(result.codeLanguage,["html","css","javascript","python"],"html")
  result.keyboardColor=result.keyboardColor==="fingers" || /^#[0-9a-f]{6}$/i.test(result.keyboardColor) ? result.keyboardColor : "fingers"
  result.codeMode=result.codeMode===true
  result.recentWords=Array.isArray(result.recentWords) ? result.recentWords.filter(function(word){return typeof word==="string"}).slice(-60) : []
  result.codeSeed=Math.max(0,Math.floor(Number(result.codeSeed)||0))
  return result
}
function stageInfo(stats) {
  function needsPractice(list, count, records) {
    if (count < list.length) return true
    for (var i=0;i<list.length;i++) if (!mastered(records[list[i]]||{})) return true
    return false
  }
  if ((stats.startingStage||0)<=0 && needsPractice(LETTERS,stats.unlockedLetters,stats.keys)) return {name:"Letters",kind:"key",list:LETTERS,active:LETTERS.slice(0,stats.unlockedLetters)}
  if ((stats.startingStage||0)<=1 && needsPractice(PATTERNS,stats.unlockedPatterns,stats.patterns)) return {name:"Common patterns",kind:"pattern",list:PATTERNS,active:PATTERNS.slice(0,stats.unlockedPatterns)}
  if ((stats.startingStage||0)<=2 && needsPractice(NUMBERS,stats.unlockedNumbers,stats.keys)) return {name:"Numbers",kind:"key",list:NUMBERS,active:NUMBERS.slice(0,stats.unlockedNumbers)}
  if ((stats.startingStage||0)<=3 && needsPractice(SYMBOLS,stats.unlockedSymbols,stats.keys)) return {name:"Punctuation & symbols",kind:"key",list:SYMBOLS,active:SYMBOLS.slice(0,stats.unlockedSymbols)}
  return {name:"Mixed fluency",kind:"mixed",list:[],active:[]}
}
function itemFor(stats, info, key) { return (info.kind==="pattern"?stats.patterns[key]:stats.keys[key]) || {correct:0,total:0,avgMs:0} }
function confidence(item) {
  var total=Number(item.total)||0, accuracy=total?Number(item.correct||0)/total:0, avg=Number(item.avgMs)||0
  var accuracyPart=Math.min(1,accuracy/ACCURACY_GATE), speedPart=avg>0?Math.min(1,12000/avg/TARGET_WPM):0
  var score=Math.min(accuracyPart,speedPart)
  return total<SAMPLE_GATE?Math.min(0.99,score):score
}
function mastered(item) {
  var total=Number(item.total)||0, accuracy=total?Number(item.correct||0)/total:0, avg=Number(item.avgMs)||0
  return total>=SAMPLE_GATE && accuracy>=ACCURACY_GATE && avg>0 && 12000/avg>=TARGET_WPM
}
function currentKey(stats) {
  var info=stageInfo(stats)
  if (info.kind==="mixed") return "fluent"
  var focus=info.active[0], lowest=2
  for (var i=0;i<info.active.length;i++) {
    var key=info.active[i], score=confidence(itemFor(stats,info,key))
    if (score<lowest) { focus=key; lowest=score }
  }
  return focus
}
function advanceProgress(stats) {
  var info=stageInfo(stats)
  if (info.kind==="mixed") return
  for (var i=0;i<info.active.length;i++) if (!mastered(itemFor(stats,info,info.active[i]))) return
  if (info.name==="Letters") stats.unlockedLetters=Math.min(LETTERS.length,info.active.length+1)
  else if (info.name==="Common patterns") stats.unlockedPatterns=Math.min(PATTERNS.length,info.active.length+1)
  else if (info.name==="Numbers") stats.unlockedNumbers=Math.min(NUMBERS.length,info.active.length+1)
  else if (info.name==="Punctuation & symbols") stats.unlockedSymbols=Math.min(SYMBOLS.length,info.active.length+1)
}
function stageFor(key, stats) { return stageInfo(stats).name + " · " + (stageInfo(stats).active.indexOf(key)+1) + "/" + stageInfo(stats).list.length }
function gateStatus(stats) {
  var info=stageInfo(stats), key=currentKey(stats), item=itemFor(stats,info,key), avg=Number(item.avgMs)||0
  return {key:key, total:Number(item.total)||0, accuracy:item.total?Number(item.correct||0)/Number(item.total):0,
    wpm:avg?Math.round(12000/avg):0, avgMs:avg, sampleGate:SAMPLE_GATE, accuracyGate:ACCURACY_GATE, speedGate:TARGET_WPM,
    active:info.active, stage:info.name}
}
function activeKeys(stats) {
  var info=stageInfo(stats)
  if (info.name==="Letters") return info.active
  if (info.name==="Common patterns") return LETTERS
  if (info.name==="Numbers") return LETTERS.concat(NUMBERS.slice(0,stats.unlockedNumbers))
  if (info.name==="Punctuation & symbols") return LETTERS.concat(NUMBERS,SYMBOLS.slice(0,stats.unlockedSymbols))
  return LETTERS.concat(NUMBERS,SYMBOLS)
}
function nextLesson(stats, count) {
  advanceProgress(stats)
  return WordGenerator.generate(stats,count,activeKeys(stats).join(""),currentKey(stats),stageInfo(stats).name)
}
function weakestSummary(stats) {
  var gate=gateStatus(stats), stageInfoValue=stageInfo(stats)
  if (gate.key==="fluent") return "All letter, pattern, number, and symbol stages are unlocked. Keep practising mixed text to maintain accuracy and rhythm."
  return stageInfoValue.name+" · active set “"+gate.active.join(" ")+"”. Weakest key: “"+gate.key+"”. Unlock the next item when every active item reaches "+SAMPLE_GATE+" samples, 95% accuracy and "+TARGET_WPM+" WPM average key speed. Focus: "+gate.total+" samples, "+Math.round(gate.accuracy*100)+"% accuracy, "+gate.wpm+" WPM."
}
if (typeof module!=="undefined") module.exports={fingerFor:fingerFor,fresh:fresh,normalize:normalize,stageInfo:stageInfo,currentKey:currentKey,advanceProgress:advanceProgress,gateStatus:gateStatus,stageFor:stageFor,activeKeys:activeKeys,nextLesson:nextLesson,weakestSummary:weakestSummary,confidence:confidence,mastered:mastered,LETTERS:LETTERS,PATTERNS:PATTERNS,NUMBERS:NUMBERS,SYMBOLS:SYMBOLS}

// Short, valid, single-line exercises fit the regular practice surface.
// Code uses the full character set immediately and is checked case-sensitively.
var CODE_LESSONS = {
  html: [
    '<h1>Hello, world!</h1>',
    '<p class="intro">Learn to code.</p>',
    '<a href="/about">About us</a>',
    '<button type="button">Save</button>',
    '<input type="text" name="email">',
    '<img src="logo.svg" alt="Logo">',
    '<ul><li>One</li><li>Two</li></ul>',
    '<label for="name">Your name</label>',
    '<div id="app">Ready &amp; waiting</div>',
    '<meta name="viewport" content="width=device-width">',
    '<section><h2>News</h2></section>',
    '<strong>Keep practising!</strong>'
  ],
  css: [
    'body { margin: 0; padding: 20px; }',
    '.card { border-radius: 8px; }',
    'a:hover { color: #ff6600; }',
    '.grid { display: grid; gap: 1rem; }',
    'h1 { font-size: 2rem; font-weight: 700; }',
    '.row { display: flex; align-items: center; }',
    'button { cursor: pointer; }',
    '.box { width: 100%; max-width: 640px; }',
    ':root { --accent: #88c0d0; }',
    'p { line-height: 1.5; color: var(--accent); }',
    '* { box-sizing: border-box; }',
    '.fade { transition: opacity 0.2s ease; }'
  ],
  javascript: [
    'const message = "Hello, world!";',
    'console.log(message);',
    'const add = (a, b) => a + b;',
    'let count = 0; count += 1;',
    'const names = ["Ada", "Grace"];',
    'const doubled = [1, 2, 3].map(n => n * 2);',
    'if (ready === true) { start(); }',
    'for (let i = 0; i < 5; i++) { run(i); }',
    'const user = { name: "Sam", active: true };',
    'function greet(name) { return `Hi, ${name}!`; }',
    'const unique = [...new Set(items)];',
    'const result = items.filter(x => x !== null);'
  ],
  python: [
    'print("Hello, world!")',
    'name = "Ada"; print(f"Hello, {name}!")',
    'numbers = [1, 2, 3, 4, 5]',
    'squares = [n ** 2 for n in range(10)]',
    'user = {"name": "Sam", "active": True}',
    'if count >= 10: print("Done!")',
    'for item in items: print(item)',
    'def add(a, b): return a + b',
    'total = sum(n for n in numbers if n > 0)',
    'words = "one two three".split()',
    'pairs = list(zip(names, scores))',
    'assert len(numbers) != 0, "Empty list"'
  ]
}
function nextCodeLesson(stats) {
  var lessons=CODE_LESSONS[stats.codeLanguage] || CODE_LESSONS.html
  var index=(Number(stats.codeSeed)||0)%lessons.length
  stats.codeSeed=index+1
  return lessons[index]
}

function unlockProgress(stats) {
  var info=stageInfo(stats)
  if (info.kind==="mixed") return {value:1,percent:100,next:"All keys unlocked",detail:"Keep building fluency."}
  var sum=0, weakest=1, limiting=info.active[0]
  for (var i=0;i<info.active.length;i++) {
    var key=info.active[i], item=itemFor(stats,info,key)
    var samples=Math.min(1,(Number(item.total)||0)/SAMPLE_GATE)
    var accuracy=item.total ? Math.min(1,item.correct/item.total/ACCURACY_GATE) : 0
    var speed=item.avgMs>0 ? Math.min(1,12000/item.avgMs/TARGET_WPM) : 0
    var score=Math.min(samples,accuracy,speed)
    sum+=score
    if (score<weakest) { weakest=score; limiting=key }
  }
  var next=info.list[info.active.length]
  if (!next) next=info.name==="Letters"?PATTERNS[0]:(info.name==="Common patterns"?NUMBERS[0]:(info.name==="Numbers"?SYMBOLS[0]:"Mixed fluency"))
  var record=itemFor(stats,info,limiting), value=sum/info.active.length
  return {value:value,percent:Math.min(99,Math.floor(value*100)),next:next,
    detail:"Focus “"+limiting+"” · "+Math.min(SAMPLE_GATE,Number(record.total)||0)+"/"+SAMPLE_GATE+" samples · "+(record.total?Math.round(100*record.correct/record.total):0)+"% / 95% accuracy · "+(record.avgMs>0?Math.round(12000/record.avgMs):0)+" / "+TARGET_WPM+" WPM"}
}

function nextPracticeBlock(stats,columns) {
  var lines=[], breaks=[], text=""
  if (stats.codeMode) {
    for(var c=0;c<4;c++) lines.push(nextCodeLesson(stats))
  } else {
    columns=Math.max(24,Math.min(64,Math.floor(columns)||40))
    var previousWords=(stats.recentWords||[]).slice()
    var words=nextLesson(stats,columns*2).split(" "), index=0
    for(var row=0;row<4;row++) {
      var line=words[index++]
      while(index<words.length && line.length+1+words[index].length<=columns) line+=" "+words[index++]
      lines.push(line)
    }
    stats.recentWords=previousWords.concat(lines.join(" ").split(" ")).slice(-60)
  }
  for(var i=0;i<lines.length;i++) {
    if(i>0) { breaks.push(text.length); text+=" " }
    text+=lines[i]
  }
  return {text:text,breaks:breaks}
}
// Reflow a saved exercise without altering its text or cursor position.
function balancedBreaks(text) {
  var spaces=[]
  for(var i=1;i<text.length-1;i++) if(text[i]===" ") spaces.push(i)
  var result=[]
  for(var row=1;row<4;row++) {
    var target=text.length*row/4, best=-1, distance=Infinity
    for(var j=0;j<spaces.length;j++) if((!result.length || spaces[j]>result[result.length-1]) && Math.abs(spaces[j]-target)<distance) { best=spaces[j];distance=Math.abs(best-target) }
    if(best>=0) result.push(best)
  }
  return result
}

// A placement choice changes availability, never measured skill/history.
function setPracticeLevel(stats,stage,count) {
  stage=Math.max(0,Math.min(4,Math.floor(Number(stage)||0)))
  var lists=[LETTERS,PATTERNS,NUMBERS,SYMBOLS]
  var fields=["unlockedLetters","unlockedPatterns","unlockedNumbers","unlockedSymbols"]
  stats.startingStage=stage
  for(var i=0;i<fields.length;i++) {
    stats[fields[i]]=i<stage ? lists[i].length : (i===stage ? Math.max(i===0?6:1,Math.min(lists[i].length,Math.floor(Number(count)||1))) : (i===0?6:1))
  }
  stats.activeKey=currentKey(stats)
  stats.recentWords=[]
  return stats
}
