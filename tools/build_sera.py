import sys, numpy as np
sys.path.insert(0,'tools')
from key3 import key
from PIL import Image, ImageFilter
S=1.25
names='neutral cold angry pout shy sad smirk disgust laugh ouch saddown sadfrown sadwipe scared soft surprised suspicious tease thinking tired tongue happy lean'.split()
only=sys.argv[1:] or names
for n in only:
    im=key(f'gen/g_{n}.jpg', S, strict=(n!='happy'))
    if n=='lean':
        W,H=im.size; s=0.9
        sm=im.resize((round(W*s),round(H*s)),Image.LANCZOS)
        c=Image.new('RGBA',(W,H),(0,0,0,0)); c.alpha_composite(sm,(-40,30)) if False else c.paste(sm,(-40,30),sm)
        im=c
    im.save(f'new/sera_{n}.webp','WEBP',quality=88,method=6)
    print(n, im.size)
# моргание
if 'neutral' in only or not sys.argv[1:]:
    b=key('gen/g_blink.jpg', S)
    x0,y0,x1,y1=[round(v*S) for v in (340,180,535,285)]
    ov=b.crop((x0,y0,x1,y1))
    a=np.array(ov).astype(np.float32)
    h,w=a.shape[:2]; f=10
    yy=np.minimum(np.arange(h),np.arange(h)[::-1])[:,None]; xx=np.minimum(np.arange(w),np.arange(w)[::-1])[None,:]
    feather=np.clip(np.minimum(yy,xx)/f,0,1)
    a[...,3]*=feather
    Image.fromarray(a.astype(np.uint8),'RGBA').save('new/blink_neutral.webp','WEBP',quality=90)
    W,H=b.size
    print('blink css: left %.3f%% top %.3f%% width %.3f%% height %.3f%%'%(x0/W*100,y0/H*100,(x1-x0)/W*100,(y1-y0)/H*100))
