import cv2,numpy as np
A=cv2.imread('gen/p1.jpg'); H0,W0=A.shape[:2]
sift=cv2.SIFT_create(6000)
gA=cv2.cvtColor(A,cv2.COLOR_BGR2GRAY)
fm=np.full_like(gA,255); fm[150:480,240:560]=0   # для регистрации — без лица
kA,dA=sift.detectAndCompute(gA,fm)
def align(B):
    kB,dB=sift.detectAndCompute(cv2.cvtColor(B,cv2.COLOR_BGR2GRAY),None)
    m=cv2.BFMatcher().knnMatch(dB,dA,k=2); good=[a for a,b in m if a.distance<0.7*b.distance]
    src=np.float32([kB[g.queryIdx].pt for g in good]); dst=np.float32([kA[g.trainIdx].pt for g in good])
    H,inl=cv2.findHomography(src,dst,cv2.RANSAC,3.0); print(len(good),int(inl.sum()),np.round(H,4).tolist())
    return cv2.warpPerspective(B,H,(W0,H0),flags=cv2.INTER_LANCZOS4,borderValue=(0,255,0))
outs=[A]
for i in (2,3):
    B=align(cv2.imread(f'gen/p{i}.jpg'))
    d=cv2.absdiff(cv2.GaussianBlur(A,(0,0),2),cv2.GaussianBlur(B,(0,0),2)).max(2)
    m=(d>25).astype(np.uint8)
    face=np.zeros((H0,W0),np.uint8); cv2.ellipse(face,(400,330),(140,150),0,0,360,1,-1)
    m=m*face; m=cv2.dilate(m,np.ones((21,21),np.uint8))
    m=np.clip(cv2.GaussianBlur(m.astype(np.float32),(0,0),7)*1.5,0,1)*face.astype(np.float32)
    m=cv2.GaussianBlur(m,(0,0),3)[...,None]
    o=(B*m+A*(1-m)).astype(np.uint8); outs.append(o)
    cv2.imwrite(f'gen/pat{i}_c.png',o); cv2.imwrite(f'/tmp/pm{i}.png',(m[...,0]*255).astype(np.uint8))
cv2.imwrite('gen/pat1_c.png',A)
cv2.imwrite('/tmp/patc.jpg',np.hstack([o[100:560,180:620] for o in outs]))
