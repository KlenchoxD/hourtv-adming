'use strict';
const test=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');
const sql=fs.readFileSync(path.join(__dirname,'../supabase/migrations/20260922093000_harden_admin_replacement_workflow.sql'),'utf8');
test('apply and search RPCs lock source and require confirmed down state',()=>{
  const locks=(sql.match(/from public\.sources where id=.*for update/gi)||[]).length;
  assert.ok(locks>=2);assert.match(sql,/only confirmed down sources can be replaced/);assert.match(sql,/search only allowed for confirmed down source/);
});
test('search persistence RPC owns attempts candidate provider increment and notification atomically',()=>{
  const body=sql.slice(sql.indexOf('admin_persist_replacement_search'),sql.indexOf('revoke all on function'));
  for(const table of ['replacement_search_attempts','replacement_candidates','backup_providers','admin_notifications'])assert.match(body,new RegExp(table));
  assert.match(sql,/security definer set search_path=''/);assert.match(sql,/public\.is_admin\(\)/);
});
