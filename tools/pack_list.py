"""pack_list.py prefix key=path ... → assets/<prefix>N.js по ≤900 КБ (ASSETS.sprites). Картинки PNG конвертируются в webp q90."""
import sys,base64,io,os,glob
from PIL import Image
prefix=sys.argv[1]; items=[a.split('=',1) for a in sys.argv[2:]]
def b64(p):
    if p.endswith('.webp'): return base64.b64encode(open(p,'rb').read()).decode()
    b=io.BytesIO(); Image.open(p).save(b,'WEBP',quality=90,method=6); return base64.b64encode(b.getvalue()).decode()
for f in glob.glob(f'assets/{prefix}[0-9]*.js'): os.remove(f)
packs=[];cur=[];size=0
for k,p in items:
    s=b64(p)
    if cur and size+len(s)>900_000: packs.append(cur);cur=[];size=0
    cur.append((k,s));size+=len(s)
packs.append(cur)
for i,pk in enumerate(packs,1):
    fn=f'assets/{prefix}{i}.js'
    with open(fn,'w') as o:
        o.write("window.ASSETS=window.ASSETS||{bg:{},sprites:{}};ASSETS.sprites=ASSETS.sprites||{};\n")
        for k,s in pk: o.write(f"ASSETS.sprites['{k}']='data:image/webp;base64,{s}';\n")
    print(fn,os.path.getsize(fn)//1024,'KB',[k for k,_ in pk])
