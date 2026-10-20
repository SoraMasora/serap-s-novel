// Exact dynamic dialogue fixtures from original JS functions, with differing death orders.
'use strict';
const fs = require('fs'), vm = require('vm'), path = require('path');
const root = path.resolve(__dirname, '../..');
const ctx=vm.createContext({window:{},console});
for(const file of ['js/story.js','js/story3.js','js/story4.js','js/story_loop.js','js/story_loop_godot.js']) vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),ctx);
const {STORY,LOOP}=vm.runInContext('({STORY,LOOP})',ctx);
const cases=[];
for(const order of [LOOP.ORDER, [...LOOP.ORDER].reverse(), ['train','road','cross','room','cliff','neck','store']]) {
  for(let n=0;n<8;n++) {
    const flags={loop:n,dord:order.slice(0,n),dth:order[Math.min(n,6)],lend:n%2?'good':'letters',d_cross:order.slice(0,n).includes('cross'),d_train:order.slice(0,n).includes('train')};
    for(const [scene,commands] of Object.entries(STORY)) for(let i=0;i<commands.length;i++) {
      const c=commands[i]; if(Array.isArray(c) && typeof c[1]==='function') cases.push({scene,index:i,flags,expected:c[1]({flags})});
    }
  }
}
fs.writeFileSync(path.join(root,'godot/tests/fixtures/loop_text.json'),JSON.stringify(cases)+'\n');
console.log('loop text cases:',cases.length);
