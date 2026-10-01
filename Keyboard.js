var BASE_ROWS = [
    [["Esc","",1.4],["","",0.4],["F1","",1],["F2","",1],["F3","",1],["F4","",1],["","",0.25],["F5","",1],["F6","",1],["F7","",1],["F8","",1],["","",0.25],["F9","",1],["F10","",1],["F11","",1],["F12","",1],["","",0.4],["Prt","",1],["Scr","",1],["Pau","",1]],
    [["~","`",1],["1","1",1],["2","2",1],["3","3",1],["4","4",1],["5","5",1],["6","6",1],["7","7",1],["8","8",1],["9","9",1],["0","0",1],["-","-",1],["=","=",1],["Bksp","backspace",2],["","",0.4],["Ins","",1],["Home","",1],["PgUp","",1]],
    [["Tab","tab",1.5],["Q","q",1],["W","w",1],["E","e",1],["R","r",1],["T","t",1],["Y","y",1],["U","u",1],["I","i",1],["O","o",1],["P","p",1],["[","[",1],["]","]",1],["\\","\\",1.5],["","",0.4],["Del","",1],["End","",1],["PgDn","",1]],
    [["Caps","caps",1.75],["A","a",1],["S","s",1],["D","d",1],["F","f",1],["G","g",1],["H","h",1],["J","j",1],["K","k",1],["L","l",1],[";",";",1],["'","'",1],["Enter","enter",2.25],["","",0.4],["","",1],["","",1],["","",1]],
    [["Shift","LShift",2.25],["Z","z",1],["X","x",1],["C","c",1],["V","v",1],["B","b",1],["N","n",1],["M","m",1],[",",",",1],[".",".",1],["/","/",1],["Shift","RShift",2.75],["","",0.4],["","",1],["↑","",1],["","",1]],
    [["Ctrl","",1.25],["Win","",1.25],["Alt","",1.25],["Space"," ",6.25],["Alt","",1.25],["Win","",1.25],["Menu","",1.25],["Ctrl","",1.25],["","",0.4],["←","",1],["↓","",1],["→","",1]]
  ]

function rows(size, layout) {
  var result=JSON.parse(JSON.stringify(BASE_ROWS))
  if (layout !== "us-ansi") {
    // ISO has an extra key beside left Shift and a tall Enter key.
    result[2][13]=["Enter","enter",1.5,2.25]
    result[3][12]=[layout === "uk-iso" ? "#  ~" : "\\  |",layout === "uk-iso" ? "#" : "\\",1]
    result[3].splice(13,0,["","",1.12])
    result[4][0][2]=1.12
    result[4].splice(1,0,[layout === "uk-iso" ? "\\  |" : "<  >",layout === "uk-iso" ? "\\" : "<",1])
    if (layout === "uk-iso") {
      result[1][0][0]="`  ¬"
      result[1][2][0]='2  "'
      result[1][3][0]="3  £"
      result[3][11][0]="'  @"
    }
  }
  if (size === "60") {
    result.shift()
    for (var r=0;r<result.length;r++) {
      var split=result[r].findIndex(function(k) { return k[0]==="" && k[2]===0.4 })
      result[r]=result[r].slice(0,split)
    }
    result[0][0][0]="Esc / `"
  }
  if (size === "90" || size === "100") {
    if (size === "90") {
      // Compact 96-key-style arrangement: function row, arrows, one nav column, numpad.
      result[0]=result[0].slice(0,16).concat([["Del","",1]])
      var nav=["Home","PgUp","PgDn","End",""]
      for (var j=1;j<result.length;j++) {
        var cut=result[j].findIndex(function(k) { return k[0]==="" && k[2]===0.4 })
        result[j]=result[j].slice(0,cut)
        if(j===4) result[j][result[j].length-1]=["Shift","RShift",1.5]
        if(j===4) result[j].push(["↑","",1])
        if(j===5) result[j]=result[j].slice(0,5).concat([["←","",1],["↓","",1],["→","",1]])
        result[j].push([nav[j-1],"",1])
      }
    }
    var pad=[[["","",4.39]],[["Num","",1],["/","/",1],["*","*",1],["-","-",1]],[["7","7",1],["8","8",1],["9","9",1],["+","+",1,2.25]],[["4","4",1],["5","5",1],["6","6",1],["","",1]],[["1","1",1],["2","2",1],["3","3",1],["Enter","enter",1,2.25]],[["0","0",2.13],[".",".",1],["","",1]]]
    var mainWidth=widthUnits(result.slice(1))
    for(var n=0;n<result.length;n++) {
      var gap=(size==="100"?0.4:0.15)+Math.max(0,mainWidth-widthUnits([result[n]]))
      result[n]=result[n].concat([["","",gap]]).concat(pad[n])
    }
  }
  return result
}
function widthUnits(rows) {
  return Math.max.apply(null,rows.map(function(row) {
    return row.reduce(function(sum,key){return sum+key[2]},0)+0.13*(row.length-1)
  }))
}
function shifted(layout) {
  var pairs={"`":"~","1":"!","2":"@","3":"#","4":"$","5":"%","6":"^","7":"&","8":"*","9":"(","0":")","-":"_","=":"+","[":"{","]":"}","\\":"|",";":":","'":'"',",":"<",".":">","/":"?"}
  if(layout==="uk-iso") { pairs['`']='¬'; pairs['2']='"'; pairs['3']='£'; pairs["'"]='@'; pairs['#']='~' }
  if(layout==="us-iso") pairs['<']='>'
  return pairs
}
function physical(ch,layout) {
  var pairs=shifted(layout)
  for(var key in pairs) if(pairs[key]===ch) return key
  if(ch==='\n') return 'enter'
  return ch.toLowerCase()
}
function isShifted(ch,layout) {
  var pairs=shifted(layout)
  for(var key in pairs) if(pairs[key]===ch) return true
  return ch >= 'A' && ch <= 'Z'
}
