"""Original Night Crossing wheelhouse, packed paint/wood textures and sea audio.
Run with Blender --background --python blender/build_sea.py. Units are metres.
Author coordinates below are Godot coordinates; export converts through Blender.
"""
import bpy, math, random, wave
import numpy as np
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
random.seed(731)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def xyz(p): return (p[0],-p[2],p[1])
def material(name, color, kind='paint', emission=0):
    n=128; y,x=np.mgrid[:n,:n]; rng=np.random.default_rng(sum(map(ord,name)))
    noise=rng.random((n,n))
    if kind=='wood':
        grain=np.sin(x*.9+np.sin(y*.12)*.6)*.027+np.sin(x*.24)*.035+(noise-.5)*.035
        grain-=((x%32)<2)*.24
    else:
        grain=(noise-.5)*.035

    pixels=np.ones((n,n,4),dtype=np.float32)
    pixels[:,:,:3]=np.clip(np.array(color)[None,None,:]+grain[:,:,None],.008,1)
    if kind=='chart':
        island=((x-30)/19)**2+((y-56)/37)**2+np.sin(y*.17)*.21
        island2=((x-93)/15)**2+((y-99)/22)**2+np.sin(x*.22)*.19
        coast=np.minimum(island,island2)
        pixels[coast<1,:3]=(.25,.31,.22)
        pixels[(coast>1)&(coast<1.22),:3]=(.34,.39,.29)
        pixels[(x%16==0)|(y%16==0),:3]*=.80
        pixels[(abs(x-(65+np.sin(y*.025)*12))<1.2)&(y%9<5),:3]=(.48,.18,.12)
    im=bpy.data.images.new(name,n,n,alpha=True);im.pixels.foreach_set(pixels.ravel());im.filepath_raw=str(R/'assets/textures'/f'{name}.png');im.file_format='PNG';im.save();im.pack()
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.78
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;tex.interpolation='Closest';mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    if emission:
        bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=emission
    return mat
cream=material('sea_ochre_paint',(.49,.38,.20)); red=material('sea_oxblood',(.25,.065,.042)); wood=material('sea_teak',(.22,.13,.064),'wood')
iron=material('sea_iron',(.065,.08,.075)); paper=material('sea_chart',(.55,.54,.36),'chart'); lamp=material('sea_lamp',(.95,.56,.19),emission=2)
green=material('sea_instrument',(.17,.49,.34),emission=.45)
def mesh(name, verts, faces, mat):
    me=bpy.data.meshes.new(name);me.from_pydata([xyz(v) for v in verts],[],faces);me.materials.append(mat);me.update()
    ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob)
    uv=me.uv_layers.new()
    for p in me.polygons:
        normal=p.normal;axis=max(range(3),key=lambda a:abs(normal[a]));axes=[a for a in range(3) if a!=axis]
        for li in p.loop_indices:
            v=me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv=(v[axes[0]]*.8,v[axes[1]]*.8)
    return ob
def box(name,p,s,mat):
    x,y,z=p;a,b,c=[v*.5 for v in s]
    return mesh(name,[(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),(x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],mat)
def beam(name,a,b,r,mat,vertices=8):
    a,b=Vector(xyz(a)),Vector(xyz(b));d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d.length,location=(a+b)*.5)
    ob=bpy.context.object;ob.name=name;ob.rotation_euler=d.to_track_quat('Z','Y').to_euler();ob.data.materials.append(mat);return ob
def ring(name,p,r,t,mat,rot=(math.pi/2,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=6,location=xyz(p),major_radius=r,minor_radius=t,rotation=rot)
    ob=bpy.context.object;ob.name=name;ob.data.materials.append(mat)
def text(name,body,p,size,mat):
    bpy.ops.object.text_add(location=xyz(p),rotation=(math.pi/2,0,0));ob=bpy.context.object;ob.name=name;ob.data.body=body;ob.data.size=size;ob.data.extrude=.001;ob.data.materials.append(mat)
    bpy.ops.object.convert(target='MESH')
# Hull shaped into a pointed bow, deck seated above the waterline.
outline=[(-1.72,2.7),(1.72,2.7),(1.7,-2.2),(1.17,-4.1),(0,-5.9),(-1.17,-4.1),(-1.7,-2.2)]
verts=[(x,.83,z) for x,z in outline]+[(x*.65,-.48,z*.87) for x,z in outline]
mesh('Riveted hull',verts,[(i,(i+1)%7,(i+1)%7+7,i+7) for i in range(7)],red)
mesh('Foredeck',[(x,.88,z) for x,z in outline],[tuple(range(7))],wood)
for i,(x,z) in enumerate(outline):
    nx,nz=outline[(i+1)%7];beam('Raised bulwark',(x,1.3,z),(nx,1.3,nz),.13,red)
    for f in [.2,.5,.8]:beam('Rail stanchion',(x+(nx-x)*f,.86,z+(nz-z)*f),(x+(nx-x)*f,1.3,z+(nz-z)*f),.033,iron)
# Windows are real openings, not opaque panes. Wide forward view from the helm.
box('Cabin floor',(0,.91,.65),(3.22,.16,3.7),wood)
box('Cabin roof',(0,3.78,.55),(3.7,.18,3.95),iron)
box('Ceiling lining',(0,3.67,.55),(3.35,.05,3.62),wood)
for x in [-1.68,1.68]:
    box('Side lower panel',(x,1.44,.55),(.13,1.05,3.65),cream)
    box('Side header',(x,3.48,.55),(.13,.4,3.65),cream)
    for z in [-1.27,.7,2.37]:box('Side mullion',(x,2.72,z),(.13,1.42,.12),cream)
box('Front apron',(0,1.45,-1.27),(3.45,1.05,.14),cream)
box('Front header',(0,3.49,-1.27),(3.5,.38,.14),cream)
for x in [-1.68,-.64,1.68]:box('Forward window pillar',(x,2.7,-1.27),(.11,1.46,.15),cream)
box('Back wall',(0,2.15,2.38),(3.4,2.45,.12),cream)
box('Door inset',(.5,2.03,2.29),(.91,2.12,.05),wood)
box('Door window',(.5,2.51,2.25),(.61,.62,.03),iron)
beam('Door handle',(.79,1.85,2.18),(.79,1.97,2.18),.022,iron)
for x in [-1.61,1.61]:
    for z in [-1.2,.68,2.28]:
        for y in [1.05,1.82,3.38]:box('Panel fastener',(x,y,z),(.035,.035,.035),iron)
# Dashboard and tactile storytelling: dead radio, chart, compass, wheel, mug.
box('Dashboard',(.1,1.95,-.85),(2.92,.16,.65),wood)
box('Dashboard lip',(.1,2.05,-.51),(2.99,.09,.06),iron)
box('Radio',(-1.02,2.19,-.9),(.48,.27,.22),iron)
box('Radio dial',(-1.02,2.21,-.777),(.29,.08,.014),green)
for x in [-1.2,-.84]:beam('Radio knob',(x,2.12,-.77),(x,2.12,-.73),.03,iron)
for i in range(5):box('Speaker slot',(-1.02+i*.033,2.11,-.773),(.012,.05,.016),wood)
chart=box('Folded sea chart',(-.43,2.042,-.79),(.54,.015,.37),paper)
for poly in chart.data.polygons:
    if poly.normal.z>.9:
        for li in poly.loop_indices:
            v=chart.data.vertices[chart.data.loops[li].vertex_index].co
            chart.data.uv_layers.active.data[li].uv=((v.x+.70)/.54,(v.y-.605)/.37)
beam('Wheel column',(.65,1.75,-.96),(.65,1.88,-.39),.068,iron)
ring('Wheel rim',(.65,2.01,-.34),.34,.027,wood)
for i in range(8):
    a=i*math.tau/8;beam('Wheel spoke',(.65,2.01,-.34),(.65+math.cos(a)*.4,2.01+math.sin(a)*.4,-.34),.018,wood)
beam('Compass binnacle',(1.26,2.02,-.89),(1.26,2.18,-.89),.13,iron)
beam('Compass face',(1.26,2.18,-.89),(1.26,2.19,-.89),.105,green)
beam('Mug',(-.06,2.04,-.77),(-.06,2.2,-.77),.065,cream)
ring('Mug handle',(.027,2.13,-.77),.045,.012,cream)
text('Radio label','156.8',(-1.145,2.175,-.759),.052,paper)
text('Safety plate','KEEP A LOOKOUT',(-1.4,1.73,-1.176),.082,paper)
for x,z in [(-.93,-3.02),(.93,-3.02),(0,-4.7)]:
    beam('Mooring bollard',(x,.9,z),(x,1.15,z),.085,iron);beam('Bollard cap',(x-.16,1.13,z),(x+.16,1.13,z),.038,iron)
for i in range(7):ring('Coiled rope',(-.55,.925,-2.6),.19+i*.022,.014,paper,rot=(0,0,0))
box('Foredeck hatch',(.32,.97,-3.13),(.81,.13,.95),red)
box('Hatch inset',(.32,1.045,-3.13),(.65,.02,.79),wood)
beam('Lamp stem',(-1.28,3.65,-.78),(-1.28,3.24,-.78),.018,iron)
beam('Amber cabin lamp',(-1.28,3.07,-.78),(-1.28,3.25,-.78),.082,lamp)
for y in [3.04,3.27]:beam('Lamp cap',(-1.28,y,-.78),(-1.28,y+.035,-.78),.12,iron)
for x in [-1.37,-1.19]:beam('Lamp cage',(x,3.05,-.78),(x,3.27,-.78),.009,iron)
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/night_crossing.blend'))
# Keep named editable parts in .blend, but batch static export by material.
for mat in list(bpy.data.materials):
    objects=[ob for ob in bpy.context.scene.objects if ob.type=='MESH' and ob.data.materials and ob.data.materials[0]==mat]
    if not objects: continue
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join();bpy.context.object.name='Cabin_'+mat.name
bpy.ops.export_scene.gltf(filepath=str(R/'assets/models/night_crossing.glb'),export_format='GLB',export_apply=True)
# Seamless coloured surf, low engine throb and intermittent timber creaks.
rate=22050;duration=24;n=rate*duration;t=np.arange(n)/rate;rng=np.random.default_rng(381)
freq=np.fft.rfftfreq(n,1/rate);spec=rng.normal(size=len(freq))+1j*rng.normal(size=len(freq))
spec/=np.maximum(freq,35)**.60;spec[freq<20]=0
surf=np.fft.irfft(spec,n);surf/=max(abs(surf));surf*=.45+.25*np.sin(math.tau*t/8)+.12*np.sin(math.tau*t/3)
engine=.05*np.sin(math.tau*48*t)*(1+.4*np.sin(math.tau*4*t))
creak=.026*np.sin(math.tau*(280*t+12*np.sin(math.tau*t/6)))*np.maximum(0,np.sin(math.tau*t/12))**12
sound=np.clip(surf+engine+creak,-1,1);stereo=np.stack((sound,np.roll(surf,250)+engine-creak),axis=1)
with wave.open(str(R/'assets/audio/night_sea.wav'),'wb') as w:
    w.setnchannels(2);w.setsampwidth(2);w.setframerate(rate);w.writeframes((stereo*26000).astype('<i2').tobytes())
print('SEA_ASSETS_READY')
