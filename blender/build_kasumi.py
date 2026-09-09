"""Kasumi: original modular architecture, cultivated valley and plant studies.
Run in Blender: blender --background --python blender/build_kasumi.py
Logical coordinates match Godot (Y up); source meshes retain semantic names.
"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
random.seed(91531)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
ATLASES = [bpy.data.images.load(str(ROOT/'assets/textures'/('KasumiAtlas%d.png'%i)), check_existing=True) for i in range(4)]
for atlas in ATLASES:atlas.pack()
NAMES = ['Wood','Plaster','Tile','Stone','Earth','Moss','Glass','Glow','Cloth','Rust','Bark','Leaf','Straw','Red','Black','Paper']
MATS=[]
for k,name in enumerate(NAMES):
    mat=bpy.data.materials.new('K%02d_%s'%(k,name));mat.use_nodes=True
    nodes=mat.node_tree.nodes;links=mat.node_tree.links
    bs=nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.92
    uv=nodes.new('ShaderNodeTexCoord');fraction=nodes.new('ShaderNodeVectorMath');fraction.operation='FRACTION'
    scale=nodes.new('ShaderNodeVectorMath');scale.operation='MULTIPLY';scale.inputs[1].default_value=(.4921875,.4921875,1)
    offset=nodes.new('ShaderNodeVectorMath');offset.operation='ADD';offset.inputs[1].default_value=(k%2*.5+.00390625,(1-(k%4)//2)*.5+.00390625,0)
    tex=nodes.new('ShaderNodeTexImage');tex.image=ATLASES[k//4];tex.interpolation='Closest'
    links.new(uv.outputs['UV'],fraction.inputs[0]);links.new(fraction.outputs[0],scale.inputs[0]);links.new(scale.outputs[0],offset.inputs[0]);links.new(offset.outputs[0],tex.inputs['Vector'])
    col=nodes.new('ShaderNodeVertexColor');col.layer_name='Shelter'
    mult=nodes.new('ShaderNodeMixRGB');mult.blend_type='MULTIPLY';mult.inputs[0].default_value=1
    links.new(tex.outputs['Color'],mult.inputs[1]);links.new(col.outputs['Color'],mult.inputs[2]);links.new(mult.outputs[0],bs.inputs['Base Color'])
    MATS.append(mat)

def xyz(p): return (p[0],-p[2],p[1])
def base_h(x,z): return .03+max(0,-z)*.007+math.sin(x*.032)*math.sin(z*.033)*.07
def terrain_h(x,z):
    r=math.hypot(x,z*.86);t=max(0,min(1,(r-115)/100))
    return base_h(x,z)+t*t*(22+13*math.sin(x*.031+z*.014)+11*math.sin(z*.035-x*.012))

class Mesh:
    def __init__(self,name): self.name=name;self.v=[];self.f=[];self.m=[];self.uv=[];self.col=[]
    def face(self,pts,mat,shade=1,uv=None):
        if len(pts)<3:return
        n=(Vector(pts[1])-Vector(pts[0])).cross(Vector(pts[2])-Vector(pts[0]))
        axis=max(range(3),key=lambda i:abs(n[i]));indices=(0,2) if axis==1 else ((2,1) if axis==0 else (0,1))
        i=len(self.v);self.v.extend(pts);self.f.append(tuple(range(i,i+len(pts))));self.m.append(mat)
        self.uv.extend(uv or [(p[indices[0]]*.75,p[indices[1]]*.75) for p in pts])
        self.col.extend([(shade,shade,shade,1)]*len(pts))
    def box(self,p,s,mat=0,shade=1,angle=0):
        x,y,z=p;w,h,d=[v*.5 for v in s];co,si=math.cos(angle),math.sin(angle)
        pts=[(x+a*co+c*si,y+b,z+c*co-a*si) for a,b,c in [(-w,-h,-d),(w,-h,-d),(w,h,-d),(-w,h,-d),(-w,-h,d),(w,-h,d),(w,h,d),(-w,h,d)]]
        for face in [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(3,7,6,2),(0,1,5,4)]:self.face([pts[i] for i in face],mat,shade)
    def beam(self,a,b,r,mat=0,r2=None,shade=1,steps=5):
        a,b=Vector(a),Vector(b);n=(b-a).normalized();u=n.cross(Vector((0,1,0)))
        if u.length<.01:u=n.cross(Vector((1,0,0)))
        u.normalize();v=n.cross(u);r2=r if r2 is None else r2
        p=[a+(u*math.cos(i*math.tau/steps)+v*math.sin(i*math.tau/steps))*r for i in range(steps)]
        q=[b+(u*math.cos(i*math.tau/steps)+v*math.sin(i*math.tau/steps))*r2 for i in range(steps)]
        for i in range(steps):j=(i+1)%steps;self.face([p[i],p[j],q[j],q[i]],mat,shade)
        self.face(list(reversed(p)),mat,shade);self.face(q,mat,shade)
    def line(self,points,r,mat=14,shade=1):
        for a,b in zip(points,points[1:]):self.beam(a,b,r,mat,shade=shade,steps=4)
    def stone(self,p,s,mat=3,shade=1):
        x,y,z=p;sx,sy,sz=s
        ring=[(x+math.cos(i*math.tau/7)*sx*random.uniform(.83,1.12),y-.025,z+math.sin(i*math.tau/7)*sz*random.uniform(.83,1.12)) for i in range(7)]
        upper=[(x+(px-x)*.68,y+sy*random.uniform(.8,1.1),z+(pz-z)*.68) for px,_,pz in ring]
        for i in range(7):j=(i+1)%7;self.face([ring[i],ring[j],upper[j],upper[i]],mat,shade)
        self.face(upper,mat,shade)
    def finish(self,origin=(0,0,0)):
        if not self.v:return None
        data=bpy.data.meshes.new(self.name);data.from_pydata([xyz(Vector(p)-Vector(origin)) for p in self.v],[],self.f);data.update()
        for m in MATS:data.materials.append(m)
        uv=data.uv_layers.new(name='UVMap');col=data.color_attributes.new(name='Shelter',type='FLOAT_COLOR',domain='CORNER')
        for poly,mat in zip(data.polygons,self.m):
            poly.material_index=mat
            for li in poly.loop_indices:
                vi=data.loops[li].vertex_index;uv.data[li].uv=self.uv[vi];col.data[li].color=self.col[vi]
        ob=bpy.data.objects.new(self.name,data);bpy.context.collection.objects.link(ob);ob.location=xyz(origin)
        return ob

layout={'version':3,'bounds':[-93,93,-112,91],'buildings':[],'fields':[],'trees':[],'atlas':NAMES,'obstacles':[],'walk_surfaces':[]}
# Fields share exactly the same layout with the walk surface and plant instancing.
for side in [-1,1]:
    for row,z in enumerate([-58,-32,-6,20,46]):
        for col in range(3):
            x=(19+col*23) if side>0 else (-40-col*23)
            layout['fields'].append({'rect':[x,z,20,23],'height':round(base_h(x+10,z+11)-.17,4),'crop':'rice' if side>0 else 'wheat'})

def height(x,z):
    for f in layout['fields']:
        a,b,w,d=f['rect']
        if a<x<a+w and b<z<b+d:return f['height']
    return terrain_h(x,z)

# Fine valley floor merges into continuous foothills. No plane edge is reachable.
ground=Mesh('Valley_floor_and_field_beds')
coords=list(range(-450,-120,18))+list(range(-120,121,3))+list(range(138,451,18))
# Insert every field boundary into the terrain lattice: excluded cells cannot
# extend beyond a plot, and water/earth meet the surrounding ground without gaps.
for f in layout['fields']:
    x,z,w,d=f['rect'];coords.extend([x,z,x+w,z+d])
coords=sorted(set(coords))
for ix in range(len(coords)-1):
    for iz in range(len(coords)-1):
        x,z=coords[ix],coords[iz];xx,zz=coords[ix+1],coords[iz+1]
        midx,midz=(x+xx)*.5,(z+zz)*.5
        if any(a<midx<a+w and b<midz<b+d for a,b,w,d in [f['rect'] for f in layout['fields']]):continue
        mat=4 if abs(midx)<15 or abs(midz-16)<2 or abs(midz+51)<2 else 5
        ground.face([(x,terrain_h(x,z),z),(x,terrain_h(x,zz),zz),(xx,terrain_h(xx,zz),zz),(xx,terrain_h(xx,z),z)],mat,.87+random.random()*.12)
for f in layout['fields']:
    x,z,w,d=f['rect'];h=f['height']
    ground.face([(x,h,z),(x,h,z+d),(x+w,h,z+d),(x+w,h,z)],4,.73)
ground.finish()
fields=Mesh('Irrigation_banks_and_paths')
for f in layout['fields']:
    x,z,w,d=f['rect'];h=f['height'];top=h+.35
    for a,b in [((x,z),(x+w,z)),((x,z+d),(x+w,z+d)),((x,z),(x,z+d)),((x+w,z),(x+w,z+d))]:
        ax,az=a;bx,bz=b;length=math.hypot(ax-bx,az-bz);horizontal=abs(ax-bx)>1
        fields.box(((ax+bx)/2,top-.11,(az+bz)/2),(length+.3,.25,.48) if horizontal else (.48,.25,length+.3),5,.75)
        for t in range(int(length/1.15)):
            f0=(t+.5)/max(1,int(length/1.15));px=ax+(bx-ax)*f0;pz=az+(bz-az)*f0
            fields.stone((px,h+.03,pz),(.55,.25,.29) if horizontal else (.28,.25,.55),3,.78)
fields.finish()

def window(m,x,y,z,w,h,front,lit=False):
    m.box((x,y,z),(.07,h+.20,w+.20),14,.60)
    m.box((x+front*.044,y,z),(.025,h,w),7 if lit else 6,.83 if lit else .70)
    for dz in [-w*.5,w*.5]:m.box((x+front*.085,y,z+dz),(.10,h+.14,.085),0,.68)
    for dy in [-h*.5,h*.5]:m.box((x+front*.085,y+dy,z),(.10,.085,w),0,.72)
    for t in range(1,int(w/.19)):
        m.box((x+front*.08,y,z-w*.5+t*w/int(w/.19)),(.06,h,.033),0,.58)
    m.box((x+front*.09,y-.03,z),(.07,.035,w),0,.65)
    m.box((x+front*.12,y-h*.5-.11,z),(.25,.12,w+.30),0,.84)

def roof(m,x,y,z,w,d,rise,mat=2):
    # Curved eave profile, a heavy dark soffit, tile courses and rounded ridge ends.
    for side in [-1,1]:
        levels=[(0,rise),(.68*w*.5,rise*.30),(w*.5,0),(w*.5+.20,.035)]
        for (a,ha),(b,hb) in zip(levels,levels[1:]):
            m.face([(x+side*a,y+ha,z-d*.5),(x+side*a,y+ha,z+d*.5),(x+side*b,y+hb,z+d*.5),(x+side*b,y+hb,z-d*.5)],mat,.84)
        m.box((x+side*w*.5,y-.10,z),(.17,.19,d+.14),14,.55)
        for j in range(int(d/.34)+1):
            zz=z-d*.5+j*.34
            m.line([(x+side*a,y+hh+.028,zz) for a,hh in levels],.033,mat,.88)
        for j in range(int(d/.70)):
            zz=z-d*.5+.25+j*.70
            m.beam((x+side*(w*.5-.85),y+.1,zz),(x+side*(w*.5+.09),y-.09,zz),.052,0,shade=.50,steps=4)
    m.box((x,y+rise+.12,z),(.22,.21,d+.18),2,.96)
    for zz in [z-d*.5-.12,z+d*.5+.12]:
        m.beam((x,y+rise-.01,zz),(x,y+rise+.30,zz),.16,2,shade=.95,steps=8)

FONT=None
for path in ['C:/Windows/Fonts/YuGothB.ttc','C:/Windows/Fonts/msgothic.ttc']:
    if Path(path).exists():FONT=bpy.data.fonts.load(path);break
def sign(m,words,p,width,front):
    x,y,z=p;m.box(p,(.15,.62,width),15,.84)
    if not FONT:return
    cu=bpy.data.curves.new('Sign lettering','FONT');cu.body=words;cu.font=FONT;cu.size=.48;cu.align_x='CENTER';cu.align_y='CENTER'
    ob=bpy.data.objects.new('Letter template',cu);bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.convert(target='MESH')
    span=max(v.co.x for v in ob.data.vertices)-min(v.co.x for v in ob.data.vertices);s=min(1,(width-.18)/max(span,.1))
    for poly in ob.data.polygons:
        pts=[(x+front*.081,y+ob.data.vertices[i].co.y*s,z-front*ob.data.vertices[i].co.x*s) for i in poly.vertices]
        m.face(pts,14,.84)
    bpy.data.objects.remove(ob,do_unlink=True)

def crate(m,x,y,z):
    for side in [-1,1]:
        for t in range(3):
            m.box((x+side*.28,y+.08+t*.14,z),(.045,.10,.64),0,.84)
            m.box((x,y+.08+t*.14,z+side*.31),(.60,.10,.045),0,.80)
        for s in [-1,1]:m.box((x+side*.27,y+.23,z+s*.28),(.07,.5,.07),0,.63)
    m.box((x,y+.03,z),(.60,.05,.64),0,.65)
def pot(m,x,y,z,s=.27):
    m.beam((x,y,z),(x,y+s*1.8,z),s*.65,9,r2=s,shade=.82,steps=9)
    m.beam((x,y+s*1.8,z),(x,y+s*1.82,z),s*.88,14,steps=9)
    for k in range(7):
        a=k*math.tau/7;tip=(x+math.cos(a)*s*1.3,y+s*2.7,z+math.sin(a)*s*1.3)
        m.face([(x,y+s*1.8,z),(tip[0]-.09,tip[1],tip[2]),(tip[0]+.05,tip[1]-.10,tip[2]+.06)],11,.9)

def house(name,x,z,w,d,h,shop=False,variant=0):
    g=base_h(x,z);front=1 if x<0 else -1;fx=x+front*w*.5
    layout['buildings'].append({'name':name,'rect':[x-w*.5-.22,z-d*.5-.22,w+.44,d+.44]})
    m=Mesh(name)
    m.box((x,g+.24,z),(w+.13,.48,d+.16),3,.69)
    m.box((x,g+h*.5+.30,z),(w,h,d),1,.83 if variant%3 else .71)
    # Timber plinth wraps the entire building; varied widths prevent tiled-box repetition.
    for side in [-1,1]:
        for j in range(int(d/.23)):
            zz=z-d*.5+.12+j*d/int(d/.23)
            m.box((x+side*(w*.5+.028),g+.83,zz),(.045,1.02,.215),0,random.uniform(.62,.88))
        for yy in [.42,1.39,2.85,h+.23]:m.box((x+side*(w*.5+.06),g+yy,z),(.15,.14,d+.10),0,.62)
        for zz in [z-d*.5,z,z+d*.5]:m.box((x+side*(w*.5+.04),g+h*.5+.26,zz),(.16,h,.16),0,.55)
    for side in [-1,1]:
        zz=z+side*d*.5
        m.face([(x-w*.5,g+h+.3,zz),(x+w*.5,g+h+.3,zz),(x,g+h+1.75,zz)],1,.72)
        for xx in [x-w*.5,x,x+w*.5]:m.box((xx,g+h*.5+.27,zz+side*.03),(.16,h,.13),0,.58)
        for yy in [.45,1.42,2.90,h+.25]:m.box((x,g+yy,zz+side*.04),(w,.14,.13),0,.62)
        # Small gable vent and rain streak boards.
        m.box((x,g+h+.49,zz+side*.065),(1.12,.42,.08),14,.7)
        for k in range(7):m.box((x-.51+k*.17,g+h+.49,zz+side*.115),(.035,.44,.05),0,.7)
        for j in range(int(w/.24)):
            m.box((x-w*.5+.12+j*.24,g+.9,zz+side*.06),(.22,1.05,.05),0,random.uniform(.65,.88))
        # Gable-end room: divided glazing and shutters break the large plaster mass.
        for wy in ([2.07,4.05] if h>4 else [2.07]):
            m.box((x,g+wy,zz+side*.055),(w*.50,1.1,.07),14,.65)
            m.box((x,g+wy,zz+side*.10),(w*.46,.98,.025),7 if shop and wy<3 and side>0 else 6,.85)
            for j in range(10):m.box((x-w*.23+j*w*.046,g+wy,zz+side*.14),(.034,1.06,.05),0,.62)
            for dy in [-.53,0,.53]:m.box((x,g+wy+dy,zz+side*.14),(w*.5,.06,.06),0,.60)
            for dx in [-w*.29,w*.29]:m.box((x+dx,g+wy,zz+side*.16),(.26,1.2,.10),0,.74)
            m.box((x,g+wy-.65,zz+side*.21),(w*.64,.12,.38),0,.77)
    roof(m,x,g+h+.34,z,w+1.15,d+1.03,1.45)
    # Recessed ground-floor frontage, glazed bays and a half-open shop door.
    for dz in [-d*.30,d*.28]:window(m,fx+front*.08,g+1.95,z+dz,1.6,1.25,front,lit=shop and dz<0)
    m.box((fx+front*.09,g+1.29,z),(.08,1.84,1.22),14,.60)
    for k in range(5):m.box((fx+front*.15,g+1.30,z-.55+k*.12),(.07,1.83,.09),0,.62)
    if h>4:
        for dz in [-d*.27,d*.27]:window(m,fx+front*.09,g+4.10,z+dz,2.0,1.28,front,False)
        m.box((fx+front*.46,g+3.33,z),(.94,.16,d-.9),0,.65)
        for zz in [z-d*.5+.5,z+d*.5-.5]:m.box((fx+front*.88,g+3.80,zz),(.09,.92,.10),0,.65)
        for j in range(int((d-.9)/.24)):
            m.box((fx+front*.9,g+3.78,z-d*.5+.53+j*.24),(.05,.75,.04),0,.72)
        m.box((fx+front*.9,g+4.17,z),(.10,.11,d-.8),0,.74)
    m.box((fx+front*.46,g+.31,z),(.96,.20,d-.3),0,.78)
    for zz in [z-d*.5+.3,z+d*.5-.3]:
        m.box((fx+front*.91,g+1.43,zz),(.12,2.35,.12),0,.57)
    # Lower tiled shop canopy casts a painted shelter gradient on the façade.
    m.face([(fx-front*.10,g+3.10,z-d*.5+.1),(fx-front*.10,g+3.10,z+d*.5-.1),(fx+front*1.06,g+2.73,z+d*.5-.1),(fx+front*1.06,g+2.73,z-d*.5+.1)],2,.72)
    m.box((fx+front*1.08,g+2.68,z),(.12,.16,d),14,.50)
    for j in range(int(d/.34)):
        zz=z-d*.5+j*.34
        m.beam((fx,g+3.12,zz),(fx+front*1.10,g+2.76,zz),.034,2,shade=.86,steps=4)
    # Roof runoff hardware; electrical service box and ceramic meter.
    zz=z+d*.5-.24
    m.line([(fx+front*.58,g+h+.26,zz),(fx+front*.34,g+h-.09,zz),(fx+front*.26,g+.30,zz)],.052,9,.76)
    m.box((fx+front*.14,g+1.64,z+d*.36),(.20,.46,.29),9,.72)
    m.beam((fx+front*.25,g+1.78,z+d*.36),(fx+front*.29,g+1.78,z+d*.36),.09,6,steps=8)
    m.line([(fx+front*.2,g+1.87,z+d*.36),(fx+front*.2,g+3.37,z+d*.36),(fx+front*.2,g+3.44,z-d*.4)],.015,14)
    if shop:
        sign(m,['三枝商店','山路食堂','米・茶','かすみ屋'][variant%4],(fx+front*1.15,g+3.04,z-.25),3.1,front)
        # An oval paper lantern and its dark bamboo hoops mark the open shop.
        lx,lz=fx+front*1.12,z+d*.34
        m.beam((lx,g+2.65,lz),(lx,g+2.23,lz),.019,14)
        m.beam((lx,g+1.68,lz),(lx,g+2.21,lz),.21,7,r2=.20,steps=12)
        for yy in [1.69,1.80,1.95,2.10,2.20]:
            m.beam((lx,g+yy,lz),(lx,g+yy+.018,lz),.214,0,steps=12,shade=.65)
        for j in range(3):
            zz=z-.52+j*.38;cloth=Mesh('Noren_'+name+'_'+str(j));origin=(fx+front*.40,g+2.54,zz)
            for row in range(4):
                a=row*.19;b=(row+1)*.19
                cloth.face([(origin[0],origin[1]-a,zz-.17),(origin[0],origin[1]-a,zz+.17),(origin[0],origin[1]-b,zz+.17),(origin[0],origin[1]-b,zz-.17)],8,.92)
            cloth.finish(origin)
        for j in range(3):crate(m,fx+front*.79,g+.42,z-d*.30+j*.7)
        pot(m,fx+front*1.12,g,z+d*.3,.28)
    else:
        pot(m,fx+front*.75,g+.42,z+d*.25,.23)
    # A bench, forgotten basket and clustered local rubble rather than uniform scatter.
    m.box((fx+front*.98,g+.53,z+d*.10),(.50,.10,1.35),0,.84)
    for zz in [z+d*.10-.52,z+d*.10+.52]:m.box((fx+front*.98,g+.27,zz),(.10,.45,.10),0,.64)
    for j in range(9):
        xx=fx+front*random.uniform(.65,1.22);zz=z+random.choice([-1,1])*random.uniform(d*.35,d*.49)
        m.stone((xx,g+.01,zz),(.09,.045,.12),3,.65)
    m.finish()

houses=[('Saegusa_general_store',-5.9,6,6,10,5.25,True),('Yamaji_tea_house',5.8,-.5,5.8,9,5.65,True),
('Shuttered_home',-6.5,-8.5,6.4,8,4.85,False),('Old_rice_merchant',6.2,-14,6.2,10,4.8,True),
('Narrow_house',-5.7,-22,5.4,8,3.1,False),('Corner_shop',-6.6,-36,6.6,10,5.4,True),
('Balcony_house',6.3,-32,6.2,9,5.7,False),('Last_lantern',5.8,-46,5.5,8,3.4,False),
('North_house',-6.4,-58,6.2,9,5.3,False),('Upper_house',6.4,-64,6.2,9,4.7,False),
('Entry_home',-8,25,6.6,9,4.6,False),('Southern_house',9,30,7,10,3.6,False)]
for i,args in enumerate(houses):house(*args,variant=i)
# Farm buildings and distant rooflines make the village part of a wider settlement.
for i,(x,z,w,d,h) in enumerate([(-18,-70,6,8,3.2),(18,-85,6,9,3.1),(-37,78,6,8,3.3),(45,77,7,8,3.5),(-19,45,4,6,2.7),(17,11,3.6,5,2.6)]):
    house('Field_shed_%02d'%i,x,z,w,d,h,False,i)

# Sagging cable geometry, porcelain insulators, streetlights and original utility clutter.
utilities=Mesh('Utility_poles_and_catenaries');poles=[]
for i,z in enumerate([18,-2,-23,-45,-70,43,68]):
    x=-2.17 if i%2==0 else 2.10;y=base_h(x,z);h=7.4+random.random()*.7
    utilities.beam((x,y,z),(x+.08,y+h,z),.12,10,r2=.083,shade=.66,steps=7)
    utilities.box((x,y+h-.25,z),(2.0,.13,.16),0,.68)
    for dx in [-.85,0,.85]:
        utilities.beam((x+dx,y+h-.25,z),(x+dx,y+h+.08,z),.024,9)
        for dy in [0,.08,.16]:utilities.beam((x+dx,y+h-.14+dy,z),(x+dx,y+h-.09+dy,z),.065,15,steps=7)
    if i%2==0:
        utilities.line([(x,y+5.0,z),(x+.55,y+5.25,z),(x+.8,y+5.15,z)],.032,9)
        utilities.box((x+.8,y+5.12,z),(.40,.10,.22),14,.80)
        utilities.box((x+.8,y+5.065,z),(.28,.025,.16),7,.85)
    poles.append((x,y+h,z))
poles.sort(key=lambda p:p[2])
for a,b in zip(poles,poles[1:]):
    for dx in [-.83,0,.83]:
        points=[]
        for j in range(13):
            t=j/12;points.append((a[0]*(1-t)+b[0]*t+dx,a[1]*(1-t)+b[1]*t-math.sin(t*math.pi)*.72,a[2]*(1-t)+b[2]*t))
        utilities.line(points,.010,14,.65)
utilities.finish()

props=Mesh('Lane_drainage_and_remnants')
for side in [-1,1]:
    x=side*2.32
    for z in range(-78,38):
        y=base_h(x,z)
        props.box((x,y+.025,z),(.32,.12,.96),3,.59)
        props.box((x-side*.14,y+.12,z),(.09,.15,.98),3,.79)
        if z%4==0:
            for j in range(6):props.box((x,y+.107,z-.38+j*.14),(.30,.015,.028),9,.72)
    for z in [14,-18,-50]:
        for j in range(6):props.box((side*3.1,base_h(side*3.1,z)+.15,z-.43+j*.16),(2.0,.08,.14),0,.81)
# Bicycle wheels, fork and visibly open frame at the tea house.
bx,bz=2.72,-3.5;by=base_h(bx,bz)
for zz in [bz-.48,bz+.48]:
    pts=[(bx,by+.36+math.sin(i*math.tau/20)*.35,zz+math.cos(i*math.tau/20)*.35) for i in range(21)]
    props.line(pts,.024,14)
    for i in range(8):a=i*math.tau/8;props.beam((bx,by+.36,zz),(bx,by+.36+math.sin(a)*.32,zz+math.cos(a)*.32),.006,9)
props.line([(bx,by+.36,bz-.48),(bx,by+.72,bz-.28),(bx,by+.36,bz+.06),(bx,by+.36,bz-.48)],.023,8)
props.line([(bx,by+.36,bz+.06),(bx,by+.75,bz+.30),(bx,by+.72,bz-.28)],.023,8)
props.line([(bx,by+.36,bz+.48),(bx,by+.99,bz+.27),(bx+.14,by+1.02,bz+.25)],.018,9)
props.box((bx,by+.81,bz-.28),(.20,.055,.26),14)
# A broom against a closed door and a red postbox whose paint has worn through.
props.beam((-2.63,.22,2),(-2.89,1.4,2.1),.018,0)
props.box((-2.61,.18,2),(.09,.28,.24),12,.9)
props.box((2.45,.77,5.4),(.46,.65,.35),13,.9)
props.box((2.45,.99,5.59),(.31,.045,.02),14)
props.beam((2.45,.05,5.4),(2.45,.5,5.4),.045,9)
for i in range(55):
    x=random.choice([-1,1])*random.uniform(1.5,2.5);z=random.uniform(-70,34);y=base_h(x,z)+.015
    props.face([(x,y,z),(x+.06,y+.012,z+.07),(x+.15,y,z+.02),(x+.05,y,z-.04)],12 if i%3 else 13,.7)
# A laundry line across a sheltered side passage.
props.line([(-3.1,3.5,-14.8),(-12.8,3.9,-14.8)],.014,14)
for j in range(4):
    x=-4.5-j*1.35;origin=(x,3.56+j*.052,-14.8);cloth=Mesh('Laundry_%02d'%j)
    for k in range(5):
        y=origin[1]-k*.19
        cloth.face([(x-.31,y,-14.8),(x+.31,y,-14.8),(x+.32,y-.19,-14.8),(x-.32,y-.19,-14.8)],15 if j%2 else 8,.80)
    cloth.finish(origin)
props.finish()

garden=Mesh('Kitchen_gardens_and_harvest_tools')
for side in [-1,1]:
    x=side*11.7
    for z in range(-65,40,2):
        if -20<z<-14 or 14<z<22 or -55<z<-48:continue
        if side==1 and -61<z<-51:continue # Leave the shrine landing and approach clear.
        y=base_h(x,z)
        # A continuous mortared core with fitted courses, buried below the soil.
        garden.box((x,y+.21,z),(.62,.58,2.02),3,.78)
        for row in range(2):
            for block in range(3):
                zz=z-.68+block*.67+(row%2)*.06
                for face in [-1,1]:
                    garden.box((x+face*.31,y+.10+row*.24,zz),(.07,.215,.63),3,.80+random.random()*.08)
        garden.box((x,y+.51,z),(.65,.065,2.02),5,.82)
        layout['obstacles'].append([x-.39,z-1.01,.78,2.02])
    # A rough bamboo boundary beside the southern plots.
    for z in range(35,74,3):
        y=base_h(side*17,z)
        garden.beam((side*17,y,z),(side*17+.08,y+1.06,z+.04),.035,0,shade=.88)
        for h in [.47,.88]:garden.beam((side*17,y+h,z),(side*17,y+h,z+3),.022,0,shade=.83)
# Empty rice drying frame, loosely stacked poles and a worn field marker.
for x in [23,29]:
    y=base_h(x,44)
    garden.line([(x,y,43.65),(x,y+1.8,44),(x,y,44.35)],.055,0,.86)
garden.beam((22.7,1.95,44),(29.3,1.95,44),.065,0,shade=.85)
for j in range(7):garden.beam((22.3+j*.07,.10,43.4),(26.0+j*.09,.16,43.5),.026,0)
# A straw-coated scarecrow stands off-centre within the wheat.
cx,cz=-36,36;cy=base_h(cx,cz)
garden.beam((cx,cy-.16,cz),(cx,cy+1.95,cz),.042,0)
garden.beam((cx-.70,cy+1.47,cz),(cx+.68,cy+1.39,cz),.045,0)
garden.stone((cx,cy+1.63,cz),(.16,.23,.15),12,.88)
garden.box((cx,cy+1.69,cz),(.57,.055,.45),12,.85)
garden.face([(cx-.27,cy+1.5,cz-.08),(cx+.25,cy+1.5,cz-.08),(cx+.35,cy+.72,cz-.10),(cx-.33,cy+.81,cz-.12)],8,.75)
garden.face([(cx-.29,cy+1.48,cz+.09),(cx+.25,cy+1.48,cz+.09),(cx+.33,cy+.74,cz+.10),(cx-.35,cy+.78,cz+.12)],8,.72)
for j in range(11):garden.beam((cx-.32+j*.06,cy+.81,cz),(cx-.32+j*.06,cy+.59-random.random()*.12,cz+.03),.008,12,steps=3)
garden.finish()

# Wayside shrine, steps, rope, votive stones and crops interrupted by a field path.
shrine=Mesh('Inari_wayside_shrine');sx,sz=12,-53
soil=base_h(sx,sz);platform=soil+.78
# Solid stepped masonry fills the space from the soil to the shrine's floor.
for j in range(6):
    top=soil+(j+1)*.13;bottom=base_h(sx,sz-j*.43)-.10
    # Touching risers, rather than overlapping boxes with coincident side faces.
    shrine.box((sx,(bottom+top)*.5,sz-j*.43),(2.25,top-bottom,.43),3,.86)
    layout['walk_surfaces'].append({'rect':[sx-1.125,sz-j*.43-.215,2.25,.43],'height':top})
bottom=base_h(sx,sz-4.4)-.12
# The cap replaces the core's upper 8 cm; their top faces must never coincide.
# Its front begins at the back of the final tread, avoiding a coplanar overlap.
landing_front=sz-5*.43-.215
landing_back=sz-6.83
landing_depth=landing_front-landing_back
landing_z=(landing_front+landing_back)*.5
core_top=platform-.085
shrine.box((sx,(bottom+core_top)*.5,landing_z),(3.8,core_top-bottom,landing_depth-.04),3,.82)
shrine.box((sx,platform-.04,landing_z),(3.86,.08,landing_depth),3,.96)
layout['walk_surfaces'].insert(0,{'rect':[sx-1.93,landing_back,3.86,landing_depth],'height':platform})
for x in [sx-.86,sx+.86]:
    shrine.box((x,platform+.07,sz-2.65),(.38,.14,.38),3,.82)
    shrine.beam((x,platform+.13,sz-2.65),(x,platform+3.05,sz-2.65),.115,13,r2=.09)
shrine.box((sx,platform+2.68,sz-2.65),(2.55,.15,.19),13,.78)
shrine.box((sx,platform+3.10,sz-2.65),(3.05,.20,.28),14,.87)
shrine.box((sx,platform+.10,sz-4.2),(1.45,.20,1.35),3,.85)
shrine.box((sx,platform+.825,sz-4.2),(1.25,1.25,1.15),0,.7)
roof(shrine,sx,platform+1.45,sz-4.2,1.8,1.7,.55)
for j in range(5):shrine.stone((sx-1.48+j*.74,platform,sz-5.9),(.20,.45,.22),3,.70)
layout['obstacles'].append([sx-.85,sz-4.95,1.7,1.5])
shrine.finish()

# Continuous nested ridgelines are sculpted profiles, with different valley notches.
for layer,(radius,peak) in enumerate([(215,53),(320,87),(425,118)]):
    ridge=Mesh('Mountain_rim_%d'%layer);count=120
    for i in range(count):
        a=i*math.tau/count;b=(i+1)*math.tau/count
        def top(t):return peak+math.sin(t*5+layer*.8)*peak*.24+math.sin(t*11+1.4)*peak*.10+math.sin(t*23)*peak*.027
        def p(t,r,h):return (math.sin(t)*r,h,math.cos(t)*r-22)
        ridge.face([p(a,radius-25,5),p(b,radius-25,5),p(b,radius,top(b)),p(a,radius,top(a))],11,.50+layer*.09)
        ridge.face([p(a,radius,top(a)),p(b,radius,top(b)),p(b,radius+65,12),p(a,radius+65,12)],11,.60)
    ridge.finish()

# Irregular groves: structural silhouettes, never stacked cones.
for i in range(490):
    if i<150:
        a=random.uniform(0,math.tau);r=random.uniform(100,150);x=math.cos(a)*r;z=math.sin(a)*r-15
    else:
        x=random.uniform(-210,210);z=random.uniform(-220,165)
        if abs(x)<95 and -105<z<85:continue
    layout['trees'].append([round(x,3),round(terrain_h(x,z),3),round(z,3),round(random.uniform(.8,1.65),3),i%3,round(random.random()*math.tau,3)])
for x,z,s,k in [(-13,17,1.05,0),(15,20,1.12,1),(-14,-29,.9,2),(16,-38,1.1,0),(-19,-52,1.2,1),(10,-79,.95,2),(-22,57,1.1,0),(13,59,1.4,1),(-40,73,1.1,0)]:
    layout['trees'].append([x,base_h(x,z),z,s,k,random.random()*math.tau])
for i in range(100):
    x=random.choice([-1,1])*random.uniform(88,109);z=random.uniform(-108,93)
    layout['trees'].append([x,terrain_h(x,z),z,random.uniform(.7,1.4),i%3,random.random()*math.tau])

# Store readable source. GLB keeps house chunks for occlusion/distance culling.
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
bpy.ops.object.camera_add(location=xyz((0,2.1,15)))
cam=bpy.context.object;cam.name='Street_composition';cam.rotation_euler=(Vector(xyz((0,2,-25)))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=28;bpy.context.scene.camera=cam
bpy.context.scene.world.color=(.3,.36,.4)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/kasumi_town.blend'))
def export(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models'/name),export_format='GLB',use_selection=True,export_yup=True,export_vertex_color='NAME',export_vertex_color_name='Shelter',export_all_vertex_colors=False)
export(objects,'kasumi_town.glb')

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
plants=[]
for kind in range(3):
    trunk=Mesh('Tree_%d_trunk'%kind);crown=Mesh('Tree_%d_crown'%kind)
    ht=9 if kind==0 else 7.5;lean=.38 if kind!=2 else -.25
    trunk.beam((0,0,0),(lean,ht*.85,0),.21,10,r2=.035,shade=.78,steps=7)
    for j in range(25 if kind==0 else 19):
        a=j*2.399+kind;yy=ht*(.24+j/(38 if kind==0 else 29));span=(1-j/34)*2.1 if kind==0 else random.uniform(1.1,2.5)
        end=Vector((math.cos(a)*span,yy+.3,math.sin(a)*span))
        branch_root=Vector((lean*yy/ht,yy-.2,0))
        trunk.beam(branch_root,end,.055,10,r2=.012,shade=.72)
        # Angled branch cards combine authored transparent foliage into a volume.
        # Each card costs two triangles; its fine silhouette comes from the texture.
        for fan in range(7):
            attachment=branch_root.lerp(end,.24+fan*.12)
            angle=a+(-1 if fan%2 else 1)*(.30+(fan%3)*.24)
            along=Vector((math.cos(angle),(.12 if kind==0 else .30)+(fan%3)*.13,math.sin(angle))).normalized()
            across=Vector((-math.sin(angle),0,math.cos(angle)))
            normal=along.cross(across).normalized()
            roll=((fan%3)-1)*.65
            right=(across*math.cos(roll)+normal*math.sin(roll))*(1.40 if kind==0 else 1.65)
            up=along*(1.70 if kind==0 else 1.65)
            # Atlas stem pixels (59,119) and (70,12), including the shader gutter.
            corner=attachment-right*(58/126)-up*(8/126)
            tip=attachment+right*(11/126)+up*(107/126)
            trunk.beam(attachment,tip,.014,10,r2=.004,shade=.74,steps=4)
            crown.face([corner,corner+right,corner+right+up,corner+up],11,random.uniform(.75,1.0),[(0,0),(1,0),(1,1),(0,1)])
    trunk_ob=trunk.finish();crown_ob=crown.finish()
    foliage=bpy.data.materials.new('K11_Foliage%d'%kind);foliage.use_nodes=True
    fn=foliage.node_tree.nodes;fl=foliage.node_tree.links;fb=fn.get('Principled BSDF')
    image=bpy.data.images.load(str(ROOT/'assets/textures/KasumiFoliage.png'),check_existing=True);image.pack()
    tex=fn.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Closest'
    uv=fn.new('ShaderNodeTexCoord');mapping=fn.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY_ADD';mapping.inputs[1].default_value=(.4921875,.4921875,1);mapping.inputs[2].default_value=(kind%2*.5+.00390625,(1-kind//2)*.5+.00390625,0)
    fl.new(uv.outputs['UV'],mapping.inputs[0]);fl.new(mapping.outputs[0],tex.inputs['Vector']);fl.new(tex.outputs['Color'],fb.inputs['Base Color']);fl.new(tex.outputs['Alpha'],fb.inputs['Alpha'])
    crown_ob.data.materials[11]=foliage
    plants.extend([trunk_ob,crown_ob])
for name,kind in [('Rice',0),('Wheat',1),('Verge',2)]:
    m=Mesh(name)
    for j in range(7 if kind!=1 else 5):
        a=j*2.399;root=Vector((math.cos(a)*.10,0,math.sin(a)*.1));h=random.uniform(.40,.65) if kind==0 else random.uniform(.67,1.08) if kind==1 else random.uniform(.20,.49)
        lean=Vector((math.cos(a)*.18,0,math.sin(a)*.18));cross=Vector((-math.sin(a),0,math.cos(a)))*(.027 if kind==0 else .018)
        mid=root+lean*.3+Vector((0,h*.56,0));tip=root+lean+Vector((0,h,0))
        mat=12 if kind==1 else 11
        m.face([root-cross*.5,root+cross*.5,mid+cross,mid-cross],mat,.7)
        m.face([mid-cross,mid+cross,tip],mat,1)
        if kind==1:
            for k in range(4):
                c=tip+Vector((0,k*.028,0));w=.035*(1-k/5)
                m.face([c-cross*2,c+Vector((w,.022,w)),c+Vector((0,.047,0))],12,1.07)
                m.face([c+cross*2,c+Vector((-w,.021,-w)),c+Vector((0,.047,0))],12,.89)
    plants.append(m.finish())
flowers=Mesh('Lily')
for j in range(4):
    x,z=random.uniform(-.13,.13),random.uniform(-.13,.13);h=random.uniform(.30,.55)
    flowers.beam((x,0,z),(x,h,z),.008,11,steps=3)
    for k in range(7):
        a=k*math.tau/7;end=(x+math.cos(a)*.15,h+.03,z+math.sin(a)*.15)
        flowers.face([(x,h,z),end,(end[0]+.018,h+.065,end[2]+.015)],13,1)
    flowers.face([(x-.025,0,z),(x-.12,.25,z),(x+.02,.04,z)],11,.80)
plants.append(flowers.finish())
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/kasumi_plants.blend'))
export(plants,'kasumi_plants.glb')
(ROOT/'assets/data').mkdir(exist_ok=True)
(ROOT/'assets/data/kasumi_layout.json').write_text(json.dumps(layout,ensure_ascii=False,indent=2),encoding='utf-8')
print('KASUMI COMPLETE:',len(layout['buildings']),'buildings,',len(layout['fields']),'fields,',len(layout['trees']),'trees; editable atlas + vertex shelter shading')
