import cv2,numpy as np
A=cv2.imread('gen/bugA.jpg'); H0,W0=A.shape[:2]
sift=cv2.SIFT_create(8000)
gA=cv2.cvtColor(A,cv2.COLOR_BGR2GRAY)
mA=np.zeros_like(gA); mA[:,:300]=255; mA[:120,:]=255   # статичные зоны: стена, верх
kA,dA=sift.detectAndCompute(gA,mA)
def align(p):
    B=cv2.imread(p); gB=cv2.cvtColor(B,cv2.COLOR_BGR2GRAY)
    kB,dB=sift.detectAndCompute(gB,None)
    m=cv2.BFMatcher().knnMatch(dB,dA,k=2); good=[a for a,b in m if a.distance<0.7*b.distance]
    src=np.float32([kB[g.queryIdx].pt for g in good]); dst=np.float32([kA[g.trainIdx].pt for g in good])
    H,inl=cv2.findHomography(src,dst,cv2.RANSAC,3.0); print(p,len(good),int(inl.sum()),np.round(H,4).tolist())
    return cv2.warpPerspective(B,H,(W0,H0),flags=cv2.INTER_LANCZOS4,borderMode=cv2.BORDER_REPLICATE)
def comp(B,name):
    d=cv2.absdiff(cv2.GaussianBlur(A,(0,0),2.5),cv2.GaussianBlur(B,(0,0),2.5)).max(2).astype(np.float32)
    m=(d>22).astype(np.uint8)
    m=cv2.morphologyEx(m,cv2.MORPH_OPEN,np.ones((5,5),np.uint8))
    m=cv2.dilate(m,np.ones((25,25),np.uint8))
    # заполнить дыры
    n,lab,stats,_=cv2.connectedComponentsWithStats(m)
    keep=np.zeros_like(m)
    for i in range(1,n):
        if stats[i,4]>1500: keep[lab==i]=1
    mf=cv2.GaussianBlur(keep.astype(np.float32),(0,0),8)
    xx=np.arange(W0)[None,:].astype(np.float32)
    ramp=np.repeat(np.clip((xx-600)/40,0,1),H0,0)
    mf=np.maximum(np.clip(mf*1.6,0,1),ramp)[...,None]
    out=(B*mf+A*(1-mf)).astype(np.uint8)
    cv2.imwrite(name,out); cv2.imwrite(name.replace('.png','_m.png'),(mf[...,0]*255).astype(np.uint8))
    return out
B=align('gen/bugB.jpg'); C=align('gen/bugC.jpg')
b=comp(B,'gen/bug3_v7.png'); c=comp(C,'gen/bug4_v7.png')
cv2.imwrite('gen/bug2_v7.png',A)
s=lambda x:cv2.resize(x,(688,384))
mb=cv2.imread('gen/bug3_v7_m.png'); mc=cv2.imread('gen/bug4_v7_m.png')
cv2.imwrite('/tmp/bugs.jpg',np.vstack([np.hstack([s(b),s(mb)]),np.hstack([s(c),s(mc)])]))
