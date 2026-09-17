"""Convert the preserved local Hunyuan pond spirit into a textured, skinned GLB.
Editable Blender source includes the rig, normalized weights and four actions.
"""
import bpy,bmesh,math,json,random
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'art/station/spirit_raw.glb'))
body=[o for o in bpy.context.scene.objects if o.type=='MESH'][0]
bpy.context.view_layer.objects.active=body
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
raw_count=sum(len(p.vertices)-2 for p in body.data.polygons)
bm=bmesh.new();bm.from_mesh(body.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001)
unseen=set(bm.verts);components=[]
while unseen:
    seed=unseen.pop();component=[seed];stack=[seed]
    while stack:
        v=stack.pop()
        for e in v.link_edges:
            q=e.other_vert(v)
            if q in unseen:unseen.remove(q);component.append(q);stack.append(q)
    components.append(component)
junk=[]
for component in components:
    extent=[max(v.co[j] for v in component)-min(v.co[j] for v in component) for j in range(3)]
    print('COMPONENT',len(component),extent,flush=True)
    if len(component)<120 or extent[1]<.065:junk.extend(component)
if junk:bmesh.ops.delete(bm,geom=junk,context='VERTS')
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free()
body.data.validate();body.data.update()
remesh=body.modifiers.new('Repair Hunyuan surface','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.009;remesh.use_smooth_shade=True
bpy.ops.object.modifier_apply(modifier=remesh.name)
smooth=body.modifiers.new('Smooth reconstruction','SMOOTH');smooth.factor=.45;smooth.iterations=3;bpy.ops.object.modifier_apply(modifier=smooth.name)
reduce=body.modifiers.new('6500 triangle silhouette budget','DECIMATE');reduce.ratio=min(1,6500/max(1,sum(len(p.vertices)-2 for p in body.data.polygons)));reduce.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier=reduce.name)
body.data.validate();body.data.update()
lo=Vector([min(v.co[j] for v in body.data.vertices) for j in range(3)]);hi=Vector([max(v.co[j] for v in body.data.vertices) for j in range(3)])
H=1.15;scale=H/(hi.z-lo.z)
for v in body.data.vertices:v.co=(v.co-Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z)))*scale
body.data.update();body.name='Hunyuan_PondSpirit_Skin'
W=max(v.co.x for v in body.data.vertices)-min(v.co.x for v in body.data.vertices)
D=max(v.co.y for v in body.data.vertices)-min(v.co.y for v in body.data.vertices)
print('CLEAN_DIMENSIONS',W,D,H,flush=True)
assert W<H and D<.8*H,'Backdrop must be removed before rigging'
surface=BVHTree.FromPolygons([v.co for v in body.data.vertices],[p.vertices[:] for p in body.data.polygons])
def front_y(x,z):
    hit,_,_,_=surface.ray_cast(Vector((x,-2,z)),Vector((0,1,0)),4)
    if hit is None:raise RuntimeError('Facial feature is outside the reconstructed head')
    return hit.y
def mix(a,b,f):return tuple(x*(1-f)+y*f for x,y in zip(a,b))
def clamp(x):return max(0,min(1,x))
def smoothstep(a,b,x):
    t=clamp((x-a)/(b-a));return t*t*(3-2*t)
def material(name,color,image=None):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.82
    if image:
        tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    return m
body.data.materials.clear()
# Two fixed planar pages: soft original colour studies, never the gray backdrop.
rr=random.Random(9141503)
for side in ['Front','Back']:
    pixels=[]
    for yy in range(512):
        v=yy/511
        for xx in range(512):
            u=xx/511;col=mix((.23,.57,.48),(.49,.77,.61),smoothstep(.05,.88,v))
            tips=max(1-smoothstep(.09,.18,v),smoothstep(.80,.90,v))
            hands=smoothstep(.25,.38,abs(u-.5))*(1-smoothstep(.26,.34,v))
            col=mix(col,(.63,.72,.28),max(tips,hands)*.90)
            if side=='Front':
                belly=((u-.50)/.19)**2+((v-.235)/.135)**2
                col=mix(col,(.84,.83,.57),(1-smoothstep(.75,1.03,belly))*.9)
            grain=rr.uniform(-.009,.009)+.008*math.sin(xx*.064+math.sin(yy*.072)*1.5)
            pixels.extend([clamp(round((c+grain)*63)/63) for c in col]+[1])
    im=bpy.data.images.new('StationSpirit'+side,width=512,height=512);im.pixels=pixels;im.filepath_raw=str(ROOT/'assets/textures'/f'StationSpirit{side}.png');im.file_format='PNG';im.save()
    body.data.materials.append(material('StationSpirit'+side,(1,1,1),im))
uv=body.data.uv_layers.new(name='PaintedSpiritUV')
for p in body.data.polygons:
    p.material_index=0 if p.normal.y<-.12 else 1;p.use_smooth=True
    for li in p.loop_indices:
        v=body.data.vertices[body.data.loops[li].vertex_index].co
        uv.data[li].uv=(v.x/W+.5,v.z/H)
# The rig uses a fixed planted root with independent feet, a breathing torso,
# head and sprout, shoulder/elbow chains, and two eyelid/eye controls.
armature=bpy.data.armatures.new('PondSpiritRig');rig=bpy.data.objects.new('PondSpiritRig',armature);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(name,a,b,parent=None):
    q=armature.edit_bones.new(name);q.head=a;q.tail=b;q.align_roll(Vector((0,-1,0)))
    if parent:q.parent=armature.edit_bones[parent]
    return q
bone('Root',(0,0,0),(0,0,.10))
bone('Body',(0,0,H*.15),(0,0,H*.365),'Root')
bone('Head',(0,0,H*.365),(0,0,H*.80),'Body')
bone('Sprout',(0,0,H*.80),(0,0,H*.99),'Head')
for sign,label in [(-1,'R'),(1,'L')]:
    bone('UpperArm.'+label,(sign*W*.14,0,H*.36),(sign*W*.29,-.005,H*.255),'Body')
    bone('Hand.'+label,(sign*W*.29,-.005,H*.255),(sign*W*.44,-.025,H*.19),'UpperArm.'+label)
    bone('Foot.'+label,(sign*W*.155,0,H*.115),(sign*W*.155,-.09,H*.06),'Root')
eye_centers={}
for sign,label in [(-1,'R'),(1,'L')]:
    x=sign*W*.212;z=H*.515;y=front_y(x,z)-.009
    eye_centers[label]=Vector((x,y,z));bone('Eye.'+label,(x,y,z),(x,y,z+.05),'Head')
bpy.ops.object.mode_set(mode='OBJECT')
def bind(obj,weights):
    obj.parent=rig
    for name in armature.bones:obj.vertex_groups.new(name=name.name)
    for index,entries in enumerate(weights):
        total=sum(entries.values())
        for name,weight in entries.items():
            if weight>0:obj.vertex_groups[name].add([index],weight/total,'REPLACE')
    mod=obj.modifiers.new('Pond spirit skin','ARMATURE');mod.object=rig
weights=[]
for v in body.data.vertices:
    x,y,z=v.co;f=z/H;a=abs(x)/W;label='L' if x>0 else 'R'
    if f>.405:
        sprout=smoothstep(.81,.90,f);q={'Head':1-sprout,'Sprout':sprout}
    elif f<.16:
        torso=smoothstep(.105,.17,f);q={'Foot.'+label:1-torso,'Body':torso}
    elif a>.15+max(0,.36-f)*.70 and f<.375:
        boundary=.15+max(0,.36-f)*.70
        arm=smoothstep(boundary,boundary+.07,a);hand=smoothstep(.25,.35,a)
        q={'Body':1-arm,'UpperArm.'+label:arm*(1-hand),'Hand.'+label:arm*hand}
    else:
        head=smoothstep(.33,.405,f);q={'Body':1-head,'Head':head}
    weights.append(q)
bind(body,weights)
ink=material('StationSpiritEyes',(.018,.045,.035));shine=material('StationSpiritEyeLight',(.88,.94,.78));cheek=material('StationSpiritCheek',(.77,.63,.32));mouth=material('StationSpiritSmile',(.13,.065,.035))
def patch(name,cx,cz,rx,rz,mat,bone_name,offset=.01,center_y=None):
    verts=[];faces=[];rings=8;sides=24
    for r in range(rings+1):
        for j in range(sides):
            a=j*math.tau/sides;f=r/rings;x=cx+math.cos(a)*rx*f;z=cz+math.sin(a)*rz*f
            y=front_y(x,z)-offset-.009*(1-f*f) if center_y is None else center_y-.007*(1-f*f)
            verts.append((x,y,z))
    for r in range(rings):
        for j in range(sides):k=r*sides+j;n=r*sides+(j+1)%sides;faces.append((k,n,n+sides,k+sides))
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);me.materials.append(mat)
    for p in me.polygons:p.use_smooth=True
    bind(o,[{bone_name:1} for _ in verts]);return o
for label,c in eye_centers.items():
    patch('Eye '+label,c.x,c.z,W*.061,H*.060,ink,'Eye.'+label,.020)
    patch('Eye glint '+label,c.x-W*.013,c.z+H*.024,W*.016,H*.017,shine,'Eye.'+label,.037)
    sign=1 if c.x>0 else -1
    patch('Cheek '+label,c.x+sign*W*.062,H*.436,W*.042,H*.019,cheek,'Head',.008)
# Follow the reconstructed mouth indentation instead of hovering a flat decal.
patch('Smile',0,H*.448,W*.054,H*.016,mouth,'Head',.016)
rig.animation_data_create()
for pose in rig.pose.bones:pose.rotation_mode='XYZ'
scene=bpy.context.scene;scene.render.fps=24
durations={'Idle':4.,'Look':6.,'Wave':5.,'Doze':8.}
for action_name,duration in durations.items():
    action=bpy.data.actions.new('Spirit'+action_name);action.use_fake_user=True;rig.animation_data.action=action
    for frame in range(int(duration*24)+1):
        t=frame/24;f=t/duration;scene.frame_set(frame)
        for p in rig.pose.bones:p.location=(0,0,0);p.rotation_euler=(0,0,0);p.scale=(1,1,1)
        breath=math.sin(f*math.tau);rig.pose.bones['Body'].scale=(1+.014*breath,1+.018*breath,1+.014*breath)
        rig.pose.bones['Sprout'].rotation_euler.z=.035*math.sin(f*math.tau)
        envelope=math.sin(math.pi*f)**2
        if action_name=='Look':
            rig.pose.bones['Head'].rotation_euler.y=.32*math.sin(f*math.tau)*envelope
            rig.pose.bones['Head'].rotation_euler.z=.055*envelope
        if action_name=='Wave':
            # Keep the small waving hand beside the oversized head, clear of
            # its cheek volume throughout the full shoulder/elbow gesture.
            rig.pose.bones['UpperArm.L'].rotation_euler.z=.50*envelope
            rig.pose.bones['Hand.L'].rotation_euler.z=(.60+.25*math.sin(f*math.tau*3))*envelope
            rig.pose.bones['Head'].rotation_euler.z=-.08*envelope
        blink=max(0,1-abs(t-duration*.63)/.13)
        if action_name=='Doze':
            blink=max(blink,envelope);rig.pose.bones['Head'].rotation_euler.x=.16*envelope
        for label in ['L','R']:rig.pose.bones['Eye.'+label].scale.y=max(.07,1-blink)
        for p in rig.pose.bones:
            p.keyframe_insert('location',frame=frame,group=p.name);p.keyframe_insert('rotation_euler',frame=frame,group=p.name);p.keyframe_insert('scale',frame=frame,group=p.name)
    rig.animation_data.action=None
    track=rig.animation_data.nla_tracks.new();track.name=action.name;strip=track.strips.new(action.name,0,action);track.mute=True
rig.animation_data.action=None;scene.frame_set(0)
for p in rig.pose.bones:p.location=(0,0,0);p.rotation_euler=(0,0,0);p.scale=(1,1,1)
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
assert triangles<10000,'Creature must fit the mobile-friendly mesh budget'
metadata=dict(generator='Local ComfyUI Hunyuan3D 2.1',seed=9141503,raw_triangles=raw_count,game_triangles=triangles,bones=len(armature.bones),height=H,actions=durations,texture_pages=[512,512],weights='normalized, maximum three bones per vertex',origin='planted feet at zero',background_removed=True)
(ROOT/'art/station/spirit_manifest.json').write_text(json.dumps(metadata,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/station_spirit.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/station_spirit.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_skins=True,export_all_influences=False,export_force_sampling=True)
print('SPIRIT_GAME_READY',metadata,flush=True)
