"""Source-authored anchors for Azure's deterministic shader particles.

The tiny source quads have nonzero area and normals indicating the direction
out of each fall. UVs reconstruct their centres after glTF's V conversion.
Colour stores independent phase, speed, size seeds and the physical drop.
All motion is evaluated from Godot's pausable scene clock.
"""
import bpy, math, random, json, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from azure_water_geometry import lip, UPPER_ARC, upper_sample
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
rng=random.Random(180927)

groups={name:dict(v=[],f=[],uv=[],c=[]) for name in ['Threads','Spray','Mist','Foam']}
counts={}
def anchor(kind,p,outward,drop):
    group=groups[kind];n=len(group['v'])
    seed=(rng.random(),rng.random(),rng.random(),drop/53)
    for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]:
        # Tangent cross up is the true outward normal, including curved lips.
        v=(p[0]+.02*x*outward[1],p[1]+.02*y,p[2]-.02*x*outward[0])
        group['v'].append((v[0],-v[2],v[1]))
        group['uv'].append((x*.5+.5,y*.5+.5));group['c'].append(seed)
    group['f'].append((n,n+1,n+2,n+3))

regions=[dict(name='Main',start=-220,end=220,top=18,bottom=-35,counts=[1300,2000,240,290]),
         dict(name='UpperCurve',start=0,end=UPPER_ARC[-1],top=42,bottom=18,counts=[1040,1520,190,230])]
for region in regions:
    counts[region['name']]={}
    for kind,count in zip(groups,region['counts']):
        counts[region['name']][kind]=count
        for i in range(count):
            along=rng.uniform(region['start'],region['end'])
            main=region['name']=='Main'
            if main:p=[along,region['top'],lip(along)];normal=(0,1)
            else:
                edge,normal=upper_sample(along)
                p=[edge[0],region['top'],edge[1]]
            if kind!='Threads':
                p[1]=region['bottom']+.16
                outward=(2.8 if main else 2.)+rng.uniform(.8,4.)
                if kind=='Foam':outward+=rng.uniform(6.,17.)
                p[0]+=normal[0]*outward;p[2]+=normal[1]*outward
            anchor(kind,p,normal,region['top']-region['bottom'])

for name,g in groups.items():
    mesh=bpy.data.meshes.new('AzureWater'+name)
    mesh.from_pydata(g['v'],[],g['f']);mesh.update()
    ob=bpy.data.objects.new(mesh.name,mesh);bpy.context.collection.objects.link(ob)
    mat=bpy.data.materials.new(mesh.name);mat.diffuse_color=(.8,.93,.88,1);mesh.materials.append(mat)
    uv=mesh.uv_layers.new(name='ParticleCorner')
    col=mesh.color_attributes.new(name='Particle',type='FLOAT_COLOR',domain='POINT')
    for i,c in enumerate(g['c']):col.data[i].color=c
    for poly in mesh.polygons:
        for li in poly.loop_indices:uv.data[li].uv=g['uv'][mesh.loops[li].vertex_index]
    ob['purpose']='Fixed emitter anchors; scene-clock GPU motion in azure_particles.gdshader'

layout=dict(regions=regions,counts=counts,total=sum(len(g['f']) for g in groups.values()),seed=180927)
(ROOT/'assets/data/azure_water.json').write_text(json.dumps(layout,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/azure_water.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/azure_water.glb'),export_format='GLB',export_vertex_color='NAME',export_vertex_color_name='Particle',export_all_vertex_colors=False,export_cameras=False,export_lights=False)
print('AZURE_WATER_READY:',layout['total'],'source-authored particles on the main and curved upper falls')
