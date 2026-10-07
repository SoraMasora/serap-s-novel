"""Упаковывает new/*.webp (Сера) в assets/seraN.js по ~900 КБ."""
import base64, glob, os
files=sorted(glob.glob('new/sera_*.webp'))+['new/blink_neutral.webp']
packs=[];cur=[];size=0
for f in files:
    b=base64.b64encode(open(f,'rb').read()).decode()
    k=os.path.basename(f)[:-5]
    if cur and size+len(b)>900_000: packs.append(cur);cur=[];size=0
    cur.append((k,b));size+=len(b)
packs.append(cur)
for f in glob.glob('assets/sera*.js'): os.remove(f)
for i,p in enumerate(packs,1):
    with open(f'assets/sera{i}.js','w') as o:
        o.write("window.ASSETS=window.ASSETS||{bg:{},sprites:{}};ASSETS.sprites=ASSETS.sprites||{};\n")
        for k,b in p: o.write(f"ASSETS.sprites['{k}']='data:image/webp;base64,{b}';\n")
    print(f'sera{i}.js',os.path.getsize(f'assets/sera{i}.js'),[k for k,_ in p])
