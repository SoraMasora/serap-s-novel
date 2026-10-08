"""Кадры анимаций Серы: стабилизация по мастер-кадру + вырезка key3 (×1.25) → new8/*.webp"""
import sys,glob,io,numpy as np,cv2
from PIL import Image
sys.path.insert(0,'tools'); from key3 import key
F='/data/.agent-service/files/'
FR={'yawn1':'21c930e7-5aea-49d3-a870-cea3e4eb1416','yawn2':'a660f9b3-6f7d-4ffd-be62-828eb15e11b0','yawn3':'ae391f16-fda4-4370-8241-d4183661f73d',
 'cover1':'0f4d7941-db18-4efb-a849-c593dd5144a9','cover2':'b8e16298-cdac-4f75-a384-baae4fa89ae6','cover3':'66f60fa7-5a7f-44b1-9068-d1a3fb195ec8',
 'giggle1':'c4313426-d42e-4747-a00b-f6a54c2c8472','giggle2':'7114f936-15c6-49af-8250-dcc56bb02046',
 'huff1':'219a9f6d-e63e-45ca-88d8-318abc0ac2a6','huff2':'94337500-b666-412e-8f07-57ec067f70d4'}
M=cv2.imread('gen/g_neutral.jpg'); H,W=M.shape[:2]
sift=cv2.SIFT_create(6000); gm=cv2.cvtColor(M,cv2.COLOR_BGR2GRAY)
km,dm=sift.detectAndCompute(gm,None)
for k,sid in FR.items():
    B=cv2.imread(glob.glob(F+sid+'/*')[0]); B=cv2.resize(B,(W,H)) if B.shape[:2]!=(H,W) else B
    kb,db=sift.detectAndCompute(cv2.cvtColor(B,cv2.COLOR_BGR2GRAY),None)
    mm=cv2.BFMatcher().knnMatch(db,dm,k=2); good=[a for a,b in mm if a.distance<0.7*b.distance]
    Hh,inl=cv2.findHomography(np.float32([kb[x.queryIdx].pt for x in good]),np.float32([km[x.trainIdx].pt for x in good]),cv2.RANSAC,3.0)
    Bw=cv2.warpPerspective(B,Hh,(W,H),flags=cv2.INTER_LANCZOS4,borderValue=(0,255,0))
    d=cv2.absdiff(cv2.GaussianBlur(M,(0,0),2),cv2.GaussianBlur(Bw,(0,0),2)).max(2)
    m=(d>28).astype(np.uint8); m=cv2.morphologyEx(m,cv2.MORPH_OPEN,np.ones((3,3),np.uint8))
    m=cv2.dilate(m,np.ones((31,31),np.uint8))
    n,lab,st,_=cv2.connectedComponentsWithStats(m); keep=np.zeros_like(m)
    for i in range(1,n):
        if st[i,4]>2500: keep[lab==i]=1
    mf=np.clip(cv2.GaussianBlur(keep.astype(np.float32),(0,0),9)*1.6,0,1)[...,None]
    out=(Bw*mf+M*(1-mf)).astype(np.uint8)
    cv2.imwrite(f'gen/a_{k}.png',out)
    im=key(f'gen/a_{k}.png',1.25)
    im.save(f'new8/sera_{k}.webp','WEBP',quality=90,method=6)
    print(k,len(good),int(inl.sum()),round(float(mf.mean()),3))
