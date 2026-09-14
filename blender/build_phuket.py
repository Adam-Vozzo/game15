"""Original midday Andaman coast. Editable Blender objects, 256px material studies.
Godot-facing dimensions in metres. Run Blender --background --python this file.
"""
import bpy, bmesh, math, random, json, numpy as np
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
driftwood=mat('PhuketDriftwood',(.46,.40,.30),'wood')
all_objects=[]
detail_layout={'trunks':[],'obstacles':[]}
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
    # Direct mesh construction avoids thousands of scene-wide operator updates.
    a,b=Vector(a),Vector(b);axis=(b-a).normalized()
    u=axis.cross(Vector((0,1,0)) if abs(axis.y)<.9 else Vector((1,0,0))).normalized();v=axis.cross(u)
    verts=[]
    for p,radius in [(a,r),(b,r if r2 is None else r2)]:
        for j in range(steps):
            angle=j*math.tau/steps;verts.append(tuple(p+(u*math.cos(angle)+v*math.sin(angle))*radius))
    faces=[tuple(reversed(range(steps))),tuple(range(steps,steps*2))]
    for j in range(steps):faces.append((j,(j+1)%steps,(j+1)%steps+steps,j+steps))
    return mesh(name,verts,faces,m)
_sphere=bmesh.new();bmesh.ops.create_icosphere(_sphere,subdivisions=2,radius=1)
_sphere.verts.ensure_lookup_table();_sphere.verts.index_update()
_sphere_v=[tuple(v.co) for v in _sphere.verts];_sphere_f=[tuple(v.index for v in f.verts) for f in _sphere.faces];_sphere.free()
def lump(name,p,s,m):
    return mesh(name,[(p[0]+v[0]*s[0],p[1]+v[1]*s[1],p[2]+v[2]*s[2]) for v in _sphere_v],_sphere_f,m)
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
    profile=[.76,.93,.98,1.0,.95,.92,.79,.66,.39,.035]
    for level in range(19):
        t=level/18
        for j in range(count):
            a=j*math.tau/count
            warped=max(0,min(1,t+.083*math.sin(a*3+k)*math.sin(t*math.pi)+.035*math.cos(a*7-k)*t))
            q=warped*9;lo=min(8,int(q));blend=q-lo;pr=profile[lo]*(1-blend)+profile[lo+1]*blend
            radius=w*radii[j]*pr*(1+.025*math.sin(level*.6+j*1.1))
            verts.append((x+math.cos(a)*radius+t*t*w*.23,h*t*(.89+.12*math.sin(a*3+k)+.085*math.cos(a*5-k))+math.sin(j*.8)*h*.008-5,z+math.sin(a)*radius*.72))
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
    # Attached blade-like buttresses and unequal pinnacles break the rounded
    # cylinder outline. Their bases extend below water into the parent island.
    for j in range(7):
        a=j*math.tau/7+k*.41;out=Vector((math.cos(a),0,math.sin(a)*.72));across=Vector((-math.sin(a),0,math.cos(a)))
        vs=[];fs=[];peak=h*(.41+.31*((j*3+k)%7)/6)
        for level,(spread,reach,yy) in enumerate([(1.,.80,-6),(.85,1.04,peak*.19),(.50,1.02,peak*.62),(.09,.85,peak)]):
            center=Vector((x,yy,z))+out*w*reach
            for q in range(6):
                angle=q*math.tau/6
                p=center+across*math.cos(angle)*w*.14*spread+out*math.sin(angle)*w*.24*spread
                vs.append(tuple(p))
        for level in range(3):
            for q in range(6):
                b=level*6+q;n=level*6+(q+1)%6;fs.append((b,n,n+6,b+6))
        fs.append(tuple(range(18,24)))
        mesh('Attached limestone blade',vs,fs,stone)
        crown=Vector((x,peak*.97,z))+out*w*.85
        lump('Wind shaped pinnacle thicket',crown,(w*.065,h*.018,w*.065),leaf)
    for j in range(9):
        a=j*math.tau/9+k
        lump('Undercut tidal talus',(x+math.cos(a)*w*.90,-1.5,z+math.sin(a)*w*.70),(w*.16,3.+h*.045,w*.12),stone)
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
    detail_layout['trunks'].append([x,z,.52])
    for j in range(7):
        a=j*math.tau/7+k*.37
        beam('Palm flared root',(x,root+.45,z),(x+math.cos(a)*.62,height(x+math.cos(a)*.62,z+math.sin(a)*.62)-.06,z+math.sin(a)*.62),.12,wood,.035)
    for j in range(13):
        t=j/12;pts.append((x+math.sin(t*1.5)*h*.20*(-1 if x>0 else 1),root+h*t,z-t*t*1.3))
    for j in range(12):beam('Ringed coconut trunk',pts[j],pts[j+1],.27-j*.011,wood,.259-j*.011)
    for j in range(30):
        t=j/30;p=Vector(pts[min(11,int(t*12))]).lerp(Vector(pts[min(12,int(t*12)+1)]),t*12-int(t*12));beam('Palm growth scar',p-Vector((0,.026,0)),p+Vector((0,.026,0)),.28-t*.14,wood)
    vs=[];fs=[]
    for f in range(14):
        a=f*math.tau/14+random.uniform(-.15,.15);length=random.uniform(3.5,5.4);forward=Vector((math.cos(a),0,math.sin(a)))
        previous=Vector((0,0,0));across=Vector((-math.sin(a),0,math.cos(a)))
        droop=.65+(f%4)*.38
        for q in range(1,21):
            t=q/20;mid=forward*length*t+Vector((0,math.sin(t*math.pi)*(1.+(f%3)*.22)-t*t*droop,0))
            b=len(vs);vs.extend([tuple(previous-across*.018),tuple(previous+across*.018),tuple(mid+across*.012),tuple(mid-across*.012)])
            fs.append((b,b+1,b+2,b+3));previous=mid
        for j in range(1,19):
            t=j/20;mid=forward*length*t+Vector((0,math.sin(t*math.pi)*(1.+(f%3)*.22)-t*t*droop,0))
            for side in [-1,1]:
                across=Vector((-math.sin(a)*side,0,math.cos(a)*side));span=math.sin(t*math.pi)*(.58+random.random()*.30);b=len(vs)
                vs.extend([tuple(mid-forward*.055),tuple(mid+across*span*.45+forward*.12+Vector((0,.04,0))),tuple(mid+across*span+forward*.33+Vector((0,-.20,0))),tuple(mid+forward*.105)])
                fs.extend([(b,b+1,b+3),(b+1,b+2,b+3)])
    crown=mesh('PalmCrown_'+str(k),vs,fs,leaf);crown.location=xyz(pts[-1])
    for j in range(5):lump('Coconut',(pts[-1][0]+random.uniform(-.3,.3),pts[-1][1]-.22,pts[-1][2]+random.uniform(-.3,.3)),(.17,.23,.17),wood)
    for j in range(4):
        a=k+j*1.6;end=Vector(pts[-1])+Vector((math.cos(a)*.9,-1.4-j*.18,math.sin(a)*.9))
        beam('Old hanging frond sheath',pts[-1],end,.085,wood,.018)
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
    for z in [-5,-13,-25,-33]:
        side=-1 if x<10 else 1
        # Hanging timber fenders tied to pile heads; visible from the underside.
        beam('Fender suspension',(x,1.68,z),(x+side*.28,.24,z),.022,canvas)
        beam('Weathered hanging fender',(x+side*.28,-.38,z),(x+side*.28,.55,z),.13,wood)
        for yy in [-.12,.31]:
            for j in range(12):
                a=j*math.tau/12;b=(j+1)*math.tau/12
                beam('Fender binding',(x+side*.28+math.cos(a)*.135,yy,z+math.sin(a)*.135),(x+side*.28+math.cos(b)*.135,yy,z+math.sin(b)*.135),.013,canvas)
        box('Pile cap',(x,1.9,z),(.32,.07,.32),wood)
        for yy in [.78,.96]:beam('Bearer through bolt',(x-.16,yy,z),(x+.16,yy,z),.026,dark)
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
        for side in [-1,1]:
            sx=x+side*w*.245
            box('Window shutter stile',(sx,2.9,z+d/2+.18),(.10,1.20,.10),wood)
            beam('Shutter diagonal brace',(sx,2.42,z+d/2+.20),(x+side*.10,3.35,z+d/2+.20),.038,wood)
        for yy in [2.35,3.45]:box('Window head and sill',(x,yy,z+d/2+.18),(w*.53,.09,.25),wood)
        for yy in [2.56,2.78,3.,3.22]:box('Louvered shutter',(x,yy,z+d/2+.20),(w*.43,.085,.065),wood)
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
# Beach wrack occurs in interrupted tidal clusters, with bleached branching wood
# and low half-buried rocks. Keep the open approach to the pier clear.
for x,z,length in [(-5,10,3.6),(24,5,2.7),(-27,3,4.1)]:
    y=height(x,z)
    path=[]
    for j in range(6):
        xx=x-length/2+length*j/5;zz=z+.18*math.sin(j*1.1)+j*.045
        path.append(Vector((xx,height(xx,zz)+.08+.035*math.sin(j*2),zz)))
    for j in range(5):
        beam('Crooked weathered driftwood',path[j],path[j+1],.23-j*.026,driftwood,.204-j*.026,9)
    for j in [1,3,4]:
        root=path[j];side=-1 if j%2 else 1
        bend=root+Vector((.18,.10,side*.37));tip=bend+Vector((.36,-.08,side*.28))
        beam('Broken driftwood fork',root,bend,.082,driftwood,.048)
        beam('Broken driftwood twig',bend,tip,.048,driftwood,.012)
    for j in range(5):
        angle=j*math.tau/5
        start=path[0]+Vector((.02,math.cos(angle)*.14,math.sin(angle)*.16))
        beam('Splintered root end',start,start+Vector((-.18-(j%3)*.08,.025,math.sin(angle)*.07)),.043,driftwood,.008)
    detail_layout['obstacles'].append([x-length/2-.15,z-.20,length+.45,1.30])
for j in range(12):
    x=-25+j*5.1+random.uniform(-1,1);z=1.7+random.random()*2
    if 6<x<14:continue
    for q in range(12):
        xx=x+random.uniform(-1.2,1.2);zz=z+random.uniform(-.35,.35)
        beam('Tidal wrack twig',(xx,height(xx,zz)+.017,zz),(xx+.16+random.random()*.23,height(xx,zz)+.02,zz+.12),.009,wood)
        if q%3==0:lump('Clustered spiral shell',(xx,height(xx,zz)+.045,zz),(.07,.045,.045),canvas)
for x,z in [(-33,8),(33,3),(-22,5)]:
    lump('Buried coastal limestone',(x,height(x,z)-.18,z),(1.3,.65,.85),stone)
    detail_layout['obstacles'].append([x-1.2,z-.75,2.4,1.5])
# Coiled line and slatted traps are placed beside, rather than across, the deck.
for x,z in [(7.55,-18.9),(12.35,-16.8)]:
    for level in range(3):
        for j in range(28):
            a=j*math.tau/28;b=(j+1)*math.tau/28
            beam('Coiled fishing line',(x+math.cos(a)*(.27+level*.035),1.12+level*.028,z+math.sin(a)*(.27+level*.035)),(x+math.cos(b)*(.27+level*.035),1.12+level*.028,z+math.sin(b)*(.27+level*.035)),.018,canvas)
for z in [-20,-16]:
    for yy in [1.16,1.48,1.8]:
        for xx in [7.18,7.67]:beam('Fish trap frame',(xx,yy,z-.38),(xx,yy,z+.38),.025,wood)
    for j in range(7):
        zz=z-.36+j*.12
        for xx in [7.18,7.67]:beam('Fish trap slat',(xx,1.12,zz),(xx,1.84,zz),.012,canvas)
        beam('Fish trap lid',(7.18,1.82,zz),(7.67,1.82,zz),.012,canvas)
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
(R/'assets/data/phuket_detail_layout.json').write_text(json.dumps(detail_layout,indent=2))
static=[o for o in bpy.context.scene.objects if o.type=='MESH' and o!=boat and not o.name.startswith('PalmCrown')]
join(static,'PhuketMidday_Landscape')
export_path=R/'build-logs/phuket_midday.glb'
bpy.ops.export_scene.gltf(filepath=str(export_path),export_format='GLB',export_apply=True,export_vertex_color='NAME',export_vertex_color_name='Shelter',export_all_vertex_colors=False)
export_path.replace(R/'assets/models/phuket_midday.glb')
print('PHUKET_MIDDAY_ASSETS_READY')


