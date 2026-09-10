"""Original Night Laundry and Reservoir art. Blender is the geometry source.

Coordinates passed to helpers are Godot X/Y/Z; conversion happens once in mesh
creation. Editable named components are saved before static material batching.
Run with Blender --background --python blender/build_interiors.py.
"""
import bpy, math, random, json, wave, struct
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
random.seed(8215)
MATS = {}

def texture(name, kind):
    n = 256
    pixels = []
    rng = random.Random(43)
    # Multiscale, irregular vertical staining rather than a repeating stripe grid.
    streaks = [(rng.random(), rng.uniform(.006,.025), rng.uniform(.025,.08), rng.random()) for _ in range(7)]
    for y in range(n):
        for x in range(n):
            u,v=x/n,y/n
            noise = rng.uniform(-.025,.025)
            if kind == 'concrete':
                value = .66+noise*.55+.035*math.sin(u*16+math.sin(v*17))+.025*math.cos(u*41-v*13)
                for at,width,strength,phase in streaks:
                    d=min(abs(u-at),1-abs(u-at))
                    value-=strength*math.exp(-(d/width)**2)*(.55+.45*math.sin(v*3+phase*4))
                # Small formwork tie holes, separated by broad mottled concrete.
                if any((x-tx)**2+(y-ty)**2<5 for tx,ty in [(39,56),(203,56),(39,205),(203,205)]): value-=.15
                col=(value*.94,value*.98,value)
            elif kind == 'tile':
                mortar = x%32<2 or y%32<2
                value = (.16 if mortar else (.65 if (x//32+y//32)%2 else .35))+noise
                col=(value*.85,value,value*.95)
            elif kind == 'enamel':
                value=.77+noise*.4
                if x<3 or y<3: value*=.75
                col=(value*.96,value,value*.93)
            elif kind == 'road':
                value=.20+noise+.02*math.sin(u*23)*math.cos(v*17)
                col=(value*.8,value*.94,value)
            elif kind == 'metal':
                value=.43+noise+.018*math.sin(u*210)
                col=(value*.9,value*.98,value)
            else:
                value=.60+noise
                col=(value,value,value)
            pixels.extend([round(max(0,min(1,c))*31)/31 for c in col]+[1])
    im=bpy.data.images.new(name,width=n,height=n)
    im.pixels=pixels
    im.filepath_raw=str(ROOT/'assets/textures'/f'{name}.png')
    im.file_format='PNG';im.save()
    return im

def material(name, image=None):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=.8
    if image:
        tx=m.node_tree.nodes.new('ShaderNodeTexImage');tx.image=image
        m.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
    MATS[name]=m

class Mesh:
    def __init__(self,name,kind):
        self.name=name;self.kind=kind;self.v=[];self.f=[];self.uv=[];self.col=[]
    def face(self,pts,uv=None,col=(1,1,1),shade=1):
        start=len(self.v);self.v.extend(pts);self.f.append(tuple(range(start,start+len(pts))))
        self.uv.extend(uv or [(0,0),(1,0),(1,1),(0,1)][:len(pts)])
        self.col.extend([tuple(c*shade for c in col)+(1,)]*len(pts))
    def finish(self):
        if not self.v:return None
        mesh=bpy.data.meshes.new(self.name)
        mesh.from_pydata([(x,-z,y) for x,y,z in self.v],[],self.f);mesh.update()
        ob=bpy.data.objects.new(self.name,mesh);bpy.context.collection.objects.link(ob)
        mesh.materials.append(MATS[self.kind])
        uv=mesh.uv_layers.new(name='SurfaceUV')
        for face in mesh.polygons:
            for li in face.loop_indices:uv.data[li].uv=self.uv[mesh.loops[li].vertex_index]
        colors=mesh.color_attributes.new(name='Shelter',type='FLOAT_COLOR',domain='POINT')
        for i,col in enumerate(self.col):colors.data[i].color=col
        return ob

def box(m,c,s,col=(1,1,1),uv_scale=1):
    x,y,z=c;a,b,d=[v/2 for v in s]
    verts=[(x-a,y-b,z-d),(x+a,y-b,z-d),(x+a,y+b,z-d),(x-a,y+b,z-d),
           (x-a,y-b,z+d),(x+a,y-b,z+d),(x+a,y+b,z+d),(x-a,y+b,z+d)]
    for idx,shade,du,dv in [((4,5,6,7),.85,s[0],s[1]),((1,0,3,2),.73,s[0],s[1]),
                           ((5,1,2,6),.9,s[2],s[1]),((0,4,7,3),.66,s[2],s[1]),
                           ((3,7,6,2),1,s[0],s[2]),((0,1,5,4),.5,s[0],s[2])]:
        m.face([verts[i] for i in idx],[(0,0),(du*uv_scale,0),(du*uv_scale,dv*uv_scale),(0,dv*uv_scale)],col,shade)

def tube(m,a,b,r,col=(1,1,1),sides=12,r2=None):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized()
    u=axis.cross(Vector((0,1,0)) if abs(axis.y)<.9 else Vector((1,0,0))).normalized()
    v=axis.cross(u);r2=r if r2 is None else r2
    ring_a=[a+r*(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides)) for i in range(sides)]
    ring_b=[b+r2*(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides)) for i in range(sides)]
    for i in range(sides):
        j=(i+1)%sides
        m.face([ring_a[i],ring_a[j],ring_b[j],ring_b[i]],col=col,shade=.78+.2*math.sin(i*math.tau/sides)**2)
        m.face([a,ring_a[j],ring_a[i]],col=col)
        m.face([b,ring_b[i],ring_b[j]],col=col)

def ring(m,c,outer,inner,axis='x',col=(1,1,1)):
    def p(r,a):
        return (c[0],c[1]+r*math.sin(a),c[2]+r*math.cos(a)) if axis=='x' else (c[0]+r*math.cos(a),c[1]+r*math.sin(a),c[2])
    for i in range(32):
        a=i*math.tau/32;b=(i+1)*math.tau/32
        m.face([p(inner,a),p(outer,a),p(outer,b),p(inner,b)],col=col)

def lettering(name,text,at,size,kind,reverse=False,side=False):
    curve=bpy.data.curves.new(name,'FONT');curve.body=text;curve.size=size
    curve.align_x='CENTER';curve.extrude=.002;curve.resolution_u=2
    ob=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(ob)
    ob.location=(at[0],-at[2],at[1]);ob.rotation_euler=(math.pi/2,0,0)
    if reverse: ob.rotation_euler=(math.pi/2,0,math.pi)
    if side: ob.rotation_euler=(math.pi/2,0,math.pi/2)
    ob.data.materials.append(MATS[kind])
    bpy.context.view_layer.objects.active=ob;ob.select_set(True)
    bpy.ops.object.convert(target='MESH');ob.select_set(False)
    # Text also carries vertex colour so it shares the surface shader.
    colors=ob.data.color_attributes.new(name='Shelter',type='FLOAT_COLOR',domain='POINT')
    for item in colors.data:item.color=(1,1,1,1)

def export(name):
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender'/f'{name}.blend'))
    for kind in MATS:
        objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith('Static') and o.data.materials[0]==MATS[kind]]
        bpy.ops.object.select_all(action='DESELECT')
        for ob in objs:ob.select_set(True)
        if objs:
            bpy.context.view_layer.objects.active=objs[0]
            if len(objs)>1:bpy.ops.object.join()
            objs[0].name=kind
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models'/f'{name}.glb'),export_format='GLB',export_vertex_color='NAME',export_vertex_color_name='Shelter',export_all_vertex_colors=False)

def laundry():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    mats={k:Mesh('Static '+k,k) for k in ['Tile','Enamel','Metal','Concrete','Road','Dark','Mint','NeonPink','NeonCyan','TubeLight']}
    t,e,m,c,r,d,mint,pink,cyan,light=[mats[k] for k in mats]
    box(t,(0,-.15,.5),(12,.3,11),uv_scale=.22)
    box(e,(-6.1,1.8,.5),(.2,3.6,11),(.7,.82,.8),.25)
    box(e,(6.1,1.8,.5),(.2,3.6,11),(.7,.82,.8),.25)
    box(e,(0,1.8,6.1),(12.4,3.6,.2),(.75,.8,.72),.25)
    box(e,(0,3.65,.5),(12.4,.15,11.4),(.5,.6,.56))
    # Tile wainscot and dark skirting meet walls and floor.
    for x in [-5.98,5.98]:
        box(t,(x,.65,.5),(.045,1.3,11),(.66,.85,.79),.4)
        box(m,(x,.09,.5),(.06,.18,11),(.3,.35,.33))
    box(t,(0,.65,5.98),(12,1.3,.045),(.66,.85,.79),.4)
    # Glazed shopfront, including a framed door in the right-hand opening.
    for x in [-6,-2,2,4,6]:box(m,(x,1.7,-5),(.095,3.4,.13),(.48,.53,.53))
    for y in [.18,3.35]:box(m,(0,y,-5),(12,.12,.16),(.5,.54,.55))
    box(m,(3,2.7,-5),(2,.08,.13))
    tube(m,(3.8,.95,-4.86),(3.8,1.5,-4.86),.028)
    glass=Mesh('WindowGlass','Glass')
    for x1,x2 in [(-5.94,-2.06),(-1.94,1.94),(2.06,3.94),(4.06,5.94)]:
        glass.face([(x1,.25,-5),(x2,.25,-5),(x2,3.28,-5),(x1,3.28,-5)],[(0,0),(x2-x1,0),(x2-x1,3.03),(0,3.03)])
    glass.finish()
    # Five washers with separate rotating, recessed drums and thick steel rims.
    for i,z in enumerate([-3.65,-1.85,-.05,1.75,3.55]):
        box(e,(-5.24,.82,z),(1.45,1.6,1.64),(.91,.95,.85))
        box(m,(-4.49,1.43,z),(.05,.27,1.5),(.72,.82,.78))
        box(d,(-4.453,1.43,z-.24),(.025,.115,.40),(.10,.17,.16))
        box(cyan,(-4.437,1.435,z-.24),(.012,.034,.14),(.2,.7,.58))
        tube(m,(-4.45,1.43,z+.44),(-4.40,1.43,z+.44),.075,(.65,.7,.67),16)
        tube(d,(-4.51,.75,z),(-4.43,.75,z),.56,(.11,.17,.19),32)
        ring(m,(-4.405,.75,z),.57,.47,col=(.9,.98,1))
        ring(m,(-4.39,.75,z),.49,.455,col=(.30,.38,.4))
        # The drum's pivot and coordinates survive export; geometry remains in Blender.
        drum=Mesh(f'Drum{i}','Metal')
        tube(drum,(-.03,0,0),(.015,0,0),.44,(.22,.3,.32),24)
        for j in range(3):
            a=j*math.tau/3
            tube(drum,(.028,.13*math.sin(a),.13*math.cos(a)),(.028,.39*math.sin(a),.39*math.cos(a)),.035,(.65,.76,.78),6)
        # Low folded cloth shapes tumble inside the glass aperture.
        for j in range(6):
            a=j*2.4
            box(drum,(.05,.24*math.sin(a),.24*math.cos(a)),(.03,.16,.19),[(.75,.67,.44),(.35,.56,.59),(.65,.69,.68)][j%3])
        ob=drum.finish();ob.location=(-4.42,-z,.75)
        lettering(f'Static machine number {i}',f'0{i+1}',(-4.40,1.39,z+.05),.085,'Dark',side=True)
    # Back wall folding counter, accessible right-hand bench, laundry carts.
    box(e,(0,1.03,5.35),(5,.14,1.0),(.7,.75,.64))
    for x in [-2.2,2.2]:box(m,(x,.49,5.35),(.1,.98,.65))
    for z in [-.3,1.3,2.9]:
        box(mint,(5.2,.48,z),(1.1,.12,1.4),(.42,.72,.64))
        box(mint,(5.7,.86,z),(.12,.75,1.4),(.42,.72,.64))
        for zz in [z-.48,z+.48]:box(m,(5.2,.23,zz),(.8,.46,.06))
    for x in [-1.7,.4]:
        box(e,(x,1.17,5.3),(.48,.12,.52),(.76,.76,.71))
        box(e,(x,1.28,5.3),(.43,.1,.47),(.67,.72,.65))
    # Ceiling fittings are suspended from rods attached to the ceiling.
    for x in [-2.5,2.5]:
        for z in [-2.2,2.2]:
            for dz in [-.65,.65]:tube(m,(x,3.18,z+dz),(x,3.58,z+dz),.017)
            box(m,(x,3.15,z),(.42,.10,1.85),(.47,.50,.5))
            for dx in [-.12,.12]:tube(light,(x+dx,3.08,z-.8),(x+dx,3.08,z+.8),.026,(.78,.95,.89))
    # Signs hang from actual frames. Text faces the room.
    box(d,(.15,2.67,-4.95),(2.45,.66,.055),(.035,.065,.065))
    lettering('Static OPEN neon','OPEN',(.15,2.43,-4.87),.52,'NeonPink')
    for a,b in [((-1.08,2.38,-4.86),(1.38,2.38,-4.86)),((-1.08,2.98,-4.86),(1.38,2.98,-4.86))]:tube(cyan,a,b,.013)
    lettering('Static rear title','NIGHT WASH',(0,2.54,5.93),.48,'Mint',True)
    lettering('Static rear subtitle','SELF SERVICE  /  24 HOURS',(0,2.17,5.92),.13,'Dark',True)
    # Vending and coin exchange cabinet, with recessed selection panel.
    box(mint,(4.75,1.05,5.35),(1.35,2.1,1.0),(.40,.62,.60))
    box(d,(4.75,1.25,4.82),(.96,1.05,.035),(.05,.12,.13))
    for x in [4.45,4.75,5.05]:
        for y in [.97,1.32,1.67]:box(e,(x,y,4.77),(.19,.25,.08),(.65,.63,.5))
    box(m,(4.75,.38,4.77),(.6,.19,.07),(.3,.32,.32))
    # Wire laundry cart: basket bars connect to its rim and lower frame; four
    # small wheels touch the tiled floor. It occupies a collidable footprint.
    cx,cz=3.35,3.6
    for x in [cx-.40,cx+.40]:
        for z in [cz-.43,cz+.43]:
            tube(m,(x,.13,z),(x,1.0,z),.019)
            tube(d,(x-.045,.10,z),(x+.045,.10,z),.10,(.12,.14,.14),10)
        for y in [.35,.65,1.0]:tube(m,(x,y,cz-.43),(x,y,cz+.43),.017)
    for z in [cz-.43,cz+.43]:
        for y in [.35,.65,1.0]:tube(m,(cx-.40,y,z),(cx+.40,y,z),.017)
        for j in range(1,6):tube(m,(cx-.4+j*.8/6,.35,z),(cx-.4+j*.8/6,1.,z),.01)
    for j in range(1,6):
        z=cz-.43+j*.86/6
        tube(m,(cx-.40,.35,z),(cx+.40,.35,z),.012)
        for x in [cx-.4,cx+.4]:tube(m,(x,.35,z),(x,1.,z),.01)
    tube(e,(3.4,2.68,5.92),(3.4,2.68,5.84),.26,(.75,.79,.7),32)
    tube(d,(3.4,2.68,5.81),(3.4,2.87,5.81),.012)
    tube(d,(3.4,2.68,5.81),(3.53,2.64,5.81),.015)
    # Supply pipe and short washer connections fixed to the tiled wall.
    tube(m,(-5.88,2.0,-4.1),(-5.88,2.0,4.3),.035,(.44,.53,.52))
    for z in [-3.65,-1.85,-.05,1.75,3.55]:tube(m,(-5.88,2.,z),(-5.88,1.55,z),.024)
    # Exterior street wraps past both side views, with curb, parking lines and facades.
    box(r,(0,-.20,-19),(110,.25,28),uv_scale=.4)
    box(c,(0,-.03,-6.3),(110,.20,2.4),(.42,.47,.48),.4)
    for x in range(-30,31,4):box(e,(x,-.063,-9),( .075,.012,3.4),(.56,.55,.4))
    for x in range(-44,45,7):box(e,(x,-.062,-17),(3,.012,.07),(.53,.55,.5))
    for i,x in enumerate(range(-40,41,8)):
        height=7+(i%3)*2
        box(c,(x,height/2,-30),(7.7,height,5),(.48,.55,.62),.2)
        box(d,(x,1.6,-27.45),(5.8,3.0,.08),(.10,.16,.19))
        for xx in [x-2,x,x+2]:
            for yy in [4.8,7.4]:box(mint,(xx,yy,-27.44),(1.1,1.3,.06),(.19,.32,.33))
    box(d,(-7.5,3.7,-27.32),(4.2,.8,.09))
    lettering('Static opposite sign','MOTEL',(-7.5,3.4,-27.2),.65,'NeonCyan')
    for x in [-13,13]:
        tube(m,(x,-.03,-7),(x,5.4,-7),.06,(.28,.31,.33))
        tube(m,(x,5.4,-7),(x,5.4,-8.1),.045)
        box(light,(x,5.35,-8.1),(.35,.07,.65),(.86,.79,.58))
    for batch in mats.values():batch.finish()
    # Original car, facing +X. Two instances share this authored mesh at runtime.
    car=Mesh('CarBody','Car')
    box(car,(0,.62,0),(4.1,.65,1.72),(.30,.43,.43))
    box(car,(.92,.92,0),(1.7,.10,1.66),(.35,.49,.47))
    box(car,(-.45,1.16,0),(1.8,.65,1.52),(.12,.23,.29))
    box(car,(-.45,1.51,0),(1.65,.08,1.54),(.36,.47,.46))
    for x in [-1.36,.49]:box(car,(x,1.20,0),(.09,.62,1.57),(.37,.48,.47))
    for z in [-.8,.8]:
        box(car,(-.4,.98,z),(1.9,.07,.04),(.65,.72,.7))
        box(car,(-.4,1.22,z),(.07,.56,.04),(.4,.50,.5))
        for x in [-1.35,1.35]:
            tube(car,(x,.36,z-.10),(x,.36,z+.10),.35,(.06,.07,.08),16)
            tube(car,(x,.36,z-.115),(x,.36,z+.115),.19,(.42,.5,.52),12)
    box(car,(2.07,.44,0),(.10,.10,1.68),(.58,.62,.61))
    car.finish()
    lamps=Mesh('CarLamps','Headlamp')
    for z in [-.6,.6]:box(lamps,(2.066,.70,z),(.03,.18,.35),(1,.85,.62))
    lamps.finish()
    rear=Mesh('CarTail','NeonPink')
    for z in [-.6,.6]:box(rear,(-2.065,.70,z),(.03,.16,.3),(1,.12,.06))
    rear.finish()
    rain=Mesh('StreetRain','Rain')
    for _ in range(1100):
        x=random.uniform(-38,38);y=random.uniform(0,9);z=random.uniform(-26,-5.2)
        rain.face([(x,y,z),(x+.009,y,z),(x+.04,y+.18,z),(x+.031,y+.18,z)])
    rain.finish()
    (ROOT/'assets/data/laundry_layout.json').write_text(json.dumps({'bounds':[-4.0,5.4,-4.55,5.45],'machine_front':-4.1,'bench':[4.55,5.9,-1.1,3.7],'counter':[-2.6,2.6,4.65,6],'vending':[4,5.6,4.5,6],'cart':[2.95,3.75,3.17,4.03]},indent=2))
    export('night_laundry')

def reservoir():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    columns=[]
    # Separate structural chunks keep frustum culling useful over the huge hall.
    for iz,z in enumerate(range(18,-218,-26)):
        col=Mesh(f'ColumnRow{iz}','Concrete')
        for x in range(-65,92,26):
            columns.append({'x':x,'z':z,'width':7})
            for y in range(0,84,7):box(col,(x,y+3.5,z),(7,7,7),(.8,.85,.87),.13)
            box(col,(x,-.25,z),(8,.5,8),(.32,.42,.43),.12)
            box(col,(x,81.5,z),(10,5,10),(.57,.64,.65),.13)
        # Complete transverse supports join every column to the ceiling.
        box(col,(13,82.5,z),(164,3,8),(.52,.60,.62),.1)
        col.finish()
    shell=Mesh('HallShell','Concrete')
    for x in [-78,104]:box(shell,(x,42,-100),(4,86,266),(.40,.48,.49),.06)
    for z in [34,-232]:box(shell,(13,42,z),(182,86,4),(.35,.44,.46),.06)
    box(shell,(13,-3,-100),(182,1,266),(.13,.22,.24),.10)
    # Ceiling slab explicitly cut around three apertures. Geometry and ray beams
    # use these same recorded rectangles; no light passes through solid concrete.
    holes=[(8,-21,7,10),(8,-73,7,10),(-44,-125,8,12)]
    xs=sorted(set([-80,106]+[h[0]+s*h[2]/2 for h in holes for s in [-1,1]]))
    zs=sorted(set([-234,36]+[h[1]+s*h[3]/2 for h in holes for s in [-1,1]]))
    for xa,xb in zip(xs,xs[1:]):
        for za,zb in zip(zs,zs[1:]):
            x,z=(xa+xb)/2,(za+zb)/2
            if any(abs(x-h[0])<h[2]/2 and abs(z-h[1])<h[3]/2 for h in holes):continue
            box(shell,(x,85,z),(xb-xa,2,zb-za),(.53,.6,.6),.08)
    shell.finish()
    aperture=Mesh('CeilingDaylight','Daylight')
    for x,z,w,d in holes:box(aperture,(x,87,z),(w,.05,d),(1,1,.93))
    aperture.finish()
    walk=Mesh('Causeways','Concrete')
    box(walk,(0,.22,-63),(3.6,1.16,177),(.62,.7,.69),.55)
    box(walk,(17,.22,-34),(30.4,1.16,3.6),(.62,.7,.69),.55)
    box(walk,(34,.22,-62),(3.6,1.16,59.6),(.62,.7,.69),.55)
    box(walk,(17,.22,-90),(30.4,1.16,3.6),(.62,.7,.69),.55)
    # Grounded support piers beneath walking slabs.
    for z in range(20,-151,-10):box(walk,(0,-1.6,z),(2.5,2.5,2),(.3,.4,.4),.5)
    walk.finish()
    rail=Mesh('CausewayRail','Metal')
    # Sparse posts provide a human scale cue while allowing a clear water view.
    for x in [-1.62,1.62]:
        for z in range(24,-152,-5):
            if x>0 and (abs(z+34)<4 or abs(z+90)<4):continue
            tube(rail,(x,.8,z),(x,1.72,z),.035,(.34,.41,.42),8)
        # Leave branch junctions open, with horizontal rails joined to posts.
        spans=[(24,-151)] if x<0 else [(24,-29),(-39,-85),(-95,-151)]
        for a,b in spans:
            tube(rail,(x,1.72,a),(x,1.72,b),.03,(.42,.46,.46),8)
            for z in [a,b]:tube(rail,(x,.8,z),(x,1.72,z),.035,(.34,.41,.42),8)
    for z in [-35.6,-32.4,-91.6,-88.4]:
        end=32.4 if z in [-35.6,-88.4] else 35.6
        for x in list(range(4,int(end),5))+[3,end]:tube(rail,(x,.8,z),(x,1.72,z),.035,(.32,.40,.42),8)
        tube(rail,(3,1.72,z),(end,1.72,z),.03,(.42,.46,.46),8)
    for x in [32.4,35.6]:
        for z in range(-38,-88,-5):tube(rail,(x,.8,z),(x,1.72,z),.035,(.32,.40,.42),8)
        za,zb=(-35.6,-88.4) if x==32.4 else (-32.4,-91.6)
        tube(rail,(x,1.72,za),(x,1.72,zb),.03,(.42,.46,.46),8)
    rail.finish()
    water=Mesh('ReservoirWater','Water')
    water.face([(-77,0,33), (103,0,33),(103,0,-231),(-77,0,-231)])
    water.finish()
    # A connected utility downpipe and elbow terminating above the water.
    pipe=Mesh('Drainage','Metal')
    tube(pipe,(-9.25,81,-8),(-9.25,4,-8),.16,(.30,.38,.36))
    tube(pipe,(-9.25,4,-8),(-7,3.2,-8),.16,(.30,.38,.36))
    tube(pipe,(-7,3.2,-8),(-7,2.2,-8),.16,(.30,.38,.36))
    for y in range(4,80,6):tube(pipe,(-9.25,y,-8),(-9.5,y,-8),.055)
    pipe.finish()
    drops=Mesh('FallingDrops','Drip')
    for x,z in [(-7,-8),(3.5,-23),(-3.1,-41),(30,-80)]:
        span=2.2 if x== -7 else 84.
        for j in range(20):
            y=.015+j*span/20
            drops.face([(x-.011,y,z),(x+.011,y,z),(x+.011,y+.075,z),(x-.011,y+.075,z)])
    drops.finish()
    dust=Mesh('BeamDust','Dust')
    for i in range(330):
        hx,hz,w,d=holes[i%3]
        y=random.uniform(1,70);x=hx-(84-y)*.16+random.uniform(-w*.65,w*.65);z=hz-(84-y)*.10+random.uniform(-d*.65,d*.65)
        a=random.uniform(.013,.039)
        dust.face([(x-a,y-a,z),(x+a,y-a,z),(x+a,y+a,z),(x-a,y+a,z)])
        dust.face([(x,y-a,z-a),(x,y-a,z+a),(x,y+a,z+a),(x,y+a,z-a)])
    dust.finish()
    (ROOT/'assets/data/reservoir_layout.json').write_text(json.dumps({'columns':columns,'ceiling':84,'apertures':holes,'walk_rects':[[-1.8,1.8,-151.5,25.5],[0,34,-35.8,-32.2],[32.2,35.8,-91.8,-32.2],[0,34,-91.8,-88.2]],'walk_height':.8},indent=2))
    export('reservoir')

def audio(name,mode):
    rng=random.Random(721);rate=22050;seconds=24;n=rate*seconds
    data=bytearray();low=0.;rain=0.
    for i in range(n):
        t=i/rate;noise=rng.uniform(-1,1);low=low*.993+noise*.007;rain=rain*.6+noise*.4
        fade=min(1,t/.12,(seconds-t)/.12)
        if mode=='laundry':
            motor=.11*math.sin(math.tau*48*t)+.045*math.sin(math.tau*96*t)
            motor*=.72+.20*math.sin(math.tau*t/3)
            value=motor+rain*.065+low*.52
            value+=.018*math.sin(math.tau*145*t)*(.5+.5*math.cos(math.tau*t*1.5))**8
        else:
            value=low*.22+.018*math.sin(math.tau*37*t)
            for at in [1.4,3.8,4.5,8.2,11.1,15.6,16.1,19.3,22.0]:
                for delay,gain in [(0,1),(.19,.32),(.43,.17),(.91,.09),(1.37,.04)]:
                    dt=t-at-delay
                    if 0<dt<.6:value+=gain*.15*math.exp(-dt*14)*math.sin(math.tau*(850*dt+750*dt*dt))
        for side in [0,1]:
            out=value*fade*(.94 if side else 1)+low*.018*side
            data.extend(struct.pack('<h',int(max(-.95,min(.95,out))*32767)))
    with wave.open(str(ROOT/'assets/audio'/f'{name}.wav'),'wb') as out:
        out.setnchannels(2);out.setsampwidth(2);out.setframerate(rate);out.writeframes(data)

for kind,file in [('Concrete','concrete'),('Tile','tile'),('Enamel','enamel'),('Metal','metal'),('Road','road')]:
    material(kind,texture('Interior'+kind,file))
for kind in ['Dark','Mint','NeonPink','NeonCyan','TubeLight','Glass','Car','Headlamp','Rain','Water','Daylight','Drip','Dust']:material(kind)
laundry();reservoir()
audio('laundry_rumble','laundry');audio('reservoir_drips','reservoir')
print('INTERIORS_READY: two editable Blender scenes, batched GLBs, original texture studies and ambience')
