// Preserve successful local generation history and its raw geometry together.
import {readFileSync,writeFileSync} from 'node:fs';
const asset=process.argv[2];
if(!['train','clock','spirit'].includes(asset))throw Error('Expected station asset name');
const dir='art/station/';const job=JSON.parse(readFileSync(dir+asset+'_job.json','utf8'));
const response=await fetch('http://127.0.0.1:8188/history/'+job.prompt_id);
const history=await response.json();const run=history[job.prompt_id];
if(!run){console.log('GENERATION_RUNNING');process.exit(0);}
writeFileSync(dir+asset+'_history.json',JSON.stringify(history,null,2)+'\n');
if(run.status.status_str!=='success')throw Error(JSON.stringify(run.status));
const output=Object.values(run.outputs).flatMap(o=>Object.values(o).flat()).find(o=>o?.filename?.endsWith('.glb'));
if(!output)throw Error('No generated GLB in completed history');
const query=new URLSearchParams({filename:output.filename,subfolder:output.subfolder??'',type:output.type??'output'});
const mesh=await fetch('http://127.0.0.1:8188/view?'+query);
if(!mesh.ok)throw Error(await mesh.text());
const data=Buffer.from(await mesh.arrayBuffer());writeFileSync(dir+asset+'_raw.glb',data);
console.log('GENERATION_SAVED',job.prompt_id,data.length);
