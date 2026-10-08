// node map.cjs <scene> <tag> <feel> — дойти до карты и погулять (скрины shots/map/)
const {chromium}=require('/vercel/sandbox/node_modules/playwright');const fs=require('fs');
const [scene,tag,feel='55']=process.argv.slice(2);
(async()=>{
const b=await chromium.launch({executablePath:'/usr/local/bin/chromium',args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy=no-user-gesture-required']});
const p=await b.newPage({viewport:{width:1280,height:720}});const errs=[];p.on('pageerror',e=>errs.push('PE '+e.message));p.on('console',m=>{if(m.type()==='error')errs.push('CE '+m.text())});
await p.goto('file:///data/serap/game.html');await p.waitForTimeout(2500);
fs.mkdirSync('/data/serap/shots/map',{recursive:true});
await p.evaluate(([scene,feel])=>localStorage.setItem('serap_save_1',JSON.stringify({st:{scene,i:0,feel:+feel,press:0,flags:{},notes:[],name:'Кирилл',bg:'stairs',chars:{},music:'calm',rain:false,chapter:'',mode:'',map:null},date:'x'})),[scene,feel]);
await p.click('#btnLoadT');await p.waitForTimeout(400);await p.click('[data-slot="1"]');await p.waitForTimeout(1500);
for(let i=0;i<40;i++){ if(await p.evaluate(()=>!document.querySelector('#pixwrap').classList.contains('hidden')))break;
  if(await p.evaluate(()=>!document.querySelector('#choices').classList.contains('hidden'))){await p.evaluate(()=>document.querySelector('#choices button').click());await p.waitForTimeout(500);continue;}
  await p.evaluate(()=>document.querySelector('#chars').click());await p.waitForTimeout(250);}
let n=0;const shot=async()=>p.screenshot({path:`/data/serap/shots/map/${tag}_${String(n++).padStart(2,'0')}.jpg`,quality:70});
await shot();
const walk=async(k,ms)=>{await p.keyboard.down(k);await p.waitForTimeout(ms);await p.keyboard.up(k);};
for(let s=0;s<9;s++){await walk("ArrowRight",+(process.env.STEP||900));await p.keyboard.press('e');await p.waitForTimeout(500);await shot();}
const info=await p.evaluate(()=>{const st=window.__pix.state();return {mode:st.mode,scene:st.scene,map:st.map&&{got:st.map.got,tleft:st.map.tleft}}});
console.log(JSON.stringify(info));console.log('ERR',errs.join('|')||'none');await b.close();process.exit(0)})();
