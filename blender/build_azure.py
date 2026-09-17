"""Azure Pilgrimage — editable, fully three-dimensional ink-and-colour world.

Reference: the user's supplied Moebius bird / waterfall illustration. Coordinates
below use Godot's Y-up convention; the GLB and .blend are regenerated together.
"""
import bpy, bmesh, math, random, json, wave, struct, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from azure_water_geometry import lip, UPPER_LIP, UPPER_ARC, UPPER_BOUNDARY, upper_sample, upper_distance, water_level
R = random.Random(180926)
TAU = math.tau
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
MATS = {}
for name in ['Colour', 'Ink', 'Water', 'Falls', 'Foam', 'Bird', 'BirdInk', 'Rim']:
    mat = bpy.data.materials.new('Azure' + name)
    mat.diffuse_color = (.8, .75, .7, 1)
    MATS[name] = mat
INK = (.24, .27, .34, 1)
ROSE = (.88, .60, .55, 1)
LILAC = (.66, .64, .77, 1)
PEACH = (.90, .70, .59, 1)
WHITE = (.985, .987, .965, 1)
objects = []

class Batch:
    def __init__(self, name, kind='Colour'):
        self.name, self.kind = name, kind
        self.v, self.f, self.c, self.uv = [], [], [], []
    def face(self, pts, col, uv=None):
        n = len(self.v)
        self.v.extend(pts); self.f.append(tuple(range(n, n+len(pts))))
        self.c.extend([col] * len(pts))
        self.uv.extend(uv or [(0, 0)] * len(pts))
    def finish(self, parent=None, origin=(0, 0, 0)):
        if not self.v: return None
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([(p[0], -p[2], p[1]) for p in self.v], [], self.f)
        mesh.update()
        ob = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(ob)
        mesh.materials.append(MATS[self.kind])
        col = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
        for i, c in enumerate(self.c): col.data[i].color = c
        uv = mesh.uv_layers.new(name='SurfaceUV')
        for poly in mesh.polygons:
            poly.use_smooth = self.kind in ['Colour','Bird','Foam']
            for li in poly.loop_indices: uv.data[li].uv = self.uv[mesh.loops[li].vertex_index]
        bm = bmesh.new(); bm.from_mesh(mesh)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.00005)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(mesh); bm.free(); mesh.update()
        ob.parent = parent
        ob.location = (origin[0], -origin[2], origin[1])
        objects.append(ob)
        return ob

def empty(name, pos=(0,0,0), parent=None):
    ob=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(ob)
    ob.location=(pos[0],-pos[2],pos[1]);ob.parent=parent
    return ob

def stroke(b, pts, radius=.035, col=INK, sides=3):
    ps=[Vector(p) for p in pts]
    if len(ps)<2:return
    rings=[]
    for i,p in enumerate(ps):
        d=(ps[min(i+1,len(ps)-1)]-ps[max(i-1,0)]).normalized()
        a=d.cross(Vector((0,1,0)))
        if a.length<.01:a=d.cross(Vector((1,0,0)))
        a.normalize(); bb=d.cross(a)
        rings.append([p+radius*(math.cos(j*TAU/sides)*a+math.sin(j*TAU/sides)*bb) for j in range(sides)])
    for i in range(len(ps)-1):
        for j in range(sides):b.face([rings[i][j],rings[i][(j+1)%sides],rings[i+1][(j+1)%sides],rings[i+1][j]],col)

def box(b, p, s, col, ink=None):
    x,y,z=p;w,h,d=s
    ps=[(x+sx*w/2,y+sy*h/2,z+sz*d/2) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,-1,1),(-1,-1,1),(-1,1,-1),(1,1,-1),(1,1,1),(-1,1,1)]]
    for f in [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:b.face([ps[i] for i in f],col)
    if ink:
        for a,c in [(0,1),(1,2),(2,3),(3,0),(4,5),(5,6),(6,7),(7,4),(0,4),(1,5),(2,6),(3,7)]:stroke(ink,[ps[a],ps[c]],.025)

def oval(b, p, s, col, n=24, m=14):
    rings=[]
    for j in range(m+1):
        t=math.pi*j/m
        rings.append([(p[0]+s[0]*math.sin(t)*math.cos(i*TAU/n),p[1]+s[1]*math.cos(t),p[2]+s[2]*math.sin(t)*math.sin(i*TAU/n)) for i in range(n)])
    for j in range(m):
        for i in range(n):b.face([rings[j][i],rings[j][(i+1)%n],rings[j+1][(i+1)%n],rings[j+1][i]],col)

def tube(b, points, widths, col, sides=16, ink=None):
    ps=[Vector(p) for p in points];rings=[]
    for i,p in enumerate(ps):
        d=(ps[min(i+1,len(ps)-1)]-ps[max(i-1,0)]).normalized()
        a=d.cross(Vector((0,1,0)))
        if a.length<.01:a=d.cross(Vector((0,0,1)))
        a.normalize();bb=d.cross(a)
        w=widths[i] if isinstance(widths[i],tuple) else (widths[i],widths[i])
        rings.append([p+a*math.cos(k*TAU/sides)*w[0]+bb*math.sin(k*TAU/sides)*w[1] for k in range(sides)])
    for i in range(len(ps)-1):
        for k in range(sides):b.face([rings[i][k],rings[i][(k+1)%sides],rings[i+1][(k+1)%sides],rings[i+1][k]],col)
    b.face(list(reversed(rings[0])),col);b.face(rings[-1],col)

# Each mountain is a closed, rounded fluted mass. Pen marks sample the very
# same surface equation, so they stay attached on the reverse and underside.
def rock(name,x,z,base,w,d,h,col,seed):
    rand=random.Random(seed); b=Batch(name);ink=Batch(name+'_pen','Ink')
    phase=rand.uniform(0,TAU); lean=rand.uniform(-.14,.14)
    def surface(a,t,off=0):
        cap=math.sqrt(max(0,1-((max(t,.69)-.69)/.315)**2)) if t>.69 else 1
        radius=(1-.16*t+.035*math.sin(t*11+phase))*cap*(1+.14*math.sin(a*5+phase)+.05*math.sin(a*9-phase))
        rr=radius+.021*math.sin(a*15+phase)*(1-.4*t)
        return Vector((x+(w*rr+off)*math.cos(a)+lean*w*t*t,base+h*t,z+(d*rr+off)*math.sin(a)))
    distant=name.startswith(('Far','Canyon'))
    n=32 if distant else 48;m=20 if distant else 26
    for j in range(m):
        for i in range(n):
            a=i*TAU/n;aa=(i+1)*TAU/n;t=j/m;tt=(j+1)/m
            c=tuple(min(1,v*(.96+.04*math.sin(a+1))) for v in col[:3])+(1,)
            b.face([surface(a,t),surface(aa,t),surface(aa,tt),surface(a,tt)],c)
    b.face([surface(i*TAU/n,0) for i in reversed(range(n))],col)
    b.face([surface(i*TAU/n,1) for i in range(n)],col)
    # Long, imperfect fissures, interrupted cross-strata and sparse hatch scars.
    for i in range(19):
        a=i*TAU/19+rand.uniform(-.055,.055);start=rand.uniform(.01,.22);end=rand.uniform(.68,.98)
        ps=[surface(a+.012*math.sin(t*21+i)+.009*math.sin(t*49+i*3),t,.055) for t in [start+(end-start)*k/20 for k in range(21)]]
        stroke(ink,ps,.062 if w<15 else .085,tuple(v+.08 for v in INK[:3])+(1,))
    for k in range(int(h*(.70 if distant else 1.5))):
        a=rand.uniform(0,TAU);t=rand.uniform(.02,.94);length=rand.uniform(.008,.035)
        if k%4==0:
            ps=[surface(a+q*.025,t+q*.008,.065) for q in [-1,0,.5,1]]
        else:ps=[surface(a+q*.012,t+q*length,.06) for q in [0,.35,.7,1]]
        stroke(ink,ps,.045,(.42,.40,.48,1))
    # Sample the actual vertical mesh rings at each water plane. Foam follows
    # each lobe; opaque overlapping rocks hide the internal parts of the rims.
    for level in [-35,18,42]:
        if not base < level < base+h:continue
        t=(level-base)/h;j=min(m-1,int(t*m));f=t*m-j
        section=[surface(i*TAU/n,j/m).lerp(surface(i*TAU/n,(j+1)/m),f) for i in range(n)]
        arc=0.
        for i,p in enumerate(section):
            q=section[(i+1)%n];length=(q-p).length
            mid=(p+q)*.5
            outward=Vector((mid.x-x,0,mid.z-z)).normalized()
            if water_level(mid.x+outward.x,mid.z+outward.z)!=level:
                arc+=length;continue
            band=[]
            for point in [p,q]:
                radial=Vector((point.x-x,0,point.z-z)).normalized()
                for width in [-.55,2.8]:
                    v=point+radial*width;v.y=level+.055;band.append(v)
            shoreline.face([band[0],band[2],band[3],band[1]],(.82,.93,.86,1),[(arc,0),(arc+length,0),(arc+length,1),(arc,1)])
            arc+=length
    b.finish();ink.finish()
    return surface

rocks=[]
def cluster(name,x,z,base,w,d,h,col,seed,lobes=5):
    rand=random.Random(seed)
    surface=rock(name,x,z,base,w,d,h,col,seed)
    rocks.append(dict(x=x,z=z,base=base,width=w,depth=d,height=h))
    for i in range(lobes):
        a=i*TAU/lobes+rand.uniform(-.3,.3); f=rand.uniform(.34,.62)
        rock(name+'_buttress_%d'%i,x+math.cos(a)*w*.70,z+math.sin(a)*d*.70,base,w*f,d*f,h*rand.uniform(.4,.83),col,seed+80+i)
    return surface

# Water levels meet both cascade lips exactly; the lower sea surrounds the
# foreground rocks. The upper shelf has physical bedrock below the curtain.
water=Batch('Upper turquoise basin','Water');fall=Batch('Main curved waterfall','Falls');bed=Batch('Waterfall limestone core')
for i in range(180):
    x=-225+i*2.5;xx=x+2.5
    water.face([(x,18,-260),(xx,18,-260),(xx,18,lip(xx)),(x,18,lip(x))],(.24,.71,.75,1))
    rings=[]
    for j in range(27):
        t=j/26
        y=18-53*t;bulge=2.8*math.sin(min(t*5,1)*math.pi/2)
        rings.append([(a,y,lip(a)+bulge) for a in [x,xx]])
    for j in range(26):
        t=j/26;tt=(j+1)/26
        fall.face([rings[j][0],rings[j][1],rings[j+1][1],rings[j+1][0]],(.26,.65,.66,1),[(x,t),(xx,t),(xx,tt),(x,tt)])
    bed.face([(x,17.9,lip(x)-.3),(xx,17.9,lip(xx)-.3),(xx,-42,lip(xx)-.3),(x,-42,lip(x)-.3)],(.53,.64,.66,1))
water.finish();fall.finish();bed.finish()
sea=Batch('Lower blue sea','Water')
sea.face([(-700,-35,-270),(700,-35,-270),(700,-35,650),(-700,-35,650)],(.08,.61,.76,1));sea.finish()
floor=Batch('Submerged canyon bed')
floor.face([(-700,-43,-270),(700,-43,-270),(700,-43,650),(-700,-43,650)],(.21,.48,.53,1));floor.finish()

# One continuous scalloped shoreline replaces the rectangular western shelf.
# Dense radial rings interpolate a physical distance-to-shore field in UV.x.
water=Batch('High western reservoir','Water');fall=Batch('Western high cascade','Falls')
center=(-197,-221)
for a,b in zip(UPPER_BOUNDARY,UPPER_BOUNDARY[1:]+UPPER_BOUNDARY[:1]):
    for j in range(24):
        points=[]
        for edge,t in [(a,j/24),(b,j/24),(b,(j+1)/24),(a,(j+1)/24)]:
            points.append((center[0]+(edge[0]-center[0])*t,42,center[1]+(edge[1]-center[1])*t))
        if j==0:points=points[1:]
        water.face(points,(.27,.73,.75,1),[(upper_distance((p[0],p[2])),0) for p in points])
water.finish()
for i,(a,b) in enumerate(zip(UPPER_LIP,UPPER_LIP[1:])):
    normals=[upper_sample(UPPER_ARC[k])[1] for k in [i,i+1]]
    for j in range(16):
        points=[];uv=[]
        for edge,n,t,u in [(a,normals[0],j/16,UPPER_ARC[i]),(b,normals[1],j/16,UPPER_ARC[i+1]),(b,normals[1],(j+1)/16,UPPER_ARC[i+1]),(a,normals[0],(j+1)/16,UPPER_ARC[i])]:
            bulge=2*math.sin(min(t*5,1)*math.pi/2)
            points.append((edge[0]+n[0]*bulge,42-24*t,edge[1]+n[1]*bulge));uv.append((u,t))
        fall.face(points,(.29,.69,.68,1),uv)
fall.finish()
core=Batch('High reservoir rounded bedrock')
boundary=[(p[0]-upper_sample(UPPER_ARC[i])[1][0]*.25,p[1]-upper_sample(UPPER_ARC[i])[1][1]*.25) if i<len(UPPER_LIP) else p for i,p in enumerate(UPPER_BOUNDARY)]
core.face([(x,41.8,z) for x,z in boundary],(.47,.64,.68,1))
core.face([(x,15,z) for x,z in reversed(boundary)],(.47,.64,.68,1))
for a,b in zip(boundary,boundary[1:]+boundary[:1]):
    core.face([(a[0],41.8,a[1]),(b[0],41.8,b[1]),(b[0],15,b[1]),(a[0],15,a[1])],(.47,.64,.68,1))
core.finish()
shoreline=Batch('Rock waterline foam','Rim')

# The canyon encloses the entire orbit, not just the initial postcard view.
for i in range(11):
    x=-230+i*44
    cluster('Far lilac escarpment %02d'%i,x,-224+R.uniform(-12,12),16,27,31,R.uniform(145,220),(.64,.68,.80,1),400+i,3)
for side in [-1,1]:
    for i in range(7):
        z=-165+i*57
        c=ROSE if side==1 else LILAC
        cluster('Canyon %d %d'%(side,i),side*R.uniform(205,231),z,-40,30,R.uniform(23,38),R.uniform(115,200),c,700+side*100+i,3)
for i in range(9):
    cluster('Far southern canyon %d'%i,-220+i*55,272+R.uniform(-10,10),-42,32,32,R.uniform(130,185),(.73,.66,.77,1),960+i,2)
citadel_surface=cluster('Pilgrim citadel',-34,-48,12,20,17,77,PEACH,123,7)
cluster('Eastern coral village',93,-105,13,35,24,22,ROSE,212,5)
cluster('Near rose needles',147,92,-40,27,29,111,ROSE,320,5)
cluster('Western lilac needles',-151,90,-40,23,30,130,LILAC,340,5)
cluster('Small harbour rock',109,-1,12,14,11,13,(.78,.62,.72,1),365,3)
cluster('Bridge stepping stone',20,-74,12,8,8,17,PEACH,384,3)
shoreline.finish()

# Connected churning volumes, not a necklace of independent oval objects.
# Each irregular billow shares its complete cross-section with its neighbours;
# the submerged underside and end caps close the mass from every viewpoint.
def foam_bank(name,length,sample,bottom,large):
    foam=Batch(name,'Foam');rings=[];segments=math.ceil(length/1.3);sides=24
    for i in range(segments+1):
        u=length*i/segments;p,n=sample(u)
        height=(7.2+2.4*math.sin(u*.117+.5)+1.3*math.sin(u*.371+1.2)+.55*math.sin(u*.83)) if large else (3.6+1.05*math.sin(u*.149+1.8)+.62*math.sin(u*.43)+.25*math.sin(u*.91))
        width=(12 if large else 8)+1.3*math.sin(u*.13)+.6*math.sin(u*.43+.4)
        ring=[]
        for j in range(sides):
            a=TAU*j/sides;s=math.sin(a)
            d=(2.35 if large else 1.6)+width*(.5-.5*math.cos(a))
            # Unequal overlapping crests merge into an unbroken low wash.
            y=bottom-.20+(height if s>=0 else .8)*s
            ring.append((p[0]+n[0]*d,y,p[1]+n[1]*d))
        rings.append(ring)
    for i in range(segments):
        for j in range(sides):
            k=(j+1)%sides
            foam.face([rings[i][j],rings[i+1][j],rings[i+1][k],rings[i][k]],(.78,.90,.85,1),[(length*i/segments,j/sides),(length*(i+1)/segments,j/sides),(length*(i+1)/segments,(j+1)/sides),(length*i/segments,(j+1)/sides)])
    foam.face(list(reversed(rings[0])),(.78,.90,.85,1));foam.face(rings[-1],(.78,.90,.85,1))
    foam.finish()

foam_bank('Main connected whitewater',450,lambda u:((-225+u,lip(-225+u)),(0,1)),-35,True)
foam_bank('Upper connected whitewater',UPPER_ARC[-1],upper_sample,18,False)
# Preserve the independent settlement-detail random sequence from the former
# foam generator; changing foam tessellation must not reshuffle the town.
for _ in range(756):R.random()

# Small, coherent architecture: inset openings on all walls, rimmed terraces,
# crenellated towers, tied awnings, grounded piles and a sagging rope bridge.
town=Batch('Waterside settlements');pen=Batch('Settlement fine pen','Ink')
def house(x,y,z,w,d,h,col,roof=True):
    # Foundations penetrate the island core beneath each level terrace.
    base=16 if y<45 else y-12
    box(town,(x,(base+y)/2,z),(w+.24,y-base,d+.24),col,pen)
    box(town,(x,y+h/2,z),(w,h,d),col,pen)
    box(town,(x,y+h+.08,z),(w+.32,.20,d+.32),(.83,.58,.52,1),pen)
    for side in [-1,1]:
        for xx in [-.25,.25]:
            box(town,(x+w*xx,y+h*.58,z+side*(d/2+.012)),(.45,h*.29,.03),(.33,.34,.41,1))
        box(town,(x+side*(w/2+.012),y+h*.56,z),(.03,h*.28,.48),(.36,.36,.44,1))
    box(town,(x,y+.68,z+d/2+.024),(.7,1.36,.04),(.39,.36,.41,1))
    if roof:
        for sx in [-1,1]:box(town,(x+sx*(w/2-.1),y+h+.36,z),(.2,.55,d),col,pen)
        for sz in [-1,1]:box(town,(x,y+h+.36,z+sz*(d/2-.1)),(w,.55,.2),col,pen)
    for k in range(9):
        xx=x+R.uniform(-w*.45,w*.45);yy=y+R.uniform(.2,h-.1)
        stroke(pen,[(xx,yy,z+d/2+.04),(xx+.22,yy-.03,z+d/2+.04)],.016)

house(-34,88,-48,5.8,5.0,11,PEACH)
box(town,(-34,99.4,-48),(8.6,.23,7.8),ROSE,pen)
for sx in [-1,1]:
    for sz in [-1,1]:stroke(town,[(-34+sx*3.4,97,-48+sz*2.8),(-34+sx*3.4,99.3,-48+sz*2.8)],.10,PEACH)
house(-41,78,-39,4,4,4,PEACH)
house(-23,71,-51,3.8,3.4,4.5,PEACH)
for i in range(11):
    a=i*2.4;xx=83+(i%4)*6.7;zz=-109+(i//4)*6
    house(xx,34-R.uniform(0,2),zz,R.uniform(3.6,5.8),R.uniform(3.4,5.0),R.uniform(2.4,4.6),(.88,.65+.04*math.sin(a),.58,1))
for i in range(5):house(-23+i*4.0,19+i*.65,-30+(i%2)*3,3.3,3.0,2.8,PEACH)
house(108,24,-2,4.6,4,3.5,(.86,.68,.64,1))

# Narrow steps follow the citadel's taper from shore to tower; the embedded
# backs of their blocks meet stone rather than floating beside the mountain.
for i in range(100):
    t=i/99;a=.4+t*4.8;y=20+68*t
    p=citadel_surface(a,(y-12)/77,.38);x=p.x;z=p.z
    box(town,(x,y-.28,z),(2,.56,1.6),PEACH)
    if i%4==0:stroke(pen,[(x-.6,y+.018,z+.45),(x+.65,y+.018,z+.45)],.022)

def bridge(a,b):
    a=Vector(a);b=Vector(b);side=(b-a).cross(Vector((0,1,0))).normalized()
    def path(t):return a.lerp(b,t)-Vector((0,math.sin(math.pi*t)*3.7,0))
    for i in range(60):
        p=path((i+.025)/60);q=path((i+.975)/60)
        ps=[p-side*1.06,p+side*1.06,q+side*1.06,q-side*1.06]
        town.face(ps,(.74,.56,.44,1));stroke(pen,[ps[0],ps[1]],.025)
        below=[v-Vector((0,.13,0)) for v in ps]
        town.face(list(reversed(below)),(.67,.50,.40,1))
        for k in range(4):town.face([ps[k],ps[(k+1)%4],below[(k+1)%4],below[k]],(.74,.56,.44,1))
    for s in [-1,1]:
        line=[path(i/60)+side*s*1.03+Vector((0,1.65,0)) for i in range(61)]
        stroke(town,line,.065,(.48,.40,.40,1));stroke(pen,line,.024)
        stroke(town,[path(i/60)+side*s*1.02-Vector((0,.08,0)) for i in range(61)],.085,(.48,.40,.40,1))
        for i in range(0,61,4):
            p=path(i/60)+side*s*1.02
            stroke(town,[p,p+Vector((0,1.65,0))],.035,(.49,.41,.42,1))
    for p in [a,b]:
        box(town,(p.x,(18+p.y)/2,p.z),(2.6,p.y-18,2.6),PEACH,pen)
        for s in [-1,1]:stroke(town,[p+side*s*1.1-Vector((0,1,0)),p+side*s*1.1+Vector((0,2.1,0))],.12,PEACH)
bridge((-15,25,-48),(19,29,-74))
bridge((24,29,-74),(69,32,-96))

def dock(x,y,z):
    for i in range(14):box(town,(x,y,z+i*.65),(9,.20,.61),(.74,.67,.51,1),pen)
    for xx in [x-4,x+4]:
        for zz in [z,z+7.8]:
            stroke(town,[(xx,-43,zz),(xx,y+2.7,zz)],.18,(.53,.48,.48,1))
            stroke(town,[(xx,y-6.5,zz),(xx,y-.15,zz+4 if zz==z else zz-4)],.12,(.53,.48,.48,1))
    for xx in [x-3.8,x+3.8]:
        for zz in [z+1,z+6.8]:stroke(town,[(xx,y,zz),(xx,y+5-.5*(zz-z-.3)/7.2,zz)],.1,(.57,.51,.46,1))
    town.face([(x-4.5,y+5,z+.3),(x+4.5,y+5,z+.3),(x+4.5,y+4.5,z+7.5),(x-4.5,y+4.5,z+7.5)],(.94,.87,.62,1))
    for xx in [x-4.5,x+4.5]:stroke(pen,[(xx,y+5,z+.3),(xx,y+4.5,z+7.5)],.035)
dock(137,-31,126)
for i in range(16):box(town,(137,-31,117.5+i*.60),(2.6,.20,.57),(.74,.67,.51,1),pen)
for xx in [135.9,138.1]:stroke(town,[(xx,-43,122),(xx,-30.9,122)],.16,(.53,.48,.48,1))
town.finish();pen.finish()

# Curved miniature river craft, complete on every side, kept in a safe closed
# route in the upper basin. Origins and paths are exported for runtime motion.
boats=[]
for i,(x,z,scale) in enumerate([(54,-57,1.0),(84,-34,.66),(-65,-69,.75),(114,-126,.65)]):
    root=empty('Ferry_%d'%i,(x,18.25,z));hull=Batch('Ferry_%d_hull'%i);pi=Batch('Ferry_%d_pen'%i,'Ink')
    n=32
    for j in range(n):
        a=j*TAU/n;aa=(j+1)*TAU/n
        def hp(t,y,s):return (math.cos(t)*2.0*scale*s,y,math.sin(t)*4.8*scale*s)
        hull.face([hp(a,-.8,.65),hp(aa,-.8,.65),hp(aa,.9,1),hp(a,.9,1)],(.92,.72,.39,1))
        hull.face([hp(a,.9,1),hp(aa,.9,1),(0,.9,0)],(.92,.78,.57,1))
        stroke(pi,[hp(a,.96,1),hp(aa,.96,1)],.026)
    box(hull,(0,1.5,0),(3.1*scale,1.4,4.6*scale),(.87,.64,.56,1),pi)
    box(hull,(0,2.27,0),(3.7*scale,.16,5.2*scale),(.96,.91,.76,1),pi)
    for zz in [-1.4,0,1.4]:
        for sx in [-1,1]:box(hull,(sx*1.56*scale,1.6,zz*scale),(.04,.68,.80*scale),(.42,.48,.56,1),pi)
    stroke(hull,[(.8*scale,2.3,-1.2*scale),(.8*scale,4.6,-1.2*scale)],.13,(.63,.63,.53,1))
    hull.finish(root);pi.finish(root)
    rim=Batch('Ferry_%d_waterline'%i,'Rim');arc=0.
    for j in range(64):
        a=j*TAU/64;b=(j+1)*TAU/64
        contact=[Vector(hp(t,-.195,.765)) for t in [a,b]]
        length=(contact[1]-contact[0]).length;band=[]
        for t,p in zip([a,b],contact):
            for width in [-.25,1.15*scale]:band.append(p+Vector((math.cos(t)*width,0,math.sin(t)*width)))
        rim.face([band[0],band[2],band[3],band[1]],(.82,.93,.86,1),[(arc,0),(arc+length,0),(arc+length,1),(arc,1)])
        arc+=length
    rim.finish(root)
    boats.append(dict(name=root.name,origin=[x,18.25,z],phase=i*1.7,rim='Ferry_%d_waterline'%i))

# White, stretched-wing carrier. Separate shoulder groups articulate around
# embedded roots; feather contours follow the actual upper and lower shells.
bird=empty('GreatWhiteBird')
body=Batch('Bird_body','Bird');bi=Batch('Bird_body_pen','BirdInk')
oval(body,(0,.0,0),(1.30,.77,3.1),WHITE,40,22)
tube(body,[(0,.25,-1.6),(0,.32,-3),(0,.40,-5.3),(0,.48,-7.4),(0,.42,-8.4)],[(.85,.48),(.6,.40),(.34,.30),(.33,.34),(.20,.22)],WHITE,24)
oval(body,(0,.48,-7.6),(.43,.42,.92),WHITE,28,16)
for side in [-1,1]:
    oval(body,(side*.34,.64,-7.96),(.043,.065,.083),INK,12,8)
    stroke(bi,[(side*.35,.64,-8.12),(side*.40,.70,-7.98),(side*.39,.69,-7.85)],.012)
    stroke(bi,[(side*.70,.33,-2.3),(side*.39,.48,-4.0),(side*.29,.50,-6.2)],.009,(.51,.58,.60,1))
beak=Batch('Bird_saffron_vermilion_bill','Bird')
tube(beak,[(0,.43,-8.1),(0,.40,-9.25),(0,.30,-11.5),(0,.24,-13.0)],[(.24,.22),(.19,.16),(.082,.073),(.008,.012)],(.98,.67,.12,1),16)
tube(beak,[(0,.30,-11.45),(0,.24,-13.02)],[(.083,.075),(.008,.01)],(.92,.25,.14,1),16)
stroke(bi,[(.21,.39,-8.35),(.16,.35,-9.7),(.075,.28,-11.55),(0,.24,-13.0)],.013)
# Three long green / orange crest plumes, attached to the crown.
for i,c in enumerate([(.42,.70,.18,1),(.74,.81,.20,1),(.92,.44,.22,1)]):
    p=[(-.10+i*.10,.78,-7.4),(-.14+i*.12,1.33+i*.07,-6.85),(-.20+i*.14,2.18-i*.14,-6.08),(-.12+i*.1,1.15,-6.78)]
    body.face(p,c);stroke(bi,p+[p[0]],.013)
body.finish(bird);bi.finish(bird);beak.finish(bird)

wings=[]
for side in [-1,1]:
    name='Wing_Left' if side<0 else 'Wing_Right'
    wing=empty(name,(side*.75,0,-.5),bird);w=Batch(name+'_ivory','Bird');ip=Batch(name+'_pen','BirdInk')
    # A swept albatross-like outline with a broad inner trailing fan and a
    # long narrow point, matching the reference's stretched white silhouette.
    sections=[(0,-1.05,2.05,.0), (1.4,-1.5,2.65,.14),(3.3,-1.8,3.6,.22),(5.6,-2.05,3.9,.32),(8,-2.4,2.35,.63),(10.5,-3.0,.4,1.08),(13,-3.9,-2.0,1.6),(15.3,-4.65,-4.60,2.12)]
    def pt(s,v,lower=False):
        x,front,back,y=s
        return (side*x,y+math.sin(v*math.pi)*(.19 if not lower else -.16),front+(back-front)*v)
    for k in range(len(sections)-1):
        for j in range(10):
            v=j/10;vv=(j+1)/10
            for lo in [False,True]:w.face([pt(sections[k],v,lo),pt(sections[k+1],v,lo),pt(sections[k+1],vv,lo),pt(sections[k],vv,lo)],WHITE if not lo else (.90,.95,.95,1))
    for v in [0,1]:stroke(ip,[pt(s,v) for s in sections],.015)
    # Individual tapered flight feathers break up the rear edge without gaps.
    for i in range(26):
        x=1.8+i*.41;idx=next((k for k in range(len(sections)-1) if sections[k][0]<=x<sections[k+1][0]),5)
        a=sections[idx];b=sections[idx+1];f=(x-a[0])/(b[0]-a[0]);s=tuple(a[k]*(1-f)+b[k]*f for k in range(4))
        p=Vector(pt(s,.76));q=Vector(pt(s,1));tip=q+Vector((side*.10,-.018,.18+.11*math.sin(i*.6)))
        w.face([p,q+Vector((side*.30,0,0)),tip,q-Vector((side*.12,0,0))],WHITE)
        stroke(ip,[p,q,tip],.008,(.50,.56,.59,1))
        stroke(ip,[(p.x,p.y-.21,p.z),(q.x,q.y-.015,q.z)],.008,(.55,.60,.62,1))
    w.finish(wing);ip.finish(wing);wings.append(name)
tail=Batch('Long forked tail','Bird');ti=Batch('Tail fine ink','BirdInk')
for side in [-1,1]:
    p=[(side*.12,.15,1.4),(side*1.04,.08,2.1),(side*1.45,-.12,6.5),(side*.16,-.05,4.4)]
    tail.face(p,WHITE);tail.face([(x,y-.08,z) for x,y,z in reversed(p)],(.90,.94,.94,1));stroke(ti,p+[p[0]],.012)
tail.finish(bird);ti.finish(bird)

# Seated traveller, saddle, rolled blanket and straps. The aboard camera sits
# above the face; the follow camera reveals the entire rider and carrier.
rider=empty('Traveller',(0,.63,.3),bird);rb=Batch('Traveller ochre coat','Bird');ri=Batch('Traveller fine ink','BirdInk')
oval(rb,(0,.10,0),(.72,.22,.94),(.63,.48,.33,1),24,12)
oval(rb,(0,.94,.15),(.46,.79,.33),(.64,.60,.46,1),24,18)
oval(rb,(0,1.81,.03),(.27,.34,.27),(.85,.72,.51,1),24,16)
oval(rb,(0,2.02,.13),(.30,.22,.27),(.55,.52,.41,1),24,12)
for side in [-1,1]:
    tube(rb,[(side*.3,.5,.15),(side*.66,.22,-.37),(side*.86,-.20,-.64)],[.25,.24,.16],(.67,.63,.46,1),16)
    oval(rb,(side*.86,-.23,-.78),(.19,.13,.36),(.74,.58,.36,1),20,10)
    tube(rb,[(side*.35,1.24,.04),(side*.51,.80,-.29),(side*.37,.52,-.66)],[.18,.15,.11],(.64,.60,.46,1),16)
    oval(rb,(side*.36,.52,-.69),(.12,.11,.16),(.87,.73,.53,1),16,10)
    stroke(ri,[(side*.30,1.25,-.14),(side*.20,.81,-.20),(side*.35,.45,-.33)],.012)
box(rb,(0,1.08,-.19),(.19,.73,.12),(.33,.32,.47,1))
for j in range(3):box(rb,(0,.86+j*.18,-.259),(.19,.064,.02),(.91,.72,.23,1))
tube(rb,[(-.66,.35,.80),(.66,.35,.80)],[.23,.23],(.81,.71,.48,1),20)
for x in [-.44,.44]:stroke(ri,[(x,.14,.8),(x,.3,1.02),(x,.54,.8),(x,.3,.57)],.02)
rb.finish(rider);ri.finish(rider)

companion=empty('SmallCompanion')
cb=Batch('Small companion swallow','Bird');ci=Batch('Small companion ink','BirdInk')
oval(cb,(0,0,0),(.26,.26,.64),WHITE,20,12)
oval(cb,(0,.06,-.57),(.30,.29,.33),(.89,.26,.20,1),20,12)
tube(cb,[(0,.10,-.75),(0,.06,-1.28)],[.12,.008],(.97,.76,.15,1),12)
for side in [-1,1]:
    ps=[(side*.15,.05,-.35),(side*2.1,.24,.38),(side*1.83,.15,.56),(side*.18,.02,.47)]
    cb.face(ps,WHITE);stroke(ci,ps+[ps[0]],.014)
    oval(cb,(side*.235,.18,-.72),(.047,.06,.06),INK,12,8)
cb.face([(-.15,0,.4),(-.37,0,1.35),(0,0,1.08),(.37,0,1.35),(.15,0,.4)],(.88,.81,.16,1))
cb.finish(companion);ci.finish(companion)

layout=dict(orbit=dict(center=[0,61,-29],radii=[111,86],period=210,phase=1.02),boats=boats,wings=wings,rocks=rocks,water_levels=[-35,18,42],seat=[0,3.5,4.1],follow=[0,13,27],upper_lip=UPPER_LIP,upper_arc=UPPER_ARC)
(ROOT/'assets/data/azure_layout.json').write_text(json.dumps(layout,indent=2))

# Original seamless air / distant falls bed. Two independently filtered channels
# and a periodic crossfade avoid discontinuities and any pitched engine drone.
rate=22050;seconds=20;rand=random.Random(908);samples=[];l=r=0
for i in range(rate*seconds):
    t=i/rate;l=.93*l+.07*rand.uniform(-1,1);r=.94*r+.06*rand.uniform(-1,1)
    swell=.50+.08*math.sin(TAU*t/seconds)+.04*math.cos(TAU*t*3/seconds)
    samples.append((l*.32*swell,r*.32*swell))
cross=rate
for i in range(cross):
    f=i/cross;a=samples[i];b=samples[-cross+i]
    samples[i]=(a[0]*f+b[0]*(1-f),a[1]*f+b[1]*(1-f))
samples=samples[:-cross]
with wave.open(str(ROOT/'assets/audio/azure_falls.wav'),'wb') as out:
    out.setnchannels(2);out.setsampwidth(2);out.setframerate(rate)
    out.writeframes(b''.join(struct.pack('<hh',int(a*32767),int(b*32767)) for a,b in samples))

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/azure_pilgrimage.blend'))
# The source keeps named landmarks. Merge only static objects of one material;
# moving birds, shoulder pivots and ferries retain their source hierarchy.
for kind in MATS:
    obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent is None and o.data.materials[0]==MATS[kind]]
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs:ob.select_set(True)
    if obs:
        bpy.context.view_layer.objects.active=obs[0]
        if len(obs)>1:bpy.ops.object.join()
        obs[0].name='AzureWorld'+kind
target=ROOT/'assets/models/azure_pilgrimage.glb'
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False,export_cameras=False,export_lights=False)
print('AZURE_READY:',len(rocks),'landmarks, seated traveller, articulated bird, two falls, four ferries;',target.stat().st_size,'bytes')
