'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
const ui = fs.readFileSync(path.join(__dirname, 'replacement-admin-ui.js'), 'utf8');

test('admin DOM exposes replacement tabs, unread counter source, and modular scripts', () => {
  assert.match(html, /id:'backup_providers'/);
  assert.match(html, /id:'notifications'/);
  assert.match(html, /replacement-logic\.js[\s\S]*replacement-admin\.js/);
  assert.match(html, /replacement-admin-ui\.js/);
  assert.match(html, /_unreadNotificationsCount/);
});

test('admin actions are wired and the removed Supabase SDK constructor is not reintroduced', () => {
  for (const action of ['Reemplazar todos', 'Comprobar otra vez', 'Buscar reemplazo', 'Reemplazar servidor', 'Probar configuración']) assert.match(ui, new RegExp(action));
  assert.doesNotMatch(html, /window\.supabase\.createClient/);
  assert.match(ui, /publish\(\{ throwOnError:true \}\)/);
});
