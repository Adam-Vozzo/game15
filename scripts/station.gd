extends "res://scripts/main.gd"

var layout: Dictionary
var materials: Array[ShaderMaterial] = []
var water_material: ShaderMaterial
var reflection_view: SubViewport
var reflection_camera: Camera3D
var residents: Array[Node3D] = []
var resident_players: Array[AnimationPlayer] = []

func _ready() -> void:
    experience_id = "station"
    bounds = Vector4(-18,18,-38,28)
    layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/station_layout.json"))
    super._ready()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--station-time="): time=float(arg.trim_prefix("--station-time="))

func surface_height(_x: float, _z: float) -> float:
    return 1.0

func can_walk(p: Vector3) -> bool:
    var inside := false
    for r in layout.walk:
        if p.x>=r[0] and p.x<=r[1] and p.z>=r[2] and p.z<=r[3]: inside=true;break
    if not inside: return false
    for resident in layout.get("residents",[]):
        if Vector2(p.x-resident.x,p.z-resident.z).length()<.51*resident.scale:return false
    for r in layout.obstacles:
        if p.x>r[0]-.20 and p.x<r[1]+.20 and p.z>r[2]-.20 and p.z<r[3]+.20: return false
    for t in layout.trunks:
        if Vector2(p.x-t[0],p.z-t[1]).length()<t[2]+.20:return false
    for g in layout.guards:
        if Vector2(p.x,p.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(p.x,p.z),Vector2(g[0][0],g[0][1]),Vector2(g[1][0],g[1][1])))<.28:return false
    return true

func _create_environment() -> void:
    world.name="VerdantTerminus"
    var env := WorldEnvironment.new()
    env.environment=Environment.new()
    env.environment.background_mode=Environment.BG_COLOR
    env.environment.background_color=Color(.44,.73,.79)
    env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color=Color(.64,.79,.76)
    env.environment.ambient_light_energy=.48
    env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
    world.add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees=Vector3(-54,-32,0)
    sun.light_color=Color(1,.98,.80)
    sun.light_energy=1.08
    sun.shadow_enabled=true
    sun.directional_shadow_max_distance=100
    sun.shadow_bias=.03
    world.add_child(sun)
    var art := load("res://assets/models/verdant_terminus.glb").instantiate() as Node3D
    world.add_child(art)
    for part in art.find_children("*","MeshInstance3D",true,false):
        for i in range(part.mesh.get_surface_count()):
            var original := part.mesh.surface_get_material(i) as StandardMaterial3D
            var material := ShaderMaterial.new()
            var kind := original.resource_name.trim_prefix("Station")
            if kind=="Water":
                material.shader=load("res://shaders/station_water.gdshader")
                material.render_priority=110
                water_material=material
                part.layers=2
                part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            elif kind=="Spill" or kind=="Mote":
                material.shader=load("res://shaders/station_particles.gdshader")
                material.set_shader_parameter("mote",kind=="Mote")
                material.render_priority=120
                part.layers=2
                part.extra_cull_margin=3
                part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            else:
                material.shader=load("res://shaders/station_surface.gdshader")
                material.set_shader_parameter("base_texture",original.albedo_texture)
                material.set_shader_parameter("textured",original.albedo_texture!=null)
                material.set_shader_parameter("base_color",original.albedo_color)
                material.set_shader_parameter("foliage",kind in ["Leaf","Grass","Flower"])
                material.set_shader_parameter("generated_asset",kind.begins_with("Train") or kind.begins_with("Clock"))
                material.set_shader_parameter("wet",kind in ["Stone","Iron","Wood","Earth"])
                material.set_shader_parameter("masonry",kind in ["Stone","Plaster"])
            part.set_surface_override_material(i,material)
            materials.append(material)

func _create_vegetation() -> void:
    var creature:PackedScene=load("res://assets/models/station_spirit.glb")
    for placement in layout.residents:
        var resident:=creature.instantiate() as Node3D
        resident.name="PondSpirit"+str(residents.size()+1)
        world.add_child(resident)
        resident.position=Vector3(placement.x,placement.y,placement.z)
        resident.rotation.y=placement.yaw
        resident.scale=Vector3.ONE*placement.scale
        var player:=resident.find_child("AnimationPlayer",true,false) as AnimationPlayer
        # Explicit seeking keeps each Blender action on the shared scene clock.
        player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
        residents.append(resident);resident_players.append(player)
    _update_residents()

func _update_residents() -> void:
    for i in range(resident_players.size()):
        var t:=fposmod(time+float(layout.residents[i].phase),48.)
        var clip:="SpiritIdle";var at:=fposmod(t,4.)
        if t>=10. and t<16.:clip="SpiritLook";at=t-10.
        elif t>=24. and t<29.:clip="SpiritWave";at=t-24.
        elif t>=36. and t<44.:clip="SpiritDoze";at=t-36.
        var player:=resident_players[i]
        if player.current_animation!=clip:player.play(clip)
        player.seek(at,true)

func _create_camera() -> void:
    super._create_camera()
    camera.far=220
    start=Vector3(layout.start[0],layout.start[1],layout.start[2])
    camera.position=start
    heading=0.;pitch=.075;target_heading=heading;target_pitch=pitch
    mist.shader=load("res://shaders/station_atmosphere.gdshader")
    mist.render_priority=100
    camera.get_child(0).layers=2
    reflection_view=SubViewport.new()
    reflection_view.world_3d=view.find_world_3d()
    reflection_view.transparent_bg=false
    reflection_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    add_child(reflection_view)
    reflection_camera=Camera3D.new()
    reflection_camera.cull_mask=1
    reflection_camera.near=.08;reflection_camera.far=220
    reflection_view.add_child(reflection_camera)
    reflection_camera.current=true
    water_material.set_shader_parameter("reflection_texture",reflection_view.get_texture())
    for arg in OS.get_cmdline_user_args():
        if arg=="--view=clock":camera.position=Vector3(.3,2.85,4.8);heading=-.42;pitch=.03
        if arg=="--view=train":camera.position=Vector3(2.8,2.85,-5);heading=-.78;pitch=-.10
        if arg=="--view=reverse":camera.position=Vector3(0,2.85,-18);heading=PI;pitch=.1
        if arg=="--view=roof":pitch=1.1;heading=.25
        if arg=="--view=side":camera.position=Vector3(13.1,2.85,9);heading=.40;pitch=.06
        if arg=="--view=water":camera.position=Vector3(2.9,2.85,10);heading=-.74;pitch=-.58
    target_heading=heading;target_pitch=pitch

func _resize() -> void:
    super._resize()
    if reflection_view:reflection_view.size=Vector2i(Vector2(view.size)*(.30 if mobile else .45)).max(Vector2i(1,1))

func _update_reflection() -> void:
    reflection_camera.position=Vector3(camera.position.x,layout.water_y*2.-camera.position.y,camera.position.z)
    reflection_camera.rotation=Vector3(-camera.rotation.x,camera.rotation.y,0)
    reflection_camera.fov=camera.fov
    reflection_camera.keep_aspect=camera.keep_aspect

func _create_audio() -> void:
    audio=AudioStreamPlayer.new()
    audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
    var stream:=load("res://assets/audio/station_garden.wav") as AudioStreamWAV
    stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
    stream.loop_end=int(stream.get_length()*stream.mix_rate)
    audio.stream=stream;audio.volume_db=-4
    add_child(audio)
    if sound_on:audio.play()

func _look(delta: Vector2) -> void:
    target_heading-=delta.x*.0025
    target_pitch=clampf(target_pitch-delta.y*.0025,-1.1,1.4)

func _reset() -> void:
    super._reset()
    heading=0.;pitch=.075;target_heading=heading;target_pitch=pitch
    camera.rotation=Vector3(pitch,heading,0)

func _process(delta: float) -> void:
    super._process(delta)
    for material in materials:material.set_shader_parameter("scene_time",time)
    _update_residents()
    _update_reflection()
    _sync_audio_pause(audio)
