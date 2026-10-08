"""setasset.py file.js kind key image [q] [maxw] — заменить/добавить ASSETS[kind][key] webp-картинкой."""
import sys,re,base64,io,os
from PIL import Image
def set_asset(js,kind,key,img,q=86,maxw=None,mode='RGB'):
    im=Image.open(img) if isinstance(img,str) else img
    im=im.convert(mode)
    if maxw and im.width>maxw: im=im.resize((maxw,round(im.height*maxw/im.width)),Image.LANCZOS)
    b=io.BytesIO(); im.save(b,'WEBP',quality=q,method=6)
    line="ASSETS.%s['%s']='data:image/webp;base64,%s';"%(kind,key,base64.b64encode(b.getvalue()).decode())
    s=open(js).read() if os.path.exists(js) else ''
    pat=re.compile(r"ASSETS\.%s\['%s'\]='[^']*';"%(kind,key))
    if pat.search(s): s=pat.sub(lambda m:line,s)
    else: s=s.rstrip('\n')+'\n'+line+'\n'
    open(js,'w').write(s); print(js,key,im.size,len(b.getvalue())//1024,'KB')
if __name__=='__main__':
    a=sys.argv; set_asset(a[1],a[2],a[3],a[4],int(a[5]) if len(a)>5 else 86,int(a[6]) if len(a)>6 else None)
