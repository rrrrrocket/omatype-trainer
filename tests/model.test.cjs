const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const root = path.join(__dirname, '..');
function load(name) {
  const context=vm.createContext({});
  let code=fs.readFileSync(path.join(root,name),'utf8');
  code=code.replace(/^\.import "([^"]+)" as (\w+)$/gm,(_,file,alias)=>{context[alias]=load(file);return '';});
  vm.runInContext(code,context); return context;
}
const model=load('Model.js'), keyboard=load('Keyboard.js');
const old={keys:{e:{correct:22,total:23,avgMs:400}},unlockedLetters:8,sessionDraft:{lesson:'retain',cursor:2},soundMuted:true};
const migrated=model.normalize(old);
assert.equal(migrated.unlockedLetters,8);
assert.equal(migrated.sessionDraft.cursor,2);
assert.equal(migrated.keys.e.total,23);
assert.equal(migrated.soundMuted,true);
assert.equal(migrated.keyboardSize,'80');
assert.equal(migrated.codeMode,false);
const invalid=model.normalize({keyboardSize:'abc',keyboardColor:'red;bad',codeLanguage:'ruby',soundTheme:'bad',keyboardLayout:'bad'});
assert.equal(invalid.keyboardColor,'fingers');
assert.equal(invalid.codeLanguage,'html');
assert.equal(invalid.soundTheme,'chiptune');
for(const language of ['html','css','javascript','python']) {
  const stats=model.fresh(); stats.codeLanguage=language;
  const lessons=Array.from({length:12},()=>model.nextCodeLesson(stats));
  assert.equal(new Set(lessons).size,12);
  assert.ok(lessons.every(text=>text.length>0 && !text.includes('\n')));
  assert.equal(model.nextCodeLesson(stats),lessons[0]);
  if(language==='javascript') for(const text of lessons) new vm.Script(text);
}
for(const size of ['60','80','90','100']) for(const layout of ['us-ansi','us-iso','uk-iso']) {
  const rows=keyboard.rows(size,layout);
  assert.equal(rows.length,size==='60'?5:6);
  assert.ok(keyboard.widthUnits(rows)>15);
  assert.equal(rows.flat().some(key=>key[0]==='Num'),size==='90'||size==='100');
  for(const key of rows.flat()) assert.ok(Number.isFinite(key[2]) && key[2]>0);
}
assert.ok(keyboard.widthUnits(keyboard.rows('90','us-ansi'))<keyboard.widthUnits(keyboard.rows('100','us-ansi')));
for(const [ch,key] of [['@',"'"],['"','2'],['£','3'],['~','#'],['|','\\']]) assert.equal(keyboard.physical(ch,'uk-iso'),key);
assert.equal(keyboard.physical('@','us-ansi'),'2');
assert.equal(keyboard.physical('A','us-ansi'),'a');
assert.equal(keyboard.isShifted('A','us-ansi'),true);
assert.equal(keyboard.isShifted('a','us-ansi'),false);
console.log('Model, migration, code lessons, and all 12 keyboard combinations passed.');

for (const theme of ['classic','chiptune','laser','mechanical','bubble','glass','marimba']) {
  assert.equal(model.normalize({soundTheme:theme,soundDefaultsVersion:1}).soundTheme,theme);
  for (const event of ['key','body','failure','unlock']) {
    const sound=fs.readFileSync(path.join(root,'assets',theme,event+'.wav'));
    assert.equal(sound.toString('ascii',0,4),'RIFF');
    assert.equal(sound.toString('ascii',8,12),'WAVE');
    assert.ok(sound.length>44);
  }
}
console.log('All seven sound themes persist and include four WAV events.');

assert.equal(model.fresh().soundTheme,'chiptune');
assert.equal(model.normalize({soundTheme:'classic'}).soundTheme,'chiptune');
const progressStats=model.fresh();
assert.equal(model.unlockProgress(progressStats).value,0);
for(const key of model.LETTERS.slice(0,6)) progressStats.keys[key]={total:10,correct:10,avgMs:600};
assert.equal(model.unlockProgress(progressStats).percent,50);
for(const key of model.LETTERS.slice(0,6)) progressStats.keys[key]={total:20,correct:20,avgMs:600};
progressStats.keys.e.correct=10;
assert.ok(model.unlockProgress(progressStats).percent<100);
assert.ok(model.unlockProgress(progressStats).detail.includes('“e”'));
for(const codeMode of [false,true]) for(const columns of [24,40,64]) {
 const stats=model.fresh();stats.codeMode=codeMode;
 const block=model.nextPracticeBlock(stats,columns);
 assert.equal(block.breaks.length,3);
 for(const pos of block.breaks) assert.equal(block.text[pos],' ');
 if(!codeMode) {
  let start=0;
  for(const end of [...block.breaks,block.text.length]) { assert.ok(end-start<=columns); assert.ok(end-start>columns-12);start=end+1; }
 }
}
console.log('Chiptune defaults, unlock gates and four-line practice blocks passed.');
const generator=load('WordGenerator.js'), data=load('EnglishData.js');
for(const locale of ['en','en-GB']) {
 const allowed='enitrl';
 for(const focus of allowed) {
  const state=model.fresh();state.keyboardLayout=locale==='en-GB'?'uk-iso':'us-ansi';
  const eligible=data.DATA[locale].words.filter(w=>w.includes(focus)&&[...w].every(ch=>allowed.includes(ch)));
  const generated=generator.generate(state,40,allowed,focus,'Letters').split(' ');
  assert.ok(generated.every(w=>w.includes(focus)&&[...w].every(ch=>allowed.includes(ch))));
  assert.ok(generated.every((w,i)=>i===0 || w!==generated[i-1]));
  if(eligible.length>=15) {
   assert.ok(generated.every(w=>eligible.includes(w)),'real words only when pool is sufficient');
   const uniqueCount=Math.min(eligible.length,40);
   assert.equal(new Set(generated.slice(0,uniqueCount)).size,uniqueCount,'exhaust pool before repeating');
  }
 }
}
const repeated=model.fresh();
const first=generator.generate(repeated,10,'enitrl','e','Letters').split(' ');
const second=generator.generate(repeated,10,'enitrl','e','Letters').split(' ');
assert.ok(second.every(word=>!first.includes(word)),'avoid previous exercise words');
const four=model.fresh(); const block=model.nextPracticeBlock(four,40);
assert.deepEqual(Array.from(four.recentWords),block.text.split(' '),'remember only displayed words');
const persisted=model.normalize(JSON.parse(JSON.stringify(four)));
assert.equal(persisted.recentWords.length,four.recentWords.length);
for(const stage of ['Numbers','Punctuation & symbols']) {
 const focus=stage==='Numbers'?'1':';';
 const state=model.fresh();
 const words=generator.generate(state,20,'abcdefghijklmnopqrstuvwxyz'+focus,focus,stage).split(' ');
 assert.ok(words.every(word=>word.includes(focus)));
 assert.equal(new Set(words).size,20);
}
console.log('Dictionary-only selection, phonetic focus/letter filters, repeat prevention, and displayed-word history passed.');
console.log('Example: '+model.nextPracticeBlock(model.fresh(),40).text);
const placed=model.fresh();
placed.keys.e={correct:3,total:5,avgMs:900};placed.totalChars=123;placed.streak=4;
const history=JSON.stringify(placed.keys);
model.setPracticeLevel(placed,0,18);
assert.equal(model.activeKeys(placed).length,18);
assert.equal(model.stageInfo(placed).name,'Letters');
assert.equal(JSON.stringify(placed.keys),history);
assert.equal(placed.totalChars,123);assert.equal(placed.streak,4);
for(const [stage,count,name] of [[1,4,'Common patterns'],[2,7,'Numbers'],[3,9,'Punctuation & symbols'],[4,0,'Mixed fluency']]) {
 model.setPracticeLevel(placed,stage,count);
 const reloaded=model.normalize(JSON.parse(JSON.stringify(placed)));
 assert.equal(model.stageInfo(reloaded).name,name);
 if(stage<4) assert.equal(model.stageInfo(reloaded).active.length,count);
 assert.equal(JSON.stringify(reloaded.keys),history);
 model.nextPracticeBlock(reloaded,40);
 assert.equal(model.stageInfo(reloaded).name,name,'skipped stages do not relock');
}
model.setPracticeLevel(placed,0,6);
assert.equal(model.stageInfo(placed).name,'Letters');
assert.equal(model.activeKeys(placed).length,6);
model.setPracticeLevel(placed,2,3);
for(const key of model.NUMBERS.slice(0,3)) placed.keys[key]={correct:20,total:20,avgMs:500};
model.advanceProgress(placed);
assert.equal(placed.unlockedNumbers,4,'automatic unlocking resumes from chosen level');
assert.equal(model.stageInfo(placed).name,'Numbers');
console.log('Manual placement, persistence, unchanged history and subsequent automatic unlocks passed.');
