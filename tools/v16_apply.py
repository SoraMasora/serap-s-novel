"""v16: возвращает старые (до v15) сцены и приводит ВСЕ фоны/CG/спрайты/титул к единой рисованной стилистике cg_reconcile
фильтром tools/v16_style.artist. Исходники — v16src/ (распаковка ассетов до v15). Затем раскладывает ассеты по файлам ≤960 КБ
(лишнее → assets/xN.js + <script> в index.html). python3 tools/v16_apply.py"""
import sys,os,re,glob; sys.path.insert(0,'tools')
import numpy as np
from PIL import Image
from setasset import set_asset
from v16_style import artist
from v14_labels import fix,STORE,SHIFT
from PIL import ImageEnhance,ImageOps
LAB={'store':('a01badb2',STORE),'cg_shift':('1fc6931f',SHIFT)}
F='/data/.agent-service/files/'
def fid(i): return Image.open(glob.glob(F+i+'*/*')[0]).convert('RGB').resize((1376,768),Image.LANCZOS)
OVR={'cg_tea':'937cb55e','cg_dumplings':'afd66bd4'}
pat=re.compile(r"ASSETS\.(\w+)\['([^']+)'\]='data:image")
where={}
for js in sorted(glob.glob('assets/*.js')):
    if re.search(r'music|sfx',js): continue
    for m in pat.finditer(open(js).read()): where[(m.group(1),m.group(2))]=js
os.makedirs('v16',exist_ok=True)
def sprite(im,k=.85):
    a=np.asarray(im.convert('RGBA')).astype(np.float32); al=a[...,3:]/255.
    rgb=a[...,:3]*al+128*(1-al); out=np.asarray(artist(Image.fromarray(rgb.astype(np.uint8)),k=k)).astype(np.float32)
    return Image.fromarray(np.concatenate([out,a[...,3:]],2).astype(np.uint8),'RGBA')
BL=(425,225)
for (kind,key),js in sorted(where.items()):
    if kind=='bg':
        src=fid(OVR[key]) if key in OVR else Image.open(f'v16src/bg_{key}.webp').convert('RGB')
        if key in LAB:  # v16.2: надписи рисуются ПОСЛЕ фильтра (иначе контур портит «Роллтон»/«Доширак»)
            src=fid(LAB[key][0]); 
            if key=='store': src=ImageEnhance.Color(ImageEnhance.Contrast(ImageOps.autocontrast(src,cutoff=1)).enhance(1.12)).enhance(1.15)
            im=fix(artist(src),LAB[key][1])
        else: im=artist(src)
        im.save(f'v16/{key}.jpg',quality=85); set_asset(js,'bg',key,im,80)
    elif kind=='title':
        set_asset(js,'title',key,artist(Image.open(f'v16src/title_{key}.webp').convert('RGB')),80)
    elif kind=='sprites':
        if key=='blink_neutral':
            base=Image.open('v16src/sprites_sera_neutral.webp').convert('RGBA'); p=Image.open('v16src/sprites_blink_neutral.webp').convert('RGBA')
            c=base.copy(); c.alpha_composite(p,BL); c=sprite(c).crop((BL[0],BL[1],BL[0]+p.width,BL[1]+p.height))
            c.putalpha(p.split()[3]); set_asset(js,'sprites',key,c,84,mode='RGBA')
        else:
            set_asset(js,'sprites',key,sprite(Image.open(f'v16src/sprites_{key}.webp')),84,mode='RGBA')
# раскладка по файлам ≤960 КБ
LIM=960_000; html=open('index.html').read(); n=len(glob.glob('assets/x*.js'))
HDR="window.ASSETS=window.ASSETS||{};['bg','sprites','title','ui'].forEach(k=>ASSETS[k]=ASSETS[k]||{});"
line=re.compile(r"^ASSETS\.\w+\['[^']+'\]='[^']*';$",re.M)
for js in sorted(set(where.values())):
    s=open(js).read()
    if len(s)<=LIM: continue
    items=line.findall(s); rest=line.sub('',s).strip('\n'); size=len(rest); keep=[]; move=[]
    for it in items:
        if size+len(it)+1<=LIM: keep.append(it); size+=len(it)+1
        else: move.append(it)
    open(js,'w').write((rest+'\n' if rest else '')+'\n'.join(keep)+'\n')
    tag=f'<script src="{js}"></script>'; chunks=[[]]; cs=len(HDR)
    for it in move:
        if cs+len(it)+1>LIM and chunks[-1]: chunks.append([]); cs=len(HDR)
        chunks[-1].append(it); cs+=len(it)+1
    for ch in chunks:
        n+=1; x=f'assets/x{n}.js'; open(x,'w').write(HDR+'\n'+'\n'.join(ch)+'\n'); t=f'<script src="{x}"></script>'
        html=html.replace(tag,tag+'\n'+t,1); tag=t; print('split',js,'->',x,len(ch))
open('index.html','w').write(html)
