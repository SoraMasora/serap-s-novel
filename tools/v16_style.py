"""v16: единая «рисованная» стилистика как у cg_reconcile — без перегенерации, композиция не меняется.
artist(img, k=1.0) -> img: сглаживание градиентов (cel), карандашно-тушевой контур, сплит-тон (холодные тени / тёплые света),
матовые чёрные, бумажное зерно. python3 tools/v16_style.py <in> <out>"""
import numpy as np, cv2
from PIL import Image
def artist(img,k=1.0,seed=7,paper=True):
    a=np.asarray(img.convert('RGB')).astype(np.float32)/255.
    # 1) cel: убираем «ИИ-глянец» — плавные градиенты/микродетали, края сохраняются
    b=cv2.edgePreservingFilter((a*255).astype(np.uint8),flags=1,sigma_s=24,sigma_r=0.22).astype(np.float32)/255.
    b=a*(1-.55*k)+b*.8*k
    # 2) контур: DoG по яркости → тёмные линии тушью, плюс сдвинутый «карандашный» дубль
    L=cv2.cvtColor((a*255).astype(np.uint8),cv2.COLOR_RGB2GRAY).astype(np.float32)/255.
    dog=cv2.GaussianBlur(L,(0,0),2.0)-cv2.GaussianBlur(L,(0,0),0.8)
    ln=np.clip(dog*16,0,1)**0.9
    ln2=np.roll(np.roll(ln,1,0),1,1)*.35
    ln=np.clip(np.maximum(ln,ln2),0,1)*.8*k
    ink=np.array([.17,.14,.18],np.float32)
    b=b*(1-ln[...,None])+ink*ln[...,None]
    # 3) цвет: чуть меньше насыщенности, сплит-тон, матовые тени
    g=b.mean(2,keepdims=True); b=g+(b-g)*(1-.12*k)
    lum=cv2.GaussianBlur(b.mean(2),(0,0),2)[...,None]
    sh=np.array([.36,.40,.50],np.float32); hi=np.array([1.0,.93,.84],np.float32)
    b=b*(1-.10*k)+ (sh*(1-lum)+hi*lum)*b*.10*k*1.6
    b=.045*k+b*(1-.06*k)
    # 4) бумага: мелкое зерно + крупные волокна
    if paper:
        r=np.random.default_rng(seed); h,w=L.shape
        n1=cv2.GaussianBlur(r.standard_normal((h,w)).astype(np.float32),(0,0),.7)
        n2=cv2.GaussianBlur(r.standard_normal((h,w)).astype(np.float32),(0,0),3.5)
        b=b*(1+(n1*.05+n2*.07)[...,None]*k)
    b=cv2.GaussianBlur(b,(0,0),.35)
    return Image.fromarray((np.clip(b,0,1)*255).astype(np.uint8))
if __name__=='__main__':
    import sys; artist(Image.open(sys.argv[1])).save(sys.argv[2],quality=92)
