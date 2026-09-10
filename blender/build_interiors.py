"""Original Night Laundry and Reservoir art. Blender is the geometry source.

Coordinates passed to helpers are Godot X/Y/Z; conversion happens once in mesh
creation. Editable named components are saved before static material batching.
Run with Blender --background --python blender/build_interiors.py.
"""
import bpy, math, random, json, wave, struct
from pathlib import Path
from mathutils import Vector
from mathutils.noise import noise as stone_noise

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
                value = .65+noise*.8
                # Aggregate, lime patches and weathered pores, at several scales.
                value += .13*stone_noise(Vector((u*6,v*6,2.7)))+.08*stone_noise(Vector((u*22,v*22,7.1)))+.045*stone_noise(Vector((u*70,v*70,4.3)))
                for at,width,strength,phase in streaks:
                    d=min(abs(u-at),1-abs(u-at))
                    value-=strength*math.exp(-(d/width)**2)*(.55+.45*math.sin(v*3+phase*4))
                # Small formwork tie holes, separated by broad mottled concrete.
                if any((x-tx)**2+(y-ty)**2<5 for tx,ty in [(39,56),(203,56),(39,205),(203,205)]): value-=.15
                # Broken casting joints and irregular hairline fractures.
                joint=abs((y+int(1.4*math.sin(x*.07)))%128-2)
                crack=abs(x-(76+19*math.sin(y*.028)+5*math.sin(y*.19)))
                if joint<1.3: value-=.14
                if crack<.8 and 32<y<231: value-=.21
                if rng.random()<.014: value-=rng.uniform(.06,.22)
                col=(value,value*.98,value*.93)
            elif kind == 'tile':
                mortar = x%32<2 or y%32<2
                value = (.24 if mortar else (.77 if (x//32+y//32)%2 else .49))+noise
                col=(value,value*.96,value*.85)
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

def oriented(m,pts,normal,col=(1,1,1),scale=1):
    pts=[Vector(p) for p in pts]
    if (pts[1]-pts[0]).cross(pts[2]-pts[0]).dot(Vector(normal))<0:pts.reverse()
    axis=max(range(3),key=lambda i:abs(normal[i]));uvaxes=[i for i in range(3) if i!=axis]
    m.face(pts,[(p[uvaxes[0]]*scale,p[uvaxes[1]]*scale) for p in pts],col)

def bevel_box(m,c,s,col=(1,1,1),bevel=.04,scale=1):
    """Six broad faces, twelve edge chamfers and eight corner triangles."""
    h=[v*.5 for v in s];b=min(bevel,min(h)*.45)
    def p(v):return [c[i]+v[i] for i in range(3)]
    for axis in range(3):
        other=[i for i in range(3) if i!=axis]
        for sign in [-1,1]:
            pts=[]
            for a,d in [(-1,-1),(1,-1),(1,1),(-1,1)]:
                v=[0,0,0];v[axis]=sign*h[axis];v[other[0]]=a*(h[other[0]]-b);v[other[1]]=d*(h[other[1]]-b);pts.append(p(v))
            n=[0,0,0];n[axis]=sign;oriented(m,pts,n,col,scale)
        for sa in [-1,1]:
            for sb in [-1,1]:
                pts=[]
                for t,edge in [(-1,0),(1,0),(1,1),(-1,1)]:
                    v=[0,0,0];v[axis]=t*(h[axis]-b)
                    v[other[0]]=sa*(h[other[0]]-(b if edge else 0));v[other[1]]=sb*(h[other[1]]-(0 if edge else b));pts.append(p(v))
                n=[0,0,0];n[other[0]]=sa;n[other[1]]=sb;oriented(m,pts,n,col,scale)
    for sx in [-1,1]:
        for sy in [-1,1]:
            for sz in [-1,1]:
                signs=[sx,sy,sz];pts=[]
                for axis in range(3):pts.append(p([signs[i]*(h[i]-(0 if i==axis else b)) for i in range(3)]))
                oriented(m,pts,signs,col,scale)

def profile(m,points,halfwidth,col=(1,1,1)):
    """A shaped silhouette extruded across Z, used for coachwork and glass."""
    for sign in [-1,1]:oriented(m,[(x,y,sign*halfwidth) for x,y in points],(0,0,sign),col)
    for i,(x,y) in enumerate(points):
        xx,yy=points[(i+1)%len(points)]
        oriented(m,[(x,y,-halfwidth),(xx,yy,-halfwidth),(xx,yy,halfwidth),(x,y,halfwidth)],(yy-y,x-xx,0),col)

def cloth(m,c,s,col,seed=0,axis='y'):
    """Soft folded fabric with an irregular hem and modeled small creases."""
    nx,nz=8,7
    verts=[]
    for j in range(nz+1):
        row=[]
        for i in range(nx+1):
            u,v=i/nx,j/nz
            xx=(u-.5)*s[0];zz=(v-.5)*s[2]
            yy=s[1]*(.3+.7*math.sin(u*math.pi)*math.sin(v*math.pi))+.012*math.sin(u*25+v*9+seed)
            zz+=.016*math.sin(i*1.7+seed);xx+=.014*math.sin(j*2.3+seed)
            p=(c[0]+xx,c[1]+yy,c[2]+zz) if axis=='y' else (c[0]+yy,c[1]+xx,c[2]+zz)
            row.append(p)
        verts.append(row)
    for j in range(nz):
        for i in range(nx):
            shade=.86+.14*math.sin((i+.5)/nx*math.pi)
            oriented(m,[verts[j][i],verts[j+1][i],verts[j+1][i+1],verts[j][i+1]],(0,1,0) if axis=='y' else (1,0,0),tuple(v*shade for v in col))

def pipe_path(m,points,r,col):
    """Continuous swept rings: elbows meet without overlapping capped tubes."""
    rings=[]
    for i,p in enumerate(points):
        axis=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized()
        u=Vector((0,0,1));v=axis.cross(u).normalized()
        rings.append([Vector(p)+r*(u*math.cos(j*math.tau/16)+v*math.sin(j*math.tau/16)) for j in range(16)])
    for i in range(len(rings)-1):
        for j in range(16):
            k=(j+1)%16
            oriented(m,[rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j]],rings[i][j]-Vector(points[i]),col)

def ring(m,c,outer,inner,axis='x',col=(1,1,1)):
    def p(r,a):
        if axis=='y':return (c[0]+r*math.cos(a),c[1],c[2]+r*math.sin(a))
        return (c[0],c[1]+r*math.sin(a),c[2]+r*math.cos(a)) if axis=='x' else (c[0]+r*math.cos(a),c[1]+r*math.sin(a),c[2])
    for i in range(32):
        a=i*math.tau/32;b=(i+1)*math.tau/32
        oriented(m,[p(inner,a),p(outer,a),p(outer,b),p(inner,b)],(1,0,0) if axis=='x' else ((0,1,0) if axis=='y' else (0,0,1)),col)

def lettering(name,text,at,size,kind,reverse=False,side=False):
    curve=bpy.data.curves.new(name,'FONT');curve.body=text;curve.size=size
    curve.align_x='CENTER';curve.extrude=.002;curve.resolution_u=2
    ob=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(ob)
    ob.location=(at[0],-at[2],at[1]);ob.rotation_euler=(math.pi/2,0,0)
    if reverse: ob.rotation_euler=(math.pi/2,0,math.pi)
    if side: ob.rotation_euler=(math.pi/2,0,-math.pi/2 if side=='right' else math.pi/2)
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
    box(e,(-6.1,1.8,.5),(.2,3.6,11),(.96,.90,.77),.25)
    box(e,(6.1,1.8,.5),(.2,3.6,11),(.96,.90,.77),.25)
    box(e,(0,1.8,6.1),(12.4,3.6,.2),(.94,.88,.76),.25)
    box(e,(0,3.65,.5),(12.4,.15,11.4),(.77,.75,.68))
    # Suspended ceiling grid, crown trim and wall electrical raceways.
    for x in range(-6,7):box(m,(x,3.557,.5),(.018,.025,11),(.52,.49,.40))
    for z in range(-5,7):box(m,(0,3.555,z),(12,.025,.018),(.52,.49,.40))
    for x in [-5.94,5.94]:
        box(e,(x,3.42,.5),(.10,.12,11),(.80,.73,.53))
        box(m,(x,1.34,.5),(.08,.045,11),(.68,.63,.47))
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
    doors=Mesh('PortholeGlass','DoorGlass')
    # Five washers with separate rotating, recessed drums and thick steel rims.
    for i,z in enumerate([-3.65,-1.85,-.05,1.75,3.55]):
        bevel_box(e,(-5.24,.82,z),(1.45,1.6,1.64),(.96,.93,.78),.055)
        bevel_box(m,(-4.495,.80,z),(.038,1.30,1.51),(.70,.76,.72),.015)
        box(m,(-4.49,1.43,z),(.05,.27,1.5),(.72,.82,.78))
        box(d,(-4.453,1.43,z-.24),(.025,.115,.40),(.10,.17,.16))
        box(cyan,(-4.437,1.435,z-.24),(.012,.034,.14),(.2,.7,.58))
        tube(m,(-4.45,1.43,z+.44),(-4.40,1.43,z+.44),.075,(.65,.7,.67),16)
        tube(d,(-4.51,.75,z),(-4.43,.75,z),.56,(.11,.17,.19),32)
        ring(m,(-4.405,.75,z),.57,.47,col=(.9,.98,1))
        ring(m,(-4.39,.75,z),.49,.455,col=(.30,.38,.4))
        ring(e,(-4.38,.75,z),.575,.55,col=(.88,.84,.66))
        tube(m,(-4.34,.62,z+.48),(-4.34,.90,z+.48),.035,(.88,.87,.73))
        # Screw heads, coin slot, detergent tray, vents and rubber feet.
        for zz in [z-.67,z+.67]:
            for yy in [.18,1.36]:tube(d,(-4.45,yy,zz),(-4.43,yy,zz),.016,(.22,.26,.26),8)
        box(d,(-4.438,1.44,z+.21),(.017,.075,.018))
        box(e,(-4.43,1.43,z-.58),(.024,.16,.25),(.85,.82,.69))
        box(d,(-4.41,1.43,z-.58),(.009,.022,.13))
        for j in range(10):box(d,(-4.45,.18,z-.32+j*.066),(.012,.047,.012),(.13,.17,.17))
        for zz in [z-.62,z+.62]:box(d,(-4.73,.047,zz),(.24,.075,.18))
        # The drum's pivot and coordinates survive export; geometry remains in Blender.
        drum=Mesh(f'Drum{i}','Metal')
        tube(drum,(-.03,0,0),(.015,0,0),.44,(.22,.3,.32),24)
        for j in range(3):
            a=j*math.tau/3
            tube(drum,(.028,.13*math.sin(a),.13*math.cos(a)),(.028,.39*math.sin(a),.39*math.cos(a)),.035,(.65,.76,.78),6)
        # Low folded cloth shapes tumble inside the glass aperture.
        fabric=Mesh(f'WasherFabric{i}','Fabric')
        for j in range(7):
            a=j*2.4
            cloth(fabric,(.045,.23*math.sin(a),.23*math.cos(a)),(.23,.045,.24),[(.66,.37,.23),(.24,.42,.55),(.79,.77,.67)][(j+i)%3],i*7+j,'x')
        ob=drum.finish();ob.location=(-4.42,-z,.75)
        cloth_ob=fabric.finish();cloth_ob.parent=ob
        lettering(f'Static machine number {i}',f'0{i+1}',(-4.40,1.39,z+.05),.085,'Dark',side=True)
        # Upper drying cabinets with glass portholes, hinges and control strip.
        bevel_box(e,(-5.27,2.40,z),(1.39,1.30,1.64),(.84,.79,.61),.06)
        tube(d,(-4.55,2.40,z),(-4.51,2.40,z),.46,(.09,.16,.18),32)
        ring(m,(-4.49,2.40,z),.50,.43,col=(.76,.77,.69))
        ring(m,(-4.48,2.40,z),.44,.41,col=(.26,.35,.36))
        dry=Mesh(f'Dryer{i}','Fabric')
        for j in range(6):
            a=j*2.4+i*.73
            cloth(dry,(.022,.19*math.sin(a),.19*math.cos(a)),(.25,.045,.26),[(.70,.70,.60),(.45,.52,.56),(.68,.46,.31)][(i+j)%3],j+i*13,'x')
        dry_ob=dry.finish();dry_ob.location=(-4.525,-z,2.4)
        for xx,yy,rr in [(-4.365,.75,.45),(-4.465,2.40,.405)]:
            for j in range(40):
                a=j*math.tau/40;b=(j+1)*math.tau/40
                pts=[(xx,yy,z),(xx,yy+rr*math.sin(b),z+rr*math.cos(b)),(xx,yy+rr*math.sin(a),z+rr*math.cos(a))]
                doors.face(pts,[(.5,.5),(.5+.5*math.cos(b),.5+.5*math.sin(b)),(.5+.5*math.cos(a),.5+.5*math.sin(a))])
        box(d,(-4.55,2.94,z),(.02,.09,.68),(.13,.17,.16))
        tube(m,(-4.53,2.94,z+.49),(-4.48,2.94,z+.49),.05,(.77,.76,.68))
        box(cyan,(-4.53,2.94,z-.15),(.02,.025,.10),(.28,.52,.34))
    doors.finish()
    # Stacking brackets bridge the washer tops to the upper dryer cabinets;
    # end posts carry the rack to the floor rather than leaving a floating row.
    for x in [-5.86,-4.64]:
        box(m,(x,1.685,-.05),(.085,.13,8.92),(.45,.47,.42))
        for z in [-4.46,4.36]:box(m,(x,1.55,z),(.08,3.10,.085),(.42,.45,.40))
    for z in [-4.46,-2.75,-.95,.85,2.65,4.36]:box(m,(-5.25,1.685,z),(1.3,.13,.07),(.43,.46,.41))
    # Back wall folding counter, accessible right-hand bench, laundry carts.
    box(e,(0,1.03,5.35),(5,.14,1.0),(.7,.75,.64))
    for x in [-2.2,2.2]:box(m,(x,.49,5.35),(.1,.98,.65))
    for z in [-.3,1.3,2.9]:
        # Bent plywood shells with rounded corners and connected tubular legs.
        bevel_box(mint,(5.17,.49,z),(1.05,.085,1.19),(.65,.35,.17),.04)
        for k in range(5):
            y=.57+k*.09;x=5.62+.065*math.sin(k*.37)
            bevel_box(mint,(x,y,z),(.085,.13,1.19),(.68,.39,.20),.032)
        for zz in [z-.40,z+.40]:
            tube(m,(4.82,.035,zz),(4.96,.45,zz),.025)
            tube(m,(5.57,.035,zz),(5.43,.45,zz),.025)
            tube(m,(4.96,.40,zz),(5.43,.40,zz),.025)
    for x in [-1.7,.4]:
        for j in range(5):cloth(e,(x,1.105+j*.05,5.3),(.58-j*.015,.045,.60),[(.90,.78,.53),(.72,.77,.67),(.44,.60,.59)][j%3],j+4)
    # Ceiling fittings are suspended from rods attached to the ceiling.
    for x in [-2.5,2.5]:
        for z in [-2.2,2.2]:
            for dz in [-.65,.65]:tube(m,(x,3.18,z+dz),(x,3.58,z+dz),.017)
            box(m,(x,3.15,z),(.42,.10,1.85),(.47,.50,.5))
            for dx in [-.12,.12]:tube(light,(x+dx,3.08,z-.8),(x+dx,3.08,z+.8),.026,(1.,.86,.63))
            for dz in [-.85,.85]:box(e,(x,3.08,z+dz),(.36,.10,.09),(.64,.60,.48))
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
    # Daily-use objects tell a quieter story than an empty showroom.
    for j in range(6):
        cloth(e,(cx+.04*math.sin(j),.37+j*.075,cz),(.60,.08,.65),[(.74,.55,.34),(.56,.67,.69),(.86,.79,.64)][j%3],j+30)
    for j in range(4):
        x=-.85+j*.35
        bevel_box(mint,(x,1.31,5.54),(.23,.38,.16),[(.79,.40,.17),(.43,.64,.62),(.78,.70,.35),(.65,.31,.22)][j],.045)
        tube(e,(x,1.50,5.54),(x,1.56,5.54),.055,(.87,.82,.67))
        box(e,(x,1.32,5.45),(.15,.15,.01),(.88,.81,.61))
    # Corkboard, paper notices and a wall-mounted ventilation unit.
    bevel_box(m,(2.9,2.22,5.94),(1.30,.93,.055),(.48,.36,.22),.025)
    box(mint,(2.9,2.22,5.902),(1.20,.83,.018),(.47,.30,.14))
    for j in range(5):
        x=2.5+(j%3)*.31;y=2.0+(j//3)*.35
        box(e,(x,y,5.88),(.25,.29,.009),(.83,.77,.60))
        for k in range(4):box(d,(x,y-.085+k*.042,5.871),(.16,.006,.002),(.32,.28,.20))
        tube(pink,(x,y+.12,5.877),(x,y+.12,5.86),.012)
    bevel_box(e,(0,3.12,5.82),(2.6,.57,.37),(.80,.79,.67),.07)
    for y in [2.92,2.98,3.04,3.10]:box(d,(0,y,5.62),(2.2,.016,.022),(.22,.24,.21))
    # Coin return station and abandoned paper cup on the folding counter.
    bevel_box(m,(-3.25,1.6,5.83),(.72,1.23,.33),(.53,.54,.43),.045)
    box(d,(-3.25,1.65,5.65),(.43,.31,.016))
    lettering('Static change label','CHANGE',(-3.25,2.08,5.61),.10,'TubeLight',True)
    tube(e,(2.02,1.115,5.21),(2.02,1.32,5.21),.075,(.78,.59,.33),12,r2=.105)
    ring(e,(2.02,1.325,5.21),.105,.086,axis='y',col=(.9,.8,.6))
    # Grille, doormat and coat hooks remain out of the walking route.
    bevel_box(d,(3,.018,-4.30),(1.65,.035,.85),(.17,.21,.18),.06)
    for j in range(15):box(m,(3,.041,-4.65+j*.05),(1.45,.008,.012),(.29,.31,.25))
    # A second folding station breaks the empty floor into useful human spaces.
    bevel_box(e,(.4,.99,2.8),(2.4,.12,.85),(.83,.76,.59),.04)
    for xx in [-.57,1.37]:
        for zz in [2.49,3.11]:tube(m,(xx,.035,zz),(xx,.93,zz),.032,(.48,.52,.49))
        tube(m,(xx,.27,2.49),(xx,.27,3.11),.022)
    for j in range(3):cloth(e,(.05,1.05+j*.045,2.8),(.68,.045,.56),(.73,.80,.73),j+44)
    cloth(mint,(.9,1.05,2.80),(.57,.06,.64),(.49,.64,.66),48)
    # Framed care cards and a local notice on the waiting-room wall.
    for i,zz in enumerate([-.65,1.22,3.10]):
        bevel_box(m,(5.94,2.20,zz),(.055,1.05,.80),(.40,.36,.25),.018)
        box(e,(5.902,2.20,zz),(.014,.95,.70),(.85,.81,.67))
        lettering(f'Static care title {i}',['WASH','DRY','FOLD'][i],(5.882,2.48,zz),.12,'Dark',side='right')
        for k in range(5):box(m,(5.881,1.90+k*.041,zz),(.004,.009,.48-k%2*.09),(.34,.40,.35))
        # Wash tub, sun and folded-cloth diagrams drawn on their attached cards.
        if i==0:
            for dz in [-.19,.19]:tube(m,(5.88,2.19,zz+dz),(5.88,2.37,zz+dz),.013,(.26,.39,.36))
            tube(m,(5.88,2.19,zz-.19),(5.88,2.19,zz+.19),.013,(.26,.39,.36))
        elif i==1:
            tube(mint,(5.889,2.27,zz),(5.869,2.27,zz),.12,(.60,.43,.23),16)
        else:
            for k in range(3):box(mint,(5.88,2.20+k*.055,zz),(.01,.034,.37),(.29,.46,.42))
    # Exterior street wraps past both side views, with curb, parking lines and facades.
    box(r,(0,-.20,-19),(110,.25,28),uv_scale=.4)
    box(c,(0,-.03,-6.3),(110,.20,2.4),(.42,.47,.48),.4)
    for x in range(-30,31,4):box(e,(x,-.063,-9),( .075,.012,3.4),(.56,.55,.4))
    for x in range(-44,45,7):box(e,(x,-.062,-17),(3,.012,.07),(.53,.55,.5))
    for i,x in enumerate(range(-40,41,8)):
        height=7+(i%3)*2
        facade=[(.50,.56,.58),(.44,.43,.39),(.51,.46,.40),(.37,.46,.50)][i%4]
        box(c,(x,height/2,-30),(7.7,height,5),facade,.38)
        # Individual storefront bays, recessed doorways, layered cornices.
        for xx in [x-2.1,x+1.55]:
            box(d,(xx,1.43,-27.44),(2.8,2.73,.05),(.07,.12,.18))
            box(m,(xx,2.89,-27.29),(3.04,.16,.23),(.45,.49,.45))
            for dx in [-1.42,0,1.42]:box(m,(xx+dx,1.43,-27.30),(.055,2.7,.16),(.44,.48,.47))
            for yy in [.18,1.90]:box(m,(xx,yy,-27.30),(2.87,.065,.16),(.35,.43,.44))
            if i%3==0:
                for yy in [.35,.60,.85,1.1,1.35,1.6,1.85,2.10,2.35,2.60]:box(m,(xx,yy,-27.22),(2.67,.13,.035),(.22,.30,.34))
            else:
                for q in range(4):bevel_box(e,(xx-1+q*.62,.55,-27.36),(.43,.62,.1),(.45,.48,.34),.035)
        for yy in [3.2,height-.12]:
            box(c,(x,yy,-27.26),(7.8,.19,.50),tuple(v*1.2 for v in facade),.3)
            box(m,(x,yy-.13,-27.22),(7.8,.065,.55),(.18,.24,.26))
        for j,xx in enumerate([x-2.35,x,x+2.35]):
            for yy in [4.8,7.4]:
                if yy+1>height:continue
                box(d,(xx,yy,-27.45),(1.42,1.65,.04),(.10,.15,.20))
                box(mint,(xx,yy,-27.42),(1.19,1.44,.018),(.48,.40,.25) if (i+j)%4==0 else (.13,.23,.30))
                for dx in [-.67,.67]:box(c,(xx+dx,yy,-27.29),(.12,1.77,.25),facade,.7)
                for dy in [-.85,.85]:box(c,(xx,yy+dy,-27.24),(1.55,.12,.37),facade,.7)
                box(m,(xx,yy,-27.32),(.045,1.62,.08),(.33,.37,.37))
                if j==1:
                    bevel_box(m,(xx,yy-.5,-26.93),(.82,.47,.56),(.42,.48,.47),.045)
                    for q in range(7):box(d,(xx-.28+q*.09,yy-.5,-26.638),(.025,.32,.01))
        # Sloped striped fabric awnings have fascias and wall-mounted braces.
        if i%2==0:
            for q in range(12):
                a=x-3.3+q*.55
                oriented(mint if q%2 else e,[(a,3.1,-27.1),(a+.55,3.1,-27.1),(a+.55,2.65,-25.9),(a,2.65,-25.9)],(0,1,0),(.38,.49,.47))
                box(mint if q%2 else e,(a+.275,2.56,-25.9),(.55,.18,.025),(.38,.49,.47))
            for xx in [x-3.2,x+3.2]:tube(m,(xx,2.12,-27.38),(xx,2.65,-25.92),.022)
        tube(m,(x+3.61,.12,-27.2),(x+3.61,height,-27.2),.065,(.20,.27,.29))
        for yy in [2,5]:tube(m,(x+3.61,yy,-27.2),(x+3.61,yy,-27.49),.028)
        bevel_box(m,(x-2.5,height+.45,-29),(1.2,.9,1.2),(.20,.25,.29),.05)
        # Brickwork breaks the uniform silhouettes at the ground floor.
        for yy in range(9):
            for q in range(3):box(c,(x+3.14+(q%2)*.16,.18+yy*.31,-27.38),(.30,.26,.10),tuple(v*(.65+.10*(yy%3)) for v in facade),2)
    # Shallow sidewalk, drains, bollards, bins and distant utility cables.
    box(c,(0,-.025,-26.2),(110,.19,2.2),(.32,.39,.43),.8)
    for x in range(-30,32,5):
        box(m,(x,.079,-25.32),(.80,.015,.40),(.19,.24,.27))
        for j in range(7):box(d,(x-.32+j*.105,.088,-25.32),(.05,.012,.32))
    for x in [-9,5,18]:
        bevel_box(m,(x,.45,-26),(.72,.92,.65),(.24,.34,.34),.08)
        bevel_box(m,(x,.93,-26),(.82,.11,.74),(.33,.40,.36),.04)
    for zz,yy in [(-26.6,6.5),(-25.8,7.2)]:
        for x in range(-40,40,2):tube(d,(x,yy-.5*math.sin((x+40)/80*math.pi),zz),(x+2,yy-.5*math.sin((x+42)/80*math.pi),zz),.014)
    box(d,(-7.5,3.7,-27.32),(4.2,.8,.09))
    lettering('Static opposite sign','MOTEL',(-7.5,3.4,-27.2),.65,'NeonCyan')
    for x in [-13,13]:
        tube(m,(x,-.03,-7),(x,5.4,-7),.06,(.28,.31,.33))
        tube(m,(x,5.4,-7),(x,5.4,-8.1),.045)
        box(light,(x,5.35,-8.1),(.35,.07,.65),(.86,.79,.58))
    for batch in mats.values():batch.finish()
    # Original car, facing +X. Two instances share this authored mesh at runtime.
    car=Mesh('CarBody','Car')
    paint=(.39,.51,.53)
    # A compact late-century saloon: stepped boot, sloping bonnet and real arches.
    outline=[(-2.13,.45),(-1.80,.45),(-1.75,.65),(-1.57,.82),(-1.29,.85),(-1.02,.72),(-.94,.45),(.89,.45),(.97,.68),(1.18,.83),(1.48,.83),(1.72,.64),(1.78,.45),(2.10,.45),(2.14,.72),(1.92,.86),(.76,.95),(-1.08,.95),(-1.69,.85),(-2.10,.79)]
    # Side outlines follow the actual wheel wells instead of burying wheels in a box.
    for sign in [-1,1]:oriented(car,[(x,y,sign*.84) for x,y in outline],(0,0,sign),paint)
    profile(car,[(-2.10,.65),(2.10,.65),(2.10,.79),(.72,.96),(-1.16,.96),(-2.1,.86)],.78,paint)
    # Tapered cabin with sloping windscreen and rear screen; broad dark glass.
    profile(car,[(-1.18,.95),(.76,.95),(.19,1.48),(-.73,1.48)],.70,(.075,.15,.19))
    bevel_box(car,(-.27,1.50,0),(1.02,.08,1.43),paint,.045)
    for z in [-.715,.715]:
        tube(car,(-1.18,.95,z),(-.73,1.49,z),.035,paint,8)
        tube(car,(.76,.95,z),(.19,1.49,z),.035,paint,8)
        tube(car,(-.38,.97,z),(-.38,1.48,z),.027,paint,8)
        tube(car,(-1.16,.965,z),(.76,.965,z),.025,(.66,.68,.62),8)
        for x in [-.69,.23]:
            bevel_box(car,(x,.88,z*1.19),(.18,.027,.028),(.69,.72,.70),.008)
            box(car,(x+.19,.65,z*1.181),(.012,.45,.01),(.19,.28,.30))
        bevel_box(car,(.45,1.04,z*1.29),(.22,.12,.20),paint,.045)
        tube(car,(.40,.99,z),(.45,1.04,z*1.25),.018,paint,8)
        # Black trim along the sill, front-quarter vent and shaped bumpers.
        bevel_box(car,(0,.49,z*1.19),(1.80,.075,.04),(.10,.14,.15),.015)
    for z in [-.39,.30]:tube(car,(.57,1.105,z-.19),(.48,1.18,z+.20),.013,(.13,.18,.20),6)
    for z in [-.8,.8]:
        for x in [-1.35,1.35]:
            tube(car,(x,.36,z-.10),(x,.36,z+.10),.35,(.055,.065,.07),24)
            tube(car,(x,.36,z-.115),(x,.36,z+.115),.22,(.49,.54,.53),20)
            for j in range(8):
                a=j*math.tau/8
                tube(car,(x+.16*math.cos(a),.36+.16*math.sin(a),z-.12),(x+.16*math.cos(a),.36+.16*math.sin(a),z+.12),.036,(.12,.17,.19),6)
            tube(car,(x,.36,z-.125),(x,.36,z+.125),.072,(.66,.68,.65),12)
    for x in [-2.10,2.10]:bevel_box(car,(x,.45,0),(.18,.17,1.73),(.20,.27,.29),.06)
    box(car,(2.15,.70,0),(.018,.17,.52),(.08,.14,.15))
    for j in range(6):box(car,(2.166,.64+j*.023,0),(.01,.008,.51),(.48,.51,.47))
    for x in [-2.206,2.201]:bevel_box(car,(x,.44,0),(.014,.10,.34),(.74,.70,.51),.01)
    car.finish()
    lamps=Mesh('CarLamps','Headlamp')
    for z in [-.6,.6]:bevel_box(lamps,(2.155,.72,z),(.035,.18,.34),(1,.85,.62),.03)
    lamps.finish()
    rear=Mesh('CarTail','NeonPink')
    for z in [-.6,.6]:bevel_box(rear,(-2.115,.70,z),(.035,.16,.3),(1,.12,.06),.022)
    rear.finish()
    rain=Mesh('StreetRain','Rain')
    for _ in range(1100):
        x=random.uniform(-38,38);y=random.uniform(0,9);z=random.uniform(-26,-5.2)
        rain.face([(x,y,z),(x+.009,y,z),(x+.04,y+.18,z),(x+.031,y+.18,z)])
    rain.finish()
    (ROOT/'assets/data/laundry_layout.json').write_text(json.dumps({'bounds':[-4.0,5.4,-4.55,5.45],'machine_front':-4.1,'bench':[4.55,5.9,-1.1,3.7],'counter':[-2.6,2.6,4.65,6],'vending':[4,5.6,4.5,6],'cart':[2.95,3.75,3.17,4.03],'island':[-.8,1.6,2.375,3.225]},indent=2))
    export('night_laundry')

def reservoir():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    columns=[]
    # Separate structural chunks keep frustum culling useful over the huge hall.
    for iz,z in enumerate(range(18,-218,-26)):
        col=Mesh(f'ColumnRow{iz}','Concrete')
        for x in range(-65,92,26):
            columns.append({'x':x,'z':z,'width':7})
            # Continuous shaft crosses the waterline. Its footing is fully
            # submerged: no coplanar top face can compete with the water.
            bevel_box(col,(x,40.75,z),(7,84.5,7),(.86,.87,.84),.055,.22)
            bevel_box(col,(x,-.72,z),(8.1,.75,8.1),(.32,.38,.37),.09,.22)
            bevel_box(col,(x,81.5,z),(10,5,10),(.60,.63,.60),.12,.22)
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
    def paving(cx,cz,w,d):
        box(walk,(cx,.11,cz),(w,.94,d),(.43,.46,.43),.35)
        nx,nz=max(1,round(w/1.2)),max(1,round(d/1.8))
        for j in range(nz):
            for i in range(nx):
                shade=.90+random.random()*.13
                bevel_box(walk,(cx-w/2+(i+.5)*w/nx,.69,cz-d/2+(j+.5)*d/nz),(w/nx-.015,.22,d/nz-.015),(.76*shade,.77*shade,.70*shade),.025,.60)
    paving(0,-63,3.6,177)
    paving(17,-34,30.4,3.6)
    paving(34,-62,3.6,59.6)
    paving(17,-90,30.4,3.6)
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
    pipe_col=(.39,.37,.29)
    path=[(-9.24,83,-8),(-9.24,4.9,-8)]
    # Two quarter-circle elbows connect a proper horizontal offset to the outlet.
    for j in range(1,9):
        a=j*math.pi/16;path.append((-8.79-.45*math.cos(a),4.9-.45*math.sin(a),-8))
    path.append((-7.45,4.45,-8))
    for j in range(1,9):
        a=j*math.pi/16;path.append((-7.45+.45*math.sin(a),4.0+.45*math.cos(a),-8))
    path.append((-7,2.2,-8))
    pipe_path(pipe,path,.18,pipe_col)
    # Open annular mouth, darkness recessed above it, flanges and anchored clamps.
    ring(pipe,(-7,2.20,-8),.205,.145,axis='y',col=(.49,.44,.31))
    pipe_path(pipe,[(-7,2.2,-8),(-7,2.4,-8)],.144,(.08,.10,.10))
    for y in range(5,81,6):
        tube(pipe,(-9.24,y-.10,-8),(-9.24,y+.10,-8),.225,pipe_col,16)
        box(pipe,(-9.46,y,-8),(.13,.30,.50),(.29,.31,.27))
        for zz in [-8.23,-7.77]:tube(pipe,(-9.55,y,zz),(-9.27,y,zz),.035,(.56,.48,.30),8)
    for y in [2.48,3.72]:tube(pipe,(-7,y-.035,-8),(-7,y+.035,-8),.23,pipe_col,20)
    pipe.finish()
    # Outlet jet and splash sprites are authored here; shaders animate in place.
    jet=Mesh('OutletStream','Stream')
    for i in range(18):
        y0=.045+i*2.155/18;y1=.045+(i+1)*2.155/18
        r0=.046+.027*(y0/2.2);r1=.046+.027*(y1/2.2)
        for j in range(10):
            a=j*math.tau/10;b=(j+1)*math.tau/10
            oriented(jet,[(-7+r0*math.cos(a),y0,-8+r0*math.sin(a)),(-7+r0*math.cos(b),y0,-8+r0*math.sin(b)),(-7+r1*math.cos(b),y1,-8+r1*math.sin(b)),(-7+r1*math.cos(a),y1,-8+r1*math.sin(a))],(math.cos(a),0,math.sin(a)),(.5,.6,.6))
    jet.finish()
    spray=Mesh('OutletSplash','Splash')
    for i in range(72):
        a=i*2.39996;r=.07+(i%9)*.048;x=-7+math.cos(a)*r;z=-8+math.sin(a)*r;y=.04+(i%7)*.025
        spray.face([(x-.017,y,z),(x+.017,y,z),(x+.017,y+.038,z),(x-.017,y+.038,z)])
    spray.finish()
    drops=Mesh('FallingDrops','Drip')
    for x,z in [(3.5,-23),(-3.1,-41),(30,-80)]:
        span=84.
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
for kind in ['Dark','Mint','NeonPink','NeonCyan','TubeLight','Glass','Car','Headlamp','Rain','Water','Daylight','Drip','Dust','Stream','Splash','Fabric','DoorGlass']:material(kind)
laundry();reservoir()
audio('laundry_rumble','laundry');audio('reservoir_drips','reservoir')
print('INTERIORS_READY: two editable Blender scenes, batched GLBs, original texture studies and ambience')
