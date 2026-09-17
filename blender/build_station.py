"""Verdant Terminus. All scene geometry is authored here in Godot coordinates.
Run prepare_station_assets.py first to convert the local Hunyuan3D outputs.
Then Blender --background --python blender/build_station.py.
"""
import bpy, math, random, json, wave, struct
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
R=random.Random(91415)
residents=[dict(x=-1.1,y=1.,z=12.,yaw=.24,scale=1.,phase=0.),dict(x=12.1,y=1.,z=-4.,yaw=-.65,scale=.85,phase=18.),dict(x=-12.4,y=1.,z=-16.,yaw=.6,scale=.92,phase=33.)]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
mats={}
palette={'Stone':(.45,.49,.41),'Plaster':(.68,.69,.56),'Paving':(.47,.50,.40),'Edge':(.70,.64,.33),'Iron':(.17,.26,.24),'Rust':(.36,.23,.15),'Wood':(.27,.31,.16),'Bark':(.28,.29,.19),'Earth':(.19,.30,.10),'Leaf':(.23,.44,.09),'Grass':(.27,.46,.10),'Flower':(.80,.63,.57),'Water':(.07,.54,.53),'Spill':(.58,.89,.84),'Mote':(.96,.94,.70),'Dark':(.08,.17,.15)}
for name,col in palette.items():
    mat=bpy.data.materials.new('Station'+name);mat.use_nodes=True;mat.diffuse_color=(*col,1)
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*col,1);bs.inputs['Roughness'].default_value=.85
    if name in ['Stone','Plaster','Paving','Bark','Iron','Wood','Earth']:
        pix=[]
        for y in range(256):
            for x in range(256):
                n=.024*math.sin(x*.055+math.sin(y*.064)*1.8)+.018*math.sin(y*.074-x*.043)+R.uniform(-.017,.017)
                if name=='Bark':n+=.035*math.sin(x*.20+math.sin(y*.028)*2)+(-.06 if (x+int(5*math.sin(y*.03)))%47<3 else 0)
                if name=='Wood':n+=.026*math.sin(x*.46+math.sin(y*.025))
                if name in ['Stone','Plaster'] and R.random()<.025:n-=R.uniform(.03,.10)
                pix.extend([max(0,min(1,round((v+n)*31)/31)) for v in col]+[1])
        im=bpy.data.images.new('Station'+name,width=256,height=256);im.pixels=pix;im.filepath_raw=str(ROOT/'assets/textures'/f'Station{name}.png');im.file_format='PNG';im.save()
        tx=mat.node_tree.nodes.new('ShaderNodeTexImage');tx.image=im;mat.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
    mats[name]=mat

class Batch:
    def __init__(self,name,kind):self.name=name;self.kind=kind;self.v=[];self.f=[];self.uv=[];self.colors=[]
    def face(self,pts,uv=None,tint=1.,wind=0.):
        at=len(self.v);self.v.extend(pts);self.f.append(tuple(range(at,at+len(pts))))
        if uv is None:
            normal=(Vector(pts[1])-Vector(pts[0])).cross(Vector(pts[-1])-Vector(pts[0]));axis=max(range(3),key=lambda j:abs(normal[j]));axes=[j for j in range(3) if j!=axis]
            uv=[(p[axes[0]]*.33,p[axes[1]]*.33) for p in pts]
        self.uv.extend(uv)
        rgb=(tint,tint,tint) if isinstance(tint,(int,float)) else tuple(tint)
        weights=[wind]*len(pts) if isinstance(wind,(int,float)) else wind
        self.colors.extend([(*rgb,w) for w in weights])
    def finish(self):
        if not self.v:return
        me=bpy.data.meshes.new(self.name);me.from_pydata([(p[0],-p[2],p[1]) for p in self.v],[],self.f);me.update()
        ob=bpy.data.objects.new(self.name,me);bpy.context.collection.objects.link(ob);me.materials.append(mats[self.kind])
        uv=me.uv_layers.new(name='FixedSurfaceUV');colors=me.color_attributes.new(name='Shelter',type='FLOAT_COLOR',domain='CORNER')
        for poly in me.polygons:
            for li in poly.loop_indices:
                vi=me.loops[li].vertex_index;uv.data[li].uv=self.uv[vi];colors.data[li].color=self.colors[vi]
        return ob
active={}
def group(name):
    global active
    for b in active.values():b.finish()
    active={k:Batch(name+' '+k,k) for k in mats}
def box(k,c,s,tint=1.):
    x,y,z=c;a,b,d=[v/2 for v in s];p=[(x-a,y-b,z-d),(x+a,y-b,z-d),(x+a,y+b,z-d),(x-a,y+b,z-d),(x-a,y-b,z+d),(x+a,y-b,z+d),(x+a,y+b,z+d),(x-a,y+b,z+d)]
    for f in [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(3,7,6,2),(0,1,5,4)]:active[k].face([p[i] for i in f],tint=tint)
def rod(k,a,b,r=.06,end=None,sides=7,tint=1.):
    a=Vector(a);b=Vector(b);d=(b-a).normalized();axis=d.cross(Vector((0,0,1)))
    if axis.length<.01:axis=d.cross(Vector((1,0,0)))
    axis.normalize();other=d.cross(axis);end=r if end is None else end
    rings=[[p+rr*(axis*math.cos(i*math.tau/sides)+other*math.sin(i*math.tau/sides)) for i in range(sides)] for p,rr in [(a,r),(b,end)]]
    for i in range(sides):j=(i+1)%sides;active[k].face([rings[0][i],rings[0][j],rings[1][j],rings[1][i]],tint=tint)
    active[k].face(list(reversed(rings[0])),tint=tint);active[k].face(rings[1],tint=tint)
def path(k,pts,r=.05,end=None):
    for i in range(len(pts)-1):
        f=i/(len(pts)-1);g=(i+1)/(len(pts)-1);e=r if end is None else end
        rod(k,pts[i],pts[i+1],r*(1-f)+e*f,r*(1-g)+e*g)
def leaf(p,angle,length=.5,width=.17,kind='Leaf',droop=.16,tint=1.,wind=.7):
    p=Vector(p);d=Vector((math.cos(angle),0,math.sin(angle)));side=Vector((-d.z,0,d.x))
    mid=p+d*length*.5+Vector((0,.10,0));tip=p+d*length+Vector((0,-droop,0))
    pts=[p,mid-side*width,mid+Vector((0,.065,0)),mid+side*width,tip]
    weights=[0,.5,.5,.5,1]
    for f in [(0,1,2),(0,2,3),(1,4,2),(2,4,3)]:active[kind].face([pts[i] for i in f],tint=tint,wind=[weights[i]*wind for i in f])
def grass(x,y,z,scale=1.,surface=None,anchors=None):
    for j in range(6):
        a=R.random()*math.tau;h=R.uniform(.20,.56)*scale;w=.045*scale;p=Vector((x+R.uniform(-.13,.13),y,z+R.uniform(-.13,.13)));d=Vector((math.cos(a),0,math.sin(a)));s=Vector((-d.z,0,d.x))*w
        left=p-s;right=p+s
        if surface:
            # Sample both fixed base vertices after blade jitter and width, so
            # even tufts on sloped roof shoulders cannot hover over the shell.
            ly=surface(left.x,left.z);ry=surface(right.x,right.z)
            if ly is None or ry is None:continue
            left.y=ly-.012;right.y=ry-.012;p=(left+right)*.5
            anchors.extend([list(left),list(right)])
        mid=p+Vector((0,h*.62,0))+d*h*.10;tip=p+Vector((0,h,0))+d*h*.38
        col=R.uniform(.78,1.18)
        active['Grass'].face([left,right,mid+s*.6,mid-s*.6],[(0,0),(1,0),(1,.6),(0,.6)],tint=col,wind=[0,0,.4,.4])
        active['Grass'].face([mid-s*.6,mid+s*.6,tip],[(0,.6),(1,.6),(.5,1)],tint=col,wind=[.4,.4,1.])
def fern(x,y,z,scale=1.):
    for j in range(7):
        a=j*math.tau/7+R.uniform(-.15,.15);d=Vector((math.cos(a),0,math.sin(a)));base=Vector((x,y,z));last=base
        for i in range(1,7):
            f=i/6;p=base+d*f*scale+Vector((0,math.sin(f*2.6)*scale*.62,0));rod('Leaf',last,p,.009);last=p
            for s in [-1,1]:leaf(p,a+s*1.13,.28*scale*(1-f*.72),.085*scale*(1-f*.7),droop=.06,tint=R.uniform(.75,1.1))
def vine(anchor,length,seed):
    rr=random.Random(seed);x,y,z=anchor;pts=[]
    for i in range(int(length/.20)+1):
        f=i*.20;pts.append((x+(math.sin(f*1.3+seed)-math.sin(seed))*.16,y-f,z+math.sin(f*.8)*.13))
    path('Bark',pts,.025,.008)
    for i,p in enumerate(pts):
        if i%2==0:
            for s in [-1,1]:leaf(p,s*1.5+seed,.25+rr.random()*.17,.13,droop=.17,tint=rr.uniform(.8,1.14),wind=.4)
def crown(p,r=2.,seed=0):
    rr=random.Random(seed)
    p=Vector(p)
    for b in range(6):
        a=b*2.4+rr.uniform(-.4,.4);d=Vector((math.cos(a),0,math.sin(a)))
        mid=p+d*r*.42+Vector((0,rr.uniform(.15,.7),0));tip=p+d*r*rr.uniform(.7,1.0)+Vector((0,rr.uniform(-.4,.4),0))
        path('Bark',[p,mid,tip],.07,.016)
        for i in range(7):
            f=.22+i*.11;stem=mid.lerp(tip,f);ang=a+rr.choice([-1,1])*rr.uniform(.65,1.35)
            end=stem+Vector((math.cos(ang)*r*.37,rr.uniform(-.26,.34),math.sin(ang)*r*.37))
            rod('Bark',stem,end,.016,.004,sides=5)
            for j in range(5):
                root=stem.lerp(end,(j+1)/5)
                leaf(root,ang+(-1 if j%2 else 1)*.90,rr.uniform(.46,.80),rr.uniform(.19,.30),tint=rr.uniform(.75,1.17),droop=rr.uniform(.08,.25))
def tree(x,y,z,h,seed):
    rr=random.Random(seed);base=Vector((x,y,z));bend=Vector((rr.uniform(-.8,.8),h,rr.uniform(-.6,.6)))
    pts=[base,base+bend*.32+Vector((.2,0,0)),base+bend*.66,base+bend]
    path('Bark',pts,h*.085,.095)
    for j in range(7):
        a=j*math.tau/7;d=Vector((math.cos(a),0,math.sin(a)));path('Bark',[base+Vector((0,.8,0)),base+d*.7+Vector((0,.12,0)),base+d*1.65+Vector((0,-.08,0))],h*.08,.035)
    for j in range(7):
        a=j*2.4;start=base+bend*(.52+j*.055);end=start+Vector((math.cos(a)*h*.35,h*.10,math.sin(a)*h*.35));mid=start.lerp(end,.54)+Vector((0,.32,0));path('Bark',[start,mid,end],.17,.035);crown(end,h*.22,seed+j)
    crown(base+bend,h*.23,seed+11)

walk=[[-3.8,3.8,-38,24,1.0],[-18,-10.5,-38,24,1.0],[10.5,18,-38,24,1.0],[-18,18,20,28,1.0]]
obstacles=[];trunks=[];guards=[];spills=[]
group('Submerged track beds')
box('Earth',(0,-1.30,-7),(44,.6,84))
for x in [-7.15,7.15]:
    for z in range(-45,27):
        box('Wood',(x,-.91,z),(3.2,.17,.26),R.uniform(.7,1))
    for dx in [-.78,.78]:
        box('Rust',(x+dx,-.73,-9),(.10,.25,74));box('Iron',(x+dx,-.59,-9),(.17,.07,74))
    box('Water',(x,.22,-8),(6.7,.025,72))
group('Platforms masonry and chipped paving')
for index,(x0,x1,z0,z1,y) in enumerate(walk):
    if index<3:z1=20
    box('Stone',((x0+x1)/2,-.03,(z0+z1)/2),(x1-x0,2.0,z1-z0))
    # Complete sides and footings continue below the water. Paving top is y=1.
    for x in range(math.ceil(x0),math.floor(x1)+1):
        for z in range(int(z0),int(z1)):
            cx=min(x1-.30,max(x0+.3,x+R.uniform(-.04,.04)));w=min(.94,2*(x1-cx),2*(cx-x0))
            if w<.08:continue
            box('Paving',(cx,.95,z+.5),(w,.1,.95),R.uniform(.88,1.11))
    if index<3:
        for x in [x0+.15,x1-.15]:
            for z in range(int(z0),20):
                box('Edge',(x,1.008,z+.48),(.28,.035,.92),R.uniform(.80,1.05))
    box('Stone',((x0+x1)/2,.42,z0),(x1-x0,.15,.12))
# Guardrails follow the same external boundaries used by walking.
for x0,x1,z0,z1,y in walk[:3]:
    for x in [x0,x1]:guards.append([[x,z0],[x,20]])
    guards.append([[x0,z0],[x1,z0]])
guards.extend([[[-18,20],[-18,28]],[[18,20],[18,28]],[[-18,28],[18,28]]])
group('Platform edge safety rails')
for a,b in guards:
    av=Vector((a[0],1.04,a[1]));bv=Vector((b[0],1.04,b[1]));length=(bv-av).length
    rod('Iron',av+Vector((0,.66,0)),bv+Vector((0,.66,0)),.028)
    for j in range(math.ceil(length/2.4)+1):
        p=av.lerp(bv,min(1,j*2.4/length));rod('Iron',p,p+Vector((0,.72,0)),.036);box('Iron',p,(.15,.07,.15))
group('Ruin perimeter and grounded roof columns')
for s in [-1,1]:
    x=s*19.2;box('Stone',(x,2,-8),(1,6,78))
    for z in range(-40,30,10):
        box('Plaster',(x,6.2,z),(1.32,14.4,1.25));box('Stone',(x,1.38,z),(1.65,4.7,1.7));box('Stone',(x,10.9,z),(1.80,.46,1.8))
        # Framed upper wall openings preserve a clear view through the ruined shell.
        box('Plaster',(x,11.8,z+4.2),(.75,1.2,7.2));box('Stone',(x,6.3,z+4.2),(.92,.33,7.2))
        for dz in [1.0,7.8]:box('Iron',(x,9,z+dz),(.12,5.1,.13))
    for z in [-30,-10,10]:
        # Side rafters break off over the tracks; the centre is entirely open sky.
        rod('Rust',(x,12,z),(s*11.5,10.8,z+.5),.18,sides=6)
        rod('Iron',(x,10.7,z),(s*13.6,11.15,z+.38),.08)
        for j in range(6):vine((s*(12+j),11.05+j*.15,z+.4),R.uniform(1,4),j+int(z)+100)
    for z in [-35,-18,4,22]:
        # Jagged roof fragments remain only at the perimeter; no complete canopy.
        top=[(x,12.6,z-2),(x-s*3.6,12.05,z-1.4),(x-s*2.3,12.15,z+1.1),(x,12.6,z+2.2)]
        bottom=[(a,b-.22,c) for a,b,c in top]
        active['Stone'].face(top,tint=.8);active['Stone'].face(list(reversed(bottom)),tint=.6)
        for j in range(4):k=(j+1)%4;active['Stone'].face([top[j],bottom[j],bottom[k],top[k]],tint=.72)
for z in [-30,-10]:
    # A bare truss spans between grounded perimeter columns. Chords meet all braces.
    for y in [11.25,12.6]:rod('Rust',(-19.2,y,z),(19.2,y,z),.15,sides=6)
    for i in range(12):
        x=-19.2+i*3.2;rod('Iron',(x,11.25,z),(x+1.6,12.6,z),.075);rod('Iron',(x+1.6,12.6,z),(x+3.2,11.25,z),.075)
    for x in [-14,-8,4,12]:vine((x,12.67,z),R.uniform(2.5,6.0),int(x+z+1000))
    for x in [-8.8,9.0]:
        spills.append([x,11.2,z]);active['Spill'].face([(x-.04,11.2,z),(x+.04,11.2,z),(x+.09,.23,z),(x-.07,.23,z)],[(0,0),(1,0),(1,1),(0,1)])
group('Broken truss resting on flooded bed')
for off in [-.42,.42]:rod('Rust',(10.2+off,-.83,-30),(17.9+off,10.7,-36),.13)
for i in range(9):
    a=Vector((10.2,-.83,-30)).lerp(Vector((17.9,10.7,-36)),i/9);b=Vector((10.2,-.83,-30)).lerp(Vector((17.9,10.7,-36)),(i+1)/9)
    rod('Iron',a+Vector((-.42,0,0)),b+Vector((.42,0,0)),.055)
group('Terminal facade')
box('Stone',(0,2.8,-46),(40,8,.8),.60)
for x in [-14,-7,0,7,14]:
    box('Dark',(x,2.5,-45.55),(4.2,4.7,.09))
    for dx in [-2.25,2.25]:box('Plaster',(x+dx,2.5,-45.42),(.25,4.9,.35),.75)
    box('Stone',(x,5.1,-45.3),(5.0,.55,.8),.75)
box('Plaster',(0,8.8,-41),(38.4,5.6,1.0))
for x in [-16,-10,-4,4,10,16]:
    box('Stone',(x,2.4,-41),(1.2,7.0,1.8));box('Stone',(x,6,-40.7),(1.8,.35,2.1))
for x in [-13,-7,0,7,13]:
    box('Dark',(x,8.5,-40.47),(3.3,2.6,.08));box('Iron',(x,8.5,-40.37),(.09,2.8,.13));box('Iron',(x,8.5,-40.37),(3.4,.11,.13))
box('Iron',(0,11,-40.38),(12.2,1.7,.18))
def text(label,pos,size,material='Edge'):
    curve=bpy.data.curves.new(label,'FONT');curve.body=label;curve.align_x='CENTER';curve.size=size;curve.extrude=.012;curve.space_character=1.12
    o=bpy.data.objects.new(label,curve);bpy.context.collection.objects.link(o);o.location=(pos[0],-pos[2],pos[1]);o.rotation_euler=(math.pi/2,0,0);o.data.materials.append(mats[material]);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False)
text('VERDANT',(0,11.12,-40.21),1.12)
text('T E R M I N U S',(0,10.54,-40.20),.34)
for x in [-2.2,13.0,-13.0]:
    z=12 if x<0 else -4
    group('Platform signage '+str(x));rod('Iron',(x,1,z),(x,4.0,z),.07);box('Iron',(x,3.65,z),(1.6,.65,.12));text('02' if abs(x)<4 else '01',(x,3.47,z+.09),.48)
    obstacles.append([x-.17,x+.17,z-.17,z+.17])
group('Benches and abandoned station details')
for x,z in [(-1.8,7),(1.6,-12),(-14,12),(14,-14),(-14,-17),(13,23)]:
    for dx in [-.83,.83]:
        for dz in [-.24,.24]:rod('Iron',(x+dx,1,z+dz),(x+dx,1.56,z+dz),.045)
        rod('Iron',(x+dx,1.4,z-.25),(x+dx,2.18,z-.38),.035)
    for j in range(4):box('Wood',(x,1.57,z-.28+j*.17),(2.25,.075,.13),.85+j*.07)
    for j in range(3):box('Wood',(x,1.78+j*.16,z-.38),(2.25,.105,.075),.88+j*.07)
    obstacles.append([x-1.25,x+1.25,z-.50,z+.42])
for s in [-1,1]:
    for z in [-33,-15,6,23]:
        x=s*17.5;box('Stone',(x,1.4,z),(.86,.8,.78));box('Earth',(x,1.81,z),(.75,.035,.67));fern(x,1.81,z,.70);obstacles.append([x-.55,x+.55,z-.55,z+.55])
# Rooted trees grow from platform pockets, the broken perimeter, and outside walls.
for i,(x,y,z,h) in enumerate([(-2.1,1,-25,9),(15.8,1,-5,10),(-15.9,1,-11,9),(15,1,18,8),(-16,1,22,8),(-21,-1,-27,15),(23,-1,-20,15),(-24,-1,4,15),(22,-1,5,14),(-21,-1,30,13),(21,-1,31,14),(-15,1,-37,10),(16,1,-38,12),(-10,-1,-47,14),(4,-1,-49,15),(22,-1,-44,15),(-24,-1,-45,17)]):
    group('Rooted tree %02d'%i);tree(x,y,z,h,i+60)
    if -18<x<18 and z>-38:trunks.append([x,z,1.05])
group('Platform grasses ferns and flowers')
for i in range(3900):
    r=walk[R.randrange(3)];x=R.uniform(r[0]+.35,r[1]-.35);z=R.uniform(r[2]+.3,19.5)
    # Leave meandering strips of broken paving visible, especially the opening route.
    centre=(r[0]+r[1])/2+math.sin(z*.12)*.85
    if abs(x-centre)<1.05 and R.random()<.92:continue
    if any(a-.15<x<b+.15 and c-.15<z<d+.15 for a,b,c,d in obstacles):continue
    if any((x-p['x'])**2+(z-p['z'])**2<1.10**2 for p in residents):continue
    grass(x,1.025,z,R.uniform(.55,1.2))
    if i%24==0:fern(x,1.02,z,R.uniform(.4,.85))
    if i%7==0:
        yy=R.uniform(.18,.45);rod('Leaf',(x,1.025,z),(x,1.025+yy,z),.008,sides=4)
        for j in range(5):leaf((x,1.025+yy,z),j*math.tau/5,.06,.036,'Flower',-.02,tint=R.uniform(.85,1.2),wind=.6)
# Moss and ivy wrap the ruins without forming repetitive vertical wallpaper.
for s in [-1,1]:
    for z in range(-38,28,3):
        x=s*18.61
        for j in range(8):
            y=R.uniform(2.1,11.6);zz=z+R.uniform(-1.4,1.4)
            leaf((x,y,zz),0 if s<0 else math.pi,R.uniform(.35,.65),.24,droop=.21,tint=R.uniform(.8,1.18))
        vine((s*18.55,R.uniform(7.6,12.1),z),R.uniform(1.5,4.6),z+s*30+500)
for x in range(-17,18,2):
    vine((x,12.0,-40.3),R.uniform(1.2,4.4),x+970)
    for j in range(8):grass(x+R.uniform(-.8,.8),11.65,-41+R.uniform(-.4,.4),1.0)
group('Broken masonry and forest floor beyond the station')
for i in range(95):
    s=R.choice([-1,1]);x=s*R.uniform(17.15,18.15);z=R.uniform(-37,19);y=1.;r=R.uniform(.12,.35)
    top=[(x+math.cos(j*math.tau/6)*r*R.uniform(.8,1.2),y+R.uniform(.14,.45),z+math.sin(j*math.tau/6)*r) for j in range(6)]
    bottom=[(a,y-.04,c) for a,b,c in top]
    active['Stone'].face(top,tint=R.uniform(.7,.9))
    for j in range(6):k=(j+1)%6;active['Stone'].face([bottom[j],bottom[k],top[k],top[j]],tint=.8)
    obstacles.append([x-r-.05,x+r+.05,z-r-.05,z+r+.05])
# A surrounding tree line closes the reverse view; the station belongs to a forest.
for i in range(9):
    group('Forest beyond concourse '+str(i));tree(-26+i*6.5,-1,38+R.uniform(0,6),R.uniform(9,13),150+i)
group('Distant forest ground')
box('Earth',(0,-1.1,44),(86,.8,32))
group('Water lilies and track bed reeds')
for i in range(250):
    x=R.choice([-7.15,7.15])+R.uniform(-2.9,2.9);z=R.uniform(-39,19)
    if abs(x-7.15)<1.9 and -24<z<-8:continue
    if abs(x+7.15)<1.9 and (-31<z<-15 or 4<z<20):continue
    r=R.uniform(.12,.33);a=R.random()*math.tau;p=(x,.255,z)
    pts=[p]+[(x+math.cos(a+j*5.8/10)*r,.26+math.sin(j)*.008,z+math.sin(a+j*5.8/10)*r) for j in range(11)]
    for j in range(1,11):active['Leaf'].face([pts[0],pts[j],pts[j+1]],tint=R.uniform(.7,1),wind=.08)
    if i%9==0:
        for j in range(7):leaf((x,.28,z),j*math.tau/7,.11,.05,'Flower',-.05)
group('Sunlit drifting seeds')
for i in range(90):
    x=R.uniform(-17,17);y=R.uniform(1.2,11);z=R.uniform(-40,26)
    active['Mote'].face([(x-.018,y-.018,z),(x+.018,y-.018,z),(x+.018,y+.018,z),(x-.018,y+.018,z)],[(0,0),(1,0),(1,1),(0,1)],tint=R.random(),wind=R.random())
group('Finished')
# Append the reduced, UV mapped Hunyuan assets, keeping each named source object.
assets=[];train_roofs=[]
for name,placements in [('train',[(-7.15,-.92,10,0),(-7.15,-.92,-24,0),(7.15,-.92,-16,0)]),('clock',[(2.0,1.0,1.4,0)])]:
    path_glb=ROOT/'assets/models'/f'station_{name}.glb'
    if not path_glb.exists():raise RuntimeError('Prepare Hunyuan asset first: '+str(path_glb))
    bpy.ops.import_scene.gltf(filepath=str(path_glb));src=[o for o in bpy.context.selected_objects if o.type=='MESH']
    for j,(x,y,z,rot) in enumerate(placements):
        for o in src:
            obj=o if j==len(placements)-1 else o.copy()
            if obj!=o:bpy.context.collection.objects.link(obj)
            obj.name=f'Hunyuan {name} {j} '+o.name;obj.location+=Vector((x,-z,y));obj.rotation_euler.z+=rot
            if name=='train':train_roofs.append((obj,x,y,z))
        assets.append(dict(kind=name,x=x,y=y,z=z))
    if name=='clock':obstacles.append([.85,3.2,.4,2.5])
# Raycast the actual reduced Hunyuan mesh, including its irregular roof profile.
group('Reclaimed carriage roof gardens')
roof_attachments=[]
for obj,x,y,z in train_roofs:
    mesh=obj.data
    roof=BVHTree.FromPolygons([v.co for v in mesh.vertices],[p.vertices[:] for p in mesh.polygons])
    def height(px,pz):
        hit,normal,_,_=roof.ray_cast(Vector((px-x,-(pz-z),5)),Vector((0,0,-1)),3)
        return hit.z+y if hit is not None and normal.z>.22 and hit.z>2.65 else None
    roots=[];vines=[]
    for j in range(80):grass(x+R.uniform(-1.25,1.25),0,z+R.uniform(-6.7,6.7),R.uniform(.55,1.2),height,roots)
    for j in range(9):
        px=x+R.choice([-1.25,1.25]);pz=z+R.uniform(-6.2,6.2);py=height(px,pz)
        if py is None:continue
        anchor=(px,py-.012,pz);vines.append(anchor)
        vine(anchor,R.uniform(.5,1.7),j+int(z)+1900)
    assert len(roots)>700,'A substantial roof garden must remain attached to each carriage'
    roof_attachments.append(dict(train=[x,y,z],grass_roots=roots,vine_roots=vines))
group('Finished')
layout=dict(walk=walk,obstacles=obstacles,trunks=trunks,guards=guards,spills=spills,assets=assets,roof_attachments=roof_attachments,residents=residents,water_y=.22,start=[.4,2.85,17.5],roof_opening=[-11.5,11.5,-38,20])
(ROOT/'assets/data/station_layout.json').write_text(json.dumps(layout,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/verdant_terminus.blend'))
for k,m in mats.items():
    obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.data.materials)==1 and o.data.materials[0]==m]
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    if obs:
        bpy.context.view_layer.objects.active=obs[0]
        if len(obs)>1:bpy.ops.object.join()
        obs[0].name='Station'+k
tmp=ROOT/'build-logs/station-export.glb';bpy.ops.export_scene.gltf(filepath=str(tmp),export_format='GLB',export_image_format='AUTO',export_vertex_color='NAME',export_vertex_color_name='Shelter',export_all_vertex_colors=False)
import shutil
shutil.copyfile(tmp,ROOT/'assets/models/verdant_terminus.glb')
# A quiet original looping water/garden soundscape, with smooth loop endpoints.
rate=22050;seconds=24;buf=bytearray();rr=random.Random(812);low=[0.,0.];phase=0.
for i in range(rate*seconds):
    t=i/rate;seam=math.sin(math.pi*t/seconds)**.3
    for ch in range(2):
        n=rr.uniform(-1,1);low[ch]=low[ch]*.965+n*.035
        water=(low[ch]*.30+n*.009)*(.8+.13*math.sin(t*math.tau/24))
        bird=0.
        for st in [2.1,7.8,14.2,19.5]:
            q=t-st-ch*.09
            if 0<q<.75:bird+=math.sin(math.tau*(1900*q+320*q*q)+1.6*math.sin(q*42))*math.sin(q/.75*math.pi)**3*.015
        buf.extend(struct.pack('<h',int(max(-1,min(1,(water+bird)*seam))*32767)))
with wave.open(str(ROOT/'assets/audio/station_garden.wav'),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(rate);f.writeframes(buf)
print('VERDANT_TERMINUS_READY',len(bpy.context.scene.objects),'batches; Hunyuan train + clock; connected platforms and collapsed roof')
