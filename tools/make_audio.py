"""Готовит музыку (MP3 64 кбит/с) и SFX (сэмплы Kenney CC0 → MP3 моно) и пакует в assets/music*.js, assets/sfx.js"""
import subprocess,numpy as np,base64,os,glob,io,wave
F='/data/.agent-service/files/'
MUSIC={'roofs':F+'5a73ea9a-e4d1-4633-bab5-84456a803632','sudno':F+'9b7af330-7e2b-4d88-a695-c12cc00ece44','elektro':F+'92f22490-2321-4a6f-ab1c-04678b0ea194'}
SR=44100
def load(p):
    r=subprocess.run(['ffmpeg','-v','quiet','-i',p,'-ac','1','-ar',str(SR),'-f','f32le','-'],capture_output=True,check=True)
    return np.frombuffer(r.stdout,np.float32)
R='/data/sfx/rpg/Audio/'; I='/data/sfx/impact/Audio/'
def mix(parts,total=None,gain=1.0):
    """parts: [(file, t_sec, vol)]"""
    clips=[(load(f),int(t*SR),v) for f,t,v in parts]
    n=max(o+len(c) for c,o,v in clips)
    out=np.zeros(n,np.float32)
    for c,o,v in clips: out[o:o+len(c)]+=c*v
    pk=np.abs(out).max()
    if pk>0: out=out/pk*0.9*gain
    return out
fc=lambda i:I+f'footstep_concrete_00{i%5}.ogg'
SFX={
 'door':  mix([(R+'doorOpen_1.ogg',0,1),(R+'doorClose_2.ogg',0.85,0.9)]),
 'keys':  mix([(R+'handleCoins.ogg',0,0.8),(R+'handleCoins2.ogg',0.25,0.6),(R+'metalLatch.ogg',0.7,1)]),
 'steps': mix([(fc(i),i*0.46,0.75+0.25*(i%2)) for i in range(6)],gain=0.85),
 'step':  mix([(fc(1),0,1)],gain=0.7),
 'bump':  mix([(I+'impactSoft_heavy_001.ogg',0,1),(I+'impactPunch_medium_000.ogg',0.01,0.5)]),
 'drop':  mix([(I+'impactPlate_light_000.ogg',0,0.8),(I+'impactTin_medium_001.ogg',0.12,1),(I+'impactPlate_light_002.ogg',0.24,0.7),(I+'impactTin_medium_003.ogg',0.42,0.8),(I+'impactGeneric_light_001.ogg',0.55,0.6)]),
 'knock': mix([(I+'impactWood_medium_000.ogg',0,1),(I+'impactWood_medium_002.ogg',0.24,0.95),(I+'impactWood_medium_004.ogg',0.48,1)]),
 'creak': mix([(R+'creak1.ogg',0,1),(R+'metalClick.ogg',0.05,0.5)]),
 'cloth': mix([(R+'cloth2.ogg',0,1),(R+'cloth4.ogg',0.15,0.7)]),
 'paper': mix([(R+'bookFlip2.ogg',0,1)],gain=0.8),
 'latch': mix([(R+'metalLatch.ogg',0,1)]),
 'unlock':mix([(R+'handleCoins.ogg',0,0.7),(R+'metalLatch.ogg',0.55,1),(R+'doorOpen_2.ogg',1.0,0.9),(R+'doorClose_3.ogg',1.9,0.8)]),
}
def mp3(sig,br='96k'):
    b=io.BytesIO()
    with wave.open(b,'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((np.clip(sig,-1,1)*32767).astype('<i2').tobytes())
    r=subprocess.run(['ffmpeg','-v','quiet','-f','wav','-i','-','-c:a','libmp3lame','-b:a',br,'-f','mp3','-'],input=b.getvalue(),capture_output=True,check=True)
    return r.stdout
with open('assets/sfx.js','w') as o:
    o.write("window.ASSETS=window.ASSETS||{bg:{},sprites:{}};ASSETS.sfx=ASSETS.sfx||{};\n")
    for k,s in SFX.items():
        d=mp3(s); o.write(f"ASSETS.sfx['{k}']='{base64.b64encode(d).decode()}';\n"); print('sfx',k,round(len(s)/SR,2),'s',len(d)//1024,'KB')
# музыка
import sys
if '--sfx-only' in sys.argv: raise SystemExit
for f in glob.glob('assets/music*.js'): os.remove(f)
idx=1
for k,d in MUSIC.items():
    src=glob.glob(d+'/*.mp3')[0]
    r=subprocess.run(['ffmpeg','-v','quiet','-i',src,'-map','0:a','-ac','2','-ar','44100','-c:a','libmp3lame','-b:a','64k','-map_metadata','-1','-f','mp3','-'],capture_output=True,check=True)
    b=base64.b64encode(r.stdout).decode(); print('music',k,len(r.stdout)//1024,'KB')
    CH=880_000
    for i in range(0,len(b),CH):
        with open(f'assets/music{idx}.js','w') as o:
            o.write("window.ASSETS=window.ASSETS||{bg:{},sprites:{}};ASSETS.music=ASSETS.music||{};\n")
            o.write(f"ASSETS.music['{k}']=(ASSETS.music['{k}']||'')+'{b[i:i+CH]}';\n")
        idx+=1
print('music files',idx-1)
