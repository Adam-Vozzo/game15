"""Render the generated creature or its game rig from accessible angles."""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
game='--game' in sys.argv
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT/('assets/models/station_spirit.glb' if game else 'art/station/spirit_raw.glb')))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name!='Icosphere']
for o in obs:print('SPIRIT_MESH',o.name,tuple(o.dimensions),tuple(o.location),len(o.data.polygons),flush=True)
corners=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box]
lo=Vector([min(v[i] for v in corners) for i in range(3)]);hi=Vector([max(v[i] for v in corners) for i in range(3)])
center=(lo+hi)*.5;size=max(hi-lo)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=640;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world.color=(.24,.29,.27)
bpy.ops.object.light_add(type='AREA',location=center+Vector((size,-size*2,size*2)));bpy.context.object.data.energy=450;bpy.context.object.data.size=size*3
for label,offset in [('front',(0,-3,.2)),('side',(3,-1,.2)),('back',(0,3,.2))]:
    bpy.ops.object.camera_add(location=center+Vector(offset)*size)
    cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size*1.25;scene.camera=cam
    scene.render.filepath=str(ROOT/'build-logs'/f'spirit-{ "game" if game else "raw"}-{label}.png');bpy.ops.render.render(write_still=True)
