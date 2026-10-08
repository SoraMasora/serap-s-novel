"""end_frames.py — кадры анимированных концовок: правленые кадры вклеиваются в базу по маске различий
(фон не «дрожит»), bad2 = смесь 50% силуэта и пустой комнаты. → assets/cg4.js (good, bad), cg5.js (neutral)"""
import sys; sys.path.insert(0,'tools')
import numpy as np
from PIL import Image, ImageFilter
from setasset import set_asset
F='/data/.agent-service/files/'
def L(i): return Image.open(F+i+'/tool-output-0.jpg').convert('RGB')
def comp(base,img,thr=38,grow=31,blur=25):
    if img.size!=base.size: img=img.resize(base.size,Image.LANCZOS)
    a=np.asarray(base).astype(np.int16); b=np.asarray(img).astype(np.int16)
    d=Image.fromarray((np.abs(a-b).max(2)>thr).astype(np.uint8)*255).filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.MaxFilter(grow)).filter(ImageFilter.GaussianBlur(blur))
    m=np.asarray(d).astype(np.float32)[...,None]/255
    print(' changed %.1f%%'%(100*(m>.5).mean()))
    return Image.fromarray((a*(1-m)+b*m).clip(0,255).astype(np.uint8))
g1=L('7420fc12-62d4-47c0-84a0-70887c99dfb1'); g2=comp(g1,L('79f77624-8c9e-439b-9287-33bcbdef20ab')); g3=comp(g2,L('5d62960f-a15d-4a3a-9df6-c67fafb0295a'))
n1=L('e584b9aa-aacf-4f04-94b1-665f274874e8'); n2=comp(n1,L('7c4ea281-f8c1-4544-a430-af30b6ad2cbb')); n3=comp(n1,L('24a5607c-29ed-4dd9-a7b6-e42d146ec50f'))
b1=L('6c738bd7-4528-4bc9-947b-645328b77e8e'); b3=L('90798294-425d-42af-8856-f7e85b674945').resize(b1.size); b2=Image.blend(b1,b3,.55)  # bad3 целиком: маска не ловит полупрозрачный силуэт
H="window.ASSETS=window.ASSETS||{bg:{},sprites:{}};ASSETS.bg=ASSETS.bg||{};\n"
for js in ('assets/cg4.js','assets/cg5.js'): open(js,'w').write(H)
for k,im in [('end_good1',g1),('end_good2',g2),('end_good3',g3),('end_neutral1',n1),('end_neutral2',n2),('end_neutral3',n3),('end_bad1',b1),('end_bad2',b2),('end_bad3',b3)]:
    im.save(f'/tmp/{k}.jpg',quality=90); set_asset('assets/cg5.js' if 'neutral' in k else 'assets/cg4.js','bg',k,im,80)
