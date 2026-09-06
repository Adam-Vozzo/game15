import assert from 'node:assert/strict';
import {readFileSync, existsSync, statSync} from 'node:fs';
const folder = new URL('../docs/', import.meta.url);
const html = readFileSync(new URL('index.html',folder),'utf8');
assert.match(html,/GODOT_THREADS_ENABLED = false/);
const match=html.match(/const GODOT_CONFIG = (\{.*\});/);
assert.ok(match,'Export engine configuration must exist');
const config=JSON.parse(match[1]);
assert.equal(config.executable,'index');
assert.ok(!config.serviceWorker,'Pages export must not rely on a service worker');
for(const [name,size] of Object.entries(config.fileSizes)){
  assert.equal(statSync(new URL(name,folder)).size,size,`Incorrect or missing ${name}`);
  assert.ok(new URL(name,'https://adam-vozzo.github.io/game15/').pathname.startsWith('/game15/'));
}
assert.equal(readFileSync(new URL('index.wasm',folder)).subarray(0,4).toString('hex'),'0061736d');
assert.equal(readFileSync(new URL('index.pck',folder)).subarray(0,4).toString(),'GDPC');
assert.ok(existsSync(new URL('.nojekyll',folder)));
assert.ok(existsSync(new URL('index.js',folder)));
console.log('PASS: valid WebAssembly, Godot package, file sizes, relative Pages paths, single-threaded export');
