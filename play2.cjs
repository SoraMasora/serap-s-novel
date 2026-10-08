const {chromium}=require('/vercel/sandbox/node_modules/playwright');
const fs=require('fs');
(async()=>{
const b=await chromium.launch({executablePath:process.env.CHR||'/usr/local/bin/chromium',args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy=no-user-gesture-required']});
const p=await b.newPage({viewport:{width:1280,height:720}});
const errs=[];p.on('pageerror',e=>errs.push('PE '+e.message));p.on('console',m=>{if(m.type()==='error')errs.push('CE '+m.text())});
await p.goto('file:///data/serap/game.html');
await p.waitForTimeout(3000);
await p.click('#btnNew');await p.waitForTimeout(600);
await p.fill('#nameInput','Кирилл');await p.click('#nameOk');await p.waitForTimeout(800);
fs.mkdirSync('/data/serap/shots/play',{recursive:true});
let pairs={},log=[],shot=0,steps=0,mapEntered=0;
const vis=async s=>p.evaluate(s=>{const e=document.querySelector(s);return !!e&&!e.classList.contains('hidden')},s);
for(let i=0;i<2400;i++){
  if(await vis('#ending')){log.push('=== ENDING ===');break;}
  if(await vis('#pixwrap')){
    const st=await p.evaluate(()=>{const s=window.__pix.state();return {spots:s.map.spots,done:s.map.done,visits:s.map.visits,title:s.map.title,scenes:s.map.scenes?Object.keys(s.map.scenes):null,items:!!s.map.items,world:s.map.world||'yard'}});
    log.push('MAP: '+JSON.stringify(st));
    await p.screenshot({path:`/data/serap/shots/play/map${mapEntered}.png`});mapEntered++;
    const cand=(st.scenes||st.spots).filter(x=>!st.done.includes(x));
    const pick=st.items?'__allitems':cand.length?cand[0]:'home';
    await p.evaluate(id=>window.__pix.enter(id),pick);
    log.push('  -> enter '+pick);
    await p.waitForTimeout(1200);
    continue;
  }
  if(await vis('#choices')){
    const opts=await p.evaluate(()=>[...document.querySelectorAll('#choices button')].map(b=>b.textContent.trim()));
    log.push('CHOICE: '+JSON.stringify(opts));
    await p.evaluate(()=>{const b=document.querySelector('#choices button:not([disabled])');if(b)b.click()});
    await p.waitForTimeout(600);
  } else {
    const t=await p.evaluate(()=>{const n=document.querySelector('#namebox'),x=document.querySelector('#text');return (n?n.textContent:'')+'|'+(x?x.textContent:'')});
    log.push(t);const au=await p.evaluate(()=>{try{return st.bg+'>'+Sound.track+'/'+Sound.mode}catch(e){return 'ERR '+e.message}});pairs[au]=(pairs[au]||0)+1;
    if(i%14===0)await p.screenshot({path:`/data/serap/shots/play/s${String(shot++).padStart(3,'0')}.png`});
    await p.evaluate(()=>{const c=document.querySelector('#chars');if(c)c.click()});
    await p.waitForTimeout(90);
  }
  steps++;
}
const end=await p.evaluate(()=>{const e=document.querySelector('#ending');return e&&!e.classList.contains('hidden')?document.querySelector('#endTitle').textContent+' :: '+document.querySelector('#endText').textContent:'(no ending) '+JSON.stringify({ch:document.querySelector('#chapter').textContent})});
log.push('FINAL: '+end);
fs.writeFileSync('/data/serap/shots/playlog.txt',log.join('\n'));
console.log('steps',steps,'shots',shot,'maps',mapEntered);
console.log('ERRORS:',errs.slice(0,12).join(' | ')||'none');
console.log('FINAL:',end);console.log('AUDIO',JSON.stringify(pairs));console.log('SAMPLES',await p.evaluate(()=>Sound.samples.join(',')));
await b.close();process.exit(0)})().catch(e=>{console.error(e);process.exit(1)});
