"""Generate the trainer's original, short PCM sound themes using only stdlib."""
from pathlib import Path
import math, struct, wave, shutil, random
ROOT=Path(__file__).parent
RATE=24000

def write(theme,event,notes,kind):
    samples=[]
    phase=0.0
    for freq,duration in notes:
        count=int(RATE*duration)
        for n in range(count):
            t=n/RATE
            pitch=freq*(1.0-0.78*n/count) if kind=='laser' else freq
            phase+=2*math.pi*pitch/RATE
            if kind=='chiptune':
                # Soft square wave, without harsh high harmonics.
                value=sum(math.sin(phase*k)/k for k in (1,3,5))/1.54
            elif kind=='laser': value=math.sin(phase)+0.2*math.sin(phase*2)
            else: value=math.sin(phase)
            envelope=min(1,t/0.004)*min(1,(duration-t)/0.025)*math.exp(-2*t/duration)
            samples.append(int(max(-1,min(1,value*envelope*0.19))*32767))
    path=ROOT/theme/(event+'.wav'); path.parent.mkdir(exist_ok=True)
    with wave.open(str(path),'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes(struct.pack('<'+'h'*len(samples),*samples))

for theme in ('classic','chiptune','laser'):
    write(theme,'key',[(1100 if theme=='laser' else 650,0.045)],theme)
    write(theme,'failure',[(220,0.075),(155,0.10)],theme)
    write(theme,'body',[(523.25,0.085),(659.25,0.085),(783.99,0.15)],theme)
    write(theme,'unlock',[(523.25,0.09),(659.25,0.09),(783.99,0.09),(1046.5,0.22)],theme)
# Keep the original classic recordings.
for event in ('key','body','unlock'):
    shutil.copyfile(ROOT/(event+'.wav'),ROOT/'classic'/(event+'.wav'))

# Distinct synthesized instruments; seeded noise keeps regeneration reproducible.
def instrument(theme, event, notes):
    rng=random.Random(theme+event)
    samples=[]
    for freq,duration in notes:
        phase=0.0
        for n in range(int(RATE*duration)):
            t=n/RATE
            if theme=='bubble':
                phase+=2*math.pi*freq*(0.5+1.6*math.exp(-t*35))/RATE
                value=math.sin(phase)*math.exp(-t*22)
            elif theme=='glass':
                value=(math.sin(2*math.pi*freq*t)+0.35*math.sin(2*math.pi*freq*2.71*t)*math.exp(-t*14))*math.exp(-t*10)
            elif theme=='marimba':
                value=(math.sin(2*math.pi*freq*t)+0.4*math.sin(2*math.pi*freq*4*t)*math.exp(-t*35))*math.exp(-t*16)
            else:
                noise=rng.uniform(-1,1)*math.exp(-t*100)
                click=math.sin(2*math.pi*freq*t)*math.exp(-t*45)
                value=0.65*noise+0.7*click
                # The rebound gives key presses a small mechanical double click.
                if 0.018<t<0.032: value+=rng.uniform(-0.3,0.3)*(1-(t-0.018)/0.014)
            envelope=min(1,t/0.002)*min(1,(duration-t)/0.012)
            samples.append(int(max(-1,min(1,value*envelope*0.21))*32767))
    path=ROOT/theme/(event+'.wav');path.parent.mkdir(exist_ok=True)
    with wave.open(str(path),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes(struct.pack('<'+'h'*len(samples),*samples))

for theme,base in [('mechanical',380),('bubble',600),('glass',1400),('marimba',440)]:
    instrument(theme,'key',[(base,0.085 if theme=='mechanical' else 0.12)])
    instrument(theme,'failure',[(base*0.7,0.12),(base*0.5,0.15)])
    instrument(theme,'body',[(base,0.12),(base*1.25,0.12),(base*1.5,0.20)])
    instrument(theme,'unlock',[(base,0.1),(base*1.25,0.1),(base*1.5,0.1),(base*2,0.25)])
