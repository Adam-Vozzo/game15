extends "res://scripts/main.gd"

var layout: Dictionary
var storm_materials: Array[ShaderMaterial]=[]
var rain_material: ShaderMaterial
var water_material: ShaderMaterial
var reflection_view: SubViewport
var reflection_camera: Camera3D
var reflection_height:=36.04
var thunder: AudioStreamPlayer
var flash := 0.0
var last_thunder_event := -1
const STRIKES := [7.0,18.4,34.0]
const STORM_PERIOD := 43.0

func _ready() -> void:
    experience_id="roccella"
    bounds=Vector4(-14,31,-55.2,26)
    layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/roccella_layout.json"))
    super._ready()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--roccella-time="):time=float(arg.trim_prefix("--roccella-time="))

func surface_height(x: float,z: float) -> float:
    for r in layout.walk:
        if x>=r.x0-.0001 and x<=r.x1+.0001 and z>=r.z0-.0001 and z<=r.z1+.0001:return r.y
    return 24.

func can_walk(p: Vector3) -> bool:
    var inside:=false
    for r in layout.walk:
        if p.x>=r.x0 and p.x<=r.x1 and p.z>=r.z0 and p.z<=r.z1:
            inside=true
            break
    if not inside:return false
    for r in layout.obstacles:
        if p.x>r[0] and p.x<r[1] and p.z>r[2] and p.z<r[3]:return false
    var point:=Vector2(p.x,p.z)
    for g in layout.guards:
        var a:=Vector2(g.a[0],g.a[1]);var b:=Vector2(g.b[0],g.b[1])
        if point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b))<.32:return false
    return true

func _create_environment() -> void:
    world.name="LaBurrasca"
    var environment:=WorldEnvironment.new()
    environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR
    environment.environment.background_color=Color(.06,.085,.11)
    world.add_child(environment)
    var art:=load("res://assets/models/roccella.glb").instantiate() as Node3D
    world.add_child(art)
    var lamp_positions:=PackedVector3Array()
    for p in layout.lamps:lamp_positions.append(Vector3(p[0],p[1],p[2]))
    lamp_positions.resize(24)
    for part in art.find_children("*","MeshInstance3D",true,false):
        if "Puddle" in part.name:
            water_material=ShaderMaterial.new()
            water_material.shader=load("res://shaders/roccella_water.gdshader")
            water_material.render_priority=110
            water_material.set_shader_parameter("lamps",lamp_positions)
            water_material.set_shader_parameter("lamp_count",layout.lamps.size())
            part.material_override=water_material
            part.layers=2
            storm_materials.append(water_material)
            continue
        if "Splash" in part.name or "Runoff" in part.name:
            var spray:=ShaderMaterial.new()
            spray.shader=load("res://shaders/roccella_splash.gdshader")
            spray.set_shader_parameter("runoff","Runoff" in part.name)
            spray.render_priority=121
            part.material_override=spray
            part.extra_cull_margin=.5
            part.layers=2
            storm_materials.append(spray)
            continue
        if "Rain" in part.name:
            rain_material=ShaderMaterial.new()
            rain_material.shader=load("res://shaders/roccella_rain.gdshader")
            rain_material.render_priority=120
            part.material_override=rain_material
            part.extra_cull_margin=120
            part.layers=2
            storm_materials.append(rain_material)
            continue
        for i in range(part.mesh.get_surface_count()):
            var original: Material=part.mesh.surface_get_material(i)
            var kind:=original.resource_name.trim_prefix("Roccella")
            var material:=ShaderMaterial.new()
            material.shader=load("res://shaders/roccella_surface.gdshader")
            var tex_path:="res://assets/textures/Roccella"+kind+".png"
            var textured:=ResourceLoader.exists(tex_path)
            material.set_shader_parameter("textured",textured)
            if textured:material.set_shader_parameter("base_texture",load(tex_path))
            elif original is StandardMaterial3D:material.set_shader_parameter("tint",original.albedo_color)
            material.set_shader_parameter("luminous",kind=="Light")
            material.set_shader_parameter("sea",kind=="Sea")
            material.set_shader_parameter("paving",kind=="Paving")
            material.set_shader_parameter("lamps",lamp_positions)
            material.set_shader_parameter("lamp_count",layout.lamps.size())
            part.set_surface_override_material(i,material)
            storm_materials.append(material)

func _create_vegetation() -> void:
    pass

func _create_camera() -> void:
    super._create_camera()
    camera.far=800
    start=Vector3(27,37.85,17.8)
    camera.position=start
    heading=.43;pitch=-.28
    mist.shader=load("res://shaders/roccella_atmosphere.gdshader")
    mist.render_priority=100
    mist.set_shader_parameter("fog_steps",18 if mobile else 28)
    camera.get_child(0).layers=4
    reflection_view=SubViewport.new()
    reflection_view.world_3d=view.find_world_3d()
    reflection_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    add_child(reflection_view)
    reflection_camera=Camera3D.new()
    reflection_camera.cull_mask=1
    reflection_camera.near=.05
    reflection_camera.far=140
    reflection_view.add_child(reflection_camera)
    water_material.set_shader_parameter("reflection_texture",reflection_view.get_texture())
    for arg in OS.get_cmdline_user_args():
        if arg=="--view=stairs":camera.position=Vector3(0,0,-9);pitch=-.26;heading=0
        if arg=="--view=reverse":camera.position=Vector3(0,0,-24);pitch=.35;heading=PI
        if arg=="--view=church":camera.position=Vector3(-3.5,0,14);pitch=.26;heading=.75
        if arg=="--view=balcony":camera.position=Vector3(2,0,12);pitch=.64;heading=-1.3
        if arg=="--view=coast":camera.position=Vector3(0,0,-45);pitch=-.05;heading=-.1
    target_heading=heading;target_pitch=pitch

func _resize() -> void:
    super._resize()
    if reflection_view:reflection_view.size=Vector2i(Vector2(view.size)*(.25 if mobile else .40)).max(Vector2i(1,1))

func _update_water_reflection() -> void:
    var nearest:=INF
    for pool in layout.puddles:
        # On the long lookout stair, mirror the lower landing until the player
        # reaches the upper one. The main camera must stay above this plane.
        if pool.floor>camera.position.y-1.65:continue
        var distance:float=absf(pool.floor-(camera.position.y-1.85))
        if distance<nearest:
            nearest=distance
            reflection_height=pool.floor+.04
    reflection_camera.position=Vector3(camera.position.x,2.*reflection_height-camera.position.y,camera.position.z)
    reflection_camera.rotation=Vector3(-camera.rotation.x,camera.rotation.y,0)
    reflection_camera.fov=camera.fov
    reflection_camera.keep_aspect=camera.keep_aspect
    for material in storm_materials:material.set_shader_parameter("reflection_height",reflection_height)

func _look(delta: Vector2) -> void:
    target_heading-=delta.x*.0025
    target_pitch=clampf(target_pitch-delta.y*.0025,-1.1,1.35)

func _create_audio() -> void:
    audio=AudioStreamPlayer.new()
    # Streaming avoids the web sample backend's buffer duplication on unpause.
    audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
    var stream:=load("res://assets/audio/roccella_rain.wav") as AudioStreamWAV
    stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
    stream.loop_end=int(stream.get_length()*stream.mix_rate)
    audio.stream=stream;audio.volume_db=-6;add_child(audio)
    if sound_on:audio.play()
    thunder=AudioStreamPlayer.new()
    thunder.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
    thunder.stream=load("res://assets/audio/roccella_thunder.wav")
    thunder.volume_db=-4;add_child(thunder)

func lightning_at(t: float) -> float:
    var phase:=fposmod(t,STORM_PERIOD)
    var value:=0.
    for strike in STRIKES:
        var dt:float=phase-strike
        if dt>=0. and dt<1.6:
            value=maxf(value,exp(-maxf(dt-.10,0.)*5.5)*minf(dt*70.,1.))
            if dt>.25:value=maxf(value,.77*exp(-(dt-.25)*4.)*minf((dt-.25)*65.,1.))
    return value

func _reset() -> void:
    super._reset()
    heading=.43;pitch=-.28;target_heading=heading;target_pitch=pitch
    camera.rotation=Vector3(pitch,heading,0)

func _process(delta: float) -> void:
    super._process(delta)
    flash=lightning_at(time)
    mist.set_shader_parameter("flash",flash)
    mist.set_shader_parameter("storm_phase",fposmod(time,STORM_PERIOD))
    for material in storm_materials:
        material.set_shader_parameter("scene_time",time)
        material.set_shader_parameter("flash",flash)
    _update_water_reflection()
    _sync_audio_pause(audio)
    _sync_audio_pause(thunder)
    if not sound_on:thunder.stop()
    var cycle:=int(floor(time/STORM_PERIOD))
    var phase:=fposmod(time,STORM_PERIOD)
    for i in range(STRIKES.size()):
        var event:=cycle*3+i
        if phase>=STRIKES[i]+1.9 and event>last_thunder_event:
            last_thunder_event=event
            if sound_on and not paused:thunder.play()
