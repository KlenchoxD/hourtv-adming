'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {escapeHtml}=require('./replacement-admin-actions');
const fs=require('node:fs');const vm=require('node:vm');const path=require('node:path');

test('user/provider content is escaped before insertion in admin DOM',()=>{
  assert.equal(escapeHtml('<img src=x onerror="alert(1)">&'),'&lt;img src=x onerror=&quot;alert(1)&quot;&gt;&amp;');
});
test('protected UI action can resolve recovery guard inside module scope',()=>{
  const callbacks=[];const storage={getItem:()=>JSON.stringify({phase:'pending_publish',candidateIds:['c1']}),removeItem(){}};
  const window={HourTVPublishRecovery:{loadRecovery:s=>JSON.parse(s.getItem())},toast(){},HourTVAdminState:{},};
  const recoveryButton={};const document={readyState:'loading',addEventListener:(_name,fn)=>callbacks.push(fn),getElementById:id=>id==='replacement-recovery-btn'?recoveryButton:null};
  const context=vm.createContext({window,document,localStorage:storage,console,setTimeout,clearTimeout,confirm:()=>false});
  vm.runInContext(fs.readFileSync(path.join(__dirname,'replacement-admin-ui.js'),'utf8'),context);
  assert.doesNotThrow(()=>window.openBatchPreview());
});
