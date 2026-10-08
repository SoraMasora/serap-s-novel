// node tools/chk.cjs — проверка: все go/tier/bg/cut/final существуют
const vm=require('vm'),fs=require('fs');const c={console};c.window=c;vm.createContext(c);
for(const f of fs.readdirSync('assets').filter(f=>/^(bg|cg)\d+\.js$/.test(f)))vm.runInContext(fs.readFileSync('assets/'+f,'utf8'),c);
vm.runInContext(fs.readFileSync('js/story.js','utf8')+'\n;'+fs.readFileSync('js/story3.js','utf8')+'\nthis.STORY=STORY;this.ENDINGS=ENDINGS;',c);
const S=c.STORY,B=c.ASSETS.bg,bad=[];
for(const [k,sc] of Object.entries(S))sc.forEach((x,i)=>{if(!x||Array.isArray(x))return;
 const gos=[x.go,x.choice&&x.choice.map(o=>o.go),x.map&&x.map.after,x.map&&x.map.scenes&&Object.values(x.map.scenes)].flat(2).filter(Boolean);
 gos.forEach(g=>{if(!S[g])bad.push(k+':'+i+' go '+g)});
 if(x.tier)Object.values(x.tier).forEach(g=>{if(g&&!S[g])bad.push(k+' tier '+g)});
 if(x.bg&&!B[x.bg])bad.push(k+' bg '+x.bg);
 if(x.cut)x.cut.forEach(q=>{if(!B[q.img])bad.push(k+' cut '+q.img)});
 if(x.final&&!c.ENDINGS[x.final])bad.push(k+' final '+x.final);});
console.log('scenes',Object.keys(S).length,'BAD',bad);
