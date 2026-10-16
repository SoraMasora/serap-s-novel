// Verifies the supplied 0.7.3, not the obsolete 234-scene web port.
'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'../..');
const source=JSON.parse(fs.readFileSync(path.join(root,'godot/data/preservation073.json'),'utf8'));
const story=JSON.parse(fs.readFileSync(path.join(root,'godot/data/story.json'),'utf8'));
const manifest=JSON.parse(fs.readFileSync(path.join(root,'godot/data/assets_manifest.json'),'utf8'));
const canonical=v=>Array.isArray(v)?'['+v.map(canonical).join(',')+']':v&&typeof v==='object'?'{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}':JSON.stringify(v);
const sha=v=>crypto.createHash('sha256').update(v).digest('hex');
const errors=[];
const mobile=process.argv.includes('--mobile');
const overrides=mobile?JSON.parse(fs.readFileSync(path.join(root,'godot/data/mobile074_overrides.json'),'utf8')):{};
let identical=0,adapted=0;
for(const [p,h] of Object.entries(source.files)){
  const f=path.join(root,p),actual=fs.existsSync(f)?sha(fs.readFileSync(f)):'';
  if(actual===h)identical++;
  else if(mobile&&overrides[p]?.sha256===actual)adapted++;
  else errors.push('Original file changed (no exact approved mobile hash): '+p);
}
for(const p of Object.keys(overrides))if(!source.files[p])errors.push('Mobile override not in baseline: '+p);
for(const group of ['scenes','endings'])for(const [key,h] of Object.entries(source[group]))if(sha(canonical(story[group][key]))!==h)errors.push('Original '+group+' changed: '+key);
for(const [group,items] of Object.entries(source.assets_manifest))for(const [key,value] of Object.entries(items))if(manifest[group]?.[key]!==value)errors.push('Original asset reference changed: '+group+'.'+key);
if(errors.length){console.error(errors.slice(0,20).join('\n'));process.exit(1);}
console.log('PRESERVATION PASS:',identical,'original files byte-identical;',adapted,'exact SHA256 mobile adaptations;',Object.keys(source.scenes).length,'original scenes;',Object.keys(source.endings).length,'original endings; original asset references unchanged.');
