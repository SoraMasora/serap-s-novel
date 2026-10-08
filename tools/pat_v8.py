import cv2,numpy as np
A=cv2.imread('gen/patA.jpg').astype(np.float32);P=cv2.imread('gen/patP.jpg').astype(np.float32)
H,W=A.shape[:2]
d=cv2.absdiff(cv2.GaussianBlur(A,(0,0),2),cv2.GaussianBlur(P,(0,0),2)).max(2)
m=((d>25)).astype(np.uint8); m[:330,:]=0; m[:,380:]=0
m=cv2.morphologyEx(m,cv2.MORPH_OPEN,np.ones((3,3),np.uint8))
n,lab,st,_=cv2.connectedComponentsWithStats(m)
keep=np.zeros_like(m)
for i in range(1,n):
    if st[i,4]>800: keep[lab==i]=1
pts=cv2.findNonZero(keep); hull=cv2.convexHull(pts)
hm=np.zeros((H,W),np.uint8); cv2.fillConvexPoly(hm,hull,1)
# фон-хромакей в A
r,g,b=A[...,2],A[...,1],A[...,0]; green=(g-np.maximum(r,b))>60
hair=((r-g)>45)&(g<110)&((r-b)>15)
arm=(hm>0)&(~green)&(~hair)
arm=cv2.erode(arm.astype(np.uint8),np.ones((2,2),np.uint8))
am=cv2.GaussianBlur(arm.astype(np.float32),(0,0),1.2)
# у нижнего края (y>1150) слой уходит в P плавно не нужно — рука и там есть
piv=(150,1300)
def frame(theta):
    M=cv2.getRotationMatrix2D(piv,theta,1.0)
    la=cv2.warpAffine(A,M,(W,H),flags=cv2.INTER_LANCZOS4,borderMode=cv2.BORDER_REPLICATE)
    ma=cv2.warpAffine(am,M,(W,H),flags=cv2.INTER_LINEAR)[...,None]
    return la*ma+P*(1-ma)
np.save('/tmp/armmask.npy',am)
# лица с закрытыми глазами из прежних кадров (pat1-база) → выравниваем на P
sift=cv2.SIFT_create(6000)
def face_from(path):
    B=cv2.imread(path); g1=cv2.cvtColor(B,cv2.COLOR_BGR2GRAY); g2=cv2.cvtColor(P.astype(np.uint8),cv2.COLOR_BGR2GRAY)
    msk=np.zeros_like(g2); msk[0:520,250:848]=255
    k1,d1=sift.detectAndCompute(g1,msk); k2,d2=sift.detectAndCompute(g2,msk)
    mm=cv2.BFMatcher().knnMatch(d1,d2,k=2); good=[a for a,b in mm if a.distance<0.7*b.distance]
    Hh,_=cv2.findHomography(np.float32([k1[x.queryIdx].pt for x in good]),np.float32([k2[x.trainIdx].pt for x in good]),cv2.RANSAC,3.0)
    print(path,len(good),np.round(Hh,3).tolist())
    return cv2.warpPerspective(B,Hh,(W,H),flags=cv2.INTER_LANCZOS4).astype(np.float32)
fm=np.zeros((H,W),np.float32); cv2.ellipse(fm,(410,330),(125,120),0,0,360,1,-1); fm=cv2.GaussianBlur(fm,(0,0),10)[...,None]
F2=face_from('gen/pat2_c.png'); F3=face_from('gen/pat3_c.png')
def withface(img,F): return img*(1-fm)+F*fm
out={'sera_pat':frame(0),'sera_pat2':withface(frame(-6),F2),'sera_pat3':withface(frame(0),F3),'sera_pat4':withface(frame(5),F3)}
for k,v in out.items(): cv2.imwrite(f'gen/{k}_v8.png',np.clip(v,0,255).astype(np.uint8))
o=[cv2.imread(f'gen/{k}_v8.png') for k in out]
cv2.imwrite('/tmp/patrot.jpg',np.hstack(o)[::2,::2])
