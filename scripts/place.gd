extends "res://scripts/main.gd"
@export_enum("coast", "town") var place: String = "coast"
var moving_materials: Array[ShaderMaterial] = []
var boat: Node3D
var boat_origin := Vector3.ZERO
var ocean_material: ShaderMaterial

func _ready() -> void:
    experience_id = place
    bounds = Vector4(-25,25,-.8,24) if place == "coast" else Vector4(-20,20,-54,18)
    super._ready()

func surface_height(x: float, z: float) -> float:
    if place == "coast":
        return .07+.065*(z-(1.+sin(x*.09)*1.1))+.12*sin(x*.07)*maxf(0,z)/24.
    return .03+maxf(0,-z)*.012+absf(x)*.003

func can_walk(point: Vector3) -> bool:
    if place == "coast": return true
    var footprints := [Rect2(-12,-.5,8.1,11),Rect2(4,-6,8,10),Rect2(-13.6,-17,9.2,12),Rect2(4.8,-23.5,8.4,11),Rect2(-13,-33,8,10),Rect2(3.9,-41.5,8.2,11),Rect2(-13.6,-50.5,9.2,11)]
    for rect in footprints:
        if rect.has_point(Vector2(point.x,point.z)): return false
    return true

func _create_environment() -> void:
    var art = load("res://assets/models/" + ("phuket_coast" if place == "coast" else "kasumi_town") + ".glb").instantiate()
    world.add_child(art)
    for node in art.find_children("*","MeshInstance3D",true,false):
        if "BoatFloat" in node.name:
            boat = node
            boat_origin = boat.position
        for i in range(node.mesh.get_surface_count()):
            var original: StandardMaterial3D = node.mesh.surface_get_material(i)
            var material := ShaderMaterial.new()
            material.shader = load("res://shaders/place_surface.gdshader")
            material.set_shader_parameter("base_texture",original.albedo_texture)
            material.set_shader_parameter("base_color",original.albedo_color)
            material.set_shader_parameter("light_color",Vector3(1.30,1.12,.90) if place=="coast" else Vector3(.80,.88,.89))
            material.set_shader_parameter("light_direction",Vector3(-.27,.15,-1) if place=="coast" else Vector3(-.2,.8,.1))
            if "PalmCrown" in node.name: material.set_shader_parameter("motion",1.)
            if "NorenFlag" in node.name or "Laundry" in node.name: material.set_shader_parameter("motion",2.)
            if "WindowGlow" in original.resource_name: material.set_shader_parameter("glow",1.)
            if "WetStone" in original.resource_name: material.set_shader_parameter("wetness",1.)
            if "Sand" in original.resource_name: material.set_shader_parameter("sand_surface",1.)
            node.set_surface_override_material(i,material)
            moving_materials.append(material)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color(.25,.3,.32)
    env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    world.add_child(env)
    if place == "coast":
        var ocean := MeshInstance3D.new()
        var plane := PlaneMesh.new()
        plane.size = Vector2(700,700)
        plane.subdivide_width = 150
        plane.subdivide_depth = 150
        ocean.mesh = plane
        ocean.position = Vector3(0,0,-325)
        ocean_material = ShaderMaterial.new()
        ocean_material.shader = load("res://shaders/ocean.gdshader")
        ocean.material_override = ocean_material
        world.add_child(ocean)

func _create_vegetation() -> void:
    pass

func _create_camera() -> void:
    super._create_camera()
    camera.far = 600 if place == "coast" else 220
    start = Vector3(0,surface_height(0,13)+1.85,13) if place=="coast" else Vector3(0,surface_height(0,17)+1.85,17)
    camera.position = start
    target_pitch = -.07 if place=="coast" else .035
    pitch = target_pitch
    mist.shader = load("res://shaders/place_atmosphere.gdshader")
    mist.set_shader_parameter("place_kind",0 if place=="coast" else 1)

func _create_interface() -> void:
    super._create_interface()
    top_label.text = "L A S T   L I G H T" if place=="coast" else "K A S U M I"
    subtitle.text = "PHUKET · THE ANDAMAN SHORE" if place=="coast" else "A QUIET MOUNTAIN TOWN"
    footer.text = "The day leaves slowly" if place=="coast" else "Someone left a light on"

func _create_audio() -> void:
    audio = AudioStreamPlayer.new()
    var stream: AudioStreamWAV = load("res://assets/audio/" + ("coast_wash" if place=="coast" else "town_rain") + ".wav")
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_end = int(stream.get_length()*stream.mix_rate)
    audio.stream = stream
    audio.volume_db = -3
    add_child(audio)
    if sound_on: audio.play()

func _reset() -> void:
    super._reset()
    target_pitch = -.07 if place=="coast" else .035

func _process(delta: float) -> void:
    super._process(delta)
    for material in moving_materials: material.set_shader_parameter("scene_time",time)
    if ocean_material: ocean_material.set_shader_parameter("scene_time",time)
    if boat:
        boat.position = boat_origin+Vector3(0,sin(time*.65)*.032,0)
        boat.rotation.x = sin(time*.42)*.007
        boat.rotation.z = sin(time*.58)*.008
