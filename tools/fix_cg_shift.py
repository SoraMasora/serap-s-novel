import cv2,numpy as np
cg=cv2.imread('/data/.agent-service/files/afcf33a6-8792-4bb3-b015-60d62b41c62e/tool-output-0.jpg')
st=cv2.imread('gen/bg_store_new.png')
H0,W0=cg.shape[:2]
sift=cv2.SIFT_create(6000)
def reg(xa,xb):
    m1=np.zeros(cg.shape[:2],np.uint8); m1[:,xa:xb]=255
    k1,d1=sift.detectAndCompute(cv2.cvtColor(st,cv2.COLOR_BGR2GRAY),None)
    k2,d2=sift.detectAndCompute(cv2.cvtColor(cg,cv2.COLOR_BGR2GRAY),m1)
    m=cv2.BFMatcher().knnMatch(d1,d2,k=2)
    good=[a for a,b in m if a.distance<0.75*b.distance]
    src=np.float32([k1[g.queryIdx].pt for g in good]); dst=np.float32([k2[g.trainIdx].pt for g in good])
    H,inl=cv2.findHomography(src,dst,cv2.RANSAC,4.0)
    print(xa,xb,len(good),int(inl.sum()),np.round(H,3).tolist())
    return cv2.warpPerspective(st,H,(W0,H0),flags=cv2.INTER_LANCZOS4,borderMode=cv2.BORDER_REPLICATE)
L=reg(0,300); R=reg(1050,W0)
xx=np.arange(W0)[None,:].astype(np.float32)
mL=np.clip((300-xx)/40,0,1); mR=np.clip((xx-1050)/40,0,1)
mL=np.repeat(mL,H0,0); mR=np.repeat(mR,H0,0)
# не трогать руку Серы: в зоне x 260..340, y 180..420 маску убираем
yy=np.arange(H0)[:,None]
out=cg.astype(np.float32)
out=out*(1-mL[...,None])+L*mL[...,None]
out=out*(1-mR[...,None])+R*mR[...,None]
cv2.imwrite('gen/cg_shift.png',out.astype(np.uint8))
cv2.imwrite('/tmp/cgs.jpg',out.astype(np.uint8)[::2,::2])
