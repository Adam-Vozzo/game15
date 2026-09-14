"""La Burrasca: original Calabrian storm village. Godot axes throughout.
Blender --background --python blender/build_roccella.py regenerates all sources.
"""
import bpy, math, random, json, wave, struct
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
random.seed(91326)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def hillside(x,z):
    return max(-18,21+(z-12)*.31+17*math.exp(-((x+30)/22)**2-((z+26)/30)**2))

footings=[];walk=[];guards=[];obstacles=[]
def footing(x0,x1,z0,z1,y,paved=False):
    footings.append(dict(x0=x0,x1=x1,z0=z0,z1=z1,y=y,paved=paved))
def terrace(x0,x1,z0,z1,y):
    footing(x0,x1,z0,z1,y,True)
    walk.append(dict(x0=x0,x1=x1,z0=z0,z1=z1,y=y))
def terrain(x,z):
    y=hillside(x,z)
    for f in footings:
        dx=max(f['x0']-x,0,x-f['x1']);dz=max(f['z0']-z,0,z-f['z1'])
        distance=max(dx,dz)
        # The 3m cut margin exceeds the 2m mesh diagonal, preventing an
        # interpolated terrain triangle from poking through a built footprint.
        if distance<7:
            blend=max(0,min(1,(distance-3)/4));blend=blend*blend*(3-2*blend)
            y=min(y,(f['y']-.5)*(1-blend)+hillside(x,z)*blend)
    return y

mats={}
for kind,base in {'Stucco':(.70,.65,.53),'Rose':(.59,.39,.32),'Ochre':(.66,.50,.30),'Stone':(.44,.46,.42),'Rock':(.30,.33,.29),'Tile':(.39,.20,.14),'Paving':(.34,.36,.34),'Wood':(.16,.23,.21),'Iron':(.13,.16,.17),'Dark':(.065,.075,.075),'Light':(1,.57,.20),'Sea':(.16,.24,.27),'Rain':(.6,.7,.8)}.items():
    mat=bpy.data.materials.new('Roccella'+kind);mat.diffuse_color=(*base,1);mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*base,1)
    if kind not in ['Light','Rain','Sea','Dark','Iron']:
        pixels=[]
        for y in range(256):
            for x in range(256):
                n=random.uniform(-.016,.016)+.012*math.sin(x*.083+math.sin(y*.07))
                if kind in ['Stone','Paving']:
                    row=y//32;edge=(y%32<2 or (x+row%2*32)%64<2)
                    n+=-.12 if edge else .022*math.sin(row*17+(x+row%2*32)//64*11)
                if kind=='Tile':n+=-.075 if x%21<3 or y%64<3 else .045*math.sin(x%21/21*math.pi)
                if kind=='Wood':n+=.025*math.sin(x*.48+math.sin(y*.04))
                if kind=='Rock':n+=.045*math.sin(x*.041+math.sin(y*.067)*2)+.025*math.sin(y*.13+x*.077)
                if kind in ['Stucco','Rose','Ochre'] and random.random()<.018:n-=random.uniform(.05,.14)
                pixels.extend([max(0,round((c+n)*31)/31) for c in base]+[1])
        im=bpy.data.images.new('Roccella'+kind,width=256,height=256);im.pixels=pixels
        im.filepath_raw=str(ROOT/'assets/textures'/('Roccella'+kind+'.png'));im.file_format='PNG';im.save()
        tx=mat.node_tree.nodes.new('ShaderNodeTexImage');tx.image=im;mat.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
    mats[kind]=mat

class Batch:
    def __init__(self,name,kind):self.name=name;self.kind=kind;self.v=[];self.f=[];self.uv=[]
    def face(self,points,uv=None):
        at=len(self.v);self.v.extend(points);self.f.append(tuple(range(at,at+len(points))))
        if uv is None:
            a=Vector(points[1])-Vector(points[0]);b=Vector(points[-1])-Vector(points[0]);u=a.length;v=b.length
            uv=[(0,0),(u/2,0),(u/2,v/2),(0,v/2)][:len(points)]
        self.uv.extend(uv)
    def finish(self):
        if not self.v:return
        me=bpy.data.meshes.new(self.name);me.from_pydata([(p[0],-p[2],p[1]) for p in self.v],[],self.f);me.update()
        ob=bpy.data.objects.new(self.name,me);bpy.context.collection.objects.link(ob);me.materials.append(mats[self.kind])
        uv=me.uv_layers.new(name='MasonryUV')
        for poly in me.polygons:
            for li in poly.loop_indices:uv.data[li].uv=self.uv[me.loops[li].vertex_index]
        return ob

active={}
def group(name):
    global active
    for b in active.values():b.finish()
    active={k:Batch(name+' '+k,k) for k in mats}
def box(k,c,s):
    x,y,z=c;a,b,d=[v/2 for v in s]
    p=[(x-a,y-b,z-d),(x+a,y-b,z-d),(x+a,y+b,z-d),(x-a,y+b,z-d),(x-a,y-b,z+d),(x+a,y-b,z+d),(x+a,y+b,z+d),(x-a,y+b,z+d)]
    for face in [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(3,7,6,2),(0,1,5,4)]:active[k].face([p[i] for i in face])
def rod(k,a,b,r=.035,sides=6):
    a=Vector(a);b=Vector(b);d=(b-a).normalized();axis=d.cross(Vector((0,0,1)))
    if axis.length<.01:axis=d.cross(Vector((1,0,0)))
    axis.normalize();other=d.cross(axis)
    rings=[[p+r*(axis*math.cos(i*math.tau/sides)+other*math.sin(i*math.tau/sides)) for i in range(sides)] for p in [a,b]]
    for i in range(sides):j=(i+1)%sides;active[k].face([rings[0][i],rings[0][j],rings[1][j],rings[1][i]])
    active[k].face(list(reversed(rings[0])),[(0,0)]*sides);active[k].face(rings[1],[(0,0)]*sides)
def arch(k,x,y,z,w,h,depth=.16):
    # Voussoir ring rests on two jambs; opening beneath remains genuinely empty.
    r=w/2;spring=y+h-r
    box(k,(x-r-.12,(y+spring)/2,z),(.24,spring-y,depth));box(k,(x+r+.12,(y+spring)/2,z),(.24,spring-y,depth))
    for i in range(12):
        a=i*math.pi/12;b=(i+1)*math.pi/12
        pts=[(x+rr*math.cos(t),spring+rr*math.sin(t),zz) for zz in [z-depth/2,z+depth/2] for rr,t in [(r,a),(r,b),(r+.24,b),(r+.24,a)]]
        for f in [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]:active[k].face([pts[j] for j in f])

buildings=[];lamps=[]
def house(name,x,z,w,d,h,kind='Stucco',base=None,detail=True):
    group(name);base=hillside(x,z) if base is None else base
    # A level apron meets the door; its retaining walls are generated only
    # after every terrain cut is known, so neighbouring cuts cannot expose gaps.
    footing(x-w/2-1.2,x+w/2+1.2,z-d/2-1.2,z+d/2+1.8,base,True)
    box(kind,(x,base+h/2,z),(w,h,d));buildings.append(dict(x=x,z=z,w=w,d=d,base=base,height=h))
    for yy in [.50,h-.25,h]:box('Stone',(x,base+yy,z),(w+.26,.16,d+.26))
    ridge=base+h+1.35
    flat=(not detail and int(abs(x)*3)%4==0)
    if flat:
        box('Paving',(x,base+h+.04,z),(w,.12,d))
        for s in [-1,1]:
            box(kind,(x+s*(w/2-.12),base+h+.5,z),(.24,1,d))
            box(kind,(x,base+h+.5,z+s*(d/2-.12)),(w,1,.24))
        box('Ochre',(x-w*.18,base+h+1,z+d*.15),(w*.40,2,d*.38))
    else:
        for side in [-1,1]:
            active['Tile'].face([(x, ridge,z-d/2-.32),(x+side*(w/2+.35),base+h+.12,z-d/2-.32),(x+side*(w/2+.35),base+h+.12,z+d/2+.32),(x,ridge,z+d/2+.32)])
        for zz in [z-d/2,z+d/2]:active[kind].face([(x-w/2,base+h,zz),(x+w/2,base+h,zz),(x,ridge,zz)])
        rod('Tile',(x,ridge+.07,z-d/2-.4),(x,ridge+.07,z+d/2+.4),.13)
    # Modeled coppi ends, courses at close range, capped chimney and gutters.
    if detail:
        for side in [-1,1]:
            for j in range(int(d/.30)+1):
                zz=z-d/2+j*.30
                rod('Tile',(x+side*.10,ridge+.055,zz),(x+side*(w/2+.35),base+h+.18,zz),.065,5)
            rod('Iron',(x+side*(w/2+.35),base+h+.02,z-d/2-.4),(x+side*(w/2+.35),base+h+.02,z+d/2+.4),.085)
        xx=x+w*.3;zz=z-d*.22
        box(kind,(xx,ridge+.35,zz),(.62,1.8,.65));box('Stone',(xx,ridge+1.2,zz),(.85,.18,.87))
        rod('Iron',(x+w/2+.16,base+.2,z+d/2),(x+w/2+.16,base+h,z+d/2),.065)
    # Windows on all four elevations, with reveals, lintels, sills and louvres.
    for side in range(4):
        across=w if side<2 else d
        count=max(2,int(across/2.7));floors=max(1,int(h/2.9))
        for floor in range(floors):
            for j in range(count):
                u=-across/2+across*(j+.5)/count;yy=base+1.55+floor*2.75
                # Work in facade-local coordinates then rotate the new vertices.
                before={k:len(b.v) for k,b in active.items()}
                warm=(floor+j+int(abs(x)+abs(z))+side)%9==0
                box('Stone',(u,yy,0),(1.35,1.92,.16));box('Light' if warm else 'Dark',(u,yy,.09),(1.02,1.58,.045))
                box('Stone',(u,yy-.93,.12),(1.55,.16,.40));box('Stone',(u,yy+.97,.05),(1.50,.13,.27))
                box('Wood',(u,yy,.14),(.055,1.6,.06));box('Wood',(u,yy,.14),(1.05,.055,.06))
                for s in [-1,1]:
                    sx=u+s*.87
                    box('Wood',(sx,yy,.13),(.52,1.72,.11))
                    if detail:
                        for slat in range(9):box('Wood',(sx,yy-.71+slat*.17,.20),(.47,.055,.075))
                if detail and floor==1 and j==count//2:
                    box('Stone',(u,yy-1.08,.56),(2.02,.19,1.22))
                    for s in [-1,1]:rod('Iron',(u+s*.71,yy-1.65,.02),(u+s*.71,yy-1.15,1.02),.055)
                    for q in range(10):rod('Iron',(u-.92+q*.205,yy-1.,1.12),(u-.92+q*.205,yy-.05,1.12),.023)
                    rod('Iron',(u-1,yy-.04,1.12),(u+1,yy-.04,1.12),.04)
                    for s in [-1,1]:
                        rod('Iron',(u+s*.99,yy-.04,.02),(u+s*.99,yy-.04,1.12),.04)
                        rod('Iron',(u+s*.99,yy-1,.6),(u+s*.99,yy-.04,.6),.024)
                def transform(p):
                    a,b,c=p
                    return [(x+a,b,z+d/2+c),(x-a,b,z-d/2-c),(x+w/2+c,b,z-a),(x-w/2-c,b,z+a)][side]
                for k,b in active.items():
                    b.v[before[k]:]=[transform(p) for p in b.v[before[k]:]]
    # Street portal and brass knob; masonry ring frames the timber leaf.
    front=z+d/2+.11
    box('Wood',(x,base+1.12,front),(1.35,2.24,.10));arch('Stone',x,base,front+.07,1.5,2.7)
    for dx in [-.37,.37]:box('Wood',(x+dx,base+1.1,front+.08),(.55,1.8,.08))
    if detail:
        rod('Iron',(x+.44,base+1.05,front+.15),(x+.44,base+1.05,front+.24),.07)
        lx=x-w/2+.6;ly=base+2.9;lz=front+.50
        rod('Iron',(lx,ly+.35,front),(lx,ly+.35,lz),.045)
        box('Iron',(lx,ly,lz),(.34,.62,.30));box('Light',(lx,ly,lz+.16),(.23,.39,.02))
        box('Iron',(lx,ly+.36,lz),(.48,.12,.44));lamps.append([lx,ly,lz+.20])

# Broad urban landings alternate with short flights; one shared surface list
# drives the masonry, boundary guards and the exported walking height map.
group('Piazzas and connected stairs')
terrace(-5.5,5.5,12,24,24)
piazzas=[]
for flight in range(7):
    top=12-flight*9.6
    for i in range(9):
        terrace(-2.7,2.7,top-(i+1)*.4,top-i*.4,24-(flight*9+i+1)*.22)
    y=24-(flight+1)*1.98;z1=top-3.6;z0=z1-6
    width=[11,9,12,9,11,10,14][flight]
    terrace(-width,width,z0,z1,y)
    piazzas.append(dict(x0=-width,x1=width,z0=z0,z1=z1,y=y))
bottom_y=piazzas[-1]['y']
for i in range(60):
    terrace(5.5+i*17.5/60,5.5+(i+1)*17.5/60,20,23,24+(i+1)*.2)
terrace(23,31,17,26,36)
for xx in [25.4,27.6]:box('Stone',(xx,36.33,24.7),(.34,.66,.72))
box('Wood',(26.5,36.73,24.7),(3.1,.16,.75))
obstacles.append([24.7,28.3,24.15,25.25])
rod('Tile',(29.7,36.05,24.8),(29.7,36.75,24.8),.43,10)
obstacles.append([29.04,30.36,24.14,25.46])
# Small civic details sit against the outer edges, leaving the centre open.
for i,p in enumerate(piazzas):
    y=p['y'];z=(p['z0']+p['z1'])/2;x=p['x0']+1.4
    if i in [0,2,4]:
        box('Stone',(x,y+.36,z),(1.25,.72,1.8))
        box('Dark',(x,y+.73,z),(.94,.02,1.46))
        box('Stone',(x-.42,y+1.0,z),(.34,2,1.8))
        rod('Iron',(x-.2,y+1.32,z),(x+.25,y+1.32,z),.065)
        obstacles.append([x-.9,x+.9,z-1.15,z+1.15])
    else:
        for zz in [-.85,.85]:box('Stone',(x,y+.3,z+zz),(.65,.6,.3))
        box('Wood',(x,y+.67,z),(.72,.14,2.6))
        obstacles.append([x-.65,x+.65,z-1.55,z+1.55])
    # Border courses and a recessed drainage grate make the landing a place.
    for j in range(15):box('Iron',(p['x1']-.6,y+.009,p['z0']+.7+j*.27),(.38,.018,.045))
    for zz in [p['z0']+.45,p['z1']-.45]:
        for a,b in [(p['x0']+.5,-3.1),(3.1,p['x1']-.5)]:box('Stone',((a+b)/2,y+.006,zz),(b-a,.012,.18))
house('Casa del belvedere',-10.4,17,6.2,8,8.5,'Ochre',24,True)
house('Casa persiane verdi',11,13,6.1,8,10,'Stucco',22.02,True)
house('Palazzo rosa',-18,-5,7.7,10,9.5,'Rose',20.04,True)
house('Casa marina',17.5,-12,6.5,8,8,'Stucco',18.06,True)
house('Casa vicolo',-16,-32,6.3,8,7.6,'Ochre',14.10,True)
house('Casa archi',16,-36,7.4,8,10,'Rose',12.12,True)

# Church on its own defensible outcrop: nave, pediment, pilasters, oculus,
# open arched campanile and connected buttresses, based on regional vocabulary.
group('San Nicola hilltop church');cx=-37;cz=-24;cy=hillside(cx,cz)+1
footing(cx-10,cx+11,cz-13,cz+18,cy,True)
box('Stucco',(cx,cy+5,cz),(12,10,20))
for s in [-1,1]:
    active['Tile'].face([(cx,cy+13,cz-10.5),(cx+s*6.6,cy+10,cz-10.5),(cx+s*6.6,cy+10,cz+10.5),(cx,cy+13,cz+10.5)])
    active['Stucco'].face([(cx-6,cy+10,cz+s*10),(cx+6,cy+10,cz+s*10),(cx,cy+13,cz+s*10)])
    for zz in [-7,0,7]:box('Stone',(cx+s*6.3,cy+3,cz+zz),(1,6,1.15))
front=cz+10.08
for dx in [-5.3,-2.8,2.8,5.3]:
    box('Stone',(cx+dx,cy+4.8,front),(.42,9.6,.35));box('Stone',(cx+dx,cy+9.45,front),(.75,.38,.52))
box('Stone',(cx,cy+9.8,front),(12.7,.32,.65))
box('Wood',(cx,cy+2,front+.19),(2.7,4,.18));arch('Stone',cx,cy,front+.30,3.0,4.7,.28)
for i in range(24):
    a=i*math.tau/24;b=(i+1)*math.tau/24
    rod('Stone',(cx+math.cos(a)*.85,cy+7.5+math.sin(a)*.85,front+.24),(cx+math.cos(b)*.85,cy+7.5+math.sin(b)*.85,front+.24),.12)
box('Dark',(cx,cy+7.5,front+.02),(1.18,1.18,.04))
rod('Iron',(cx,cy+13,front),(cx,cy+14.6,front),.07);rod('Iron',(cx-.45,cy+14.1,front),(cx+.45,cy+14.1,front),.065)
tx=cx+8.3;tz=cz+5
box('Stone',(tx,cy+6,tz),(4.3,12,4.3))
for sx in [-1,1]:
    for sz in [-1,1]:box('Stone',(tx+sx*1.8,cy+14.1,tz+sz*1.8),(.7,4.2,.7))
for zz in [-2,2]:arch('Stone',tx,cy+12,tz+zz,2.9,4.2,.5)
box('Stone',(tx,cy+16.4,tz),(4.9,.5,4.9));box('Tile',(tx,cy+16.9,tz),(4.6,.5,4.6))
rod('Wood',(tx-1.8,cy+15,tz),(tx+1.8,cy+15,tz),.14)
rod('Iron',(tx,cy+13.1,tz),(tx,cy+15,tz),.35,10)
box('Stone',(tx,cy+17.3,tz),(3.4,.3,3.4))
rod('Iron',(tx,cy+17.4,tz),(tx,cy+19,tz),.07)

# Unequal roof levels and offset blocks follow the actual slope, with gaps for lanes.
for row,z in enumerate([-74,-93,-113,-134,-157]):
    for col in range(12):
        x=-99+col*18+random.uniform(-1,1);zz=z+random.uniform(-2,2)
        house('Borgo %02d %02d'%(row,col),x,zz,random.uniform(7,11),random.uniform(7,12),random.choice([6,8.5,11,13]),random.choice(['Stucco','Stucco','Rose','Ochre']),detail=row<2)
for i,(x,z) in enumerate([(-51,1),(-47,22),(-62,-25),(30,6),(30,-19),(48,-37),(52,16),(-70,-48),(71,-23)]):
    house('Upper hillside %02d'%i,x,z,9,10,random.choice([7,10,13]),detail=True)

# Only outside edges receive guards. Split edges at neighbouring rectangles,
# including stair mouths, so no invisible boundary or rail blocks a connection.
group('Continuous parapets')
for r in walk:
    for axis,at,lo,hi,sign in [('x',r['x0'],r['z0'],r['z1'],-1),('x',r['x1'],r['z0'],r['z1'],1),('z',r['z0'],r['x0'],r['x1'],-1),('z',r['z1'],r['x0'],r['x1'],1)]:
        other='z' if axis=='x' else 'x'
        splits=sorted(set([lo,hi]+[v for q in walk for v in [q[other+'0'],q[other+'1']] if lo<v<hi]))
        for a,b in zip(splits,splits[1:]):
            m=(a+b)/2;x,z=(at+sign*.01,m) if axis=='x' else (m,at+sign*.01)
            if any(q['x0']-.0001<=x<=q['x1']+.0001 and q['z0']-.0001<=z<=q['z1']+.0001 and abs(q['y']-r['y'])<.221 for q in walk):continue
            if b-a<.001:continue
            y=r['y'];p0=[at,a] if axis=='x' else [a,at];p1=[at,b] if axis=='x' else [b,at]
            guards.append(dict(a=p0,b=p1,y=y))
            xx,zz=(at,m) if axis=='x' else (m,at)
            size=(.26,.48,b-a) if axis=='x' else (b-a,.48,.26)
            box('Stone',(xx,y+.20,zz),size)
            count=max(1,math.ceil((b-a)/1.25))
            for j in range(count+1):
                t=a+(b-a)*j/count;xx,zz=(at,t) if axis=='x' else (t,at)
                rod('Iron',(xx,y+.40,zz),(xx,y+1.10,zz),.035)
            rod('Iron',(p0[0],y+1.10,p0[1]),(p1[0],y+1.10,p1[1]),.045)
            rod('Iron',(p0[0],y+.72,p0[1]),(p1[0],y+.72,p1[1]),.022)

group('Cut limestone hillside')
for ix in range(155):
    for iz in range(165):
        x=-155+ix*2;z=-205+iz*2
        points=[(x,terrain(x,z),z),(x,terrain(x,z+2),z+2),(x+2,terrain(x+2,z+2),z+2),(x+2,terrain(x+2,z),z)]
        active['Rock'].face(points,[(p[0]/11,p[2]/11) for p in points])

group('Grounded masonry and level building aprons')
for f in footings:
    x0,x1,z0,z1,y=[f[k] for k in ['x0','x1','z0','z1','y']]
    samples=[terrain(x,z) for x in [x0,x1,(x0+x1)/2] for z in [z0,z1,(z0+z1)/2]]
    # Adjacent cut floors can be lower than the original hill by many metres.
    samples += [q['y']-.5 for q in footings if q['x0']-7<x1 and q['x1']+7>x0 and q['z0']-7<z1 and q['z1']+7>z0]
    bottom=min(samples+[y-1])-1
    f['bottom']=bottom
    box('Stone',((x0+x1)/2,(bottom+y)/2,(z0+z1)/2),(x1-x0,y-bottom,z1-z0))
    if f['paved']:box('Paving',((x0+x1)/2,y-.06,(z0+z1)/2),(x1-x0,.12,z1-z0))

group('Coast and rain anchors')
active['Sea'].face([(-550,-18.2,-145),(-550,-18.2,-700),(550,-18.2,-700),(550,-18.2,-145)])
for i in range(24000):
    x=random.uniform(-130,130) if i<15000 else random.uniform(-24,24)
    z=random.uniform(-170,40) if i<15000 else random.uniform(-55,28)
    y=random.uniform(0,1)
    # Degenerate source quads are expanded around fixed anchors by rain shader.
    p=(x,y,z);active['Rain'].face([p,p,p,p],[(0,0),(1,0),(1,1),(0,1)])
group('Finished')
layout=dict(buildings=buildings,lamps=lamps[:24],walk=walk,guards=guards,obstacles=obstacles,footings=footings,piazzas=piazzas,bottom_y=bottom_y,church=[cx,cy,cz])
(ROOT/'assets/data/roccella_layout.json').write_text(json.dumps(layout,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/roccella.blend'))
for kind in mats:
    bpy.ops.object.select_all(action='DESELECT')
    obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==mats[kind]]
    for o in obs:o.select_set(True)
    if obs:
        bpy.context.view_layer.objects.active=obs[0]
        if len(obs)>1:bpy.ops.object.join()
        obs[0].name='Roccella'+kind
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/roccella.glb'),export_format='GLB',export_image_format='NONE')

# Original storm recordings synthesized from filtered stereo noise. Thunder is
# separate so runtime delays it from the corresponding light flash.
def sound(name,seconds,thunder=False):
    rng=random.Random(411 if thunder else 731);rate=22050;buf=bytearray();low=[0.,0.];slow=[0.,0.]
    for i in range(int(rate*seconds)):
        t=i/rate
        for ch in range(2):
            n=rng.uniform(-1,1);low[ch]=low[ch]*.94+n*.06;slow[ch]=slow[ch]*.997+n*.003
            if thunder:
                env=min(1,t*4)*math.exp(-t*.65)*(1+.24*math.sin(t*7))
                v=(low[ch]*2.0+slow[ch]*5+math.sin(t*43)*.08)*env
            else:v=(n*.24+low[ch]*.55+slow[ch]*1.8)*(.83+.10*math.sin(t*math.tau/seconds)+.06*math.sin(t*math.tau*3/seconds))
            buf.extend(struct.pack('<h',int(max(-.95,min(.95,v))*26000)))
    with wave.open(str(ROOT/'assets/audio'/name),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(rate);f.writeframes(buf)
sound('roccella_rain.wav',16);sound('roccella_thunder.wav',7,True)
print('ROCCELLA_READY',len(buildings),'complete buildings, 63 stair treads, seven piazzas, church and 24000 rain anchors')
