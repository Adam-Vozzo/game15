"""Make the two locally generated Hunyuan3D 2.1 meshes game ready.
Raw outputs and inference records remain in art/station, outside Godot importing.
Remove ground-sheet artifacts, retain connected surface components, decimate,
set metric scale / grounded origins, create fixed UVs and compact material pages.
"""
import bpy,bmesh,math,json,random
import numpy as np
from collections import deque
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
rr=random.Random(91416)
stats={}
def material(name,pixels=None,w=512,h=512,color=(1,1,1)):
    mat=bpy.data.materials.new('Station'+name);mat.use_nodes=True;mat.diffuse_color=(*color,1)
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.92
    if pixels is not None:
        im=bpy.data.images.new('Station'+name,width=w,height=h);im.pixels=pixels;im.filepath_raw=str(ROOT/'assets/textures'/f'Station{name}.png');im.file_format='PNG';im.save()
        tx=mat.node_tree.nodes.new('ShaderNodeTexImage');tx.image=im;mat.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
    return mat
def weather(x,y,base):
    m=math.sin(x*.071+math.sin(y*.046)*2)*math.sin(y*.088+x*.023)
    n=rr.uniform(-.017,.017)+.024*m
    col=[c+n for c in base]
    if m>.52 and rr.random()<.62:col=[v*.58 for v in (.40,.40,.21)]
    if rr.random()<.013:col=[v*.64 for v in col]
    return [max(0,min(1,round(c*31)/31)) for c in col]+[1]
def clock_projection_texture():
    """Exclude the photograph's neutral backdrop from the material projection.

    Reconstructed roots do not exactly follow the reference silhouette. Pad the
    foreground colours across that mismatch; never project the studio backdrop
    onto geometry. Coverage also selects bark for faces outside the photograph.
    """
    im=bpy.data.images.load(str(ROOT/'art/station/clock_reference.png'));im.scale(512,768)
    w,h=im.size;rgba=np.array(im.pixels[:],dtype=np.float32).reshape(h,w,4)
    rgb=rgba[:,:,:3];hi=rgb.max(axis=2);lo=rgb.min(axis=2)
    background=(hi-lo<.085)&(lo>.32)
    # Keep the ivory dial, including its faded numerals and small specular areas.
    yy,xx=np.mgrid[:h,:w]
    dial=((xx/w-.575)/.143)**2+((yy/h-.794)/.112)**2<1
    background[dial]=False
    # Remove antialiased backdrop pixels along the foreground edge as well.
    for _ in range(2):
        grown=background.copy()
        grown[1:]|=background[:-1];grown[:-1]|=background[1:]
        grown[:,1:]|=background[:,:-1];grown[:,:-1]|=background[:,1:]
        background=grown&~dial
    coverage=~background
    # A multi-source edge dilation provides generous UV padding, including holes
    # between roots. The original reference remains untouched in art/station.
    filled=coverage.copy();boundary=np.zeros_like(filled)
    boundary[1:]|=coverage[1:]&background[:-1];boundary[:-1]|=coverage[:-1]&background[1:]
    boundary[:,1:]|=coverage[:,1:]&background[:,:-1];boundary[:,:-1]|=coverage[:,:-1]&background[:,1:]
    queue=deque(zip(*np.where(boundary)))
    while queue:
        y,x=queue.popleft()
        for qy,qx in [(y-1,x),(y+1,x),(y,x-1),(y,x+1)]:
            if 0<=qy<h and 0<=qx<w and not filled[qy,qx]:
                rgba[qy,qx]=rgba[y,x];filled[qy,qx]=True;queue.append((qy,qx))
    assert filled.all(),'Every projected texel must have foreground coverage'
    im.pixels=rgba.ravel();im.filepath_raw=str(ROOT/'assets/textures/StationClockFront.png');im.file_format='PNG';im.save()
    print('CLOCK_TEXTURE_COVERAGE',int(background.sum()),'backdrop texels replaced with foreground padding',flush=True)
    return im,coverage
for name in ['train','clock']:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'art/station'/f'{name}_raw.glb'))
    o=[o for o in bpy.context.scene.objects if o.type=='MESH'][0];bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    raw_triangles=sum(len(p.vertices)-2 for p in o.data.polygons)
    bm=bmesh.new();bm.from_mesh(o.data)
    # The carriage output contains a spurious flat display plinth below its wheels.
    # It is entirely below this plane; wheels remain above it and sit on real rails.
    # Keep the closed reconstruction intact until after volume repair. Cutting
    # the attached base first opens its shell and makes voxel repair lose panels.
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00008)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.00001)
    # Remove detached reconstruction specks while retaining the substantive object.
    unseen=set(bm.verts);components=[]
    while unseen:
        seed=unseen.pop();component=[seed];stack=[seed]
        while stack:
            v=stack.pop()
            for e in v.link_edges:
                q=e.other_vert(v)
                if q in unseen:unseen.remove(q);component.append(q);stack.append(q)
        components.append(component)
    largest=max(len(c) for c in components)
    junk=[v for c in components if len(c)<max(60,largest*.0006) for v in c]
    if junk:bmesh.ops.delete(bm,geom=junk,context='VERTS')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    o.data.validate(verbose=False,clean_customdata=True);o.data.update()
    # Surface-net output has non-manifold microfaces that collapse alone cannot
    # reduce. Rebuild a clean continuous volume before silhouette decimation.
    remesh=o.modifiers.new('Clean reconstruction topology','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.006 if name=='train' else .008;remesh.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    if name=='train':
        bm=bmesh.new();bm.from_mesh(o.data);low=min(v.co.z for v in bm.verts)
        cut=bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,0,low+.050),plane_no=(0,0,1),clear_inner=True,clear_outer=False)
        edges=[e for e in cut['geom_cut'] if isinstance(e,bmesh.types.BMEdge) and e.is_boundary]
        if edges:bmesh.ops.holes_fill(bm,edges=edges,sides=0)
        bm.to_mesh(o.data);bm.free();o.data.validate(verbose=False);o.data.update()
    smooth=o.modifiers.new('Remove voxel steps','SMOOTH');smooth.factor=.35;smooth.iterations=2
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    target=14000 if name=='train' else 10000
    mod=o.modifiers.new('Game silhouette reduction','DECIMATE');mod.ratio=min(1,target/max(1,sum(len(p.vertices)-2 for p in o.data.polygons)));mod.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    lo=Vector([min(v.co[j] for v in o.data.vertices) for j in range(3)]);hi=Vector([max(v.co[j] for v in o.data.vertices) for j in range(3)])
    size=Vector((3.0,14.5,4.0) if name=='train' else (2.15,1.65,3.25))
    for v in o.data.vertices:
        v.co=Vector(((v.co.x-(lo.x+hi.x)/2)/(hi.x-lo.x)*size.x,(v.co.y-(lo.y+hi.y)/2)/(hi.y-lo.y)*size.y,(v.co.z-lo.z)/(hi.z-lo.z)*size.z))
    o.data.validate(verbose=True,clean_customdata=True)
    o.data.update();o.name='Hunyuan_'+name+'_game';o.location=(0,0,0)
    o.data.materials.clear()
    if name=='train':
        for kind in ['Side','Front','Roof','Under']:
            pix=[];w=512 if kind=='Side' else 256;h=256
            for yy in range(h):
                v=yy/(h-1)
                for xx in range(w):
                    u=xx/(w-1);col=(.71,.73,.56)
                    if kind=='Under':col=(.12,.18,.16)
                    elif kind=='Roof':col=(.40,.47,.28)
                    else:
                        if .21<v<.37:col=(.12,.31,.23)
                        if v<.20:col=(.15,.22,.18)
                        if kind=='Side':
                            cell=u*9;cu=cell%1;idx=int(cell)
                            door=idx in [0,4,8]
                            if door and .18<v<.82 and .08<cu<.91:
                                col=(.45,.51,.39)
                                if abs(cu-.50)<.022:col=(.15,.24,.20)
                            if .42<v<.78 and .10<cu<.91:
                                col=(.20,.30,.27)
                                if .15<cu<.86 and .445<v<.755:
                                    col=(.075,.19,.18)
                                    if (cu+.7*v)%1<.23:col=(.13,.28,.26)
                                if abs(v-.59)<.012:col=(.43,.49,.39)
                            if cu<.019:col=(.42,.48,.37)
                        else:
                            if (.10<u<.43 or .57<u<.9) and .46<v<.83:
                                col=(.16,.27,.23)
                                if (.12<u<.41 or .59<u<.88) and .48<v<.80:col=(.07,.19,.18)
                            if .45<u<.55 and .22<v<.8:col=(.4,.49,.36)
                            if .38<u<.62 and .88<v<.935:col=(.1,.2,.15)
                            for cx in [.20,.80]:
                                d=((u-cx)/.07)**2+((v-.34)/.043)**2
                                if d<1.4:col=(.23,.30,.24)
                                if d<.85:col=(.69,.71,.53)
                    pix.extend(weather(xx,yy,col))
            o.data.materials.append(material('Train'+kind,pix,w,h))
    else:
        im,clock_coverage=clock_projection_texture()
        mat=material('ClockFront');tx=mat.node_tree.nodes.new('ShaderNodeTexImage');tx.image=im;mat.node_tree.links.new(tx.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color']);o.data.materials.append(mat)
        pix=[]
        for y in range(256):
            for x in range(256):pix.extend(weather(x,y,(.30+.055*math.sin(x*.2+math.sin(y*.04)),.34,.21)))
        o.data.materials.append(material('ClockBark',pix,256,256))
    uv=o.data.uv_layers.new(name='AuthoredGameUV')
    for poly in o.data.polygons:
        c=poly.center;n=poly.normal
        if name=='train':
            # The generated cab is rounded and recessed about a metre from its
            # extreme bumper. Classify by its normal as well as its end region,
            # so its windshield gets front UVs instead of a stretched side strip.
            front=abs(c.y)>5.8 and abs(n.y)>.36
            kind=3 if c.z<.65 else (2 if c.z>3.53 else (1 if front else 0));poly.material_index=kind
        else:
            cu=.12+(c.x/size.x+.5)*.76;cv=.018+c.z/size.z*.965
            covered=clock_coverage[min(767,max(0,int(cv*768))),min(511,max(0,int(cu*512)))]
            poly.material_index=0 if n.y<-.14 and covered else 1
        poly.use_smooth=True
        for li in poly.loop_indices:
            p=o.data.vertices[o.data.loops[li].vertex_index].co
            if name=='train':
                if kind==1:co=(p.x/size.x+.5,p.z/size.z)
                elif kind==2:co=(p.x/size.x+.5,p.y/size.y+.5)
                else:co=(p.y/size.y+.5,p.z/size.z)
            else:
                co=(.12+(p.x/size.x+.5)*.76,.018+(p.z/size.z)*.965) if poly.material_index==0 else (p.x*.8+p.y*.3,p.z*.5)
            uv.data[li].uv=co
    triangles=sum(len(p.vertices)-2 for p in o.data.polygons)
    assert triangles<target*1.15, 'Asset exceeds its game mesh budget'
    stats[name]=dict(model='Hunyuan3D 2.1 local ComfyUI',raw_triangles=raw_triangles,game_triangles=triangles,dimensions=list(size),materials=len(o.data.materials),vertices=len(o.data.vertices),uv='fixed planar material atlas',grounded_origin=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender'/f'station_{name}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models'/f'station_{name}.glb'),export_format='GLB',export_image_format='AUTO',export_normals=True)
    print('GAME_ASSET',name,stats[name],flush=True)
(ROOT/'art/station/asset_manifest.json').write_text(json.dumps(stats,indent=2)+'\n')
