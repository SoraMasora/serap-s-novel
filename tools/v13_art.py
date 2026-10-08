"""v13: двор с отцом, cg_father/cg_quarrel по старым композициям, концовки с шарфом, новые CG в cg10.js. python3 tools/v13_art.py"""

import sys,glob
from PIL import Image,ImageEnhance,ImageOps
sys.path.insert(0,'tools'); from setasset import set_asset
import numpy as np
from PIL import ImageFilter
F='/data/.agent-service/files/'; W,H=1376,768
def L(i):
    im=Image.open(glob.glob(F+i+'*/*')[0]).convert('RGB')
    return im if im.size==(W,H) else im.resize((W,H),Image.LANCZOS)
def comp(base,img,thr=38,grow=31,blur=25,keep=()):
    if img.size!=base.size: img=img.resize(base.size,Image.LANCZOS)
    a=np.asarray(base).astype(np.int16); b=np.asarray(img).astype(np.int16)
    d=(np.abs(a-b).max(2)>thr).astype(np.uint8)*255
    for x0,y0,x1,y1 in keep: d[y0:y1,x0:x1]=0
    d=Image.fromarray(d).filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.MaxFilter(grow)).filter(ImageFilter.GaussianBlur(blur))
    m=np.asarray(d).astype(np.float32)[...,None]/255
    for x0,y0,x1,y1 in keep: m[y0:y1,x0:x1]=0
    return Image.fromarray((a*(1-m)+b*m).clip(0,255).astype(np.uint8))
def match(img,ref):
    import cv2
    a=cv2.cvtColor(np.asarray(img),cv2.COLOR_RGB2LAB).astype(np.float32); r=cv2.cvtColor(np.asarray(ref),cv2.COLOR_RGB2LAB).astype(np.float32)
    for c in range(3): a[...,c]=(a[...,c]-a[...,c].mean())/(a[...,c].std()+1e-6)*r[...,c].std()+r[...,c].mean()
    return Image.fromarray(cv2.cvtColor(a.clip(0,255).astype(np.uint8),cv2.COLOR_LAB2RGB))

def put(js,items):
    for k,im in items: im.save(f'v13/{k}.jpg',quality=88); set_asset(js,'bg',k,im,80)
what=sys.argv[1:] or ['all']
SIGN=(290,268,400,364)
put('assets/bg2.js',[('yard_father',L('1e080bf4'))])
put('assets/cg2.js',[('cg_father',L('3cfabff6'))])
put('assets/cg6.js',[('cg_quarrel',L('22352930'))])
put('assets/cg4.js',[('end_good1',L('7cb6ec2c')),('end_good2',L('7184b263')),('end_good3',L('6bd5ebfe'))])
import numpy as np
hit=L('32e68151'); a=np.asarray(hit).astype(int); b=np.asarray(L('81b1d677')).astype(int); x0,y0,x1,y1=SIGN
r,g,bb=[a[y0:y1,x0:x1,i] for i in range(3)]; hair=(r>g+35)&(bb>g+5)&(r<190)  # бордовые волосы поверх таблички — не трогать
from PIL import Image,ImageFilter
m=Image.fromarray((~hair*255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))
m=np.asarray(m)[...,None]/255.; a[y0:y1,x0:x1]=(b[y0:y1,x0:x1]*m+a[y0:y1,x0:x1]*(1-m)).astype(int)
hit=Image.fromarray(a.astype(np.uint8))
open('assets/cg10.js','w').write('window.ASSETS=window.ASSETS||{bg:{},sprites:{}};ASSETS.bg=ASSETS.bg||{};ASSETS.sprites=ASSETS.sprites||{};\n')
put('assets/cg10.js',[('cg_shoulders',L('50badadc')),('cg_hit',hit),('end_gone',L('763960f8')),('end_expo',L('bfa769f6')),
    ('end_home',L('7ee86a4a')),('end_letters',L('cbc4181f'))])
