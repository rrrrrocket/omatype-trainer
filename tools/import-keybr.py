"""Convert keybr's pinned English assets into a QML-compatible JS data module.
Usage: python tools/import-keybr.py /path/to/keybr.com
"""
from pathlib import Path
import json, struct, sys, subprocess, shutil
repo=Path(sys.argv[1]); root=Path(__file__).resolve().parents[1]
revision=subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip()
blocked=json.loads((repo/'packages/keybr-phonetic-model/lib/blacklist/blacklist-en.json').read_text())
blocked=[''.join(word[(23*i+13)%len(word)] for i in range(len(word))) for word in blocked]
data={}
for locale in ['en','en-GB']:
    words=json.loads((repo/f'packages/keybr-content-words/lib/data/words-{locale}.json').read_text())
    raw=(repo/f'packages/keybr-phonetic-model/assets/model-{locale}.data').read_bytes()
    assert raw[:9]==b'keybr.com'
    order,size=raw[9:11];offset=11
    assert order==4
    alphabet=[chr(struct.unpack_from('>H',raw,offset+2*i)[0]) for i in range(size)];offset+=2*size
    segments={}
    for index in range(size**(order-1)):
        length=raw[offset];offset+=1
        assert length<=size
        segment=[]
        for _ in range(length):
            char,frequency=raw[offset:offset+2];offset+=2
            assert char<size and frequency>0
            segment.append([alphabet[char],frequency])
        if segment:
            context=''.join(alphabet[(index//(size**power))%size] for power in range(order-2,-1,-1))
            segments[context]=segment
    assert offset==len(raw)
    data[locale]={'words':[w for w in words if w not in blocked and w.isascii() and w.isalpha() and 3<=len(w)<=12],'segments':segments}
(root/'EnglishData.js').write_text('// English word lists and phonetic tables from aradzie/keybr.com.\n// AGPL-3.0; see THIRD_PARTY.md and licenses/keybr-AGPL-3.0.txt.\n// Source revision: '+revision+'\nvar DATA = '+json.dumps(data,separators=(',',':'))+'\nvar BLOCKED = '+json.dumps(blocked)+'\n')
shutil.copyfile(repo/'LICENSE',root/'licenses/keybr-AGPL-3.0.txt')
print('Imported',revision,[(lang,len(value['words'])) for lang,value in data.items()])
