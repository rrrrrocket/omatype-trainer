.import "EnglishData.js" as EnglishData
// Adapted for QML from keybr's guided dictionary/phonetic generation approach.
// AGPL-3.0; upstream source and modifications are documented in THIRD_PARTY.md.
var cachedKey="", cachedWords=[]
function randomSource(seed) {
  var state=(Number(seed)||1)>>>0
  return function() { state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296 }
}
function shuffle(items,random) {
  for(var i=items.length-1;i>0;i--) { var j=Math.floor(random()*(i+1)), value=items[i];items[i]=items[j];items[j]=value }
  return items
}
function fits(word,allowed) {
  for(var i=0;i<word.length;i++) if(allowed.indexOf(word[i])<0) return false
  return true
}
function phonetic(data,allowed,focus,random) {
  function segment(word) { return data.segments[("   "+word).slice(-3)]||[] }
  // Seed with genuine word prefixes that contain the focused letter.
  var prefixes=[]
  function walk(prefix) {
    if(prefix.length && prefix.indexOf(focus)>=0) prefixes.push(prefix)
    if(prefix.length>=3) return
    var entries=segment(prefix)
    for(var i=0;i<entries.length;i++) if(entries[i][0]!==" " && allowed.indexOf(entries[i][0])>=0) walk(prefix+entries[i][0])
  }
  walk("")
  for(var attempt=0;attempt<6;attempt++) {
    var word=prefixes.length ? prefixes[Math.floor(random()*prefixes.length)] : focus
    while(word.length<=10) {
      var entries=segment(word), choices=[], total=0
      for(var j=0;j<entries.length;j++) {
        var ch=entries[j][0], weight=entries[j][1]
        if(ch===" " ? word.length<3 : allowed.indexOf(ch)<0) continue
        if(ch===" ") weight*=Math.pow(1.3,word.length)
        total+=weight;choices.push([ch,total])
      }
      if(!total) break
      var point=random()*total, next=choices[choices.length-1][0]
      for(var k=0;k<choices.length;k++) if(point<choices[k][1]) { next=choices[k][0];break }
      if(next===" ") {
        if(word.indexOf(focus)>=0 && EnglishData.BLOCKED.indexOf(word)<0) return word
        break
      }
      word+=next
    }
  }
  return ""
}
function candidates(locale,allowed,focus,random) {
  var key=locale+"|"+allowed+"|"+focus
  if(key===cachedKey) return cachedWords.slice()
  var data=EnglishData.DATA[locale]||EnglishData.DATA.en, words=[]
  for(var i=0;i<data.words.length && words.length<1000;i++) {
    var word=data.words[i]
    if((!focus || word.indexOf(focus)>=0) && fits(word,allowed)) words.push(word)
  }
  // Match keybr's natural-words mode: phonetic fallback only for sparse pools.
  for(var tries=0;words.length<15 && focus && tries<120;tries++) {
    var generated=phonetic(data,allowed,focus,random)
    if(generated && words.indexOf(generated)<0) words.push(generated)
  }
  cachedKey=key;cachedWords=words.slice()
  return words
}
function generate(stats,count,allowed,focus,stage) {
  var locale=stats.keyboardLayout==="uk-iso" ? "en-GB" : "en"
  stats.lessonSeed=(Number(stats.lessonSeed)||0)+1
  var random=randomSource(Math.imul(stats.lessonSeed,2654435761))
  var nonletter=stage==="Numbers" || stage==="Punctuation & symbols"
  var words=candidates(locale,nonletter?"abcdefghijklmnopqrstuvwxyz":allowed,nonletter || focus==="fluent"?"":focus,random)
  if(nonletter) words=words.map(function(word) { return word+focus })
  // Never inject an unlearned letter if no phonetic path is possible.
  if(!words.length) words=[focus==="fluent"?"practice":focus]
  var history=Array.isArray(stats.recentWords)?stats.recentWords:[]
  var fresh=words.filter(function(word){return history.indexOf(word)<0})
  var old=words.filter(function(word){return history.indexOf(word)>=0})
  old.sort(function(a,b){return history.lastIndexOf(a)-history.lastIndexOf(b)})
  var bag=shuffle(fresh,random).concat(old), out=[], index=0
  while(out.length<count) {
    if(index>=bag.length) { bag=shuffle(words.slice(),random);index=0 }
    var last=out.length?out[out.length-1]:history[history.length-1]
    if(bag[index]===last && bag.length>1) {
      var other=index+1<bag.length?index+1:0, temp=bag[index];bag[index]=bag[other];bag[other]=temp
    }
    out.push(bag[index++])
  }
  stats.recentWords=history.concat(out).slice(-60)
  return out.join(" ")
}
