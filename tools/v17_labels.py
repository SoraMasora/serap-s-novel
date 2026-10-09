"""v17.2: «Роллтон»/«Доширак» в store и cg_shift — дорисованы генератором (правка увеличенных кропов artist-кадра),
патчи вклеиваются с растушёвкой. Заменяет v14_labels.fix. compose(artist(store)), compose_shift(artist(cg_shift))"""
import glob
import numpy as np
from PIL import Image, ImageFilter
F='/data/.agent-service/files/'
def L(i): return Image.open(glob.glob(F+i+'*/*')[0]).convert('RGB')
def feather(size,m=10,blur=6):
    a=Image.new('L',size,0); a.paste(255,(m,m,size[0]-m,size[1]-m)); return a.filter(ImageFilter.GaussianBlur(blur))
def paste(dst,src,box):
    x,y,w,h=box; s=src.resize((w,h),Image.LANCZOS); dst.paste(s,(x,y),feather((w,h)))
GEN_TOP,GEN_BOT='30a8009b','5174b7e1'          # правки кропов (0,0,688,384) и (0,384,688,768), ×2
CUPS,SMALL,PACK='ffd99ee0','af393e58','d6d115bd' # правки увеличенных кропов внутри GEN_TOP/GEN_BOT
def compose(base):
    base=base.convert('RGB').copy()
    gt=L(GEN_TOP); paste(gt,L(CUPS),(380,430,440,245)); paste(gt,L(SMALL),(480,226,380,212))
    gb=L(GEN_BOT); paste(gb,L(PACK),(0,450,560,313))
    gt=gt.resize((688,384),Image.LANCZOS); gb=gb.resize((688,384),Image.LANCZOS)
    m=Image.new('L',(688,384),0); m.paste(255,(0,0,430,372)); base.paste(gt,(0,0),m.filter(ImageFilter.GaussianBlur(5)))
    m=Image.new('L',(688,384),0); m.paste(255,(0,60,296,384)); m=m.filter(ImageFilter.GaussianBlur(5))
    mm=np.asarray(m).copy(); mm[-6:,:]=np.asarray(m)[-7:-6,:]
    base.paste(gb,(0,384),Image.fromarray(mm))
    return base
def _mask(box,W,H,m=4,blur=3):
    x,y,w,h=box; a=Image.new('L',(w,h),0)
    l=0 if x<=0 else m; t=0 if y<=0 else m; r=w if x+w>=W else w-m; b=h if y+h>=H else h-m
    a.paste(255,(l,t,r,b)); a=a.filter(ImageFilter.GaussianBlur(blur)); A=np.asarray(a).copy(); k=blur*2
    if x<=0: A[:,:k]=A[:,k:k+1]
    if y<=0: A[:k,:]=A[k:k+1,:]
    if x+w>=W: A[:,-k:]=A[:,-k-1:-k]
    if y+h>=H: A[-k:,:]=A[-k-1:-k,:]
    return Image.fromarray(A)
# cg_shift: (id, кроп x0,y0,x1,y1 в 1376×768[, clip]); порядок наложения важен
SHIFT_P=[('3d8f7273',(0,0,340,191)),('520d95a2',(0,170,373,380)),('30487c18',(240,113,430,220),(298,0,1376,768)),
         ('e55cb5b3',(190,215,410,339)),('4bb61568',(0,440,300,609)),('fad50ae2',(0,610,280,768))]
def compose_boxes(base,patches):
    base=base.convert('RGB').copy(); W,H=base.size
    for i,(x0,y0,x1,y1),*clip in patches:
        w,h=x1-x0,y1-y0; p=L(i).resize((w,h),Image.LANCZOS); m=_mask((x0,y0,w,h),W,H)
        if clip:
            c=Image.new('L',(W,H),0); c.paste(255,clip[0]); c=c.filter(ImageFilter.GaussianBlur(2)).crop((x0,y0,x1,y1))
            m=Image.fromarray((np.asarray(m,float)*np.asarray(c,float)/255).astype(np.uint8))
        base.paste(p,(x0,y0),m)
    return base
def compose_shift(base): return compose_boxes(base,SHIFT_P)
def fix_take(im):
    """cg_take: стереть псевдобуквы в шапке листовки на доске объявлений"""
    a=np.asarray(im.convert('RGB')).astype(float); y0,y1,x0,x1=363,377,773,812
    paper=np.median(a[y0:y1,x0:x1].reshape(-1,3),0)
    b=np.asarray(im.convert('RGB').filter(ImageFilter.GaussianBlur(3))).astype(float)[y0:y1,x0:x1]
    a[y0:y1,x0:x1]=.5*b+.5*paper; return Image.fromarray(a.clip(0,255).astype(np.uint8))
