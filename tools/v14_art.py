"""v14: надписи РОЛЛТОН/ДОШИРАК, новый Тимур в cg_shift, cg_study в комнате Серы, cg_roof_quiet без рук и мокрая крыша,
мокрые court/roof, cg_shoulders в стиле игры, новый cg_walkhome. python3 tools/v14_art.py"""
import sys,glob; sys.path.insert(0,'tools')
import numpy as np
from PIL import Image,ImageFilter
from setasset import set_asset
from v14_labels import fix,STORE,SHIFT
F='/data/.agent-service/files/'; W,H=1376,768
def L(i):
    im=Image.open(glob.glob(F+i+'*/*')[0]).convert('RGB')
    return im if im.size==(W,H) else im.resize((W,H),Image.LANCZOS)
def put(js,items):
    for k,im in items: im.save(f'v13/{k}.jpg',quality=88); set_asset(js,'bg',k,im,80)
SIGN=(290,268,400,364)
def sign(im):  # табличка «ПЛАТФОРМА 47 км» из фона, волосы поверх не трогаем
    a=np.asarray(im).astype(int); b=np.asarray(L('81b1d677')).astype(int); x0,y0,x1,y1=SIGN
    r,g,bb=[a[y0:y1,x0:x1,i] for i in range(3)]; hair=(r>g+35)&(bb>g+5)&(r<190)
    m=Image.fromarray((~hair*255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))
    m=np.asarray(m)[...,None]/255.; a[y0:y1,x0:x1]=(b[y0:y1,x0:x1]*m+a[y0:y1,x0:x1]*(1-m)).astype(int)
    return Image.fromarray(a.astype(np.uint8))
from PIL import ImageEnhance,ImageOps
st=fix(L('a01badb2'),STORE); st=ImageOps.autocontrast(st,cutoff=1); st=ImageEnhance.Contrast(st).enhance(1.12); st=ImageEnhance.Color(st).enhance(1.15)
put('assets/bg1.js',[('store',st),('roof',L('e24ad84e'))])
put('assets/bg3.js',[('court',L('4bb8df48'))])
put('assets/cg2.js',[('cg_shift',fix(L('1fc6931f'),SHIFT))])
put('assets/cg3.js',[('cg_study',L('c778cad6'))])
put('assets/cg9.js',[('cg_roof_quiet',L('92e24c45')),('cg_guests',L('e7612b13')),('cg_tea',L('afd66bd4'))])  # v14.2: на-модельные Сера и герой в стиле cg_platform
put('assets/cg10.js',[('cg_shoulders',sign(L('ce43e73f'))),('cg_walkhome',L('4ea25c57'))])
