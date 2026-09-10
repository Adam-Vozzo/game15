"""Lowwater: original oak/canal study. Godot coordinates, deterministic editable source.

Run with Blender --background --python blender/build_lowwater.py.
Photographic references inform the composition; no reference pixels are shipped.
"""
import bpy, math, random, json, wave, struct
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

ROOT = Path(__file__).resolve().parents[1]
random.seed(41923)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def center(z): return 1.5 + math.sin(z*.055)*1.3
def ground(x,z):
    d = abs(x-center(z))
    bank = min(1.,max(0.,(d-2.6)/1.6))
    bank = bank*bank*(3-2*bank)
    return -.72 + bank*(1.4+.14*math.sin(x*.25+z*.13)+.09*math.cos(z*.31))

def texture(name, fn):
    im=bpy.data.images.new(name,width=256,height=256,alpha=True)
    pixels=[]
    for y in range(256):
        for x in range(256): pixels.extend(fn(x,y))
    im.pixels=pixels
    im.filepath_raw=str(ROOT/'assets/textures'/f'{name}.png')
    im.file_format='PNG'; im.save()
    return im

def bark(x,y):
    # Irregular vertical fissures and interrupted horizontal scars, RGB555 ramp.
    v=.23+.035*math.sin(x*.31+math.sin(y*.041)*1.5)+.025*math.sin(x*.91+y*.012)
    v-=.065*max(0.,math.sin(x*.58+math.sin(y*.063)))**9
    v+=random.uniform(-.022,.022)
    v=round(v*31)/31
    return (v*.94,v*.94,v*.84,1.)

def earth(x,y):
    v=.29+.05*math.sin(x*.042+math.cos(y*.047)*2)+.025*math.sin(x*.23+y*.31)
    v+=random.uniform(-.035,.035)
    v=round(v*31)/31
    return (v,v*.98,v*.86,1.)

# A hand-arranged botanical spray drawn into a small texture page, with pointed
# leaves, petioles and a branching stem; used on folded cards attached to twigs.
leaves=[]
for i in range(12):
    sy=20+i*18
    for side in [-1,1]:
        leaves.append((128+side*(28+i%3*17),sy+12,side*.65,26+random.random()*6,14+random.random()*5))
def foliage(x,y):
    a=0.; tone=.52
    if abs(x-(128+math.sin(y*.021)*3))<1.5 and 20<y<242: a=1.; tone=.35
    for cx,cy,angle,length,width in leaves:
        dx=x-cx;dy=y-cy
        u=dx*math.cos(angle)+dy*math.sin(angle)
        v=-dx*math.sin(angle)+dy*math.cos(angle)
        if abs(u)/length+v*v/(width*width)<1:
            a=1.;tone=.42+.16*(v/width*.5+.5)
            if abs(v)<.7: tone+=.08
    return (tone*.93,tone*.98,tone*.81,a)

def moss(x,y):
    a=0.
    for j in range(12):
        line=12+j*20+math.sin(y*.047+j*3)*5+math.sin(y*.13+j)*2
        end=115+(j*47)%140
        taper=min(1.,max(0.,(end-y)/42.))
        if y<end and abs(x-line)<(1.6+math.sin(y*.16+j)*.6)*taper: a=1.
        if y<end-12 and abs(x-line-6*math.sin(y*.19+j))<.7*taper: a=1.
    return (.46,.48,.40,a)

def ivy(x,y):
    u=(x-128)/110;v=(y-128)/108
    # Broad heart-shaped leaf, pointed end, shallow lobes and central vein.
    width=(1.-abs(v)**1.45)**.7 if abs(v)<1 else 0
    inside=abs(u)<width*(.81+.16*math.cos(v*9)) and not (v<-.65 and abs(u)<(-v-.65)*.40)
    value=.43+.045*(u*.5+.5)+.018*math.cos(v*5+u*3)
    # A fine midrib and a few branching veins, without the old chevron bands.
    if abs(u)<.014:value+=.055
    for vein in [-.35,.02,.39]:
        if abs(v-(vein+abs(u)*.54))<.014 and abs(u)<.7:value+=.025
    return (value*.94,value*.99,value*.85,1. if inside else 0.)

images={k:texture('Lowwater'+k,f) for k,f in [('Bark',bark),('Earth',earth),('Foliage',foliage),('Moss',moss),('Ivy',ivy)]}
mats={}
for name,im in images.items():
    mat=bpy.data.materials.new('Lowwater'+name);mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF')
    tx=mat.node_tree.nodes.new('ShaderNodeTexImage');tx.image=im;tx.interpolation='Closest'
    mat.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
    if name in ['Foliage','Moss','Ivy']:
        mat.node_tree.links.new(tx.outputs['Alpha'],bs.inputs['Alpha'])
        mat.surface_render_method='DITHERED'
    bs.inputs['Roughness'].default_value=.94
    mats[name]=mat

sun_vertices=[];sun_triangles=[];sun_uvs=[];sun_kinds=[]
class Batch:
    def __init__(self,name,kind): self.name=name;self.kind=kind;self.v=[];self.f=[];self.uv=[];self.colors=[]
    def face(self,points,uv=None,shade=1.):
        n=len(self.v);self.v.extend(points);self.f.append(tuple(range(n,n+len(points))))
        self.uv.extend(uv or [(0,0),(1,0),(1,1),(0,1)][:len(points)])
        self.colors.extend([(shade,shade,shade,1)]*len(points))
    def finish(self):
        if not self.v:return
        # Keep original Godot coordinates for a static, alpha-aware sun-depth
        # bake. This gives Compatibility fog real world-space canopy occlusion.
        if self.kind in ['Bark','Foliage','Ivy'] and 'Bank ferns' not in self.name:
            offset=len(sun_vertices)
            sun_vertices.extend(Vector(p) for p in self.v)
            sun_uvs.extend(Vector((uv[0],uv[1],0)) for uv in self.uv)
            for face in self.f:
                for j in range(1,len(face)-1):
                    sun_triangles.append((offset+face[0],offset+face[j],offset+face[j+1]))
                    sun_kinds.append(self.kind)
        mesh=bpy.data.meshes.new(self.name)
        mesh.from_pydata([(p[0],-p[2],p[1]) for p in self.v],[],self.f);mesh.update()
        ob=bpy.data.objects.new(self.name,mesh);bpy.context.collection.objects.link(ob)
        mesh.materials.append(mats[self.kind])
        uv=mesh.uv_layers.new(name='SurfaceUV')
        for p in mesh.polygons:
            p.use_smooth=self.kind=='Bark'
            for li in p.loop_indices: uv.data[li].uv=self.uv[mesh.loops[li].vertex_index]
        c=mesh.color_attributes.new(name='Shelter',type='FLOAT_COLOR',domain='POINT')
        for i,col in enumerate(self.colors):c.data[i].color=col
        return ob

def tube(batch, points, radii, sides=7, shade=.7):
    rings=[]
    for i,p in enumerate(points):
        p=Vector(p);direction=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        direction.normalize();axis=direction.cross(Vector((0,0,1)))
        if axis.length<.01:axis=direction.cross(Vector((0,1,0)))
        axis.normalize();other=direction.cross(axis).normalized()
        rings.append([p+radii[i]*(axis*math.cos(j*math.tau/sides)+other*math.sin(j*math.tau/sides)) for j in range(sides)])
    for i in range(len(rings)-1):
        for j in range(sides):
            k=(j+1)%sides
            batch.face([rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j]],[(j/sides*2,i*.65),(k/sides*2,i*.65),(k/sides*2,(i+1)*.65),(j/sides*2,(i+1)*.65)],shade)
    batch.face(list(reversed(rings[0])),[(0,0)]*sides,shade)
    batch.face(rings[-1],[(0,0)]*sides,shade)

def spray(batch,p,size,angle,shade=.8,tilt=.85):
    p=Vector(p);side=Vector((math.cos(angle),.12,math.sin(angle)))*size*.5
    up=Vector((math.sin(angle)*(.95-abs(tilt)*.6),tilt,-math.cos(angle)*(.95-abs(tilt)*.6)))*size
    if batch.name.startswith('Oak '):
        # Two irregular skylights between crowns, aligned with the sunlight.
        # Leave woody forks in place: their silhouettes naturally divide beams.
        sun_direction=Vector((-.40,.76,-.51)).normalized()
        for base,radius in [((5.5,.7,0),1.55),((-3.3,.7,8),1.35)]:
            delta=p+up*.5-Vector(base)
            across=delta-sun_direction*delta.dot(sun_direction)
            edge=radius+.20*math.sin(p.y*1.7+p.x*.7)
            if across.length<edge:return
    # Fold down the middle; each spray starts at a twig/branch point.
    batch.face([p-side,p,p+up,p+up-side*.65],[(0,0),(.5,0),(.5,1),(0,1)],shade)
    batch.face([p,p+side,p+up+side*.65,p+up],[(.5,0),(1,0),(1,1),(.5,1)],shade*.93)

moss_anchors=[]
def curtain(batch,p,length,width,angle):
    moss_anchors.append({'position':list(p),'length':length})
    p=Vector(p);side=Vector((math.cos(angle),0,math.sin(angle)))*width*.5
    for k in range(3):
        t=k/3;u=(k+1)/3
        a=p+Vector((.12*math.sin(t*3),-length*t,.08*t))
        b=p+Vector((.12*math.sin(u*3),-length*u,.08*u))
        # Pixel y=0 is the attachment end in the Blender-generated image.
        # glTF flips V: the imported root has UV.y=1 and the loose tip UV.y=0.
        side_a=side*(1.-t*.30);side_b=side*(1.-u*.30)
        batch.face([a-side_a,a+side_a,b+side_b,b-side_b],[(0,t),(1,t),(1,u),(0,u)],.68)

def drooping_leaf(batch,p,size,angle,shade):
    """A shallow convex leaf: its petiole is above its outward/downward tip."""
    p=Vector(p);out=Vector((math.cos(angle),0,math.sin(angle)))
    side=Vector((-math.sin(angle),0,math.cos(angle)))*size*.5
    spine=[p,p+out*size*.24+Vector((0,-size*.37,0)),p+out*size*.33+Vector((0,-size*.83,0))]
    for i in range(2):
        t=[0.,.44,1.][i];u=[0.,.44,1.][i+1]
        a=spine[i];b=spine[i+1]
        # Texture provides the heart-shaped shoulders and tapered terminal point.
        ridge_a=out*(math.sin(t*math.pi)*size*.045)
        ridge_b=out*(math.sin(u*math.pi)*size*.045)
        batch.face([a-side,a+ridge_a,b+ridge_b,b-side],[(0,t),(.5,t),(.5,u),(0,u)],shade)
        batch.face([a+ridge_a,a+side,b+side,b+ridge_b],[(.5,t),(1,t),(1,u),(.5,u)],shade*.98)

def canopy_limb(wood,leaf,hanging,origin,angle,reach,radius,upper=False):
    """A connected arch with lateral twigs carrying overlapping drooping sprays."""
    origin=Vector(origin);direction=Vector((math.cos(angle),0,math.sin(angle)))
    side=Vector((-math.sin(angle),0,math.cos(angle)))
    lift=2.3 if upper else 1.55
    path=[origin,
          origin+direction*reach*.22+Vector((0,lift*.68,0)),
          origin+direction*reach*.52+side*.35+Vector((0,lift,0)),
          origin+direction*reach*.79-side*.18+Vector((0,lift*.72,0)),
          origin+direction*reach+Vector((0,lift*.40,0))]
    tube(wood,path,[radius,radius*.79,radius*.51,radius*.27,.025],6,.64)
    for k in range(7):
        fraction=.19+k*.125
        stations=[0.,.22,.52,.79,1.]
        segment=next(i for i in range(4) if fraction<=stations[i+1])
        t=(fraction-stations[segment])/(stations[segment+1]-stations[segment])
        root=path[segment].lerp(path[segment+1],t)
        for flank in [-1,1]:
            tip=root+side*flank*random.uniform(1.3,2.9)+direction*random.uniform(.45,1.3)+Vector((0,random.uniform(-.35,.45),0))
            elbow=root.lerp(tip,.55)+Vector((0,.17,0))
            tube(wood,[root,elbow,tip],[radius*.22,radius*.11,.009],5,.62)
            for m in range(5):
                f=.14+m*.20
                p=root.lerp(elbow,f/.55) if f<.55 else elbow.lerp(tip,(f-.55)/.45)
                spray(leaf,p,random.uniform(2.3,3.4) if upper else random.uniform(1.8,2.6),angle+flank*(.45+m*.53),random.uniform(.46,.64),random.uniform(-.48,-.12))
        if not upper and k in [2,5]:
            curtain(hanging,root,random.uniform(.85,1.65),random.uniform(.45,.8),angle)

terrain=Batch('Silt banks and wooded ground','Earth')
for z in range(-110,47,2):
    for x in range(-62,63,2):
        ps=[(x,ground(x,z),z),(x,ground(x,z+2),z+2),(x+2,ground(x+2,z+2),z+2),(x+2,ground(x+2,z),z)]
        terrain.face(ps,[(a*.19,c*.19) for a,b,c in ps],.69+random.random()*.10)
terrain.finish()

trunks=[]
def tree(x,z,h,r,seed,ivy=False,hero=False):
    random.seed(seed);y=ground(x,z)-.08
    trunks.append({'x':x,'z':z,'radius':r*1.15})
    wood=Batch(f'Oak {seed} connected trunk roots and boughs','Bark')
    leaf=Batch(f'Oak {seed} twig foliage','Foliage')
    hanging=Batch(f'Oak {seed} hanging moss','Moss')
    climbing=Batch(f'Oak {seed} climbing ivy','Ivy')
    lean=random.uniform(-.9,.9)
    points=[(x,y,z),(x+.15,y+h*.18,z+.13),(x+lean,y+h*.40,z-.2),(x+lean*.8,y+h*.70,z+.4),(x+lean*1.6,y+h*.87,z+.6)]
    tube(wood,points,[r*1.6,r,r*.75,r*.43,.08],9,.69)
    for j in range(7):
        a=j*math.tau/7+random.uniform(-.2,.2);reach=r*random.uniform(2.3,4.)
        ex=x+math.cos(a)*reach;ez=z+math.sin(a)*reach
        tube(wood,[(x,y+.55,z),(x+math.cos(a)*reach*.5,ground(x,z)+.12,z+math.sin(a)*reach*.5),(ex,ground(ex,ez)-.03,ez)],[r*.46,r*.24,.025],6,.58)
    for j in range(8 if hero else 6):
        idx=1+j%3;origin=Vector(points[idx]);a=j*2.399+random.uniform(-.3,.3)
        # Lift low growth from a higher point on the actual trunk, including
        # the branch's attached twigs and moss, to clear the walking corridor.
        if idx==1:origin=origin.lerp(Vector(points[2]),.42)
        reach=h*(.67 if hero else .39)*random.uniform(.65,1.05)
        # Crooked, spreading limbs grow continuously out of the trunk.
        end=origin+Vector((math.cos(a)*reach,h*.18,math.sin(a)*reach))
        mid=origin.lerp(end,.50)+Vector((0,-.35,0))
        bent=origin.lerp(mid,.5)+Vector((0,.28,0))
        bend2=mid.lerp(end,.52)+Vector((math.sin(a)*.3,.22,math.cos(a)*.3))
        tube(wood,[origin,bent,mid,bend2,end],[r*.5,r*.40,r*.28,r*.17,.045],7,.72)
        for k in range(4):
            fraction=k/4
            attach=mid.lerp(bend2,fraction/.52) if fraction<.52 else bend2.lerp(end,(fraction-.52)/.48)
            tip=attach+Vector((math.cos(a+k*1.8)*reach*.35,.45-k*.25,math.sin(a+k*1.8)*reach*.35))
            tube(wood,[attach,attach.lerp(tip,.55),tip],[r*.16,r*.08,.015],5,.73)
            for m in range(12):
                pos=attach.lerp(tip,.18+m*.075)
                spray(leaf,pos,random.uniform(1.45,2.35),a+m*1.7,random.uniform(.50,.69),random.uniform(-.85,-.18))
            if k%2==0:curtain(hanging,attach,random.uniform(1.2,3.3),random.uniform(.55,1.2),a)
    # Broad upper crowns replace the exposed spear-like treetops. A separate
    # seed keeps the established lower branches, ivy and walking footprints fixed.
    saved_random=random.getstate()
    random.seed(seed+62000)
    for crown in range(6):
        angle=crown*math.tau/6+random.uniform(-.30,.30)
        origin=Vector(points[3]).lerp(Vector(points[4]),random.uniform(.0,.65))
        canopy_limb(wood,leaf,hanging,origin,angle,h*random.uniform(.39,.52),r*.37,True)
    # Higher, uneven arches keep enclosure while leaving broken skylights.
    if seed in [100,101,102,103]:
        toward=0. if x<center(z) else math.pi
        for arch in range(3):
            angle=toward+[-.56,.10,.60][arch]+random.uniform(-.07,.07)
            origin=Vector(points[2]).lerp(Vector(points[3]),.08+arch*.10)
            canopy_limb(wood,leaf,hanging,origin,angle,abs(x-center(z))+random.uniform(4.6,6.2),r*.39)
    random.setstate(saved_random)
    if ivy:
        # Rooted runners follow the actual bent trunk profile. Alternating leaves
        # overlap downward in loose skirts, rather than sticking upward like scales.
        levels=[0.,.18,.40,.70,1.];radii=[r*1.6,r,r*.75,r*.43,.08]
        def vine_point(f,angle):
            segment=next(i for i in range(4) if f<=levels[i+1])
            t=(f-levels[segment])/(levels[segment+1]-levels[segment])
            axis=Vector(points[segment]).lerp(Vector(points[segment+1]),t)
            radius=radii[segment]*(1-t)+radii[segment+1]*t+.055
            return axis+Vector((math.cos(angle)*radius,0,math.sin(angle)*radius))
        runners=28 if hero else 22
        for runner in range(runners):
            angle=runner*math.tau/runners+random.uniform(-.08,.08)
            maximum=random.uniform(.72,.91)
            count=int(h*maximum/.30)
            vine=[]
            for k in range(count+1):
                f=maximum*(k+random.uniform(-.35,.35) if 0<k<count else k)/count
                a=angle+.10*math.sin(k*.54+runner)
                p=vine_point(f,a)
                if k==0:p.y=ground(p.x,p.z)-.035
                vine.append(p)
                if k>1:
                    leaf_angle=a+random.uniform(-.4,.4)
                    drooping_leaf(climbing,p,random.uniform(.39,.65),leaf_angle,random.uniform(.52,.67))
            tube(wood,vine,[.018*(1-k/(count+2)) for k in range(count+1)],4,.55)
    wood.finish();leaf.finish();hanging.finish();climbing.finish()

tree(-5.8,10,15,1.3,100,True,True)
tree(10.8,6,17,1.55,101,True,True)
tree(-5,-9,19,1.0,102,True)
tree(10,-19,18,1.05,103,True)
tree(-6,-29,21,1.2,104,True)
tree(12,-42,18,1.,105,True)
random.seed(81)
locations=[]
for side in [-1,1]:
    for i in range(21):
        z=30-i*5.7+random.uniform(-2,2)
        x=center(z)+side*random.uniform(9,29)
        locations.append((x,z,random.uniform(12,22),random.uniform(.4,.9),200+len(locations)))
for x,z,h,r,seed in locations:tree(x,z,h,r,seed,seed%3==0)
for i in range(7):tree(-28+i*10,38,16,.65,300+i,True)

random.seed(772)
verge=Batch('Bank ferns and saplings','Foliage')
for i in range(4000):
    z=random.uniform(-98,38);x=random.uniform(-32,34);d=abs(x-center(z))
    # Keep a continuous right-bank walking lane, with fern-heavy margins.
    if d<3.6 or (3.8<x-center(z)<6.0):continue
    spray(verge,(x,ground(x,z)-.03,z),random.uniform(.35,1.15),random.random()*math.tau,random.uniform(.45,.72))
verge.finish()

# A fallen bough embedded in the far bank, with branching ends above ground.
fallen=Batch('Fallen oak on the western bank','Bark')
tube(fallen,[(-13,ground(-13,-17)+.3,-17),(-10,.9,-22),(-8,.65,-27)],[.48,.35,.10],8,.6)
tube(fallen,[(-10,.9,-22),(-12,1.5,-24),(-13,1.6,-26)],[.19,.12,.02],6,.65)
fallen.finish()

# Water is editable source geometry, with actual bends matching the bank formula.
water=Batch('Quiet canal surface','Earth')
for z in range(-110,47,2):
    water.face([(center(z)-2.95,-.12,z),(center(z+2)-2.95,-.12,z+2),(center(z+2)+2.95,-.12,z+2),(center(z)+2.95,-.12,z)])
ob=water.finish();ob.name='CanalWater'

# Bake first opaque canopy depth from the sun. Transparent parts of each leaf
# are skipped using the same texture alpha cutoff as the runtime material.
# RG stores a 16-bit linear distance, avoiding 8-bit depth stair steps.
sun=Vector((-.40,.76,-.51)).normalized()
sun_u=Vector((0,1,0)).cross(sun).normalized();sun_v=sun.cross(sun_u).normalized()
sun_center=Vector((0,0,-25));sun_span=160.;sun_range=200.;sun_size=384
bvh=BVHTree.FromPolygons(sun_vertices,sun_triangles,all_triangles=True)
alpha={kind:list(images[kind].pixels)[3::4] for kind in ['Foliage','Ivy']}
depth_pixels=[]
for iy in range(sun_size):
    for ix in range(sun_size):
        start=sun_center+sun_u*((ix+.5)/sun_size-.5)*sun_span+sun_v*((iy+.5)/sun_size-.5)*sun_span+sun*100.
        ray_start=start.copy();depth=1.
        for intersection in range(64):
            hit,normal,index,distance=bvh.ray_cast(ray_start,-sun,sun_range)
            if hit is None:break
            kind=sun_kinds[index]
            opaque=kind=='Bark'
            if not opaque:
                a,b,c=sun_triangles[index]
                uv=barycentric_transform(hit,sun_vertices[a],sun_vertices[b],sun_vertices[c],sun_uvs[a],sun_uvs[b],sun_uvs[c])
                opaque=alpha[kind][int((uv.y%1)*256)*256+int((uv.x%1)*256)]>=.5
            if opaque:
                depth=min(1.,max(0.,(start-hit).dot(sun)/sun_range));break
            ray_start=hit-sun*.008
        packed=depth*255.;depth_pixels.extend((math.floor(packed)/255.,packed%1,0.,1.))
sun_image=bpy.data.images.new('LowwaterSunDepth',width=sun_size,height=sun_size,alpha=True)
sun_image.colorspace_settings.name='Non-Color'
sun_image.pixels=depth_pixels
sun_image.filepath_raw=str(ROOT/'assets/textures/LowwaterSunDepth.png');sun_image.file_format='PNG';sun_image.save()
print('LOWWATER_SUN_DEPTH_READY',sun_size)

(ROOT/'assets/data/lowwater_layout.json').write_text(json.dumps({'trees':trunks,'moss_anchors':moss_anchors,'water_level':-.12,'walk_bounds':[-26,28,-89,32]},indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/lowwater.blend'))
# Preserve named editable parts in .blend; batch static GLB by material.
for kind in mats:
    bpy.ops.object.select_all(action='DESELECT')
    objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name!='CanalWater' and o.data.materials[0]==mats[kind]]
    for o in objs:o.select_set(True)
    if objs:
        bpy.context.view_layer.objects.active=objs[0]
        if len(objs)>1:bpy.ops.object.join()
        objs[0].name='Lowwater'+kind
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/lowwater.glb'),export_format='GLB',export_vertex_color='NAME',export_vertex_color_name='Shelter',export_all_vertex_colors=False)

# Seamless original stereo air, insect trills and distant soft bird notes.
random.seed(931);rate=22050;seconds=16;n=rate*seconds
with wave.open(str(ROOT/'assets/audio/lowwater_air.wav'),'wb') as out:
    out.setnchannels(2);out.setsampwidth(2);out.setframerate(rate)
    data=bytearray();air=0.
    for i in range(n):
        t=i/rate;air=air*.985+random.uniform(-1,1)*.015
        envelope=math.sin(math.pi*t/seconds)**2
        trill=(.5+.5*math.sin(math.tau*t*1.5))**7
        insect=.025*math.sin(math.tau*2816*t+1.7*math.sin(math.tau*t*7))*trill
        bird=0.
        for at in [3.1,3.6,10.3,11.]:
            dt=t-at
            if 0<dt<.38:bird+=.075*math.sin(math.pi*dt/.38)**2*math.sin(math.tau*(1250*dt+520*dt*dt))
        for side in [0,1]:
            value=(air*.75+insect*(.8 if side else 1)+bird*(1 if side else .65))*envelope
            data.extend(struct.pack('<h',int(max(-1,min(1,value))*32767)))
    out.writeframes(data)
print('LOWWATER_READY',len(trunks),'rooted trees; editable Blender source and GLB exported')
