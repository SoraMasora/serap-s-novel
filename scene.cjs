// node scene.cjs <scene> <bg> <tag> <clicks> [charsJSON] [shotEveryMs] — запуск сцены через сохранение, скрины в shots/scene/
const {chromium}=require('/vercel/sandbox/node_modules/playwright');const fs=require('fs');
const [scene,bg,tag,clicks='12',chars='{}',every='0']=process.argv.slice(2);
(async()=>{
const b=await chromium.launch({executablePath:process.env.CHR||'/usr/local/bin/chromium',args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy=no-user-gesture-required']});
const p=await b.newPage({viewport:{width:1280,height:720}});const errs=[];p.on('pageerror',e=>errs.push('PE '+e.message));
await p.goto('file:///data/serap/game.html');await p.waitForTimeout(2500);
fs.mkdirSync('/data/serap/shots/scene',{recursive:true});
if(tag==='title'){await p.screenshot({path:'/data/serap/shots/scene/title.png'});await b.close();return;}
await p.evaluate(([scene,bg,chars])=>localStorage.setItem('serap_save_1',JSON.stringify({st:{scene,i:0,feel:90,press:0,flags:{defended:true,therapy:true},notes:[],name:'Кирилл',bg,chars:JSON.parse(chars),music:'calm',rain:false,chapter:'',mode:'',map:null},date:'t'})),[scene,bg,chars]);
await p.click('#btnLoadT');await p.waitForTimeout(400);await p.click('[data-slot="1"]');await p.waitForTimeout(1500);
let n=0;
for(let i=0;i<+clicks;i++){
  const t=await p.evaluate(()=>document.querySelector('#text').textContent.slice(0,50));
  if(+every){for(let k=0;k<(+process.env.SHOTS||3);k++){await p.screenshot({path:`/data/serap/shots/scene/${tag}_${String(n++).padStart(2,'0')}.jpg`,quality:60});await p.waitForTimeout(+every);}}
  else await p.screenshot({path:`/data/serap/shots/scene/${tag}_${String(n++).padStart(2,'0')}.jpg`,quality:60});
  console.log(i,t);
  if(await p.evaluate(()=>!document.querySelector('#ending').classList.contains('hidden'))){console.log('ENDING');break;}
  if(await p.evaluate(()=>!document.querySelector('#cut').classList.contains('hidden'))){for(let k=0;k<5;k++){await p.waitForTimeout(1500);await p.screenshot({path:`/data/serap/shots/scene/${tag}_${String(n++).padStart(2,'0')}.jpg`,quality:60});}await p.waitForTimeout(3500);continue;}
  await p.evaluate(()=>document.querySelector('#chars').click());await p.waitForTimeout(150);
  await p.evaluate(()=>document.querySelector('#chars').click());await p.waitForTimeout(700);
}
console.log('ERR',errs.join('|')||'none');await b.close();})();
