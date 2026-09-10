extends "res://scripts/main.gd"

var landscape_materials: Array[ShaderMaterial] = []
var water_material: ShaderMaterial
var layout: Dictionary
var reflection_view: SubViewport
var reflection_camera: Camera3D

func _create_view() -> void:
    super._create_view()
    # Grade inside the scene viewport so menu return snapshots retain the look.
    var print_layer := CanvasLayer.new()
    print_layer.layer = 10
    view.add_child(print_layer)
    var grade := ColorRect.new()
    grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var material := ShaderMaterial.new()
    material.shader = load("res://shaders/lowwater_grade.gdshader")
    grade.material = material
    print_layer.add_child(grade)

func _ready() -> void:
    experience_id = "lowwater"
    bounds = Vector4(-26,28,-89,32)
    layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/lowwater_layout.json"))
    super._ready()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--lowwater-time="):
            time = float(argument.trim_prefix("--lowwater-time="))

static func canal_center(z: float) -> float:
    return 1.5+sin(z*.055)*1.3

func surface_height(x: float,z: float) -> float:
    var bank := clampf((absf(x-canal_center(z))-2.6)/1.6,0.,1.)
    bank = bank*bank*(3.-2.*bank)
    return -.72+bank*(1.4+.14*sin(x*.25+z*.13)+.09*cos(z*.31))

func can_walk(point: Vector3) -> bool:
    if absf(point.x-canal_center(point.z))<3.85: return false
    for tree in layout.trees:
        if Vector2(point.x-tree.x,point.z-tree.z).length()<tree.radius+.35: return false
    # Fallen trunk on the west bank, in the same footprint as the Blender bough.
    var p := Vector2(point.x,point.z)
    if Geometry2D.get_closest_point_to_segment(p,Vector2(-13,-17),Vector2(-8,-27)).distance_to(p)<.65: return false
    return true

func _create_environment() -> void:
    world.name = "Lowwater"
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(.56,.56,.48)
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color = Color(.70,.71,.62)
    environment.environment.ambient_light_energy = .48
    world.add_child(environment)
    var light := DirectionalLight3D.new()
    light.light_color = Color(.95,.91,.72)
    light.light_energy = .62
    world.add_child(light)
    light.look_at_from_position(Vector3(-.40,.76,-.51)*100.,Vector3.ZERO)
    var art := load("res://assets/models/lowwater.glb").instantiate() as Node3D
    world.add_child(art)
    water_material = ShaderMaterial.new()
    water_material.shader = load("res://shaders/lowwater_water.gdshader")
    for part in art.find_children("*","MeshInstance3D",true,false):
        if "CanalWater" in part.name:
            part.material_override = water_material
            part.layers = 2
            continue
        for i in range(part.mesh.get_surface_count()):
            var original: Material = part.mesh.surface_get_material(i)
            var kind := "Earth"
            for candidate in ["Bark","Foliage","Moss","Ivy"]:
                if candidate in original.resource_name: kind = candidate
            var material := ShaderMaterial.new()
            material.shader = load("res://shaders/lowwater_surface.gdshader")
            material.set_shader_parameter("base_texture",load("res://assets/textures/Lowwater"+kind+".png"))
            material.set_shader_parameter("cutout",kind in ["Foliage","Moss","Ivy"])
            material.set_shader_parameter("moss",kind=="Moss")
            material.set_shader_parameter("earth",kind=="Earth")
            part.set_surface_override_material(i,material)
            landscape_materials.append(material)

func _create_vegetation() -> void:
    pass # Rooted vegetation is authored and batched in the Blender source.

func _create_camera() -> void:
    super._create_camera()
    start = Vector3(6.4,surface_height(6.4,17)+1.85,17)
    camera.position = start
    camera.far = 220
    target_heading = .16
    heading = .16
    target_pitch = .07
    pitch = .07
    mist.shader = load("res://shaders/lowwater_atmosphere.gdshader")
    mist.set_shader_parameter("sun_depth",load("res://assets/textures/LowwaterSunDepth.png"))
    mist.set_shader_parameter("fog_steps",28 if mobile else 48)
    camera.get_child(0).layers = 4
    camera.cull_mask = 7
    reflection_view = SubViewport.new()
    reflection_view.world_3d = view.find_world_3d()
    reflection_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(reflection_view)
    reflection_camera = Camera3D.new()
    reflection_camera.cull_mask = 1
    reflection_camera.far = 145
    reflection_camera.near = .08
    reflection_view.add_child(reflection_camera)
    water_material.set_shader_parameter("reflection_texture",reflection_view.get_texture())
    for argument in OS.get_cmdline_user_args():
        if argument=="--view=canal": camera.position = Vector3(6.1,2.5,-18);heading=.16;pitch=-.12
        if argument=="--view=reverse": camera.position = Vector3(6.8,2.5,-32);heading=PI;pitch=.08
        if argument=="--view=roots": camera.position = Vector3(7.4,2.5,9);heading=-.85;pitch=-.35
        if argument=="--view=canopy": camera.position = Vector3(6.8,2.5,3);heading=.6;pitch=1.05
        if argument=="--view=west": camera.position = Vector3(-4.5,2.5,-18);heading=-.4;pitch=.05
        if argument=="--view=ivy-front": camera.position = Vector3(6.6,2.5,10);heading=-.81;pitch=.26
        if argument=="--view=ivy-back": camera.position = Vector3(14.7,2.5,2);heading=2.35;pitch=.26
        if argument=="--view=moss": camera.position = Vector3(6.5,2.5,9.5);heading=-1.88;pitch=.36
        if argument=="--view=shafts": camera.position = Vector3(6.4,2.5,15);heading=.80;pitch=.15
    target_heading = heading
    target_pitch = pitch

func _look(delta: Vector2) -> void:
    target_heading -= delta.x*.0025
    target_pitch = clampf(target_pitch-delta.y*.0025,-1.1,1.3)

func _reset() -> void:
    super._reset()
    heading = .16
    target_heading = .16
    pitch = .07
    target_pitch = .07
    camera.rotation = Vector3(pitch,heading,0)

func _create_audio() -> void:
    super._create_audio()
    var stream := load("res://assets/audio/lowwater_air.wav") as AudioStreamWAV
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_end = int(stream.get_length()*stream.mix_rate)
    audio.stream = stream
    audio.volume_db = -6
    if sound_on: audio.play()

func _process(delta: float) -> void:
    super._process(delta)
    for material in landscape_materials: material.set_shader_parameter("scene_time",time)
    water_material.set_shader_parameter("scene_time",time)
    reflection_camera.position = Vector3(camera.position.x,-.24-camera.position.y,camera.position.z)
    reflection_camera.rotation = Vector3(-camera.rotation.x,camera.rotation.y,0)
    reflection_camera.fov = camera.fov
    reflection_camera.keep_aspect = camera.keep_aspect

func _resize() -> void:
    super._resize()
    if reflection_view: reflection_view.size = Vector2i(Vector2(view.size)*.40)
