"""Original Phuket-inspired coast and rural Japanese town. Blender 5.2+.
Run: blender --background --python blender/build_places.py
The moor's editable source is preserved by this script.
"""
import bpy, math, random, wave, struct
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
random.seed(8815)

def reset():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def xyz(p):return (p[0],-p[2],p[1])
def texture(name,color,kind='grain'):
    mat=bpy.data.materials.get(name)
    if mat:return mat
    im=bpy.data.images.new(name+'128',width=128,height=128);pixels=[]
    for y in range(128):
        for x in range(128):
            n=random.random()*.20-.1
            if kind=='wood':n+=math.sin(y*.27+math.sin(x*.04)*2)*.08; n-=.11 if y%23<2 else 0
            if kind=='tile':n-=.14 if x%16<2 or y%32<2 else 0
            if kind=='plaster':n+=math.sin(x*.08)*math.sin(y*.09)*.06
            pixels.extend([max(.015,min(.95,c*(1+n))) for c in color]+[1])
    im.pixels=pixels;im.filepath_raw=str(R/'assets'/'textures'/(name+'128.png'));im.file_format='PNG';im.save();im.pack()
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.88
    node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;node.interpolation='Closest';mat.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
    return mat
sand=texture('Sand',(.60,.49,.34));wood=texture('WeatheredWood',(.24,.16,.10),'wood');palm=texture('PalmLeaf',(.13,.21,.12));rock=texture('CoastalRock',(.25,.27,.23));red=texture('FadedRed',(.44,.16,.10));rope=texture('Rope',(.42,.34,.20));cloth=texture('Canvas',(.52,.48,.36));blue=texture('BoatBlue',(.11,.24,.26))
plaster=texture('Plaster',(.46,.43,.34),'plaster');timber=texture('TownTimber',(.23,.16,.12),'wood');roofmat=texture('RoofTile',(.17,.20,.20),'tile');stone=texture('WetStone',(.24,.26,.25),'tile');glow=texture('WindowGlow',(.96,.66,.31));noren=texture('Noren',(.17,.24,.25));white=texture('RicePaper',(.64,.60,.49));moss=texture('Moss',(.15,.22,.13));rust=texture('Rust',(.25,.14,.09));black=texture('Wire',(.035,.04,.038));flower=texture('RedFlowers',(.47,.09,.075));damp_sand=texture('DampSand',(.46,.39,.27))

def mesh(name,verts,faces,mat,uvs=None):
    data=bpy.data.meshes.new(name);data.from_pydata([xyz(v) for v in verts],[],faces);data.materials.append(mat);data.update()
    ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob);layer=data.uv_layers.new(name='UVMap')
    for poly in data.polygons:
        for li in poly.loop_indices:
            i=data.loops[li].vertex_index;layer.data[li].uv=uvs[i] if uvs else (verts[i][0]*.35,verts[i][2]*.35)
    return ob

def box(name,p,scale,mat,rotation=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));ob=bpy.context.object;ob.name=name;ob.scale=(scale[0],scale[2],scale[1]);ob.rotation_euler.z=-rotation;ob.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return ob

def beam(name,a,b,r,mat,r2=None,steps=6):
    aa=Vector(xyz(a));bb=Vector(xyz(b));delta=bb-aa
    bpy.ops.mesh.primitive_cone_add(vertices=steps,radius1=r,radius2=r if r2 is None else r2,depth=delta.length,location=(aa+bb)/2)
    ob=bpy.context.object;ob.name=name;ob.rotation_euler=delta.to_track_quat('Z','Y').to_euler();ob.data.materials.append(mat);return ob

def ico(name,p,s,mat,sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=xyz(p));ob=bpy.context.object;ob.name=name;ob.scale=(s[0],s[2],s[1]);ob.data.materials.append(mat);return ob

def curve(name,points,r,mat):
    return [beam(name+str(i),points[i],points[i+1],r,mat,steps=4) for i in range(len(points)-1)]

def join(objects,name,origin=None):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();ob=bpy.context.object;ob.name=name
    if origin is not None:bpy.context.scene.cursor.location=xyz(origin);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return ob

def save_export(name,objects):
    bpy.ops.object.camera_add(location=(0,-15,3));cam=bpy.context.object;cam.name='Composition_Camera';cam.rotation_euler=(Vector((0,20,2))-cam.location).to_track_quat('-Z','Y').to_euler();bpy.context.scene.camera=cam
    bpy.context.scene.world.color=(.15,.17,.18)
    bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender'/(name+'.blend')))
    # Keep an editable art file, but consolidate static geometry to minimize runtime draw calls.
    static=[o for o in objects if not any(k in o.name for k in ['PalmCrown','BoatFloat','NorenFlag','Laundry','WindChime'])]
    dynamic=[o for o in objects if o not in static]
    merged=join(static,name+'_Landscape')
    bpy.ops.object.select_all(action='DESELECT')
    for o in [merged]+dynamic:o.select_set(True)
    bpy.context.view_layer.objects.active=merged
    bpy.ops.export_scene.gltf(filepath=str(R/'assets'/'models'/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True)

def beach_h(x,z):return .07+.065*(z-(1+math.sin(x*.09)*1.1))+.12*math.sin(x*.07)*max(0,z)/24
reset();all=[]
verts=[];uv=[];faces=[];nx=100;nz=65
for j in range(nz+1):
    z=-14+j*.8
    for i in range(nx+1):
        x=-50+i;verts.append((x,beach_h(x,z),z));uv.append((x/4,z/4))
for j in range(nz):
    for i in range(nx):a=j*(nx+1)+i;b=a+1;c=a+nx+1;d=c+1;faces.extend([(a,b,c),(b,d,c)])
all.append(mesh('Tidal_Sand',verts,faces,sand,uv))
# Curving palms form a sparse, irregular canopy around the opening view.
for k,(x,z,h) in enumerate([(-6.8,3.5,5.8),(-13,5,7),(8,2.5,6.4),(17,8,8),(24,17,10),(-23,19,9)]):
    y=beach_h(x,z);pts=[]
    for j in range(10):
        t=j/9;pts.append((x+(-1 if x>0 else 1)*math.sin(t*1.5)*h*.19,y+t*h,z-t*t*.6))
    for j in range(9):all.append(beam('Palm_Trunk',pts[j],pts[j+1],.25*(1-j*.055),wood,.25*(1-(j+1)*.055),7))
    for j in range(22):
        t=j/23;p=(x+(-1 if x>0 else 1)*math.sin(t*1.5)*h*.19,y+t*h,z-t*t*.6)
        all.append(beam('Trunk_Ring',(p[0],p[1]-.025,p[2]),(p[0],p[1]+.025,p[2]),.262*(1-t*.5),wood,steps=7))
    vs=[];fs=[]
    for f in range(10):
        a=f*math.tau/10+random.uniform(-.15,.15);length=random.uniform(2.3,3.7);base=len(vs)
        for j in range(8):
            t=j/7;mid=Vector((math.cos(a)*length*t,math.sin(t*math.pi)*.65-t*t*.7,math.sin(a)*length*t));width=math.sin(t*math.pi)*.045
            for side in [-1,1]:vs.append(tuple(mid+Vector((-math.sin(a)*width*side,0,math.cos(a)*width*side))))
        for j in range(7):b=base+j*2;fs.extend([(b,b+1,b+2),(b+1,b+3,b+2)])
        # Separate tapered leaflets give each frond a broken, feathered silhouette.
        for j in range(1,13):
            t=j/14;mid=Vector((math.cos(a)*length*t,math.sin(t*math.pi)*.65-t*t*.7,math.sin(a)*length*t))
            forward=Vector((math.cos(a),0,math.sin(a)))
            for side in [-1,1]:
                across=Vector((-math.sin(a)*side,0,math.cos(a)*side));span=math.sin(t*math.pi)*.56
                b=len(vs);vs.extend([tuple(mid-forward*.07),tuple(mid+across*span+forward*.28+Vector((0,-.13,0))),tuple(mid+forward*.10)])
                fs.append((b,b+1,b+2))
    crown=mesh('PalmCrown_'+str(k),vs,fs,palm);crown.location=xyz(pts[-1]);all.append(crown)
# Rocky island silhouettes in the Andaman haze.
for k,(x,z,s) in enumerate([(-50,-115,22),(-22,-155,13),(64,-180,35),(88,-155,17)]):
    all.append(ico('Distant_Headland',(x,s*.30,z),(s*.85,s*.80,s*.62),rock,2))
    all.append(ico('Headland_Trees',(x-1,s*.70,z),(s*.73,s*.35,s*.6),palm,2))
# Local granite and shells.
for i in range(55):
    x=random.choice([-1,1])*random.uniform(21,43);z=random.uniform(-1,27);all.append(ico('Shore_Stone',(x,beach_h(x,z),z),(random.uniform(.3,2),random.uniform(.3,1),random.uniform(.3,1.4)),rock))
for i in range(70):
    x=random.uniform(-18,18);z=random.uniform(2,16);all.append(ico('Washed_Shell',(x,beach_h(x,z)+.02,z),(.045,.025,.07),cloth))
# Long-tail boat: a lifted prow, narrow timber hull, faded stripe, seats, and engine shaft.
boat=[];vs=[];fs=[]
for z,width,rise in [(-3.3,.04,.9),(-2.4,.55,.25),(-.8,.72,0),(1.5,.62,.05),(2.6,.35,.32)]:
    vs.extend([(-width,.12+rise,z),(-width*.8,-.2+rise,z),(width*.8,-.2+rise,z),(width,.12+rise,z)])
for j in range(4):
    for f in range(3):a=j*4+f;fs.append((a,a+1,a+5,a+4))
fs.extend([(0,1,2,3),(16,17,18,19)])
boat.append(mesh('Longtail_Hull',vs,fs,wood))
for side in [-1,1]:
    pts=[(side*w,.17+r,z) for z,w,r in [(-3.3,.04,.9),(-2.4,.55,.25),(-.8,.72,0),(1.5,.62,.05),(2.6,.35,.32)]];boat+=curve('Blue_Gunwale',pts,.07,blue)
for z in [-1.8,-.5,.9,1.9]:boat.append(box('Boat_Seat',(0,.08,z),(1.2,.11,.2),wood))
boat.append(box('Small_Engine',(0,.3,2.25),(.47,.45,.53),rust));boat.append(beam('Long_Propeller_Shaft',(0,.3,2.4),(0,-.17,5.1),.026,black))
boat.append(beam('High_Prow',(0,.8,-3.3),(0,1.48,-3.48),.065,wood,.04))
boat.append(box('Prow_Ribbon',(0,1.07,-3.44),(.18,.48,.08),red))
boatob=join(boat,'BoatFloat',origin=(0,0,0));boatob.location=xyz((5,.1,-4));boatob.rotation_euler.z=-1.3;all.append(boatob)
# A rope leads to the shore, next to a small coiled line and sandals.
all+=curve('Mooring_Line',[(8.3,1.2,-4.9),(6,.25,-1),(2.5,beach_h(2.5,3)+.04,3)],.018,rope)
for loop in range(4):
    pts=[]
    for j in range(19):a=j*math.tau/18;r=.24+loop*.04;pts.append((2.5+math.cos(a)*r,beach_h(2.5,3)+.045,3+math.sin(a)*r))
    all+=curve('Coiled_Rope',pts,.018,rope)
for x in [-.5,-.16]:
    y=beach_h(x,7);all.append(ico('Sandal_Sole',(x,y+.025,7),(.10,.025,.20),red,2))
    all+=curve('Sandal_Strap',[(x-.075,y+.05,6.95),(x,y+.09,6.92),(x+.075,y+.05,6.95)],.018,rope)
for k in range(14):
    z=1.7+k*.32;x=-.35+math.sin(k*.16)*.4+(-.1 if k%2 else .1)
    all.append(ico('Fading_Footprint',(x,beach_h(x,z)+.009,z),(.065,.006,.13),damp_sand,1))
# Two empty chairs and a small table under the palms.
for x in [-5.5,-7.5]:
    y=beach_h(x,6)
    all.append(box('Woven_Chair_Seat',(x,y+.5,6),(.8,.08,.7),cloth))
    all.append(box('Chair_Back',(x,y+1,6.3),(.8,.85,.07),wood))
    for dx in [-.32,.32]:
        for dz in [-.26,.26]:all.append(beam('Chair_Leg',(x+dx,y,6+dz),(x+dx,y+.55,6+dz),.035,wood))
y=beach_h(-6.5,6);all.append(box('Tea_Table',(-6.5,y+.6,6),(.7,.12,.7),wood));all.append(beam('Table_Leg',(-6.5,y,6),(-6.5,y+.6,6),.12,wood))
all.append(ico('Forgotten_Cup',(-6.5,y+.74,6),(.07,.1,.07),cloth))
save_export('phuket_coast',all)

# Ambient loops: shore wash and soft rain, deliberately sparse and loopable.
for name,kind in [('coast_wash','sea'),('town_rain','rain'),('menu_air','menu')]:
    sr=22050;duration=18;data=[];brown=0;rng=random.Random(551)
    for i in range(sr*duration):
        t=i/sr;n=rng.uniform(-1,1);brown=(brown+n*.035)/1.02
        if kind=='sea':v=brown*(.30+.7*(.5+.5*math.sin(t*math.tau/6))**3)+n*.009
        elif kind=='rain':v=brown*.20+n*.018
        else:v=sum(math.sin(math.tau*f*t)*.014 for f in [220,277.183,329.628,440])*(.6+.2*math.sin(t*math.tau/9))
        fade=min(1,t/.25,(duration-t)/.25);data.append(int(max(-1,min(1,v*fade))*26000))
    with wave.open(str(R/'assets'/'audio'/(name+'.wav')),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes(struct.pack('<'+'h'*len(data),*data))
print('COAST AND AUDIO COMPLETE; rebuilding Kasumi next')

# Kasumi has its own architectural generator and committed Aseprite texture pages.
import runpy
runpy.run_path(str(R/'blender/build_kasumi.py'), run_name='__main__')
