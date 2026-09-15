// Local ComfyUI Hunyuan3D 2.1 shape generation. No remote inference service.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import path from 'node:path';
const [asset,imagePath]=process.argv.slice(2);
if (!['train','clock','spirit'].includes(asset) || !imagePath) throw Error('Usage: node tools/generate_station_assets.mjs train|clock|spirit image.png');
const root=path.resolve('art/station'); mkdirSync(root,{recursive:true});
const base='http://127.0.0.1:8188';
const form=new FormData();form.append('image',new Blob([readFileSync(imagePath)],{type:'image/png'}),`still_station_${asset}.png`);form.append('overwrite','true');
const up=await fetch(base+'/upload/image',{method:'POST',body:form}); if(!up.ok)throw Error(await up.text());
const uploaded=await up.json();
const node=(class_type,inputs)=>({class_type,inputs});
const prompt={
 '1':node('ImageOnlyCheckpointLoader',{ckpt_name:'hunyuan_3d_v2.1.safetensors'}),
 '2':node('LoadImage',{image:uploaded.name}),
 '3':node('ModelSamplingAuraFlow',{model:['1',0],shift:1}),
 '4':node('CLIPVisionEncode',{clip_vision:['1',1],image:['2',0],crop:'none'}),
 '5':node('Hunyuan3Dv2Conditioning',{clip_vision_output:['4',0]}),
 '6':node('EmptyLatentHunyuan3Dv2',{resolution:4096,batch_size:1}),
 '7':node('KSampler',{model:['3',0],seed:{train:9141501,clock:9141502,spirit:9141503}[asset],steps:30,cfg:5,sampler_name:'euler',scheduler:'normal',positive:['5',0],negative:['5',1],latent_image:['6',0],denoise:1}),
 '8':node('VAEDecodeHunyuan3D',{samples:['7',0],vae:['1',2],num_chunks:8000,octree_resolution:384}),
 '9':node('VoxelToMesh',{voxel:['8',0],algorithm:'surface net',threshold:.6}),
 '10':node('SaveGLB',{mesh:['9',0],filename_prefix:`still_station/${asset}`})
};
writeFileSync(path.join(root,asset+'_workflow.json'),JSON.stringify(prompt,null,2)+'\n');
const submit=await fetch(base+'/prompt',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({prompt,client_id:'still-station-build'})});
const job=await submit.json();if(!submit.ok)throw Error(JSON.stringify(job));
writeFileSync(path.join(root,asset+'_job.json'),JSON.stringify(job,null,2)+'\n');console.log(JSON.stringify(job));
