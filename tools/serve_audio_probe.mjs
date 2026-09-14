// Local-only instrumented view of docs; generated shipping files stay untouched.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const docs=path.join(root,'docs');
const types={'.html':'text/html','.js':'application/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
http.createServer((req,res)=>{
  const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  if(pathname==='/__audio_probe.js'){
    res.writeHead(200,{'Content-Type':'application/javascript','Cache-Control':'no-store'});
    return fs.createReadStream(path.join(root,'tests/web_audio_probe.js')).pipe(res);
  }
  const file=path.resolve(docs,'.'+(pathname==='/'?'/index.html':pathname));
  if(!file.startsWith(docs+path.sep)||!fs.existsSync(file)){res.writeHead(404);return res.end();}
  res.writeHead(200,{'Content-Type':types[path.extname(file)]??'application/octet-stream','Cache-Control':'no-store'});
  if(path.extname(file)==='.html')return res.end(fs.readFileSync(file,'utf8').replace('<head>','<head><script src="/__audio_probe.js"></script>'));
  fs.createReadStream(file).pipe(res);
}).listen(5186,'127.0.0.1',()=>console.log('Muted audio probe: http://127.0.0.1:5186/'));
