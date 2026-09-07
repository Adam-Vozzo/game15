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

# --- Rain-softened rural town ---
reset();all=[]
def town_h(x,z):return .03+max(0,-z)*.012+abs(x)*.003
v=[];uv=[];f=[];nx=70;nz=90
for j in range(nz+1):
    z=24-j*1.1
    for i in range(nx+1):x=-38+i*1.1;v.append((x,town_h(x,z),z));uv.append((x/3,z/3))
for j in range(nz):
    for i in range(nx):a=j*(nx+1)+i;f.extend([(a,a+1,a+nx+1),(a+1,a+nx+2,a+nx+1)])
all.append(mesh('Wet_Lane',v,f,stone,uv))
# Houses are built individually, with timber frames, deep eaves, tiled ridges, and shoji lights.
def house(x,z,w,d,h,index):
    base=town_h(x,z);front=1 if x<0 else -1
    all.append(box('Stone_Foundation',(x,base+.25,z),(w+.2,.5,d+.2),stone))
    all.append(box('Plaster_Walls',(x,base+h/2+.35,z),(w,h,d),plaster))
    for dx in [-w/2,0,w/2]:all.append(box('Timber_Post',(x+dx,base+h/2+.35,z+d/2+.04),(.14,h,.13),timber))
    for dz in [-d/2,-d/4,0,d/4,d/2]:all.append(box('Side_Post',(x+front*(w/2+.04),base+h/2+.35,z+dz),(.13,h,.15),timber))
    for y in [base+.65,base+1.8,base+h+.3]:all.append(box('Timber_Beam',(x+front*(w/2+.07),y,z),(.18,.13,d+.2),timber))
    # Roof ridge runs along the street.
    roof_y=base+h+.35;peak=roof_y+1.55;left=x-w/2-.65;right=x+w/2+.65
    all.append(mesh('Gabled_Roof',[(left,roof_y,z-d/2-.7),(x,peak,z-d/2-.7),(right,roof_y,z-d/2-.7),(left,roof_y,z+d/2+.7),(x,peak,z+d/2+.7),(right,roof_y,z+d/2+.7)],[(0,1,4,3),(1,2,5,4)],roofmat))
    all.append(beam('Roof_Ridge',(x,peak+.07,z-d/2-.8),(x,peak+.07,z+d/2+.8),.11,roofmat,steps=6))
    for zz in [z-d/2,z+d/2]:
        all.append(mesh('Gable_Plaster',[(x-w/2,roof_y,zz),(x,peak-.22,zz),(x+w/2,roof_y,zz)],[(0,1,2)],plaster))
        all.append(box('Gable_Vent',(x,roof_y+.4,zz+.03),(1.2,.36,.10),timber))
    # Weatherboards, shuttered end windows, and a little tiled awning break up the end walls.
    for k in range(6):all.append(box('Weatherboard',(x,base+.40+k*.12,z+d/2+.075),(w,.08,.09),timber))
    for dx in [-w*.24,w*.24]:
        all.append(box('End_Shutter',(x+dx,base+1.95,z+d/2+.10),(1.15,1.2,.09),noren if index%2 else timber))
        for kk in range(7):all.append(box('Shutter_Slat',(x+dx-.52+kk*.17,base+1.95,z+d/2+.16),(.035,1.22,.07),wood))
        all.append(box('Small_Awning',(x+dx,base+2.67,z+d/2+.35),(1.48,.14,.75),roofmat))
    for s in [-1,1]:
        for j in range(int(d/.42)+3):
            zz=z-d/2-.65+j*.42
            all.append(beam('Tile_Rib',(x,peak+.03,zz),(x+s*(w/2+.65),roof_y+.03,zz),.055,roofmat,steps=5))
    # Street-facing windows and sliding wooden shutters.
    wallx=x+front*(w/2+.08)
    for dz in [-d*.25,d*.22]:
        all.append(box('WindowGlow' if index%3!=2 else 'Closed_Shutter',(wallx,base+1.8,z+dz),(.05,1.2,1.75),glow if index%3!=2 else noren))
        for yy in [base+1.25,base+1.8,base+2.35]:all.append(box('Window_Frame',(wallx+front*.05,yy,z+dz),(.075,.055,1.83),timber))
        for dd in [-.84,-.42,0,.42,.84]:all.append(box('Shoji_Lattice',(wallx+front*.055,base+1.8,z+dz+dd),(.08,1.22,.045),timber))
    all.append(box('Door',(wallx+front*.025,base+1.25,z),(.05,1.8,.96),timber))
    # Slatted porch, a step, and rain gutter.
    all.append(box('Porch',(wallx+front*.45,base+.25,z),(1,.2,d*.65),timber))
    all.append(box('Porch_Step',(wallx+front*.85,base+.1,z),(1,.2,1.4),stone))
    all.append(beam('Rain_Gutter',(wallx+front*.45,roof_y-.06,z-d/2-.6),(wallx+front*.45,roof_y-.06,z+d/2+.6),.08,black))
    all.append(beam('Downspout',(wallx+front*.4,roof_y-.05,z+d/2+.2),(wallx+front*.4,base+.1,z+d/2+.2),.05,black))
for i,args in enumerate([(-8,5,7,9,3.4),(8,-1,7,8,4),(-9,-11,8,10,4.1),(9,-18,7,9,3.5),(-9,-28,7,8,3.2),(8,-36,7,9,4),(-9,-45,8,9,3.8)]):house(*args,i)
# Narrow open drains and their stepping slabs.
for x in [-3.5,3.5]:
    all.append(box('Drain',(x,.04,-17),(.4,.04,76),black))
    for z in [9,-3,-14,-28,-42]:all.append(box('Drain_Crossing',(x,town_h(x,z)+.1,z),(.9,.15,1.4),stone))
# Utility poles, crossbars, and gently drooping wires.
for x,z in [(3.6,12),(-3.7,-10),(3.8,-33),(-3.8,-53)]:
    y=town_h(x,z);all.append(beam('Utility_Pole',(x,y,z),(x,y+7,z),.13,timber,.09));all.append(box('Crossarm',(x,y+6.7,z),(1.8,.13,.18),timber))
    for dx in [-.7,.7]:all.append(ico('Ceramic_Insulator',(x+dx,y+6.9,z),(.095,.15,.095),white))
for (x,z),(xx,zz) in zip([(3.6,12),(-3.7,-10),(3.8,-33)],[(-3.7,-10),(3.8,-33),(-3.8,-53)]):
    for dx in [-.65,.65]:
        pts=[]
        for j in range(13):t=j/12;pts.append((x+(xx-x)*t+dx,6.9+town_h(x,z)*(1-t)+town_h(xx,zz)*t-math.sin(t*math.pi)*.8,z+(zz-z)*t))
        all+=curve('Overhead_Wire',pts,.014,black)
# A rice merchant's noren, delivery crates, and an old bicycle at the porch.
for k in range(3):
    ob=mesh('NorenFlag_'+str(k),[(0,0,0),(.54,0,0),(0,-.9,0),(.54,-.9,0)],[(0,1,3,2)],noren,[(0,0),(1,0),(0,1),(1,1)])
    ob.location=xyz((-4.25,2.65,4.4+k*.57));ob.rotation_euler.z=math.pi/2;all.append(ob)
for x,z in [(-3.9,7),(-4.2,7.5),(-3.9,8)]:
    y=town_h(x,z);all.append(box('Delivery_Crate',(x,y+.25,z),(.55,.5,.5),wood))
    for yy in [-.12,.12]:all.append(box('Crate_Slat',(x+.28,y+.25+yy,z),(.025,.025,.52),black))
# A paper lantern sheltered under the merchant's eaves, with rings and a hanging cord.
all.append(beam('Lantern_Cord',(-4.05,3.7,8.8),(-4.05,3.05,8.8),.012,black))
all.append(ico('Paper_Lantern',(-4.05,2.78,8.8),(.22,.37,.22),glow,2))
for yy in [2.46,2.56,2.68,2.8,2.92,3.04]:all.append(beam('Lantern_Rib',(-4.05,yy-.012,8.8),(-4.05,yy+.012,8.8),.20 if 2.55<yy<3 else .14,timber,steps=9))
# Mismatched pots, broad leaves, a rain barrel, and a broom left at a doorway.
for k,(x,z) in enumerate([(-3.8,10),(4.2,5),(-4,-5),(4.3,-13),(-4,-23),(4,-31)]):
    y=town_h(x,z)
    all.append(beam('Clay_Pot',(x,y,z),(x,y+.31,z),.17,rust,.23,8))
    for j in range(7):
        a=j*math.tau/7;r=random.uniform(.28,.46);yy=y+random.uniform(.45,.68)
        all.append(mesh('Broad_Pot_Leaf',[(x,y+.3,z),(x+math.cos(a)*r*.5-math.sin(a)*.12,yy,z+math.sin(a)*r*.5+math.cos(a)*.12),(x+math.cos(a)*r,yy-.15,z+math.sin(a)*r),(x+math.cos(a)*r*.5+math.sin(a)*.12,yy,z+math.sin(a)*r*.5-math.cos(a)*.12)],[(0,1,2),(0,2,3)],moss))
all.append(beam('Rain_Barrel',(-4,.12,-1),(-4,.9,-1),.31,blue,steps=10))
all.append(beam('Broom_Handle',(-3.9,.05,6.4),(-4.25,1.5,6.5),.025,wood))
all.append(beam('Broom_Brush',(-3.9,.07,6.4),(-3.98,.38,6.42),.17,rope,.06,6))
# Bicycle wheels and frame (side-on to the lane).
for z in [1.7,2.7]:
    pts=[(-4.0,.5+town_h(-4,z)+math.sin(j*math.tau/24)*.36,z+math.cos(j*math.tau/24)*.36) for j in range(25)]
    all+=curve('Bicycle_Tyre',pts,.035,black)
    for j in range(8):all.append(beam('Bicycle_Spoke',(-4,.5+town_h(-4,z),z),pts[j*3],.008,white))
y=town_h(-4,2)
all+=curve('Bicycle_Frame',[(-4,y+.5,1.7),(-4,y+.6,2.3),(-4,y+1.0,2.0),(-4,y+.5,1.7)],.027,red)
all+=curve('Bicycle_Frame',[(-4,y+.6,2.3),(-4,y+1.1,2.6),(-4,y+.5,2.7)],.027,red)
all.append(box('Bicycle_Seat',(-4,y+1.04,2),(.25,.055,.28),black))
# Merchant sign text, converted to geometry; no game logos or borrowed assets.
font=None
try:font=bpy.data.fonts.load('C:/Windows/Fonts/YuGothB.ttc')
except:pass
all.append(box('Merchant_Sign',(-4.38,3.15,5),(.1,.7,2),wood))
if font:
    curve_data=bpy.data.curves.new('Rice_Merchant_Text','FONT');curve_data.body='米 商店';curve_data.font=font;curve_data.size=.47;curve_data.extrude=.001
    text=bpy.data.objects.new('Painted_Sign',curve_data);bpy.context.collection.objects.link(text);text.location=xyz((-4.30,2.96,4.2));text.rotation_euler=(math.pi/2,0,math.pi/2);text.data.materials.append(white)
    bpy.ops.object.select_all(action='DESELECT');text.select_set(True);bpy.context.view_layer.objects.active=text;bpy.ops.object.convert(target='MESH');all.append(bpy.context.object)
# Laundry just visible in a side gap. Top edge remains anchored when swaying.
all+=curve('Clothesline',[(9,3.1,8),(15,3,8)],.012,black)
for k in range(2):
    ob=mesh('Laundry_'+str(k),[(0,0,0),(.8,0,0),(0,-1.3,0),(.8,-1.3,0)],[(0,1,3,2)],cloth);ob.location=xyz((10+k*2,3,8));all.append(ob)
# Red roadside flowers and potted plants hint at the town's lingering care.
for i in range(65):
    x=random.choice([-1,1])*random.uniform(3.7,4.4);z=random.uniform(-46,13);y=town_h(x,z)
    all.append(beam('Flower_Stem',(x,y,z),(x,y+.35,z),.009,moss,steps=3))
    for k in range(4):a=k*math.pi/2;all.append(ico('RedFlowers',(x+math.cos(a)*.065,y+.37,z+math.sin(a)*.065),(.09,.025,.025),flower))
for side,z in [(-1,12),(1,7),(-1,-8),(1,-22),(-1,-35),(1,-43)]:
    for j in range(15):
        x=side*random.uniform(3.8,4.4);zz=z+random.uniform(-.7,.7);y=town_h(x,zz);h=random.uniform(.28,.55)
        all.append(beam('Cluster_Stem',(x,y,zz),(x,y+h,zz),.009,moss,steps=3))
        for k in range(5):a=k*math.tau/5;all.append(ico('Spider_Lily',(x+math.cos(a)*.07,y+h,zz+math.sin(a)*.07),(.095,.028,.03),flower))
        all.append(mesh('Lily_Leaves',[(x-.04,y,zz),(x-.16,y+.3,zz),(x+.04,y,zz),(x+.13,y+.28,zz+.05)],[(0,1,2),(0,2,3)],moss))
# Small shrine beyond a side alley and mossy stone steps.
for k in range(7):all.append(box('Shrine_Step',(14,.07+k*.17,-48-k*.6),(3,.2,.65),stone))
for x in [12.6,15.4]:all.append(beam('Torii_Post',(x,1.1,-52.5),(x,4.4,-52.5),.16,red,.13))
all.append(box('Torii_Crossbeam',(14,4.25,-52.5),(4.2,.22,.3),red));all.append(box('Torii_Cap',(14,4.6,-52.5),(4.8,.25,.44),black))
for i in range(30):
    x=random.choice([-1,1])*random.uniform(24,42);z=random.uniform(-75,22);h=random.uniform(8,15);all.append(beam('Cedar_Trunk',(x,0,z),(x,h,z),.22,timber,.07))
    for k in range(3):
        bpy.ops.mesh.primitive_cone_add(vertices=7,radius1=3-k*.4,radius2=0,depth=5,location=xyz((x,h-2-k*2,z)));ob=bpy.context.object;ob.name='Cedar_Canopy';ob.data.materials.append(moss);all.append(ob)
for x,z in [(-40,-95),(40,-100),(0,-130)]:all.append(ico('Mountain',(x,8,z),(45,30,25),moss,2))
save_export('kasumi_town',all)
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
print('PLACES COMPLETE: phuket_coast.blend, kasumi_town.blend, original meshes/textures/audio')
