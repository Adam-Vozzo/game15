extends "res://scripts/main.gd"

var layout: Dictionary
var pixel_material: ShaderMaterial
var pixel_mesh: MeshInstance3D
var drift_material: ShaderMaterial
var drift_mesh: MeshInstance3D

func _ready() -> void:
    experience_id = "signal"
    bounds = Vector4(-31,32,-65,28)
    layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/signal_layout.json"))
    super._ready()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--signal-time="): time = float(argument.trim_prefix("--signal-time="))

func surface_height(x: float,z: float) -> float:
    var trail := -2.9+sin(z*.095)*2.1
    return .045*x+.22*exp(-pow((x-14.)/19.,2.)-pow((z+24.)/27.,2.))-.14*exp(-pow((x+18.)/16.,2.)-pow((z-9.)/23.,2.))-.10*exp(-pow((x-trail)/1.65,2.))

func can_walk(point: Vector3) -> bool:
    for tree in layout.trees:
        if Vector2(point.x-tree.x,point.z-tree.z).length()<tree.radius+.25: return false
    for rock in layout.rocks:
        if Vector2(point.x-rock.x,point.z-rock.z).length()<rock.radius+.16: return false
    return true

func _create_view() -> void:
    super._create_view()
    var layer := CanvasLayer.new()
    layer.layer = 10
    view.add_child(layer)
    var grade := ColorRect.new()
    grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    grade.material = ShaderMaterial.new()
    grade.material.shader = load("res://shaders/signal_grade.gdshader")
    layer.add_child(grade)

func _create_environment() -> void:
    world.name = "SignalGrove"
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(.42,.49,.47)
    world.add_child(environment)
    var art := load("res://assets/models/signal_grove.glb").instantiate() as Node3D
    world.add_child(art)
    pixel_material = ShaderMaterial.new()
    pixel_material.shader = load("res://shaders/signal_pixels.gdshader")
    drift_material = ShaderMaterial.new()
    drift_material.shader = load("res://shaders/signal_drift.gdshader")
    drift_material.render_priority = 127
    for tree in layout.trees:
        if tree.feature:
            for material in [pixel_material,drift_material]:
                material.set_shader_parameter("feature_root",Vector3(tree.x,surface_height(tree.x,tree.z),tree.z))
                material.set_shader_parameter("feature_height",tree.height)
    for part in art.find_children("*","MeshInstance3D",true,false):
        if "Drift" in part.name:
            part.material_override = drift_material
            part.extra_cull_margin = 8.5
            drift_mesh = part
            continue
        if "Pixels" in part.name:
            part.material_override = pixel_material
            pixel_mesh = part
            continue
        for i in range(part.mesh.get_surface_count()):
            var original: Material = part.mesh.surface_get_material(i)
            var kind := "Bark"
            for candidate in ["Earth","Stone","Needles"]:
                if candidate in original.resource_name: kind = candidate
            var material := ShaderMaterial.new()
            material.shader = load("res://shaders/signal_surface.gdshader")
            material.set_shader_parameter("base_texture",load("res://assets/textures/Signal"+kind+".png"))
            material.set_shader_parameter("earth",kind=="Earth")
            material.set_shader_parameter("needles",kind=="Needles")
            part.set_surface_override_material(i,material)

func _create_vegetation() -> void:
    pass # Blender is the source for rooted trees, light cells and understory.

func _create_camera() -> void:
    super._create_camera()
    camera.far = 150
    start = Vector3(-3.0,surface_height(-3.0,11.5)+1.85,11.5)
    camera.position = start
    heading = -.29
    pitch = .28
    mist.shader = load("res://shaders/signal_atmosphere.gdshader")
    mist.render_priority = 100
    mist.set_shader_parameter("fog_steps",18 if mobile else 28)
    for argument in OS.get_cmdline_user_args():
        if argument=="--view=close": camera.position = Vector3(-1,2,3);heading=-.40;pitch=.50
        if argument=="--view=reverse": camera.position = Vector3(4,2,-15);heading=2.95;pitch=.30
        if argument=="--view=side": camera.position = Vector3(14,2,-1);heading=1.41;pitch=.29
        if argument=="--view=under": camera.position = Vector3(2,2,0);heading=.10;pitch=1.12
        if argument=="--view=trail": camera.position = Vector3(-4,2,-28);heading=PI;pitch=.12
        if argument=="--view=ground": camera.position = Vector3(-3,2,11.5);heading=-.6;pitch=-.55
        if argument=="--view=foliage": camera.position = Vector3(-4,2,3);heading=.6;pitch=.55
    target_heading = heading
    target_pitch = pitch

func _look(delta: Vector2) -> void:
    target_heading -= delta.x*.0025
    target_pitch = clampf(target_pitch-delta.y*.0025,-1.1,1.3)

func _resize() -> void:
    super._resize()
    # Preserve the focal tree on a narrow display instead of excessive sky.
    if get_viewport().get_visible_rect().size.x < get_viewport().get_visible_rect().size.y:
        camera.fov = 46

func _reset() -> void:
    super._reset()
    heading = -.29
    target_heading = heading
    pitch = .28
    target_pitch = pitch
    camera.rotation = Vector3(pitch,heading,0)

func _process(delta: float) -> void:
    super._process(delta)
    pixel_material.set_shader_parameter("scene_time",time)
    drift_material.set_shader_parameter("scene_time",time)
    _sync_audio_pause(audio)
