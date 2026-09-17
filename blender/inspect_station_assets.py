import bpy, math,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
for name in ['train','clock']:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    game='--game' in sys.argv
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models'/f'station_{name}.glb') if game else str(ROOT/'art/station'/f'{name}_raw.glb'))
    obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
    print(name,[(o.name,tuple(o.dimensions),len(o.data.polygons)) for o in obs],flush=True)
    mat=bpy.data.materials.new('clay');mat.diffuse_color=(.55,.65,.49,1)
    if game:
        scale=2./max(max(o.dimensions) for o in obs)
        for o in obs:o.location.z=-o.dimensions.z*scale*.5;o.scale*=scale
    else:
        for o in obs:o.data.materials.clear();o.data.materials.append(mat)
    scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=720;scene.render.resolution_y=600;scene.render.resolution_percentage=100
    scene.world.color=(.3,.3,.3)
    bpy.ops.object.light_add(type='AREA',location=(2,-4,5));bpy.context.object.data.energy=550;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=5
    for label,pos in [('front',(2,-3,1.6)),('rear',(-2,3,1.4))]:
        bpy.ops.object.camera_add(location=pos);cam=bpy.context.object;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.8;scene.camera=cam
        scene.render.filepath=str(ROOT/'build-logs'/f'{name}-{"game" if game else "raw"}-{label}.png');bpy.ops.render.render(write_still=True)
