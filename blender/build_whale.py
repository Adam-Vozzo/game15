"""Original 20 metre whale, with broad head, ventral pleats and articulated silhouette."""
import bpy, math
from pathlib import Path
R=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mesh(name,verts,faces):
    m=bpy.data.meshes.new(name);m.from_pydata([(x,-z,y) for x,y,z in verts],[],faces);m.update()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o)
    for p in m.polygons:p.use_smooth=True
    return o
stations=[(-8.8,.06,.08),(-8.,1.2,1.0),(-6.,1.9,1.65),(-3.,2.05,1.9),(0.,1.7,1.7),(3.,1.0,1.15),(5.5,.55,.6),(7.5,.24,.27),(8.5,.16,.16)]
v=[];f=[];n=20
for z,w,h in stations:
    for j in range(n):
        a=j*math.tau/n;v.append((math.cos(a)*w,math.sin(a)*h,z))
for k in range(len(stations)-1):
    for j in range(n):
        a=k*n+j;b=k*n+(j+1)%n;f.append((a,b,b+n,a+n))
f.extend([tuple(reversed(range(n))),tuple(range((len(stations)-1)*n,len(stations)*n))])
mesh('Whale body',v,f)
for side in [-1,1]:
    mesh('Long pectoral flipper',[(side*1.6,-.45,-4),(side*3.3,-.7,-2.7),(side*5.5,-1.1,.5),(side*4.9,-1.2,1),(side*2,-.8,-1.6)],[(0,1,2,3,4)])
    mesh('Tail fluke',[(side*.15,0,7.6),(side*3.5,.08,8.9),(side*4.,0,10),(side*1.6,-.12,9.6),(0,-.05,9.05)],[(0,1,2,3,4)])
mesh('Swept dorsal fin',[(0,1.3,1.5),(.08,2.55,2.7),(0,1.15,4.1),(-.08,1.3,1.5)],[(0,1,2),(3,2,1)])
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/night_whale.blend'))
bpy.ops.export_scene.gltf(filepath=str(R/'assets/models/night_whale.glb'),export_format='GLB')
print('WHALE_READY')
