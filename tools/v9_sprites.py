"""v9: новый герой (7 эмоций, кадр макушка–бёдра 1120×1494) и новый Тимур (3 эмоции, вписан в канву старого спрайта)."""
import sys,re,base64,io,glob,numpy as np
from PIL import Image
sys.path.insert(0,'tools'); from key3 import key
F='/data/.agent-service/files/'
HERO={'neutral':'50bd2180-27c6-4e06-8447-c8f9cd399765','grin':'17f06dad-502b-44ad-a530-febc70091403','serious':'be6ca624-ea4c-40b3-b344-89bfe55b4949',
 'shy':'d6c6b889-0125-4989-a625-d9d8cdb21630','surprised':'6967ea18-73f2-4a9c-b020-d1223492c9e7','sad':'e0471622-64d3-458e-b407-b98a943bd77f','soft':'d1e746ab-0db0-4d4a-aff2-354810c94e7c'}
TIMUR={'timur':'3cc50d3d-7e5f-4724-9dbd-9eab56d4fd1d','timur_grin':'35e9c4e7-6143-4c38-a889-6652a73ba6f0','timur_serious':'1592f451-93c8-4a1f-990a-7a217e17e05f'}
P=lambda i: glob.glob(F+i+'/*')[0]
for e,i in HERO.items():
    im=key(P(i),1.25,strict=False); im.save(f'new9/hero_{e}.png'); print('hero',e,im.size)
src=open('assets/sprites6.js').read()
m=re.search(r"\['timur'\]='data:image/\w+;base64,([^']*)'",src)
o=Image.open(io.BytesIO(base64.b64decode(m.group(1)))).convert('RGBA'); oa=np.array(o)[...,3]
ob=Image.fromarray(oa).point(lambda v:255 if v>40 else 0).getbbox()
def legs_cx(a): h=a.shape[0]; ys,xs=np.nonzero(a[int(h*0.7):]>128); return xs.mean()
cx_old=legs_cx(oa[ob[1]:ob[3],:])
for k,i in TIMUR.items():
    im=key(P(i),1.0,strict=False); a=np.array(im)[...,3]
    bb=Image.fromarray(a).point(lambda v:255 if v>40 else 0).getbbox(); im=im.crop(bb)
    s=(ob[3]-ob[1])*1.0/im.height; im=im.resize((round(im.width*s),round(im.height*s)),Image.LANCZOS)
    cx=legs_cx(np.array(im)[...,3]); W=max(o.width,im.width+40)
    cv=Image.new('RGBA',(W,o.height),(0,0,0,0)); x=round(cx_old+(W-o.width)/2-cx)
    cv.alpha_composite(im,(x,ob[3]-im.height)); cv.save(f'new9/{k}.png'); print(k,cv.size,im.size)
