'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {escapeHtml}=require('./replacement-admin-actions');

test('user/provider content is escaped before insertion in admin DOM',()=>{
  assert.equal(escapeHtml('<img src=x onerror="alert(1)">&'),'&lt;img src=x onerror=&quot;alert(1)&quot;&gt;&amp;');
});
