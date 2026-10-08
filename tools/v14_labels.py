"""v14: чинит псевдотекст на лапше в фоне магазина: овалы «РОЛЛТОН», лотки «ДОШИРАК». fix(img, labels) -> img"""
from PIL import Image,ImageDraw,ImageFont,ImageFilter
import numpy as np
FONT='/usr/share/fonts/msttcore/arialbd.ttf'
R,D='РОЛЛТОН','ДОШИРАК'
# (cx, cy, w, h, angle, text) — координаты 1376x768, angle — как в PIL.rotate (против часовой)
STORE=[(64,207,52,17,0,R),(138,228,50,16,0,R),(194,245,44,15,0,R),(238,258,38,13,0,R),(280,268,36,12,0,R),(310,280,30,11,0,R),(347,290,30,10,0,R),
 (50,306,58,18,0,R),(138,315,48,16,0,R),(194,320,44,15,0,R),(240,325,38,13,0,R),(280,328,36,12,0,R),(316,334,30,11,0,R),(350,340,30,10,0,R),
 (326,134,26,9,0,R),(352,154,24,9,0,R),(326,178,24,9,0,R),(353,194,24,9,0,R),
 (8,4,22,10,-30,D),(81,33,58,15,-33,D),(158,82,50,15,-32,D),(221,106,48,14,-37,D),(282,140,44,13,-37,D),
 (40,540,68,17,14,D),(123,516,56,16,19,D),(197,492,52,15,20,D),
 (152,693,38,16,35,R),(207,663,32,14,40,R),(82,752,42,16,22,R),(4,221,12,14,0,'')]
def fix(img,labels=STORE,scale=1.0):
    img=img.convert('RGB'); a=np.asarray(img).astype(int)
    for cx,cy,w,h,ang,t in labels:
        cx,cy,w,h=cx*scale,cy*scale,w*scale,h*scale
        x0,y0,x1,y1=int(cx-w/2),int(cy-h/2),int(cx+w/2),int(cy+h/2)
        pts=a[max(0,y0):y1,max(0,x0):x1].reshape(-1,3); lum=pts.sum(1)
        bg=tuple(int(v) for v in np.median(pts[lum>=np.percentile(lum,60)],0))
        ink=tuple(int(v) for v in np.median(pts[lum<=np.percentile(lum,12)],0))
        ink=tuple(max(0,int(v*.8)) for v in ink)
        if t==R: ink=(min(255,ink[0]+60),int(ink[1]*.45),int(ink[2]*.4))
        S=4; W,Hh=int(w*S*1.15),int(h*S*1.5)
        lay=Image.new('RGBA',(W,Hh),(0,0,0,0)); d=ImageDraw.Draw(lay)
        d.ellipse((W*.04,Hh*.12,W*.96,Hh*.88),fill=bg+(255,)) if ang==0 or t==R else d.rounded_rectangle((W*.03,Hh*.15,W*.97,Hh*.85),radius=Hh*.2,fill=bg+(255,))
        fs=int(h*S*.95)
        if not t: f=ImageFont.truetype(FONT,8)
        while fs>6 and t:
            f=ImageFont.truetype(FONT,fs); bb=d.textbbox((0,0),t,font=f)
            if bb[2]-bb[0]<=w*S*.86 and bb[3]-bb[1]<=h*S*.78: break
            fs-=1
        bb=d.textbbox((0,0),t,font=f); d.text(((W-(bb[2]-bb[0]))/2-bb[0],(Hh-(bb[3]-bb[1]))/2-bb[1]),t,font=f,fill=ink+(255,))
        lay=lay.rotate(ang,resample=Image.BICUBIC,expand=True).resize((max(1,int(lay.width/S*1)) if False else int(lay.rotate(ang,expand=True).width/S),int(lay.rotate(ang,expand=True).height/S)),Image.LANCZOS)
        lay=lay.filter(ImageFilter.GaussianBlur(.35))
        img.paste(lay,(int(cx-lay.width/2),int(cy-lay.height/2)),lay)
    return img
if __name__=='__main__':
    import glob
    im=fix(Image.open(glob.glob('/data/.agent-service/files/a01badb2*/*')[0]))
    im.save('/tmp/store_fixed.jpg',quality=92)
    im.crop((0,0,560,420)).resize((1120,840)).save('/tmp/sf1.jpg'); im.crop((0,380,560,768)).resize((1120,776)).save('/tmp/sf2.jpg')
SHIFT=[(61,208,46,15,0,R),(138,227,42,14,0,R),(195,244,38,13,0,R),(238,257,32,11,0,R),(277,267,28,10,0,R),(316,280,28,9,0,R),(350,288,22,8,0,R),
 (61,307,48,15,0,R),(139,314,44,14,0,R),(195,320,38,13,0,R),(239,325,32,11,0,R),(277,328,28,10,0,R),(316,335,28,9,0,R),(350,339,22,8,0,R),
 (325,180,26,9,0,R),(352,194,22,8,0,R)]+[l for l in STORE if l[5]==D and l[0]!=197]+[(192,499,48,15,22,D),(149,695,38,16,35,R),(207,667,34,14,35,R),(88,748,42,16,20,R)]
