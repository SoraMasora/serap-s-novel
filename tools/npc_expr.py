"""Новые эмоции NPC/героя: хромакей → вписать в канву исходного спрайта (по росту и ногам)."""
import sys,re,base64,io,glob,numpy as np,cv2
from PIL import Image, ImageOps
sys.path.insert(0,'tools'); from key3 import key
F='/data/.agent-service/files/'
JOBS={ # ключ: (session id, исходный спрайт, фон)
 'father_angry':('3eceaa66-a097-4759-8cab-b44958582245','father','g'),
 'father_pray':('9fbd8001-50c5-498e-b5e6-f23af2182032','father','g'),
 'valya_laugh':('5b2513cb-e926-4ebe-8752-07ae6c17fde3','valya','g'),
 'valya_worry':('1b3072b3-6bd5-492c-ab8d-c85e6397afd8','valya','g'),
 'timur_grin':('885f5f44-e75a-492c-a6d2-6664f099cb30','timur','m'),
 'timur_serious':('492c264a-79d0-4e8b-8cfc-f70039203cc7','timur','m'),
 'liza_pout':('e43d6761-f52b-4131-a181-71cd59be1fd2','liza','g'),
 'liza_wow':('4c6885c3-183e-481d-9adb-d81a1d789fed','liza','g'),
 'margo_smile':('2be05772-2973-4255-baec-2fe72a9635eb','margo','g'),
 'margo_strict':('95107785-bb78-4f19-9d57-914128f35b6a','margo','g'),
 'hero_shy':('b1e158d3-5772-422b-a263-1a08412105ed','hero_neutral','g'),
 'hero_surprised':('7286a6be-17ed-4761-addf-893f43b59a9b','hero_neutral','g'),
}
src=''.join(open(f).read() for f in glob.glob('assets/sprites*.js'))
def orig(k):
    m=re.search(r"ASSETS\.sprites\['%s'\]='data:image/\w+;base64,([^']*)'"%k,src)
    return Image.open(io.BytesIO(base64.b64decode(m.group(1)))).convert('RGBA')
def legs_cx(a):
    h=a.shape[0]; ys,xs=np.nonzero(a[int(h*0.7):]>128); return xs.mean()
for k,(sid,base,bg) in JOBS.items():
    p=glob.glob(F+sid+'/*')[0]
    if bg=='m':
        inv=ImageOps.invert(Image.open(p).convert('RGB')); inv.save('/tmp/inv.png')
        al=np.array(key('/tmp/inv.png',1.0,strict=False))[...,3]
        rgb=np.array(Image.open(p).convert('RGB')).astype(np.int16)
        r,g,b=rgb[...,0],rgb[...,1],rgb[...,2]; edge=al<250
        lim=np.maximum(g,np.minimum(r,b)-40)
        rgb[...,0]=np.where(edge,np.minimum(r,g+25),r); rgb[...,2]=np.where(edge,np.minimum(b,np.maximum(g,r)+30),b)
        im=Image.fromarray(np.dstack([np.clip(rgb,0,255).astype(np.uint8),al]),'RGBA')
    else:
        im=key(p,1.0,strict=False)
    a=np.array(im); bb=Image.fromarray(a[...,3]).point(lambda v:255 if v>40 else 0).getbbox(); im=im.crop(bb)
    o=orig(base); oa=np.array(o)[...,3]; ob=Image.fromarray(oa).point(lambda v:255 if v>40 else 0).getbbox()
    s=(ob[3]-ob[1])/im.height; im=im.resize((round(im.width*s),round(im.height*s)),Image.LANCZOS)
    na=np.array(im)[...,3]; cx_new=legs_cx(na); cx_old=legs_cx(oa[ob[1]:ob[3],:])
    canvas=Image.new('RGBA',o.size,(0,0,0,0))
    x=round(cx_old-cx_new); y=ob[3]-im.height
    canvas.alpha_composite(im,(max(0,x),y)) if x>=0 else canvas.alpha_composite(im.crop((-x,0,im.width,im.height)),(0,y))
    canvas.save(f'new8/{k}.png'); print(k,o.size,im.size,x,y)
