"""The Painted Mere: original ink geometry and translucent pigment studies.
Godot coordinates are used throughout; Blender remains the editable source.
Run blender --background --python blender/build_painted.py.
"""
import bpy, bmesh, math, random, json, wave, struct
from pathlib import Path
from mathutils import Vector, noise

ROOT=Path(__file__).resolve().parents[1]
random.seed(92517)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
mats={}
for name,col in {'Wash':(.73,.61,.92,1),'Ink':(.19,.15,.28,1),'Water':(.78,.76,.98,1),'Leaf':(.64,.40,.90,1),'Petal':(.96,.42,.73,1),'Sun':(1,.36,.08,1),'Bleed':(.90,.50,.82,1),'Bird':(.98,.43,.68,1),'Pad':(.32,.82,.61,1),'Timber':(.78,.70,.9,1)}.items():
    m=bpy.data.materials.new('Painted'+name);m.diffuse_color=col;mats[name]=m

class Batch:
    def __init__(self,name,kind):self.name=name;self.kind=kind;self.v=[];self.f=[];self.c=[];self.uv=[]
    def face(self,p,col=(.78,.70,.94,1),uv=None):
        n=len(self.v);self.v.extend(p);self.f.append(tuple(range(n,n+len(p))));self.c.extend([col]*len(p));self.uv.extend(uv or [(0,0),(1,0),(1,1),(0,1)][:len(p)])
    def finish(self):
        if not self.v:return
        mesh=bpy.data.meshes.new(self.name);mesh.from_pydata([(v[0],-v[2],v[1]) for v in self.v],[],self.f);mesh.update()
        ob=bpy.data.objects.new(self.name,mesh);bpy.context.collection.objects.link(ob);mesh.materials.append(mats[self.kind])
        uv=mesh.uv_layers.new(name='SurfaceUV')
        for poly in mesh.polygons:
            poly.use_smooth=self.kind in ['Leaf','Sun','Bird','Bleed']
            for li in poly.loop_indices:uv.data[li].uv=self.uv[mesh.loops[li].vertex_index]
        c=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
        for i,value in enumerate(self.c):c.data[i].color=value
        if self.kind in ['Leaf','Sun','Bird'] or (self.kind=='Bleed' and self.name.startswith('Tree')):
            bm=bmesh.new();bm.from_mesh(mesh)
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            bm.to_mesh(mesh);bm.free();mesh.update()
        return ob

ink=Batch('Fine ink contours and dry pen marks','Ink')
spills=Batch('Occasional pigment outside petal and leaf ink','Bleed')

def spill_ribbon(edge,center,width,col,seed):
    """Authored feathered paint extending from a fixed ink edge, on both faces."""
    center=Vector(center)
    for j in range(len(edge)-1):
        t=j/max(1,len(edge)-1);tt=(j+1)/max(1,len(edge)-1)
        p=Vector(edge[j]);q=Vector(edge[j+1])
        a=(p-center).normalized();b=(q-center).normalized()
        wa=width*(.65+.35*math.sin(t*13+seed))*(.4+.6*math.sin(t*math.pi))
        wb=width*(.65+.35*math.sin(tt*13+seed))*(.4+.6*math.sin(tt*math.pi))
        # Inner edge lies just within the opaque fill, outer edge is wholly outside.
        spills.face([p-a*.015,q-b*.015,q+b*wb,p+a*wa],col,[(t,0),(tt,0),(tt,1),(t,1)])
def stroke(points,r=.009,col=(.24,.20,.32,1),batch=None):
    b=batch or ink;ps=[Vector(p) for p in points];rings=[]
    for i,p in enumerate(ps):
        d=(ps[min(i+1,len(ps)-1)]-ps[max(i-1,0)]).normalized()
        a=d.cross(Vector((0,0,1)))
        if a.length<.01:a=d.cross(Vector((0,1,0)))
        a.normalize();other=d.cross(a);rr=r*(.88+.14*math.sin(i*1.7))
        rings.append([p+(a*math.cos(j*math.tau/4)+other*math.sin(j*math.tau/4))*rr for j in range(4)])
    for i in range(len(ps)-1):
        for j in range(4):b.face([rings[i][j],rings[i][(j+1)%4],rings[i+1][(j+1)%4],rings[i+1][j]],col)

def box(b,p,s,col,lines=True):
    x,y,z=p;w,h,d=s
    pts=[(x+sx*w/2,y+sy*h/2,z+sz*d/2) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,-1,1),(-1,-1,1),(-1,1,-1),(1,1,-1),(1,1,1),(-1,1,1)]]
    for f in [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:b.face([pts[i] for i in f],col)
    if lines:
        for a,c in [(0,1),(1,2),(2,3),(3,0),(4,5),(5,6),(6,7),(7,4),(0,4),(1,5),(2,6),(3,7)]:stroke([pts[a],pts[c]],.008)

def oval(b,p,s,col,detail=24,rings=12,scallop=0):
    p=Vector(p);vs=[]
    for j in range(rings+1):
        v=j/rings;t=math.pi*v
        ring=[]
        for i in range(detail):
            a=math.tau*i/detail;w=1+scallop*(math.sin(3*a+v*35)*.65+math.sin(v*51-a*2)*.35)*math.sin(t)
            lean=math.sin(v*5.1)*s[0]*scallop
            ring.append(p+Vector((s[0]*math.sin(t)*math.cos(a)*w+lean,s[1]*math.cos(t),s[2]*math.sin(t)*math.sin(a)*w)))
        vs.append(ring)
    for j in range(rings):
        for i in range(detail):b.face([vs[j][i],vs[j][(i+1)%detail],vs[j+1][(i+1)%detail],vs[j+1][i]],col,[(i/detail,j/rings),((i+1)/detail,j/rings),((i+1)/detail,(j+1)/rings),(i/detail,(j+1)/rings)])

# Fine cold-press paper height, with stable fibre structure. Not a screen overlay.
size=256;im=bpy.data.images.new('PaintedPaper',width=size,height=size,alpha=False);pixels=[]
for y in range(size):
    for x in range(size):
        n=noise.noise_vector(Vector((x*.24,y*.24,3.1))).x
        v=.58+n*.23+random.uniform(-.13,.13)
        pixels.extend((v,v,v,1))
im.pixels=pixels;im.filepath_raw=str(ROOT/'assets/textures/PaintedPaper.png');im.file_format='PNG';im.save()

# The complete boardwalk is a supported continuous surface; small plank seams
# are narrower than a foot and the traversal height is exported with its bounds.
walk=Batch('Mere walkway individual weathered planks','Timber')
def drawn_plank(cx,z,width,seed):
    r=random.Random(4450+seed)
    # Small chipped ends and gently bowed seams, with a flat, continuous top.
    left=-width/2+r.uniform(-.03,.02);right=width/2+r.uniform(-.02,.03)
    outline=[]
    for side in [-1,1]:
        xs=[left,left+.075,-width*.22,width*.12,right-.11,right]
        if side==1:xs.reverse()
        for j,x in enumerate(xs):
            zz=z+side*(.2375-(.035 if j in [0,5] else 0))+.009*math.sin(x*2.3+seed*.7)
            outline.append(Vector((cx+x,.45,zz)))
    centre=Vector((cx,.45,z))
    tint=(r.uniform(.72,.84),r.uniform(.65,.78),r.uniform(.86,.96),1)
    for j,p in enumerate(outline):
        q=outline[(j+1)%len(outline)]
        walk.face([centre,p,q],tint,[(.5,.5),((p.x-cx)/width+.5,(p.z-z)/.475+.5),((q.x-cx)/width+.5,(q.z-z)/.475+.5)])
        walk.face([p,q,q-Vector((0,.14,0)),p-Vector((0,.14,0))],tint)
        path=[p.lerp(q,t)+Vector((0,.005,.003*math.sin(t*math.pi*2+seed))) for t in [0,.2,.4,.6,.8,1]]
        stroke(path,.0058,(.31,.23,.40,1))
    walk.face([p-Vector((0,.14,0)) for p in reversed(outline)],tint,[(0,0)]*len(outline))
    # Sparse pale glazes run beyond a board end and slightly across a seam.
    if seed%4==0:
        edge=outline[:4] if seed%8==0 else outline[6:10]
        spill_ribbon(edge,centre,.12,(.73,.62,.94,.40),seed)
    if seed%3==0:
        knotx=cx+r.uniform(-width*.3,width*.3)
        for layer in range(2):
            stroke([(knotx+(.07+layer*.06)*math.cos(t),.456,z+(.028+layer*.012)*math.sin(t)+.008*math.sin(t*3)) for t in [j*math.tau/28 for j in range(29)]],.0035,(.45,.34,.53,1))
wood=(.77,.70,.89,1);walkways=[[-1.7,1.7,-28,14],[-5.5,5.5,-28,-19]]
for i in range(84):
    z=13.75-i*.5;width=3.4+random.uniform(-.09,.09)
    drawn_plank(0,z,width,i)
    for k in range(3):
        x=random.uniform(-1.45,1.0);zz=z+random.uniform(-.17,.17)
        stroke([(x,.456,zz),(x+.16,.457,zz+.007),(x+random.uniform(.28,.58),.456,zz-.008)],.0045,(.39,.30,.46,1))
    for x in [-1.3,1.3]:
        stroke([(x+.018*math.cos(a),.46,z+.018*math.sin(a)) for a in [j*math.tau/8 for j in range(9)]],.004)
for x in [-1.22,1.22]:box(walk,(x,.12,-7),( .18,.26,42),(.67,.65,.81,1))
for z in range(-27,15,4):
    box(walk,(0,-.035,z),(3.65,.18,.24),wood)
    for x in [-1.72,1.72]:
        box(walk,(x,-.14,z),(.20,1.82,.23),wood)
        stroke([(x-.06,-.83,z+.12),(x-.04,.35,z+.12)],.006)
    stroke([(-1.65,-.72,z),(1.65,-.04,z)],.048,(.63,.59,.77,1),walk)
    stroke([(1.65,-.72,z),(-1.65,-.04,z)],.048,(.63,.59,.77,1),walk)
for i in range(18):
    z=-19.25-i*.5
    for x in [-3.65,3.65]:drawn_plank(x,z,3.85,100+i+(50 if x>0 else 0))
for x in [-4.8,4.8]:
    box(walk,(x,.12,-23.5),(.18,.26,9),wood)
    for z in [-19.3,-23.5,-27.7]:box(walk,(x,-.30,z),(.24,1.50,.24),wood)
walk.finish()

# Quiet wet ground fills all views with fixed, uneven washes; no repeated waves.
water=Batch('Lavender water paper field','Water')
water.face([(-130,-.16,-150),(130,-.16,-150),(130,-.16,100),(-130,-.16,100)],(.80,.77,.96,1));water.finish()
bed=Batch('Mere bed beneath rooted piles','Wash')
bed.face([(-130,-1.05,-150),(130,-1.05,-150),(130,-1.05,100),(-130,-1.05,100)],(.72,.69,.84,1));bed.finish()

# Conservatory: complete iron ribs, lantern dome, open front doorway, and
# overlapping whitewashed glass panes. The opening joins the landing.
house=Batch('Conservatory frame and plinth','Wash');glass=Batch('Conservatory pale glass','Wash')
center=Vector((0,.45,-31.7));R=5.2;N=32
for i in range(8):
    a=i*math.tau/8
    box(house,(4.4*math.cos(a),-.30,-31.7+4.4*math.sin(a)),(.22,1.50,.22),(.76,.71,.85,1))
for i in range(N):
    a=i*math.tau/N;aa=(i+1)*math.tau/N
    # front opening faces the landing; keep it two metres wide.
    doorway=math.sin((a+aa)*.5)>.98
    base=center+Vector((R*math.cos(a),0,R*math.sin(a)))
    if not doorway:
        stroke([base,base+Vector((0,3.4,0))],.035,(.45,.41,.54,1),house)
        nextbase=center+Vector((R*math.cos(aa),0,R*math.sin(aa)))
        glass.face([base,nextbase,nextbase+Vector((0,3.4,0)),base+Vector((0,3.4,0))],(.91,.90,.96,1))
        stroke([base,nextbase],.025)
    roof=[]
    for j in range(13):
        t=j/12*math.pi/2;r=R*math.cos(t)
        roof.append(center+Vector((r*math.cos(a),3.4+3.5*math.sin(t),r*math.sin(a))))
    stroke(roof,.019,(.46,.41,.55,1))
    for j in range(12):
        t=j/12*math.pi/2;tt=(j+1)/12*math.pi/2
        glass.face([center+Vector((R*math.cos(t)*math.cos(a),3.4+3.5*math.sin(t),R*math.cos(t)*math.sin(a))),center+Vector((R*math.cos(t)*math.cos(aa),3.4+3.5*math.sin(t),R*math.cos(t)*math.sin(aa))),center+Vector((R*math.cos(tt)*math.cos(aa),3.4+3.5*math.sin(tt),R*math.cos(tt)*math.sin(aa))),center+Vector((R*math.cos(tt)*math.cos(a),3.4+3.5*math.sin(tt),R*math.cos(tt)*math.sin(a)))],(.92,.89,.97,1))
for h,r in [(1.2,R),(2.5,R),(3.4,R)]+[(3.4+3.5*math.sin(j*math.pi/24),R*math.cos(j*math.pi/24)) for j in [2,4,6,8,10]]:
    for i in range(N):
        a=i*math.tau/N;aa=(i+1)*math.tau/N
        if h<3.4 and math.sin((a+aa)*.5)>.98:continue
        stroke([center+Vector((r*math.cos(a),h,r*math.sin(a))),center+Vector((r*math.cos(aa),h,r*math.sin(aa)))],.017,(.46,.40,.54,1))
for j in range(64):
    a=j*math.tau/64;aa=(j+1)*math.tau/64
    house.face([(0,.46,-31.7),(5.18*math.cos(a),.46,-31.7+5.18*math.sin(a)),(5.18*math.cos(aa),.46,-31.7+5.18*math.sin(aa))],(.86,.83,.93,1))
for x in [-1.05,1.05]:
    box(house,(x,1.88,-26.45),(.10,2.86,.16),(.73,.67,.81,1))
    stroke([(x,.45,-26.33),(x,3.3,-26.33),(0,4.1,-26.33)],.025)
stroke([(-1.3,3.34,-26.3),(0,4.28,-26.3),(1.3,3.34,-26.3)],.036)
stroke([(-1.05,3.32,-26.3),(1.05,3.32,-26.3)],.025)
for j in range(9):
    x=-.9+j*.225;stroke([(x,3.32,-26.3),(x,4.05-abs(x)*.7,-26.3)],.008)
# A small octagonal roof lantern and finial.
for j in range(8):
    a=j*math.tau/8;aa=(j+1)*math.tau/8
    p=center+Vector((.85*math.cos(a),6.35,.85*math.sin(a)))
    stroke([p,p+Vector((0,1.0,0)),center+Vector((0,7.85,0))],.018)
    glass.face([p,center+Vector((.85*math.cos(aa),6.35,.85*math.sin(aa))),center+Vector((.85*math.cos(aa),7.35,.85*math.sin(aa))),p+Vector((0,1,0))],(.86,.78,.94,1))
stroke([center+Vector((0,7.8,0)),center+Vector((0,8.4,0))],.025)
house.finish();glass.finish()

# Trees have closed three-dimensional crowns and attached trunks/branches.
# Fine ink silhouettes use a backface shell at runtime, while branch strokes
# remain real geometry readable from below and behind.
trees=[]
for idx,(x,z,h) in enumerate([(-7,4,6),(8,-2,7),(-9,-10,7.3),(10,-18,6.4),(-13,-24,8),(13,-34,8.4),(-17,-43,8),(19,-48,8),(-16,15,7.6),(14,18,6.5),(-25,-12,8),(25,-20,9),(-30,-50,10),(32,5,8)]):
    crown=Batch('Tree %02d scalloped pigment crown'%idx,'Leaf')
    oval(crown,(x,h*.55-.16,z),(h*random.uniform(.22,.27),h*.49,h*.22),(.59+random.uniform(-.04,.07),.39,.89,1),64,72,.12)
    crown.finish();trees.append(dict(x=x,z=z,radius=.45))
    trunk=[(x,-.35,z),(x+.10,h*.24,z+.04),(x-.12,h*.47,z),(x+.08,h*.71,z)]
    stroke(trunk,.045,(.28,.20,.38,1))
    for i in range(8):
        a=i*2.4;y=h*(.20+i*.045)
        for j in range(len(trunk)-1):
            if trunk[j][1]<=y<=trunk[j+1][1]:
                at=Vector(trunk[j]).lerp(Vector(trunk[j+1]),(y-trunk[j][1])/(trunk[j+1][1]-trunk[j][1]));break
        end=at+Vector((math.cos(a)*h*.15,h*.22,math.sin(a)*h*.14))
        stroke([at.lerp(end,t)+Vector((0,-math.sin(t*math.pi)*.16,0)) for t in [j/7 for j in range(8)]],.016,(.30,.22,.43,1))

# Lotus: radial cupped petals, outline contours, joined stems, not flat sprites.
petals=Batch('Lotus petals with cupped profiles','Petal');pads=Batch('Floating lotus leaves','Pad')
plant_rng=random.Random(20731)
lotus=[]
for idx,(x,z,s) in enumerate([(-4.2,7,1.05),(4.7,-5,.9),(-5.9,-12,1.1),(7,-15,.65),(-8,0,.6),(-11,-18,.8),(5.7,10,.65)]):
    lotus.append([x,z,s]);base=Vector((x,.70*s,z))
    stroke([(x,-.22,z),(x+.04,.32*s,z),base],.075,(.36,.67,.49,1),pads)
    for tier in range(3):
        for k in range(8):
            a=k*math.tau/8+tier*.39+plant_rng.uniform(-.13,.13);d=Vector((math.cos(a),0,math.sin(a)));side=Vector((-d.z,0,d.x));l=s*(1.30-tier*.25)*plant_rng.uniform(.9,1.14)
            left=[];right=[];mid=[];width=plant_rng.uniform(.29,.44);lean=plant_rng.uniform(-.12,.12)
            colour=(.98,plant_rng.uniform(.34,.52)+tier*.06,plant_rng.uniform(.66,.79),1)
            for j in range(17):
                t=j/16;at=base+d*(l*t)+side*(s*lean*math.sin(t*math.pi))+Vector((0,s*(.12+(.35+tier*.23)*t*t),0));w=s*width*math.sin(math.pi*t)**.65
                left.append(at-side*w*(1+.10*math.sin(t*7+k)));right.append(at+side*w)
                mid.append(at+Vector((0,s*.055*math.sin(t*math.pi),0)))
            for j in range(16):
                for aa,bb,ua,ub in [(left,mid,0,.5),(mid,right,.5,1)]:
                    petals.face([aa[j],bb[j],bb[j+1],aa[j+1]],colour,[(ua,j/16),(ub,j/16),(ub,(j+1)/16),(ua,(j+1)/16)])
            stroke(left+list(reversed(right)),.0065,(.42,.21,.39,1))
            stroke([mid[j]+Vector((0,.008,0)) for j in range(3,12)],.0028,(.67,.37,.58,1))
            if (k+idx*2+tier)%3==0:
                # Side-only glazes avoid folding a transparent ribbon over the
                # pointed tip; softened endpoints read as a loose brush pass.
                spill_ribbon((left if k%2 else right)[3:14],mid[8],s*.28,(.98,.30,.70,.48),k+idx)
    for k in range(12):
        a=k*math.tau/12;stroke([base+Vector((0,.2,0)),base+Vector((math.cos(a)*s*.18,s*.8,math.sin(a)*s*.18))],.014,(.86,.54,.13,1))
    for k in range(7):
        a=k*2.4;px=x+math.cos(a)*(1+k*.21)*s;pz=z+math.sin(a)*(1+k*.21)*s;r=s*random.uniform(.45,.85)
        rotation=plant_rng.uniform(0,math.tau);ring=[]
        for j in range(49):
            a=.18+j/48*(math.tau-.53);t=a+rotation
            rad=r*(1+.043*math.sin(a*5+k)+.024*math.sin(a*11+idx))
            ring.append(Vector((px+math.cos(t)*rad,-.13+idx*.001+.010*math.sin(a*3+k),pz+math.sin(t)*rad*.78)))
        p=Vector((px,-.13+idx*.001,pz))
        for j in range(len(ring)-1):
            a=ring[j];b=ring[j+1]
            pads.face([p,a,b],(.32,.83,.64,1),[(.5,.5),((a.x-px)/(2*r)+.5,(a.z-pz)/(2*r*.78)+.5),((b.x-px)/(2*r)+.5,(b.z-pz)/(2*r*.78)+.5)])
        stroke([p]+ring+[p],.0058,(.24,.45,.42,1))
        for j in range(5,47,8):
            end=p.lerp(ring[j],.72)
            stroke([p+Vector((0,.007,0)),p.lerp(end,.5)+Vector((.012,.008,.012)),end+Vector((0,.009,0))],.0025,(.36,.60,.49,1))
        if (k+idx)%2==0:spill_ribbon(ring,p+Vector((-.06,0,.04)),r*.38,(.27,.88,.66,.44),k*2+idx)
petals.finish();pads.finish()
spills.finish()

# Fine dried seed heads frame foreground and surround all accessible sides.
for cluster in range(38):
    cx=random.choice([-1,1])*random.uniform(3,25);cz=random.uniform(-48,25)
    for i in range(random.randint(9,19)):
        x=cx+random.uniform(-1.1,1.1);z=cz+random.uniform(-1,1);h=random.uniform(.28,1.0)
        bend=random.uniform(-.14,.14);tip=Vector((x+bend,h,z))
        stroke([(x,-.18,z),(x+bend*.4,h*.6,z),tip],.005,(.35,.28,.47,1))
        stroke([tip+Vector((math.cos(j*math.tau/10)*.055,math.sin(j*math.tau/10)*.045,0)) for j in range(11)],.006,(.35,.28,.47,1))

# Curled iron bench on the landing, with legs that meet the plank top.
bench=Batch('Landing bench slats and grounded legs','Wash')
for z in [-23.5,-23.23,-22.96]:box(bench,(3.5,.93,z),(2.6,.09,.23),wood)
for y in [1.25,1.50,1.75]:box(bench,(3.5,y,-23.62),(2.6,.19,.075),wood)
for x in [2.4,4.6]:
    for z in [-23.45,-23.0]:stroke([(x,.45,z),(x+.08,.92,z)],.035)
    stroke([(x,.45,-23.45),(x,1.88,-23.62)],.030)
    stroke([(x,1.1,-22.9),(x,1.3,-23.0),(x,1.3,-23.45),(x,1.15,-23.6)],.022)
bench.finish()
ink.finish()
sun=Batch('Vermilion sun pigment disc','Sun');oval(sun,(-24,24,-90),(4.4,4.4,1), (1,.32,.06,1),48,24);sun.finish()

# Sparse bubbles rise beside flowers. Each separate object preserves its anchor.
for i in range(35):
    x,z,s=lotus[i%len(lotus)];b=Batch('Bubble_%02d'%i,'Ink');p=Vector((x+random.uniform(-1.6,1.6),random.uniform(.2,3),z+random.uniform(-1.5,1.5)))
    stroke([Vector((.033*math.cos(j*math.tau/12),.07*math.sin(j*math.tau/12),0)) for j in range(13)],.003,(.36,.68,.70,1),b)
    ob=b.finish();ob.location=(p.x,-p.z,p.y)

# Separate source module uses the same mesh/ink helpers and keeps articulated
# bird groups editable. No generated wildlife geometry is patched at runtime.
exec(compile((ROOT/'blender/build_painted_wildlife.py').read_text(),str(ROOT/'blender/build_painted_wildlife.py'),'exec'))
(ROOT/'assets/data/painted_layout.json').write_text(json.dumps(dict(walkways=walkways,deck_height=.45,trees=trees,lotus=lotus,flamingos=flamingos,dragonflies=dragonflies,conservatory=[0,-31.7,5.2]),indent=2))
# Original quiet water/bird loop, seamless by using integer-cycle oscillations.
rate=22050;duration=16;frames=bytearray();rr=random.Random(302);smooth=0
for i in range(rate*duration):
    t=i/rate;smooth=.97*smooth+.03*rr.uniform(-1,1)
    v=smooth*.055
    for k in range(5):
        q=(t-k*3.1)%duration;env=math.exp(-((q-.35)/.13)**2)+.6*math.exp(-((q-.68)/.10)**2)
        v+=.023*env*math.sin(math.tau*(1550*t+24*math.sin(math.tau*t*7)))
    v+=.004*math.sin(math.tau*137*t)*(.5+.5*math.sin(math.tau*t*3/16))
    n=int(max(-1,min(1,v))*32767);frames.extend(struct.pack('<hh',n,int(n*.91)))
with wave.open(str(ROOT/'assets/audio/painted_mere.wav'),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(rate);f.writeframes(frames)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/painted_mere.blend'))
# Keep bubbles separate for object-anchored pausable animation; batch other ink.
for kind in mats:
    if kind in ['Leaf','Bleed','Bird']:continue # Separate transparent glazes and articulated wildlife.
    bpy.ops.object.select_all(action='DESELECT');obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==mats[kind] and not o.name.startswith(('Bubble','Flamingo','Dragonfly'))]
    for ob in obs:ob.select_set(True)
    if obs:
        bpy.context.view_layer.objects.active=obs[0]
        if len(obs)>1:bpy.ops.object.join()
        obs[0].name='Painted'+kind
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/painted_mere.glb'),export_format='GLB',export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False)
print('PAINTED_READY: supported walkway, conservatory, 14 volumetric trees, seven lotus clusters')
