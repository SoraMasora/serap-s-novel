"""v11: hero_panting (запыхавшийся герой) → assets/hero2.js; исправленный cg_quarrel (одна открытая дверь) → assets/cg6.js."""
import sys,glob
from PIL import Image
sys.path.insert(0,'tools'); from key3 import key; from setasset import set_asset
F='/data/.agent-service/files/'
P=lambda i: glob.glob(F+i+'/*')[0]
H="window.ASSETS=window.ASSETS||{bg:{},sprites:{}};ASSETS.sprites=ASSETS.sprites||{};\n"
open('assets/hero2.js','w').write(H)
im=key(P('6cd3745b-6d9b-40a8-baa2-020faf4edd4b'),1.25,strict=False); im.save('v10/hero_panting.png')
set_asset('assets/hero2.js','sprites','hero_panting',im,88,mode='RGBA')
q=Image.open(P('7267ee56-c97d-4751-bf0a-32ce7aabc674')).convert('RGB'); q.save('v10/cg_quarrel.jpg',quality=88)
set_asset('assets/cg6.js','bg','cg_quarrel',q,80)
