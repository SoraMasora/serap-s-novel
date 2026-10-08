const {chromium}=require('/vercel/sandbox/node_modules/playwright');
(async()=>{
const b=await chromium.launch({executablePath:'/usr/local/bin/chromium',args:['--use-gl=angle','--use-angle=swiftshader','--autoplay-policy=no-user-gesture-required']});
const p=await b.newPage({viewport:{width:1280,height:720}});
const errs=[];p.on('pageerror',e=>errs.push('PE '+e.message));p.on('console',m=>{if(m.type()==='error')errs.push('CE '+m.text())});
await p.goto('file:///data/serap/game.html');await p.waitForTimeout(3000);
await p.click('#btnNew');await p.waitForTimeout(500);await p.fill('#nameInput','Кирилл');await p.click('#nameOk');await p.waitForTimeout(800);
const vis=async s=>p.evaluate(s=>{const e=document.querySelector(s);return !!e&&!e.classList.contains('hidden')},s);
let n=0;
for(let i=0;i<300&&n<60;i++){
  if(await vis('#choices')){await p.evaluate(()=>document.querySelector('#choices button').click());await p.waitForTimeout(300);continue;}
  if(await vis('#cut')){await p.mouse.click(640,300);await p.waitForTimeout(300);continue;}
  if(await vis('#pixwrap'))break;
  await p.mouse.click(640,400);await p.waitForTimeout(120);await p.mouse.click(640,400);await p.waitForTimeout(150);n++;
}
const txt=()=>p.evaluate(()=>document.querySelector('#text').textContent);
console.log('before:',(await txt()).slice(0,60));
await p.click('[data-a=log]');await p.waitForTimeout(400);
const ents=await p.evaluate(()=>[...document.querySelectorAll('.log [data-k]')].map(d=>d.dataset.k+'|'+d.textContent.slice(0,50)));
console.log('entries',ents.length,'heads',await p.evaluate(()=>document.querySelectorAll('.log h3').length));
const pick=ents[Math.floor(ents.length/3)]; console.log('pick',pick);
await p.click(`.log [data-k="${pick.split('|')[0]}"]`);await p.waitForTimeout(300);
await p.screenshot({path:'/data/serap/shots/rb_confirm.png'});
await p.click('#rbYes');await p.waitForTimeout(1500);
await p.mouse.click(640,400);await p.waitForTimeout(300);
console.log('after:',(await txt()).slice(0,60));
console.log('logLen',await p.evaluate(()=>document.querySelectorAll('.log').length));
await p.screenshot({path:'/data/serap/shots/rb_after.png'});
for(let i=0;i<20;i++){ if(await vis('#choices')){await p.evaluate(()=>document.querySelector('#choices button:last-child').click());await p.waitForTimeout(300);continue;} await p.mouse.click(640,400);await p.waitForTimeout(150);}
const sz=await p.evaluate(()=>(localStorage.getItem('serap_save_auto')||'').length);
console.log('auto save size',sz,'txt',(await txt()).slice(0,50));
console.log('ERR',errs.join('\n')||'none');
await b.close();process.exit(0);})();
