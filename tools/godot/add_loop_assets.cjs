'use strict';
const fs=require('fs'),path=require('path'),vm=require('vm');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'godot');
const ctx=vm.createContext({window:{}});ctx.window=ctx;
for(const f of ['loop1.js','loop2.js','loop3.js','loop4.js','loop5.js','loop6.js'])vm.runInContext(fs.readFileSync(path.join(root,'assets',f),'utf8'),ctx);
const manifest=JSON.parse(fs.readFileSync(path.join(out,'data/assets_manifest.json'),'utf8'));
let count=0;
for(const [group,items] of Object.entries(ctx.ASSETS)) for(const [key,value] of Object.entries(items)){
 if(manifest[group]?.[key])continue; // Never overwrite a 0.7.3 resource.
 const m=/^data:([^;]+);base64,/.exec(value);if(!m)throw new Error(key);
 const ext={'image/webp':'webp','image/png':'png','image/jpeg':'jpg'}[m[1]];
 const dest=path.join(out,'assets',group,key+'.'+ext);fs.mkdirSync(path.dirname(dest),{recursive:true});
 if(fs.existsSync(dest))throw new Error('Unexpected collision: '+dest);
 fs.writeFileSync(dest,Buffer.from(value.slice(m[0].length),'base64'));
 (manifest[group] ||= {})[key]='res://assets/'+group+'/'+key+'.'+ext;count++;
}
fs.writeFileSync(path.join(out,'data/assets_manifest.json'),JSON.stringify(manifest,null,1)+'\n');
console.log('New loop assets only:',count);
