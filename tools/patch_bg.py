"""Вклеивает отредактированные фрагменты обратно в фон с регистрацией (ORB+гомография)."""
import cv2, numpy as np, sys
def patch(base, edit_path, box, feather=18):
    x0,y0,x1,y1=box; w,h=x1-x0,y1-y0
    orig=base[y0:y1,x0:x1]
    ed=cv2.imread(edit_path)
    up=cv2.resize(orig,(ed.shape[1],ed.shape[0]),interpolation=cv2.INTER_LANCZOS4)
    orb=cv2.SIFT_create(4000)
    k1,d1=orb.detectAndCompute(cv2.cvtColor(ed,cv2.COLOR_BGR2GRAY),None)
    k2,d2=orb.detectAndCompute(cv2.cvtColor(up,cv2.COLOR_BGR2GRAY),None)
    m=cv2.BFMatcher().knnMatch(d1,d2,k=2)
    good=[a for a,b in m if a.distance<0.75*b.distance]
    src=np.float32([k1[g.queryIdx].pt for g in good]); dst=np.float32([k2[g.trainIdx].pt for g in good])
    H,inl=cv2.findHomography(src,dst,cv2.RANSAC,4.0)
    print(edit_path,'matches',len(good),'inliers',int(inl.sum()),'\nH',np.round(H,3))
    S=np.diag([w/ed.shape[1],h/ed.shape[0],1])
    Hs=S@H
    warped=cv2.warpPerspective(ed,Hs,(w,h),flags=cv2.INTER_AREA,borderMode=cv2.BORDER_REPLICATE)
    valid=cv2.warpPerspective(np.ones(ed.shape[:2],np.float32),Hs,(w,h))
    mask=np.ones((h,w),np.float32)
    # перо по краям рамки, кроме краёв, совпадающих с краем фона
    H0,W0=base.shape[:2]
    yy=np.arange(h)[:,None].astype(np.float32); xx=np.arange(w)[None,:].astype(np.float32)
    dl=xx if x0>0 else np.full_like(xx,1e9); dr=(w-1-xx) if x1<W0 else np.full_like(xx,1e9)
    dt=yy if y0>0 else np.full_like(yy,1e9); db=(h-1-yy) if y1<H0 else np.full_like(yy,1e9)
    d=np.minimum(np.minimum(dl,dr),np.minimum(dt,db))
    mask=np.clip(d/feather,0,1)*(valid>0.99)
    out=base.copy()
    out[y0:y1,x0:x1]=(warped*mask[...,None]+orig*(1-mask[...,None])).astype(np.uint8)
    return out
if __name__=='__main__':
    b=cv2.imread('gen/bg_store.png')
    b=patch(b,'gen/e_noodles.jpg',(0,0,400,400))
    b=patch(b,'gen/e_trays.jpg',(0,440,260,700))
    b=patch(b,'gen/e_cans.jpg',(1180,60,1376,256))
    cv2.imwrite('gen/bg_store_new.png',b)
