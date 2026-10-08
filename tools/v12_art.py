"""v12: перерисованные фоны/CG в стиле Серы (мягкий cel shading). python3 tools/v12_art.py [bg] [cg]"""
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
what=sys.argv[1:] or ['bg','cg']
def put(js,items):
    for k,im in items: im.save(f'v12/{k}.jpg',quality=88); set_asset(js,'bg',k,im,80)
if 'bg' in what:
    st=L('a01badb2'); st=ImageOps.autocontrast(st,cutoff=1); st=ImageEnhance.Contrast(st).enhance(1.12); st=ImageEnhance.Color(st).enhance(1.15)
    put('assets/bg1.js',[('store',st),('stairs',L('fe028b72')),('room',L('99058e8c')),('roof',L('cb8d1bb8'))])
    put('assets/bg2.js',[('cafe',L('71dc983e')),('empty',L('70f36daf')),('street',L('bbc8b401')),('kitchen',L('ae263cf4')),('yard',L('e086596b'))])
    put('assets/bg3.js',[('court',L('ea81bcdd')),('college',L('e3b584ba'))])
    put('assets/bg4.js',[('street_rain',L('f6f6e73d')),('heroroom',L('efda7b40'))])
    put('assets/bg5.js',[('platform',L('81b1d677')),('underpass',L('c2ed6663')),('clinic',L('751fc850'))])
if 'cg' in what:
    put('assets/cg1.js',[('bug1',L('7b4176c9')),('bug2',L('744a00a7')),('bug3',L('4036f382')),('bug4',L('129d689b')),('bug_art',L('3b518bc5'))])
    put('assets/cg2.js',[('cg_shift',L('8d11b5a1')),('cg_father',L('9c538134'))])
    s=Image.open(glob.glob(F+'bc8a596e*/*')[0]).convert('RGB'); s=s.crop((0,62,s.width,62+round(s.width*H/W))).resize((W,H),Image.LANCZOS)
    put('assets/cg3.js',[('cg_cafe',L('472bb106')),('cg_roof',L('5d9e560e')),('cg_study',s),('cg_swing',L('596a1c7f')),('cg_parapet',L('b79daa13')),('cg_jacket',L('4ecfe31d'))])
    g1=L('088cd0bd'); b1=L('a956cd06'); b3=comp(b1,L('0a528105'),thr=30)
    b2=Image.blend(b1,b3,.55)
    put('assets/cg4.js',[('end_good1',g1),('end_good2',comp(g1,L('8ea63c06'))),('end_good3',comp(g1,L('a981f784'))),('end_bad1',b1),('end_bad2',b2),('end_bad3',b3)])
    n1=L('ffe9a71d')
    put('assets/cg5.js',[('end_neutral1',n1),('end_neutral2',comp(n1,L('570df234'))),('end_neutral3',comp(n1,L('23810592')))])
    l1=L('3ac16c32')
    put('assets/cg6.js',[('cg_leaflet1',l1),('cg_leaflet2',comp(l1,L('6ba4e4b7'))),('cg_quarrel',L('5c923d98')),('cg_panic',L('c3488804'))])
    SIGN=(290,268,400,364); bg=L('81b1d677')
    pl=L('19b081a7'); pl.paste(bg.crop(SIGN),SIGN[:2])
    def fix(im): im.paste(bg.crop(SIGN),SIGN[:2]); return im
    put('assets/cg7.js',[('cg_platform',pl),('cg_train1',fix(match(L('053b2fe1'),pl))),('cg_train2',fix(match(L('79df70e0'),pl))),('cg_reconcile',fix(match(L('9ec41798'),pl)))])
    put('assets/cg8.js',[('cg_angel',L('153c9b66')),('cg_clinic',L('ce18f443'))])
if 'cg9' in what or 'cg' in what:  # v12: CG-реакции на выборы
    open('assets/cg9.js','w').write('window.ASSETS=window.ASSETS||{bg:{},sprites:{}};ASSETS.bg=ASSETS.bg||{};ASSETS.sprites=ASSETS.sprites||{};\n')
    put('assets/cg9.js',[('cg_store_help',L('1d8fe53d')),('cg_roof_quiet',L('5d93ffaa')),('cg_guests',L('b3347669')),('cg_tea',L('937cb55e')),
        ('cg_sing',L('96ffb00e')),('cg_take',L('bce50dcc')),('cg_dumplings',L('c0447906')),('cg_canvas',L('86404925'))])
