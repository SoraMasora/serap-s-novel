"""v10 (глава 3 «Трещины»): кадры анимаций Серы (chain/shout/vsign), Матвей, фоны platform/underpass/clinic, CG главы 3.
Анимации Серы — стабилизация по мастеру (как sera_anim.py) → assets/anim4.js; Матвей → assets/npc2.js;
фоны → assets/bg5.js; CG → assets/cg6.js, cg7.js, cg8.js."""
import sys,glob,io,base64,numpy as np,cv2
from PIL import Image, ImageFilter
sys.path.insert(0,'tools'); from key3 import key; from setasset import set_asset
F='/data/.agent-service/files/'
def L(i): return Image.open(glob.glob(F+i+'/*')[0]).convert('RGB')
H="window.ASSETS=window.ASSETS||{bg:{},sprites:{}};ASSETS.bg=ASSETS.bg||{};ASSETS.sprites=ASSETS.sprites||{};\n"
what=sys.argv[1:] or ['sera','npc','bg','cg']
# ── анимации Серы ──
FR={'chain1':'40fc2f86-a412-4219-bd40-38bb401b8cae','chain2':'94bc026a-87e6-40ff-ae5e-f55e634eb227',
 'shout1':'fcbaec1b-d52c-4f72-98c4-4ba91d8ca5c1','shout2':'304dbd58-711f-4b60-b292-0d8acbf1caa2',
 'vsign1':'98e025ba-cbd7-4e9b-90dd-385453b75ecd','vsign2':'e5eebe87-9b42-4d30-bf51-95a0f6de755a'}
if 'sera' in what:
    M=cv2.imread('gen/g_neutral.jpg'); Hh,W=M.shape[:2]
    sift=cv2.SIFT_create(6000); km,dm=sift.detectAndCompute(cv2.cvtColor(M,cv2.COLOR_BGR2GRAY),None)
    for k,sid in FR.items():
        B=cv2.imread(glob.glob(F+sid+'/*')[0]); B=cv2.resize(B,(W,Hh)) if B.shape[:2]!=(Hh,W) else B
        kb,db=sift.detectAndCompute(cv2.cvtColor(B,cv2.COLOR_BGR2GRAY),None)
        mm=cv2.BFMatcher().knnMatch(db,dm,k=2); good=[a for a,b in mm if a.distance<0.7*b.distance]
        Hm,inl=cv2.findHomography(np.float32([kb[x.queryIdx].pt for x in good]),np.float32([km[x.trainIdx].pt for x in good]),cv2.RANSAC,3.0)
        Bw=cv2.warpPerspective(B,Hm,(W,Hh),flags=cv2.INTER_LANCZOS4,borderValue=(0,255,0))
        d=cv2.absdiff(cv2.GaussianBlur(M,(0,0),2),cv2.GaussianBlur(Bw,(0,0),2)).max(2)
        m=(d>28).astype(np.uint8); m=cv2.morphologyEx(m,cv2.MORPH_OPEN,np.ones((3,3),np.uint8)); m=cv2.dilate(m,np.ones((31,31),np.uint8))
        n,lab,st,_=cv2.connectedComponentsWithStats(m); keep=np.zeros_like(m)
        for i in range(1,n):
            if st[i,4]>2500: keep[lab==i]=1
        mf=np.clip(cv2.GaussianBlur(keep.astype(np.float32),(0,0),9)*1.6,0,1)[...,None]
        out=(Bw*mf+M*(1-mf)).astype(np.uint8); cv2.imwrite(f'v10/a_{k}.png',out)
        key(f'v10/a_{k}.png',1.25).save(f'new10/sera_{k}.webp','WEBP',quality=90,method=6)
        print(k,len(good),int(inl.sum()),round(float(mf.mean()),3))
    open('assets/anim4.js','w').write(H+''.join("ASSETS.sprites['sera_%s']='data:image/webp;base64,%s';\n"%(k,base64.b64encode(open(f'new10/sera_{k}.webp','rb').read()).decode()) for k in FR))
# ── Матвей ──
if 'npc' in what:
    out=H
    for k,sid in [('matvey','9c3f42d8-3cdd-44bc-ab14-9c3281c2ccea'),('matvey_stern','2bad2426-8f80-4a87-b62e-0f49a9f9508c')]:
        p=glob.glob(F+sid+'/*')[0]; im=key(p,1.25); b=io.BytesIO(); im.save(b,'WEBP',quality=90,method=6); im.save(f'new10/{k}.png')
        out+="ASSETS.sprites['%s']='data:image/webp;base64,%s';\n"%(k,base64.b64encode(b.getvalue()).decode()); print(k,im.size,len(b.getvalue())//1024)
    open('assets/npc2.js','w').write(out)
def comp(base,img,thr=38,grow=31,blur=25,keep=()):
    if img.size!=base.size: img=img.resize(base.size,Image.LANCZOS)
    a=np.asarray(base).astype(np.int16); b=np.asarray(img).astype(np.int16)
    d=(np.abs(a-b).max(2)>thr).astype(np.uint8)*255
    for x0,y0,x1,y1 in keep: d[y0:y1,x0:x1]=0
    d=Image.fromarray(d).filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.MaxFilter(grow)).filter(ImageFilter.GaussianBlur(blur))
    m=np.asarray(d).astype(np.float32)[...,None]/255
    for x0,y0,x1,y1 in keep: m[y0:y1,x0:x1]=0
    print(' changed %.1f%%'%(100*(m>.5).mean()))
    return Image.fromarray((a*(1-m)+b*m).clip(0,255).astype(np.uint8))
if 'bg' in what:
    open('assets/bg5.js','w').write(H)
    for k,sid in [('platform','57f35762-9f9f-4875-b2ff-4f61f0ec2cf3'),('underpass','89434f14-cafc-46cb-b9d8-ceff5a44a328'),('clinic','a39da8fb-d54b-4d15-a7c9-9be23e42825d')]:
        set_asset('assets/bg5.js','bg',k,L(sid),84)
if 'cg' in what:
    SIGN=(285,265,405,368)
    pl=L('6fdc9ba6-260d-417c-8589-363644fc5d32')
    t1=comp(pl,L('10d341b3-dfc3-4f7f-bf16-6bcac8c89cee'),keep=[SIGN]); t2=comp(pl,L('418eecbb-9cf8-486e-ae34-23c8c1d5d237'),keep=[SIGN])
    rc=comp(pl,L('d45bf49b-cf7b-4aeb-90e8-50e3b0ea32e5'),keep=[SIGN])
    l1=L('6960ad94-827f-4445-984d-b49a51057858'); l2=comp(l1,L('d46d93f1-8a52-4d79-99be-8e8925842a17'))
    cl=L('a39da8fb-d54b-4d15-a7c9-9be23e42825d'); cc=comp(cl,L('7bb45a44-8383-47ed-a7fa-f8d4f1e428fd'),keep=[(190,165,285,240)])
    J={'assets/cg6.js':[('cg_leaflet1',l1),('cg_leaflet2',l2),('cg_quarrel',L('ed58c74e-629d-4ebb-b3c4-89ff2580f472')),('cg_panic',L('500e8068-becb-4f4d-ae59-19c2d7d389de'))],
       'assets/cg7.js':[('cg_platform',pl),('cg_train1',t1),('cg_train2',t2),('cg_reconcile',rc)],
       'assets/cg8.js':[('cg_angel',L('10ea432d-decd-44c9-84b1-9d18229a75d1')),('cg_clinic',cc)]}
    for js,items in J.items():
        open(js,'w').write(H)
        for k,im in items: im.save(f'v10/{k}.jpg',quality=88); set_asset(js,'bg',k,im,80)
