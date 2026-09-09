"""Original midday Andaman coast. Editable Blender objects, 256px material studies.
Godot-facing dimensions in metres. Run Blender --background --python this file.
"""
import bpy, math, random, numpy as np
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]; random.seed(10291)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def xyz(v):return (v[0],-v[2],v[1])
def mat(name,color,kind):
    n=256;y,x=np.mgrid[:n,:n];rng=np.random.default_rng(sum(map(ord,name)));noise=rng.random((n,n))-.5
    field=noise*.025+np.sin(x*.024)*np.cos(y*.032)*.018
    if kind=='wood':field+=np.sin(x*.27+np.sin(y*.036)*1.3)*.032+np.sin(x*.097)*.018
    if kind=='stone':
        field+=np.sin(x*.12+np.sin(y*.043)*1.5)*.05+np.sin(y*.085)*.025
        field-=np.exp(-((np.sin(x*.037+y*.014+np.sin(y*.04)*.15))/.045)**2)*.17
    if kind=='tile':field+=np.cos(x*math.tau/32)*.065;field-=((y%64)<3)*.12
    if kind=='leaf':field+=np.sin(x*.31+y*.14)*.028;field-=np.exp(-((x-128)/3)**2)*.05
    pixels=np.ones((n,n,4),dtype=np.float32);pixels[:,:,:3]=np.clip(np.array(color)+field[:,:,None],.015,.98)
    pixels[:,:,:3]=np.round(pixels[:,:,:3]*31)/31
    image=bpy.data.images.new(name,n,n);image.pixels.foreach_set(pixels.ravel());image.filepath_raw=str(R/'assets/textures'/f'{name}.png');image.file_format='PNG';image.save();image.pack()
    material=bpy.data.materials.new(name);material.use_nodes=True
    bs=material.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.85
    tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Closest';material.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    return material
sand=mat('PhuketSand',(.72,.67,.51),'sand');wood=mat('PhuketTeak',(.40,.25,.115),'wood')
stone=mat('PhuketLimestone',(.58,.57,.45),'stone');leaf=mat('PhuketLeaf',(.20,.36,.09),'leaf')
tile=mat('PhuketRoof',(.52,.23,.12),'tile');blue=mat('PhuketTurquoisePaint',(.055,.37,.42),'wood')
canvas=mat('PhuketCanvas',(.84,.77,.54),'cloth');dark=mat('PhuketIron',(.09,.12,.12),'stone')
all_objects=[]
def mesh(name,verts,faces,material,colors=None):
    me=bpy.data.meshes.new(name);me.from_pydata([xyz(v) for v in verts],[],faces);me.materials.append(material);me.update()
    ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);all_objects.append(ob)
    uv=me.uv_layers.new();col=me.color_attributes.new(name='Shelter',type='FLOAT_COLOR',domain='CORNER')
    for poly in me.polygons:
        axis=max(range(3),key=lambda a:abs(poly.normal[a]));axes=[i for i in range(3) if i!=axis]
        for li in poly.loop_indices:
            index=me.loops[li].vertex_index;v=me.vertices[index].co
            uv.data[li].uv=(v[axes[0]]*.23,v[axes[1]]*.23)
            col.data[li].color=(*((colors[index] if colors else (1,1,1))),1)
    return ob
def box(name,p,s,m):
    x,y,z=p;a,b,c=[q/2 for q in s]
    return mesh(name,[(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),(x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],m)
def beam(name,a,b,r,m,r2=None,steps=7):
    a,b=Vector(xyz(a)),Vector(xyz(b));d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=steps,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(a+b)/2)
    ob=bpy.context.object;ob.name=name;ob.rotation_euler=d.to_track_quat('Z','Y').to_euler();ob.data.materials.append(m);all_objects.append(ob);return ob
def lump(name,p,s,m):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=xyz(p));o=bpy.context.object;o.name=name;o.scale=(s[0],s[2],s[1]);o.data.materials.append(m);all_objects.append(o);return o
def height(x,z):return .12+.052*z+.12*math.sin(x*.06)*max(z,0)/25
# Sand continues beneath the lagoon, allowing fish silhouettes and depth colour.
verts=[];faces=[];colors=[]
for j in range(101):
    z=-70+j*1.3
    for i in range(141):
        x=-105+i*1.5;verts.append((x,height(x,z),z));shade=.92+.06*math.sin(x*.071+z*.16)*math.sin(z*.039);colors.append((shade,shade,shade))
for j in range(100):
    for i in range(140):
        a=j*141+i;faces.extend([(a,a+141,a+1),(a+1,a+141,a+142)])
mesh('Continuous coral-sand shore',verts,faces,sand,colors)
# Tall karsts: undercut base, steep fluted walls, fractured shoulders and irregular crowns.
def karst(k,x,z,w,h):
    verts=[];faces=[];colors=[];count=47
    radii=[1.+.12*math.sin(j*.67)+.09*math.sin(j*1.61)+random.uniform(-.035,.035) for j in range(count)]
    profile=[.90,.94,.98,1.0,.97,.91,.84,.73,.44,.035]
    for level in range(19):
        t=level/18
        for j in range(count):
            a=j*math.tau/count
            warped=max(0,min(1,t+.045*math.sin(a*3+k)*math.sin(t*math.pi)))
            q=warped*9;lo=min(8,int(q));blend=q-lo;pr=profile[lo]*(1-blend)+profile[lo+1]*blend
            radius=w*radii[j]*pr*(1+.025*math.sin(level*.6+j*1.1))
            verts.append((x+math.cos(a)*radius+t*t*w*.23,h*t*(.93+.07*math.sin(a*3+k)+.045*math.cos(a*5-k))+math.sin(j*.8)*h*.008-5,z+math.sin(a)*radius*.72))
            shade=(.57 if level<3 else .88)+.06*math.sin(j*.52);colors.append((shade,shade*.99,shade*.92))
    for level in range(18):
        for j in range(count):
            a=level*count+j;b=level*count+(j+1)%count;faces.extend([(a,a+count,b),(b,a+count,b+count)])
    obj=mesh(f'Karst {k} fluted limestone',verts,faces,stone,colors)
    obj.data.materials.append(leaf)
    for poly in obj.data.polygons:
        poly.use_smooth=True
        if min(obj.data.vertices[v].co.z for v in poly.vertices)>h*.74:poly.material_index=1
    for j in range(85):
        px,py,pz=random.choice(verts[14*count:18*count])
        lump(f'Karst {k} clifftop forest',(px,py-.6,pz),(w*.055,h*.018,w*.045),leaf)
    for j in range(8):
        px,py,pz=random.choice(verts[5*count:13*count])
        lump('Vegetated limestone ledge',(px,py-.3,pz),(w*.055,h*.012,w*.04),leaf)
for k,args in enumerate([(-115,-290,43,112),(-212,-420,60,159),(190,-540,80,190),(345,-730,99,269),(-365,-780,108,296),(20,-1100,126,330),(490,-1040,125,335),(-535,-1200,136,353)]):karst(k,*args)
# A natural sea cave opening framed by two separate buttresses and an eroded bridge.
verts=[];faces=[]
for i in range(19):
    a=i*math.pi/18
    for depth in [-12,12]:
        verts.extend([(-73+math.cos(a)*(30+3*math.sin(a*5)),math.sin(a)*(53+4*math.sin(a*7))-3,-250+depth+3*math.sin(a*3)),(-73+math.cos(a)*(15+2*math.sin(a*4)),math.sin(a)*(33+3*math.sin(a*5))-3,-250+depth+2*math.cos(a*4))])
for i in range(18):
    k=i*4
    for f in [(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]:faces.append(tuple(k+n for n in f))
mesh('Tidal limestone arch',verts,faces,stone)
# Foreground coconut palms: curved ringed stems with individually folded leaflets.
for k,(x,z,h) in enumerate([(-8,6,10.5),(-18,12,13),(18,9,12.5),(-29,24,16),(29,23,15),(42,12,14),(-42,5,12),(56,34,18),(-58,33,16)]):
    root=height(x,z);pts=[]
    for j in range(13):
        t=j/12;pts.append((x+math.sin(t*1.5)*h*.20*(-1 if x>0 else 1),root+h*t,z-t*t*1.3))
    for j in range(12):beam('Ringed coconut trunk',pts[j],pts[j+1],.27-j*.011,wood,.259-j*.011)
    for j in range(30):
        t=j/30;p=Vector(pts[min(11,int(t*12))]).lerp(Vector(pts[min(12,int(t*12)+1)]),t*12-int(t*12));beam('Palm growth scar',p-Vector((0,.026,0)),p+Vector((0,.026,0)),.28-t*.14,wood)
    vs=[];fs=[]
    for f in range(14):
        a=f*math.tau/14+random.uniform(-.15,.15);length=random.uniform(3.5,5.4);forward=Vector((math.cos(a),0,math.sin(a)))
        for j in range(1,19):
            t=j/20;mid=forward*length*t+Vector((0,math.sin(t*math.pi)*1.2-t*t*1.05,0))
            for side in [-1,1]:
                across=Vector((-math.sin(a)*side,0,math.cos(a)*side));span=math.sin(t*math.pi)*.75;b=len(vs)
                vs.extend([tuple(mid-forward*.055),tuple(mid+across*span*.45+forward*.12+Vector((0,.04,0))),tuple(mid+across*span+forward*.33+Vector((0,-.20,0))),tuple(mid+forward*.105)])
                fs.extend([(b,b+1,b+3),(b+1,b+2,b+3)])
    crown=mesh('PalmCrown_'+str(k),vs,fs,leaf);crown.location=xyz(pts[-1])
    for j in range(5):lump('Coconut',(pts[-1][0]+random.uniform(-.3,.3),pts[-1][1]-.22,pts[-1][2]+random.uniform(-.3,.3)),(.17,.23,.17),wood)
# Working timber pier: individually varied planks, braced piles and tied fenders.
for j in range(110):
    z=7-j*.42
    box('Pier deck plank',(10,1.0+random.uniform(-.008,.008),z),(3.5,.16,.39),wood)
for x in [8.55,11.45]:
    box('Pier bearer',(x,.69,-15.9),(.21,.32,47),wood)
    for z in range(-37,9,4):
        beam('Round pier piling',(x,-3.5,z),(x,1.86,z),.135,wood)
        if z<7: beam('Diagonal cross brace',(x,-.7,z),(x,1.,z+3.6),.065,wood)
        if not (x>10 and z==-37):
            beam('Rope railing',(x,1.69,z),(x,1.55,z+2),.027,canvas)
            beam('Rope railing',(x,1.55,z+2),(x,1.69,z+4),.027,canvas)
    beam('Shore rope terminal post',(x,height(x,11)-.18,11),(x,1.86,11),.135,wood)
# Sloped shore approach is continuous with the walking height.
mesh('Boardwalk shore ramp',[(8.25,height(10,11),11),(11.75,height(10,11),11),(11.75,1.08,7),(8.25,1.08,7)],[(0,1,2,3)],wood)
def pavilion(x,z,w,d,closed=False):
    y=1.08
    box('Raised pavilion deck',(x,y-.1,z),(w,.2,d),wood)
    for dx in [-w/2+.25,w/2-.25]:
        for dz in [-d/2+.25,d/2-.25]:
            beam('Timber stilt',(x+dx,-3,z+dz),(x+dx,4.6,z+dz),.13,wood)
            beam('Angled eave bracket',(x+dx,3.65,z+dz),(x+dx*.65,4.53,z+dz),.07,wood)
    # Continuous plates and tie beams give the knee braces an actual joint.
    for dx in [-w/2+.25,w/2-.25]:
        beam('Longitudinal wall plate',(x+dx,4.53,z-d/2+.25),(x+dx,4.53,z+d/2-.25),.13,wood)
    for dz in [-d/2+.25,d/2-.25]:
        beam('Roof tie beam',(x-w/2+.25,4.53,z+dz),(x+w/2-.25,4.53,z+dz),.13,wood)
        beam('King post',(x,4.53,z+dz),(x,5.62,z+dz),.085,wood)
        for side in [-1,1]:
            beam('Connected principal rafter',(x,5.62,z+dz),(x+side*(w/2+.8),4.53,z+dz),.095,wood)
    # Broad overhang and rising gable, with layered tile courses and ridge caps.
    for side in [-1,1]:
        for row in range(8):
            t=row/8;u=(row+1)/8
            def edge(q):return (x+side*(w/2+.8)*q,5.75-1.2*q+.12*q*q)
            a,b=edge(t),edge(u)
            mesh('Terracotta tile course',[(a[0],a[1],z-d/2-.65),(a[0],a[1],z+d/2+.65),(b[0],b[1],z+d/2+.65),(b[0],b[1],z-d/2-.65)],[(0,1,2,3)],tile)
        beam('Deep eave fascia',(x+side*(w/2+.8),4.65,z-d/2-.65),(x+side*(w/2+.8),4.65,z+d/2+.65),.095,wood)
    beam('Tiled roof ridge',(x,5.78,z-d/2-.8),(x,5.78,z+d/2+.8),.13,tile)
    for end in [-1,1]:
        for dx in [-w/2,w/2]:beam('Gable rake',(x+dx,4.5,z+end*d/2),(x,5.7,z+end*d/2),.085,wood)
    if closed:
        for end in [-1,1]:
            for j in range(int(w/.25)):
                box('Weathered gable wall board',(x-w/2+.125+j*.25,2.77,z+end*d/2),(.24,3.38,.10),blue)
        for side in [-1,1]:
            for j in range(int(d/.25)):
                dz=-d/2+.125+j*.25
                if side<0 and abs(dz)<1.: continue
                box('Weathered side wall board',(x+side*w/2,2.77,z+dz),(.10,3.38,.24),blue)
        box('Door lintel',(x-w/2,4.15,z),(.16,.55,2.1),wood)
        for dz in [-1.04,1.04]:box('Door jamb',(x-w/2,2.65,z+dz),(.16,3.14,.14),wood)
        box('Shuttered window',(x,2.9,z+d/2+.08),(w*.45,1.1,.13),wood)
    else:
        for side in [-1,1]:
            bx=x+side*(w/2-.5)
            box('Shaded waiting bench',(bx,1.58,z),(.63,.14,d-1.),wood)
            for dz in [-d/2+.8,0,d/2-.8]:
                for dx in [-.22,.22]:box('Bench leg',(bx+dx,1.30,z+dz),(.10,.48,.12),wood)
                box('Bench seat bearer',(bx,1.47,z+dz),(.57,.12,.16),wood)
            box('Bench under-seat stretcher',(bx,1.30,z),(.10,.12,d-1.5),wood)
    for j in range(5):
        px=x-w/2+.4+j*.22
        box('Stacked fish crate',(px,1.34,z+d/2-.6),(.2,.4,.55),blue)
pavilion(10,-18,6,6)
pavilion(21,-35,7,6,True)
for j in range(23):box('Connecting walkway plank',(11.75+(j+.5)*.25,1.,-35),(.24,.16,4.),wood)
for dz in [-36.65,-33.35]:
    box('Connecting walkway bearer',(14.625,.75,dz),(5.75,.30,.18),wood)
    for x in [12,14.5,17.25]:
        beam('Walkway rail post',(x,-3.5,dz),(x,1.9,dz),.09,wood)
    beam('Walkway handrail',(12,1.85,dz),(17.3,1.85,dz),.055,wood)
for x in [15,20,24]:
    for z in [-33.5,-36.5]:beam('Landing foundation',(x,-4,z),(x,1,z),.16,wood)
# Beach-side stall: a woven canopy, pottery, a hanging cloth and fishing baskets.
pavilion(-16,17,5,4,True)
for i in range(4):
    x=-13+i*.55;lump('Fishing basket',(x,height(x,14)+.35,14),(.26,.34,.26),canvas)
for k in range(65):
    x=random.uniform(-55,55);z=random.uniform(1,34)
    lump('Coral fragment',(x,height(x,z)+.025,z),(random.uniform(.025,.08),.025,random.uniform(.04,.12)),canvas)
# New long-tail with raised prow, planked hull, seats, engine and fabric sunshade.
start=len(all_objects);vs=[];fs=[]
stations=[(-4.2,.05,1.25),(-3.1,.62,.45),(-1.4,.91,.12),(1.2,.87,.10),(3,.53,.40)]
for z,w,r in stations:vs.extend([(-w,.22+r,z),(-w*.62,-.38+r,z),(w*.62,-.38+r,z),(w,.22+r,z)])
for j in range(4):
    for f in range(3):a=j*4+f;fs.append((a,a+1,a+5,a+4))
fs.extend([(3,2,1,0),(16,17,18,19)])
mesh('Longtail planked hull',vs,fs,wood)
# Raised inner floor follows the keel; it stays inside the watertight shell.
for j in range(4):
    z,w,r=stations[j];zz,ww,rr=stations[j+1]
    mesh('Interior floorboards',[(-w*.59,-.32+r,z),(w*.59,-.32+r,z),(ww*.59,-.32+rr,zz),(-ww*.59,-.32+rr,zz)],[(0,1,2,3)],wood)
for side in [-1,1]:
    for j in range(4):
        z,w,r=stations[j];zz,ww,rr=stations[j+1]
        beam('Painted gunwale',(side*w,.25+r,z),(side*ww,.25+rr,zz),.072,blue)
for z in [-2.4,-1.,.5,1.8]:box('Boat seat',(0,.30,z),(1.4,.1,.28),wood)
box('Diesel engine',(0,.65,2.5),(.58,.64,.65),dark)
beam('Long drive shaft',(0,.8,2.65),(0,-.2,6),.035,dark)
for x in [-.74,.74]:
    for z in [-.8,1.4]:beam('Canopy support',(x,.25,z),(x,2.,z),.035,blue)
mesh('Canvas canopy',[(-.9,1.95,-1),(0,2.23,-1),(.9,1.95,-1),(-.9,1.95,1.7),(0,2.23,1.7),(.9,1.95,1.7)],[(0,1,4,3),(1,2,5,4)],canvas)
beam('Longtail prow',(0,1.4,-4.2),(0,2.1,-4.45),.075,wood)
box('Prow offering ribbon',(0,1.63,-4.44),(.22,.55,.05),tile)
boat_parts=all_objects[start:]
def join(obs,name):
    # glTF fills absent colour layers with zero when meshes are joined. Supply
    # white on every primitive so authored shelter colours cannot blacken timber.
    for ob in obs:
        if not ob.data.color_attributes.get('Shelter'):
            col=ob.data.color_attributes.new(name='Shelter',type='FLOAT_COLOR',domain='CORNER')
            for v in col.data:v.color=(1,1,1,1)
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;return o
boat=join(boat_parts,'BoatFloat');bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');boat.location=xyz((5.7,.07,-12));boat.rotation_euler.z=.12
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/phuket_midday.blend'))
static=[o for o in bpy.context.scene.objects if o.type=='MESH' and o!=boat and not o.name.startswith('PalmCrown')]
join(static,'PhuketMidday_Landscape')
bpy.ops.export_scene.gltf(filepath=str(R/'assets/models/phuket_midday.glb'),export_format='GLB',export_apply=True,export_vertex_color='NAME',export_vertex_color_name='Shelter',export_all_vertex_colors=False)
print('PHUKET_MIDDAY_ASSETS_READY')


