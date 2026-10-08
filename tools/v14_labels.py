"""v14: чинит псевдотекст на лапше в фоне магазина: овалы «РОЛЛТОН», лотки «ДОШИРАК». fix(img, labels) -> img"""
from PIL import Image,ImageDraw,ImageFont,ImageFilter
import numpy as np
FONT='/usr/share/fonts/msttcore/arialbd.ttf'
R,D='РОЛЛТОН','ДОШИРАК'
# (cx, cy, w, h, angle, text) — координаты 1376x768, angle — как в PIL.rotate (против часовой)
STORE=[(60,207,50,17,0,R),(138,228,50,16,0,R),(194,245,44,15,0,R),(238,258,38,13,0,R),(280,268,36,12,0,R),(310,280,30,11,0,R),(347,290,30,10,0,R),
 (60,306,50,20,0,R),(138,315,48,16,0,R),(194,320,44,15,0,R),(240,325,38,13,0,R),(280,328,36,12,0,R),(316,334,30,11,0,R),(350,340,30,10,0,R),
 (326,134,26,9,0,R),(352,154,24,9,0,R),(326,178,24,9,0,R),(353,194,24,9,0,R),
 (8,4,22,10,-30,D),(81,33,58,15,-33,D),(158,82,50,15,-32,D),(221,106,48,14,-37,D),(282,140,44,13,-37,D),
 (40,540,68,17,14,D),(123,516,56,16,19,D),(197,492,52,15,20,D),
 (150,695,42,19,35,R),(208,665,40,18,33,R),(87,746,46,19,27,R),(4,221,12,14,0,'')]
def _font(path,t,w,h,S):
    fs=int(h*S*1.2)
    while fs>6:
        f=ImageFont.truetype(path,fs); bb=f.getbbox(t,stroke_width=int(fs*.09))
        if bb[2]-bb[0]<=w*S and bb[3]-bb[1]<=h*S: return f
        fs-=1
    return ImageFont.truetype(path,6)
def fix(img,labels=STORE,scale=1.0):
    """v14.1: без наклеек. Стаканы: внутренность родного овала перекрашивается его же кремовым цветом (контур овала остаётся),
    надпись — цветом старых букв. Лотки: псевдотекст стирается inpaint, «Доширак» рисуется кремовым с тёмной обводкой."""
    import cv2
    img=img.convert('RGB'); src=np.asarray(img).copy(); a=src.copy()
    mask=np.zeros(a.shape[:2],np.uint8)
    for cx,cy,w,h,ang,t in labels:
        if t==D: cv2.fillPoly(mask,[cv2.boxPoints(((cx*scale,cy*scale),(w*scale*1.12,h*scale*1.35),-ang)).astype(np.int32)],255)
    a=cv2.inpaint(a,mask,5,cv2.INPAINT_TELEA)
    info=[]
    for cx,cy,w,h,ang,t in labels:
        cx,cy,w,h=cx*scale,cy*scale,w*scale,h*scale
        m=np.zeros(a.shape[:2],np.uint8)
        if t==D: cv2.fillPoly(m,[cv2.boxPoints(((cx,cy),(w,h),-ang)).astype(np.int32)],255)
        else: cv2.ellipse(m,((cx,cy),(w*.84,h*.70),-ang),255,-1)
        pts=src[m>0].astype(int); lum=pts.sum(1)
        light=np.median(pts[lum>=np.percentile(lum,55)],0); dark=np.median(pts[lum<=np.percentile(lum,10)],0)
        if t!=D:  # заливка внутренности овала его же цветом, мягкий край
            mm=cv2.GaussianBlur(m.astype(float)/255,(0,0),.7)[...,None]
            a=(a*(1-mm)+light[None,None,:]*mm).astype(np.uint8)
        info.append((cx,cy,w,h,ang,t,light,dark))
    out=Image.fromarray(a)
    for cx,cy,w,h,ang,t,light,dark in info:
        if not t: continue
        S=4
        if t==R:
            txt='Роллтон'; fill=tuple(int(v) for v in dark); stroke=None
            f=_font('/usr/share/fonts/msttcore/georgiab.ttf',txt,w*.74,h*.58,S)
        else:
            txt='Доширак'; fill=tuple(int(min(255,.4*l+.6*c)) for l,c in zip(light,(255,240,180))); stroke=tuple(int(v*.8) for v in dark)
            f=_font('/usr/share/fonts/msttcore/comicbd.ttf',txt,w*1.04,h*1.15,S)
        sw=max(1,int(f.size*.12)) if stroke else 0
        bb=f.getbbox(txt,stroke_width=sw); W,Hh=bb[2]-bb[0]+8*S,bb[3]-bb[1]+8*S
        lay=Image.new('RGBA',(W,Hh),(0,0,0,0)); d=ImageDraw.Draw(lay)
        d.text((4*S-bb[0],4*S-bb[1]),txt,font=f,fill=fill+(255,),stroke_width=sw,stroke_fill=(stroke+(255,)) if stroke else None)
        lay=lay.rotate(ang,resample=Image.BICUBIC,expand=True)
        lay=lay.resize((max(1,lay.width//S),max(1,lay.height//S)),Image.LANCZOS).filter(ImageFilter.GaussianBlur(.5))
        out.paste(lay,(int(round(cx-lay.width/2)),int(round(cy-lay.height/2))),lay)
    return out
SHIFT=[(61,208,46,15,0,R),(138,227,42,14,0,R),(195,244,38,13,0,R),(238,257,32,11,0,R),(277,267,28,10,0,R),(316,280,28,9,0,R),(350,288,22,8,0,R),
 (61,307,48,15,0,R),(139,314,44,14,0,R),(195,320,38,13,0,R),(239,325,32,11,0,R),(277,328,28,10,0,R),(316,335,28,9,0,R),(350,339,22,8,0,R),
 (326,134,26,9,0,R),(352,154,24,9,0,R),(325,180,26,9,0,R),(352,194,22,8,0,R)]+[l for l in STORE if l[5]==D and l[0]!=197]+[(192,499,48,15,22,D),(150,695,42,19,35,R),(208,665,40,18,33,R),(87,746,46,19,27,R)]
if __name__=='__main__':
    import glob
    im=fix(Image.open(glob.glob('/data/.agent-service/files/a01badb2*/*')[0]))
    im.crop((0,0,380,360)).resize((760,720)).save('/data/tmp/sf1.jpg'); im.crop((0,460,260,768)).resize((780,924)).save('/data/tmp/sf2.jpg')
    im2=fix(Image.open(glob.glob('/data/.agent-service/files/1fc6931f*/*')[0]),SHIFT); im2.crop((0,0,380,360)).resize((760,720)).save('/data/tmp/sh1.jpg'); im2.crop((0,460,260,768)).resize((780,924)).save('/data/tmp/sh2.jpg')
