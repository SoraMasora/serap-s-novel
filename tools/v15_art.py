"""v15: «как будто рисовал художник» — CG перерисованы с нуля в стиле cg_reconcile (эталон 3c32e3e6) по референсам
Серы c111d158, героя 50bd2180, отца, Матвея. Запускать ПОСЛЕ v14_art.py. python3 tools/v15_art.py"""
import sys,glob; sys.path.insert(0,'tools')
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageFilter
from setasset import set_asset
F='/data/.agent-service/files/'; W,H=1376,768
def L(i):
    im=Image.open(glob.glob(F+i+'*/*')[0]).convert('RGB')
    return im if im.size==(W,H) else im.resize((W,H),Image.LANCZOS)
def put(js,items):
    for k,im in items: im.save(f'v13/{k}.jpg',quality=88); set_asset(js,'bg',k,im,80)
def sign(im,box=(292,270,398,362)):  # табличка «ПЛАТФОРМА 47 км» из эталона (тот же ракурс платформы)
    ref=L('3c32e3e6'); m=Image.new('L',im.size,0); ImageDraw.Draw(m).rectangle(box,fill=255); m=m.filter(ImageFilter.GaussianBlur(2))
    return Image.composite(ref,im,m)
def cuptext(im):  # «INSTANT NOODLE» на стакане → «Роллтон» в стиле картинки
    a=np.asarray(im).astype(float); x0,y0,x1,y1=38,543,100,569
    pts=a[y0:y1,x0:x1].reshape(-1,3); lum=pts.sum(1); cream=np.median(pts[lum>=np.percentile(lum,60)],0)
    m=Image.new('L',im.size,0); ImageDraw.Draw(m).rounded_rectangle((x0,y0,x1,y1),radius=6,fill=255); m=np.asarray(m.filter(ImageFilter.GaussianBlur(1.5)))[...,None]/255.
    a=a*(1-m)+cream*m; im=Image.fromarray(a.astype(np.uint8))
    S=4; lay=Image.new('RGBA',((x1-x0)*S,(y1-y0)*S),(0,0,0,0)); f=ImageFont.truetype('/usr/share/fonts/msttcore/georgiab.ttf',13*S)
    ImageDraw.Draw(lay).text((lay.width/2,lay.height/2),'Роллтон',font=f,fill=(160,72,55,235),anchor='mm')
    lay=lay.resize((x1-x0,y1-y0),Image.LANCZOS).filter(ImageFilter.GaussianBlur(.5)); im.paste(lay,(x0,y0),lay)
    return im
if __name__=='__main__':
    put('assets/bg2.js',[('cafe',L('00f751fa'))])
    put('assets/cg2.js',[('cg_father',L('bd2cc852'))])
    put('assets/cg3.js',[('cg_cafe',L('98f794a9')),('cg_study',L('2e13a52f')),('cg_jacket',L('6c0f4cea')),('cg_parapet',L('81e686c5')),('cg_swing',L('d1e3d583'))])
    put('assets/cg4.js',[('end_good1',L('52b87bc8')),('end_good2',L('013e4c14')),('end_good3',L('8851a21e'))])
    put('assets/cg5.js',[('end_neutral1',L('46cbccfd')),('end_neutral2',L('7d166740')),('end_neutral3',L('08710466'))])
    put('assets/cg6.js',[('cg_quarrel',L('382e0b21')),('cg_panic',L('1e68a120'))])
    put('assets/cg8.js',[('cg_clinic',L('bd0b7710'))])
    put('assets/cg9.js',[('cg_tea',L('ab2180ec')),('cg_dumplings',L('afd66bd4')),('cg_store_help',L('58019d34')),('cg_canvas',L('3aa27d4f')),('cg_sing',L('4183b291')),('cg_take',L('fba82ec9'))])
    put('assets/cg10.js',[('cg_hit',sign(L('cd7a9416'))),('cg_shoulders',L('3fd9bd00')),('end_expo',L('026abf55')),('end_home',L('cae09eea')),('end_letters',cuptext(L('38523d1b')))])
