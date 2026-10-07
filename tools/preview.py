import sys
from PIL import Image
im=Image.open(sys.argv[1]); W,H=im.size
c=Image.new('RGBA',(W*2,H),(235,235,235,255)); c.paste((30,30,40,255),(W,0,W*2,H))
c.alpha_composite(im,(0,0)); c.alpha_composite(im,(W,0))
x,y,w,h=[int(v) for v in sys.argv[3].split(',')] if len(sys.argv)>3 else (W+250,200,450,400)
c.crop((x,y,x+w,y+h)).resize((w*2,h*2),Image.NEAREST).save(sys.argv[2])
