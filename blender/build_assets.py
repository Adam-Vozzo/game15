"""Rebuild the original low-poly art. Run: blender --background --python blender/build_assets.py"""
import bpy, math, random, os, sys, wave, struct
from mathutils import Vector
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
random.seed(14015)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for d in bpy.data.materials: bpy.data.materials.remove(d)

def height(x,z):
    stream=math.exp(-((x-2-math.sin(z*.045)*3)/3.7)**2)*.5
    return math.sin(x*.065+z*.035)*1.5+math.cos(z*.095-x*.03)*.8+math.sin(x*.2+z*.16)*.18-stream

def tex(name,kind):
    n=128; im=bpy.data.images.new(name,width=n,height=n); pix=[]
    for y in range(n):
        for x in range(n):
            grain=random.random(); broad=math.sin(x*.19+math.sin(y*.12)*2)*.5+.5
            if kind=='bark':
                groove=(math.sin(x*.45+math.sin(y*.085)*.7)+1)*.5
                v=.13+grain*.16+groove*.13
                moss=max(0,math.sin(x*.2)*math.sin(y*.065)-.25)*.23
                rgb=(v*.76+moss*.23,v*.82+moss*.55,v*.67+moss*.28)
            elif kind=='ground':
                v=.12+grain*.22+broad*.025
                if random.random()<.035:v+=.16
                rgb=(v*.70,v*.78,v*.65)
            else:
                v=.24+grain*.17+broad*.06
                lichen=max(0,math.sin(x*.2)*math.sin(y*.15)-.4)*.14
                rgb=(v*.85+lichen,v*.94+lichen,v*.86)
            pix.extend((*rgb,1))
    im.pixels=pix; im.filepath_raw=str(ROOT/'assets'/'textures'/f'{name}.png');im.file_format='PNG';im.save();im.pack()
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.94
    node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;node.interpolation='Closest'
    mat.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
    return mat
bark=tex('Bark','bark');ground=tex('Peat','ground');rock=tex('Stone','rock')

def mesh_obj(name,verts,faces,material,uvs=None):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(material);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    uv=mesh.uv_layers.new(name='UVMap')
    for poly in mesh.polygons:
        poly.use_smooth=False
        for li in poly.loop_indices:
            vi=mesh.loops[li].vertex_index
            uv.data[li].uv=uvs[vi] if uvs else (verts[vi][0]*.35,verts[vi][2]*.35)
    return obj

# Triangulated, gently eroded terrain, with a shallow meandering hollow.
verts=[];uvs=[];faces=[];N=150
for j in range(N+1):
    z=-110+j*1.25
    for i in range(N+1):
        x=-94+i*1.25
        verts.append((x,-z,height(x,z)));uvs.append((x/5,z/5))
for j in range(N):
    for i in range(N):
        a=j*(N+1)+i;b=a+1;c=a+N+1;d=c+1
        faces.extend([(a,c,b),(b,c,d)] if (i+j)%2 else [(a,c,d),(a,d,b)])
env=[mesh_obj('Moor_Terrain',verts,faces,ground,uvs)]

def limb(name,points,radii,sides=7):
    vs=[];fs=[];uv=[]
    for i,(p,r) in enumerate(zip(points,radii)):
        axis=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
        u=axis.cross(Vector((0,1,0))).normalized()
        if u.length<.1:u=axis.cross(Vector((1,0,0))).normalized()
        v=axis.cross(u).normalized()
        for k in range(sides):
            angle=2*math.pi*k/sides+.1*math.sin(i)
            rr=r*(1+random.uniform(-.17,.17))
            q=p+(u*math.cos(angle)+v*math.sin(angle))*rr
            vs.append(tuple(q));uv.append((k/sides*1.8,p.z*.4))
    for i in range(len(points)-1):
        for k in range(sides):a=i*sides+k;b=i*sides+(k+1)%sides;c=b+sides;d=a+sides;fs.append((a,b,c,d))
    fs.append(tuple(range(sides-1,-1,-1)));fs.append(tuple((len(points)-1)*sides+k for k in range(sides)))
    ob=mesh_obj(name,vs,fs,bark,uv);env.append(ob)

def tree(x,z,size,index):
    root=Vector((x,-z,height(x,z)))
    rings=[];radii=[]
    for k in range(9):
        t=k/8; rings.append(root+Vector((math.sin(t*6+index)*.18*t,-.15*math.sin(t*3),size*t)))
        radii.append(size*(.072*(1-t)**1.1+.004)*(1.6 if k==0 else 1))
    limb(f'Tree_{index:02}_Trunk',rings,radii,9)
    for r in range(6):
        a=r*math.tau/6+random.random()*.2;length=random.uniform(.8,1.8)*size/8
        dest=root+Vector((math.cos(a)*length,math.sin(a)*length,0));dest.z=height(dest.x,-dest.y)+.06
        limb(f'Tree_{index:02}_Root_{r}',[root+Vector((0,0,.4)),(root+dest)*.5+Vector((0,0,.1)),dest],[size*.031,size*.023,.018],5)
    for b in range(10):
        t=random.uniform(.22,.85);a=random.uniform(0,math.tau);length=random.uniform(.1,.31)*size
        start=root+Vector((0,0,size*t));mid=start+Vector((math.cos(a)*length*.6,math.sin(a)*length*.6,length*random.uniform(-.2,.3)))
        end=mid+Vector((math.cos(a+.25)*length*.5,math.sin(a+.25)*length*.5,length*random.uniform(-.3,.4)))
        limb(f'Tree_{index:02}_Bough_{b}',[start,mid,end],[size*.017,size*.009,.012],6)
        if b%2==0:
            tip=end+Vector((math.cos(a-.5)*.4,math.sin(a-.5)*.4,random.uniform(-.6,.4)))
            limb(f'Tree_{index:02}_Twig_{b}',[mid,end,tip],[.045,.02,.006],4)
    # Long jagged splinters on the broken crown.
    for k in range(3):
        base=rings[-2]+Vector((random.uniform(-.12,.12),random.uniform(-.12,.12),0))
        limb(f'Tree_{index:02}_Splinter_{k}',[base,base+Vector((random.uniform(-.12,.12),0,size*random.uniform(.12,.2)))],[.08,.001],4)
for i,(x,z,h) in enumerate([(-6.5,-1,8.8),(8.8,-20,7.6),(-18,-28,8),(24,-47,9),(-9,-57,7),(4,-80,8),(-25,7,9),(30,-15,7),(-32,-67,10)]):tree(x,z,h,i)

# Angular lichen-covered stones, concentrated near the eroded hollow.
for i in range(180):
    z=random.uniform(-90,26);x=random.uniform(-60,60)
    if i<55:x=2+math.sin(z*.045)*3+random.uniform(-4,4)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,-z,height(x,z)))
    ob=bpy.context.object;ob.name=f'Lichen_Stone_{i:03}'
    ob.scale=(random.uniform(.12,.65),random.uniform(.15,.6),random.uniform(.09,.34));ob.rotation_euler=(random.random(),random.random(),random.random()*6)
    ob.data.materials.append(rock)
    uv=ob.data.uv_layers.new(name='UVMap')
    for poly in ob.data.polygons:
        for li in poly.loop_indices:
            v=ob.data.vertices[ob.data.loops[li].vertex_index].co;uv.data[li].uv=(v.x*.5+.5,v.y*.5+.5)
    env.append(ob)

# A reusable modeled tuft; Godot instances and animates it on the GPU.
vs=[];fs=[];uv=[]
for i in range(7):
    a=random.random()*math.tau;h=random.uniform(.38,.85);w=random.uniform(.025,.05);ox=random.uniform(-.12,.12);oy=random.uniform(-.12,.12)
    start=len(vs)
    for j in range(4):
        t=j/3
        for sign in [-1,1]:
            vs.append((ox+math.cos(a)*w*sign*(1-t)+t*t*h*.24,oy+math.sin(a)*w*sign*(1-t),h*t));uv.append((0 if sign<0 else 1,t))
    for j in range(3):a0=start+j*2;fs.extend([(a0,a0+1,a0+2),(a0+1,a0+3,a0+2)])
grass=mesh_obj('Wind_Grass_Tuft',vs,fs,ground,uv)
grass.location=(0,0,-30)
# A dry fern silhouette, an alternate ground-cover mesh.
vs=[];fs=[];uv=[]
for arm in range(4):
    a=arm*math.pi/2+.2
    for k in range(7):
        t=(k+1)/8;r=t*.45;wide=(1-t)*.16
        for side in [-1,1]:
            p=Vector((math.cos(a)*r,math.sin(a)*r,math.sin(t*math.pi)*.22));q=p+Vector((math.cos(a+side*.9)*wide,math.sin(a+side*.9)*wide,.03))
            base=len(vs);vs.extend([tuple(p),tuple(q),tuple(p+Vector((math.cos(a)*.08,math.sin(a)*.08,.015)))]);fs.append((base,base+1,base+2));uv.extend([(0,t),(1,t+.1),(0,t+.1)])
fern=mesh_obj('Dry_Fern',vs,fs,ground,uv);fern.location=(2,0,-30)

# Editable art file includes a camera and moon light for material inspection.
bpy.ops.object.camera_add(location=(0,-15,height(0,15)+2.2));camera=bpy.context.object;camera.name='Opening_View';camera.rotation_euler=(Vector((-1,20,3))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=26;bpy.context.scene.camera=camera
bpy.ops.object.light_add(type='SUN',location=(-30,40,50));bpy.context.object.name='Moonlight';bpy.context.object.data.energy=.5;bpy.context.object.rotation_euler=(.4,-.4,-.5)
bpy.context.scene.world.color=(.06,.085,.09)
bpy.context.scene.render.resolution_x=1280;bpy.context.scene.render.resolution_y=800
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender'/'hollow_moor.blend'))

def export_selected(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets'/'models'/name),export_format='GLB',use_selection=True,export_materials='EXPORT',export_yup=True)
# Move source assets to origin for export; blend retains their source positions.
grass.location=(0,0,0);export_selected([grass],'grass_tuft.glb')
fern.location=(0,0,0);export_selected([fern],'fern.glb')
# Join only the runtime environment, retaining the individually editable .blend.
bpy.ops.object.select_all(action='DESELECT')
for o in env:o.select_set(True)
bpy.context.view_layer.objects.active=env[0];bpy.ops.object.join();environment=bpy.context.object;environment.name='Moor_Environment'
export_selected([environment],'moor.glb')
# Seamless wind loop, pre-rendered for single-threaded browser audio.
rate=22050;duration=16;length=rate*duration;rng=random.Random(111);brown=0;audio=[]
for i in range(length):
    brown=(brown+(rng.random()*2-1)*.045)/1.025
    gust=.6+.18*math.sin(i/length*math.tau*2)+.13*math.sin(i/length*math.tau*5)
    audio.append(brown*gust)
fade=2048
for i in range(fade):
    t=i/fade;v=audio[i]*t+audio[length-fade+i]*(1-t);audio[i]=v;audio[length-fade+i]=v
with wave.open(str(ROOT/'assets'/'audio'/'moor_wind.wav'),'wb') as f:
    f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,s))*26000)) for s in audio))
print('ASSETS COMPLETE: editable Blender scene, three GLBs, three textures, wind loop')
