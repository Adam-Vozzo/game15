"""Signal Grove. Original, deterministic forest and object-anchored light cells.
Run Blender --background --python blender/build_signal.py to regenerate all art.
Coordinates below use Godot axes; the editable .blend retains named tree groups.
"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
random.seed(8127)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def trail(z): return -2.9 + math.sin(z*.095)*2.1
def ground(x,z):
    # One gentle hillside with broad irregular relief, no repeated wave ridges.
    return .045*x + .22*math.exp(-((x-14)/19)**2-((z+24)/27)**2) - .14*math.exp(-((x+18)/16)**2-((z-9)/23)**2) - .10*math.exp(-((x-trail(z))/1.65)**2)

def texture(name, pixels):
    im=bpy.data.images.new('Signal'+name,width=256,height=256,alpha=True)
    im.pixels=pixels; im.filepath_raw=str(ROOT/'assets/textures'/('Signal'+name+'.png'))
    im.file_format='PNG'; im.save(); return im

images={}
earth_rng=random.Random(7138)
earth_patches=[(earth_rng.uniform(0,256),earth_rng.uniform(0,256),earth_rng.uniform(12,42),earth_rng.uniform(-.025,.025)) for _ in range(30)]
for kind in ['Bark','Earth','Stone']:
    pix=[]
    for y in range(256):
        for x in range(256):
            n=random.uniform(-.045,.045)
            if kind=='Bark':
                v=.24+n+.045*math.sin(x*.31+math.sin(y*.065))-.075*max(0,math.sin(x*.68+math.sin(y*.029)*2))**10
                col=(v*.84,v,v*.94)
            elif kind=='Earth':
                v=.23+n*.65
                for px,py,radius,shade in earth_patches:
                    dx=min(abs(x-px),256-abs(x-px));dy=min(abs(y-py),256-abs(y-py))
                    v+=shade*math.exp(-(dx*dx+dy*dy)/(radius*radius))
                if random.random()<.10:v+=.08
                col=(v*.90,v,v*.91)
            else:
                v=.29+n+.055*math.sin(x*.07+math.sin(y*.09))
                col=(v*.91,v,v*.98)
            pix.extend((*[round(c*31)/31 for c in col],1.))
    if kind=='Earth':
        # Small, irregular litter marks survive mip filtering without directional
        # waves. Each decomposing leaf/needle has its own orientation and tone.
        litter_rng=random.Random(6312)
        for mark in range(420):
            cx=litter_rng.randrange(256);cy=litter_rng.randrange(256)
            angle=litter_rng.random()*math.tau;length=litter_rng.uniform(2,7)
            width=litter_rng.uniform(.45,1.7);tone=litter_rng.uniform(.20,.34)
            for dy in range(-8,9):
                for dx in range(-8,9):
                    u=dx*math.cos(angle)+dy*math.sin(angle);v=-dx*math.sin(angle)+dy*math.cos(angle)
                    if abs(u)/length+(v/width)**2<1:
                        at=(((cy+dy)%256)*256+(cx+dx)%256)*4
                        pix[at:at+4]=[tone*.92,tone,tone*.84,1.]
    images[kind]=texture(kind,pix)

# Needle spray, drawn as connected stemlets with tapered pairs of needles.
pix=[0.]*(256*256*4)
def line(a,b,width,col):
    length=max(1,int(math.dist(a,b)*2))
    for step in range(length+1):
        t=step/length; x=round(a[0]+(b[0]-a[0])*t); y=round(a[1]+(b[1]-a[1])*t)
        for dy in range(-width,width+1):
            for dx in range(-width,width+1):
                if 0<=x+dx<256 and 0<=y+dy<256:
                    at=((y+dy)*256+x+dx)*4;pix[at:at+4]=[*col,1.]
line((128,3),(124,250),1,(.19,.25,.22))
for i in range(15):
    y=14+i*14
    for side in [-1,1]:
        a=(128,y); b=(128+side*(72*(1-y/310)+random.uniform(-9,9)),y+43)
        line(a,b,0,(.20,.29,.25))
        for j in range(11):
            t=j/11; p=(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)
            for s in [-1,1]:
                tone=random.uniform(.28,.46)
                line(p,(p[0]+side*13+s*8,p[1]+14-s*10),1 if (i+j)%4==0 else 0,(tone*.76,tone,tone*.87))
images['Needles']=texture('Needles',pix)
mats={}
for kind in ['Bark','Earth','Stone','Needles','Pixels','Drift']:
    mat=bpy.data.materials.new('Signal'+kind);mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.96
    if kind in images:
        tx=mat.node_tree.nodes.new('ShaderNodeTexImage');tx.image=images[kind]
        mat.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
        if kind=='Needles':
            mat.node_tree.links.new(tx.outputs['Alpha'],bs.inputs['Alpha']);mat.surface_render_method='DITHERED'
    mats[kind]=mat

class Batch:
    def __init__(self,name,kind):self.name=name;self.kind=kind;self.v=[];self.f=[];self.uv=[];self.c=[]
    def face(self,points,uv=None,color=(1,1,1,1)):
        n=len(self.v);self.v.extend(points);self.f.append(tuple(range(n,n+len(points))))
        self.uv.extend(uv or [(0,0),(1,0),(1,1),(0,1)][:len(points)])
        self.c.extend([color]*len(points))
    def finish(self):
        if not self.v:return
        mesh=bpy.data.meshes.new(self.name);mesh.from_pydata([(p[0],-p[2],p[1]) for p in self.v],[],self.f);mesh.update()
        ob=bpy.data.objects.new(self.name,mesh);bpy.context.collection.objects.link(ob);mesh.materials.append(mats[self.kind])
        uv=mesh.uv_layers.new(name='SurfaceUV')
        for poly in mesh.polygons:
            for li in poly.loop_indices:uv.data[li].uv=self.uv[mesh.loops[li].vertex_index]
        colors=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
        for i,c in enumerate(self.c):colors.data[i].color=c
        return ob

def tube(batch,pts,radii,sides=6):
    rings=[]
    for i,p in enumerate(pts):
        direction=(Vector(pts[min(i+1,len(pts)-1)])-Vector(pts[max(i-1,0)])).normalized()
        axis=direction.cross(Vector((0,0,1))).normalized();other=direction.cross(axis)
        rings.append([Vector(p)+radii[i]*(axis*math.cos(j*math.tau/sides)+other*math.sin(j*math.tau/sides)) for j in range(sides)])
    for i in range(len(pts)-1):
        for j in range(sides):
            k=(j+1)%sides
            batch.face([rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j]],[(j/sides,i),(k/sides,i),(k/sides,i+1),(j/sides,i+1)])

cells={};SPACING=.105
def cell(p,red=0.):
    key=tuple(round(v/SPACING) for v in p)
    if key not in cells or red>cells[key]:cells[key]=red
def light_line(a,b,red=0.,spread=0.):
    for j in range(max(2,int((b-a).length/SPACING*1.5))):
        t=j/max(1,int((b-a).length/SPACING*1.5)-1)
        p=a.lerp(b,min(1,t));cell(p,red)
        if spread:
            cell(p+Vector((random.uniform(-spread,spread),random.uniform(-spread,spread),random.uniform(-spread,spread))),red)

trees=[];pendant_roots=[];pendant_tips=[]

def pendant(batch,root,direction,length,width):
    # Folded, tapering growth hangs from a real twig. UV=0 is the attachment;
    # export flips it to UV.y=1 in Godot. Each strip follows gravity.
    side=Vector((-direction.z,0,direction.x)).normalized()*width
    points=[]
    for t in [0.,.48,1.]:
        points.append(root+direction*(length*.26*t)+Vector((0,-length*t,0)))
    widths=[.07,.62,.035]
    for i in range(2):
        a=points[i];b=points[i+1];v0=i/2;v1=(i+1)/2
        ridge=direction*width*.17
        batch.face([a-side*widths[i],a+ridge,b+ridge,b-side*widths[i+1]],[(0,v0),(.5,v0),(.5,v1),(0,v1)])
        batch.face([a+ridge,a+side*widths[i],b+side*widths[i+1],b+ridge],[(.5,v0),(1,v0),(1,v1),(.5,v1)])
    pendant_roots.append(list(root));pendant_tips.append(list(points[-1]))
    return points

def tree(x,z,h,r,seed,feature=False):
    rng=random.Random(seed);base=ground(x,z)
    wood=Batch(('Feature' if feature else 'Fir %03d'%seed)+' rooted wood','Bark')
    needles=Batch(('Feature' if feature else 'Fir %03d'%seed)+' needles','Needles')
    def trunk(y):return Vector((x+math.sin(y*.35+seed)*.09*y/h,base+y,z+math.sin(y*.23)*.18))
    pts=[trunk(h*i/8) for i in range(9)]
    tube(wood,pts,[r*(1-i/8)**1.05+.014 for i in range(9)],8)
    for j in range(6):
        a=j*math.tau/6;tip=Vector((x+math.cos(a)*r*2.7,0,z+math.sin(a)*r*2.7));tip.y=ground(tip.x,tip.z)-.04
        tube(wood,[trunk(.42),tip],[r*.47,.025],5)
    if feature:
        for i in range(8):
            for side in range(6):
                a=side*math.tau/6;off=Vector((math.cos(a),0,math.sin(a)))
                light_line(pts[i]+off*(r*(1-i/8)+.02),pts[i+1]+off*(r*(1-(i+1)/8)+.02),.96)
    levels=22 if feature else 13
    for level in range(levels):
        y=h*((.15 if feature else .22)+level/levels*(.81 if feature else .74));length=h*.29*(1-y/h)**.73
        count=7 if feature else 5
        for j in range(count):
            a=j*math.tau/count+level*2.39+rng.uniform(-.22,.22)
            direction=Vector((math.cos(a),0,math.sin(a)));cross=Vector((-math.sin(a),0,math.cos(a)))
            length2=length*rng.uniform(.68,1.16)
            root=trunk(y);mid=root+direction*length2*.5+Vector((0,-length2*.13,0));end=root+direction*length2+Vector((0,rng.uniform(-.20,.035)*length2,0))
            tube(wood,[root,mid,end],[r*.27*(1-y/h)+.015,.033,.006],5)
            if feature:light_line(root,mid,.75);light_line(mid,end,.36)
            for k in range(1,8 if feature else 6):
                t=k/(8 if feature else 6);attach=mid.lerp(end,(t-.5)*2) if t>.5 else root.lerp(mid,t*2)
                for side in [-1,1]:
                    tip=attach+direction*length2*.19+cross*side*length2*.26*(1-t*.6)+Vector((0,-length2*.12,0))
                    if feature or abs(x)+abs(z)<28: tube(wood,[attach,tip],[.016,.003],4)
                    axis=(tip-attach);width=cross*length2*.13
                    needles.face([attach-width*.25,attach+width*.25,tip+width,tip-width])
                    for u in ([.85] if k%2==1 else []):
                        anchor=attach.lerp(tip,u)
                        drop=min(rng.uniform(.55,.95)*max(.35,length2*.30),anchor.y-ground(anchor.x,anchor.z)-.32)
                        hanging=pendant(needles,anchor,(direction+cross*side*.6).normalized(),max(.12,drop),max(.18,length2*.28))
                        if feature:
                            for m in range(len(hanging)-1):light_line(hanging[m],hanging[m+1],.04)
                            for m in range(7):
                                q=hanging[0].lerp(hanging[-1],m/7)
                                for s in [-1,1]:
                                    light_line(q,q+cross*s*length2*.065+Vector((0,-drop*.11,0)),0.)
                    if feature:
                        light_line(attach,tip,.12)
                        for n in range(7):
                            q=attach.lerp(tip,n/7)
                            for s in [-1,1]:
                                light_line(q,q+direction*.15+cross*s*length2*.045+Vector((0,.05,0)),0.)
    wood.finish();needles.finish();trees.append(dict(x=x,z=z,radius=r+.24,height=h,feature=feature))

terrain=Batch('Continuous sloping forest floor','Earth')
for z in range(-88,43,1):
    for x in range(-48,49,1):
        pts=[(x,ground(x,z),z),(x,ground(x,z+1),z+1),(x+1,ground(x+1,z+1),z+1),(x+1,ground(x+1,z),z)]
        terrain.face(pts,[(p[0]*.5,p[2]*.5) for p in pts])
terrain.finish()
tree(1.6,-3,11.4,.30,71,True)
positions=[(-9,7,20), (15,3,24),(-7,-11,23),(10,-15,25),(-13,-22,26),(4,-23,24),(-16,17,25),(17,15,24)]
for iz,z in enumerate(range(-73,36,10)):
    for ix,x in enumerate(range(-39,41,9)):
        x+=random.uniform(-2.8,2.8);z1=z+random.uniform(-3,3)
        if abs(x-trail(z1))<3.3 or (Vector((x,z1))-Vector((1.6,-3))).length<8:continue
        positions.append((x,z1,random.uniform(17,28)))
for i,(x,z,h) in enumerate(positions):tree(x,z,h,random.uniform(.23,.48),100+i)

lights=Batch('Feature tree light cells','Pixels')
for key,red in cells.items():
    p=Vector(key)*SPACING;s=.027
    phase=random.random();color=(red,random.uniform(.72,1),random.random(),1)
    # Editable square cells at fixed 3D anchors. Runtime orients each square to
    # the view without moving its center or resampling its surface coordinates.
    lights.face([p+Vector((-s,-s,0)),p+Vector((s,-s,0)),p+Vector((s,s,0)),p+Vector((-s,s,0))],color=color)
lights.finish()

drift=Batch('Rising detached pixel fragments','Drift')
for key in random.sample(list(cells),min(1600,len(cells))):
    p=Vector(key)*SPACING;s=.027
    phase=random.random();seed=random.random()
    color=(cells[key],random.uniform(.65,1),random.random(),1)
    drift.face([p+Vector((-s,-s,0)),p+Vector((s,-s,0)),p+Vector((s,s,0)),p+Vector((-s,s,0))],color=color)
drift.finish()

verge=Batch('Understory needle ferns','Needles')
for i in range(2300):
    x=random.uniform(-42,43);z=random.uniform(-78,36)
    if abs(x-trail(z))<1.35:continue
    p=Vector((x,ground(x,z)-.02,z));size=random.uniform(.26,.66)
    for j in range(5):
        a=j*math.tau/5+i;d=Vector((math.cos(a),0,math.sin(a)));w=Vector((-d.z,0,d.x))*size*.24
        tip=p+d*size+Vector((0,size*.44,0));verge.face([p-w*.1,p+w*.1,tip+w,tip-w])
verge.finish()
stones=Batch('Scattered moss stones','Stone');rocks=[]
for i in range(140):
    x=random.uniform(-33,34);z=random.uniform(-63,29)
    if abs(x-trail(z))<1.6:continue
    r=random.uniform(.16,.60);p=Vector((x,ground(x,z)-.10,z))
    ring=[p+Vector((math.cos(j*math.tau/7)*r,random.uniform(.04,.18),math.sin(j*math.tau/7)*r*.8)) for j in range(7)]
    top=p+Vector((r*.13,r*.75,0))
    for j in range(7):stones.face([ring[j],ring[(j+1)%7],top],[(0,0),(1,0),(.5,1)])
    rocks.append(dict(x=x,z=z,radius=r))
stones.finish()
(ROOT/'assets/data/signal_layout.json').write_text(json.dumps(dict(trees=trees,rocks=rocks,pixel_count=len(cells),pixel_spacing=SPACING,pendant_count=len(pendant_roots)),indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/signal_grove.blend'))
# Material batches reduce draw calls; editable tree objects remain in the .blend.
for kind in mats:
    bpy.ops.object.select_all(action='DESELECT')
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==mats[kind]]
    for o in objects:o.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:bpy.ops.object.join()
        objects[0].name='Signal'+kind
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/signal_grove.glb'),export_format='GLB',export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False)
print('SIGNAL_READY',len(trees),'rooted firs;',len(cells),'fixed light cells')
