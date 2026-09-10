extends "res://scripts/main.gd"

var is_reservoir := false
var layout: Dictionary
var materials: Array[ShaderMaterial] = []
var drums: Array[Node3D] = []
var dryers: Array[Node3D] = []
var cars: Array[Node3D] = []
var water_material: ShaderMaterial
var reflection_view: SubViewport
var reflection_camera: Camera3D
var art: Node3D
var opening_heading := .32
var opening_pitch := .02

func _ready() -> void:
    is_reservoir = name == "Reservoir"
    experience_id = "reservoir" if is_reservoir else "laundry"
    layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/"+experience_id+"_layout.json"))
    bounds = Vector4(-76,102,-225,30) if is_reservoir else Vector4(-4.,5.4,-4.55,5.45)
    opening_heading = .13 if is_reservoir else .56
    opening_pitch = .11 if is_reservoir else -.015
    time = 0. if is_reservoir else 19.
    super._ready()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--interior-time="): time = float(argument.trim_prefix("--interior-time="))
    _animate()

func _create_view() -> void:
    super._create_view()
    var layer := CanvasLayer.new()
    layer.layer = 10
    view.add_child(layer)
    var grade := ColorRect.new()
    grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var material := ShaderMaterial.new()
    material.shader = load("res://shaders/interior_grade.gdshader")
    material.set_shader_parameter("reservoir",is_reservoir)
    grade.material = material
    layer.add_child(grade)

func surface_height(_x: float,_z: float) -> float:
    return .8 if is_reservoir else 0.

func _in_rect(point: Vector3,rect: Array,margin: float) -> bool:
    return point.x>=rect[0]+margin and point.x<=rect[1]-margin and point.z>=rect[2]+margin and point.z<=rect[3]-margin

func can_walk(point: Vector3) -> bool:
    if is_reservoir:
        for rect in layout.walk_rects:
            if _in_rect(point,rect,.24): return true
        return false
    if not _in_rect(point,layout.bounds,0.): return false
    for key in ["bench","counter","vending","cart","island"]:
        if _in_rect(point,layout[key],-.28): return false
    return true

func _create_environment() -> void:
    world.name = "ReservoirOfColumns" if is_reservoir else "NightLaundry"
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(.27,.32,.34) if is_reservoir else Color(.018,.027,.04)
    world.add_child(environment)
    art = load("res://assets/models/"+("reservoir" if is_reservoir else "night_laundry")+".glb").instantiate() as Node3D
    world.add_child(art)
    var cache: Dictionary = {}
    for part in art.find_children("*","MeshInstance3D",true,false):
        part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        if str(part.name).begins_with("Drum"): drums.append(part)
        if str(part.name).begins_with("Dryer"): dryers.append(part)
        for i in range(part.mesh.get_surface_count()):
            var kind: String = part.mesh.surface_get_material(i).resource_name
            var material: ShaderMaterial
            if cache.has(kind):
                material = cache[kind]
            else:
                material = ShaderMaterial.new()
                cache[kind] = material
                materials.append(material)
                if kind in ["Rain","Drip","Dust","Stream","Splash"]:
                    material.shader = load("res://shaders/interior_particles.gdshader")
                    material.set_shader_parameter("mode",["Rain","Drip","Dust","Stream","Splash"].find(kind))
                    material.render_priority = 2
                elif kind == "Glass":
                    material.shader = load("res://shaders/laundry_glass.gdshader")
                    material.render_priority = 4
                elif kind == "DoorGlass":
                    material.shader = load("res://shaders/laundry_door.gdshader")
                    material.render_priority = 3
                elif kind == "Water":
                    material.shader = load("res://shaders/reservoir_water.gdshader")
                    water_material = material
                else:
                    material.shader = load("res://shaders/interior_surface.gdshader")
                    material.set_shader_parameter("reservoir",is_reservoir)
                    material.set_shader_parameter("road",kind=="Road")
                    material.set_shader_parameter("reflective_floor",kind=="Tile")
                    material.set_shader_parameter("metallic",kind=="Metal")
                    var glowing := ["NeonPink","NeonCyan","TubeLight","Headlamp","Daylight"].find(kind)+1
                    material.set_shader_parameter("glow_kind",glowing)
                    if kind in ["Concrete","Tile","Enamel","Metal","Road"]:
                        material.set_shader_parameter("base_texture",load("res://assets/textures/Interior"+kind+".png"))
                        material.set_shader_parameter("textured",true)
            part.set_surface_override_material(i,material)
        if part.name == "ReservoirWater": part.layers = 2
        if part.name == "Tile": part.layers = 2
        if part.name in ["BeamDust","FallingDrops","OutletStream","OutletSplash"]:
            part.layers = 8
            part.extra_cull_margin = 1.
        if part.name == "StreetRain": part.extra_cull_margin = 10
    if not is_reservoir:
        var car := Node3D.new()
        car.name = "ParkingCar"
        world.add_child(car)
        for part_name in ["CarBody","CarLamps","CarTail"]:
            var part: Node3D = art.find_child(part_name,true,false)
            part.reparent(car,false)
        cars.append(car)
        var passing := car.duplicate() as Node3D
        passing.name = "PassingCar"
        world.add_child(passing)
        cars.append(passing)

func _create_vegetation() -> void:
    pass

func _create_camera() -> void:
    super._create_camera()
    start = Vector3(0,2.65,24) if is_reservoir else Vector3(1.5,1.85,1.7)
    camera.position = start
    camera.far = 340 if is_reservoir else 120
    camera.near = .12
    heading = opening_heading
    pitch = opening_pitch
    mist.shader = load("res://shaders/interior_atmosphere.gdshader")
    # Opaque atmosphere must precede window trails, outdoor rain and beam dust.
    mist.render_priority = -100
    mist.set_shader_parameter("reservoir",is_reservoir)
    mist.set_shader_parameter("fog_steps",24 if mobile else 40)
    camera.get_child(0).layers = 4
    camera.cull_mask = 15
    reflection_view = SubViewport.new()
    reflection_view.world_3d = view.find_world_3d()
    reflection_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(reflection_view)
    reflection_camera = Camera3D.new()
    reflection_camera.cull_mask = 1
    reflection_camera.far = 300 if is_reservoir else 100
    reflection_camera.near = .12
    reflection_view.add_child(reflection_camera)
    if water_material:
        water_material.set_shader_parameter("reflection_texture",reflection_view.get_texture())
    for material in materials:
        if material.get_shader_parameter("reflective_floor")==true:
            material.set_shader_parameter("reflection_texture",reflection_view.get_texture())
    for argument in OS.get_cmdline_user_args():
        if is_reservoir:
            if argument=="--view=water": camera.position=Vector3(.3,2.65,-20);heading=.50;pitch=-.12
            if argument=="--view=ceiling": camera.position=Vector3(0,2.65,-4);heading=-.44;pitch=1.34
            if argument=="--view=reverse": camera.position=Vector3(34,2.65,-82);heading=2.6;pitch=.2
            if argument=="--view=columns": camera.position=Vector3(29,2.65,-34);heading=-.5;pitch=.18
            if argument=="--view=pipe": camera.position=Vector3(-1.45,2.65,-5.5);heading=1.14;pitch=-.25
        else:
            if argument=="--view=machines": camera.position=Vector3(-1,1.85,-3.3);heading=1.8;pitch=-.13
            if argument=="--view=street": camera.position=Vector3(-.3,1.85,-3.6);heading=-.12;pitch=.04
            if argument=="--view=reverse": camera.position=Vector3(1,1.85,-3.9);heading=PI;pitch=.02
            if argument=="--view=ceiling": camera.position=Vector3(1,1.85,0);heading=.4;pitch=1.15
    target_heading = heading
    target_pitch = pitch
    camera.rotation = Vector3(pitch,heading,0)

func _look(delta: Vector2) -> void:
    target_heading -= delta.x*.0025
    target_pitch = clampf(target_pitch-delta.y*.0025,-1.2,1.42)

func _reset() -> void:
    super._reset()
    heading = opening_heading
    pitch = opening_pitch
    target_heading = heading
    target_pitch = pitch
    camera.rotation = Vector3(pitch,heading,0)

func _create_audio() -> void:
    audio = AudioStreamPlayer.new()
    var stream := load("res://assets/audio/"+("reservoir_drips" if is_reservoir else "laundry_rumble")+".wav") as AudioStreamWAV
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_end = int(stream.get_length()*stream.mix_rate)
    audio.stream = stream
    audio.volume_db = -4
    add_child(audio)
    if sound_on: audio.play()

func _animate() -> void:
    if not is_reservoir:
        for i in range(drums.size()): drums[i].rotation.x=time*(.72+i*.047)+sin(time*.2+i)*.15
        for i in range(dryers.size()): dryers[i].rotation.x=-time*(.48+i*.029)+i*.57
        # A parking cycle: approach, turn into bay, wait, reverse out, depart.
        # Vehicles are hidden only beyond the populated street, never at a bay.
        var phase := fmod(time,76.)
        var car := cars[0]
        car.visible = phase<63.
        if phase<12.:
            car.position = Vector3(lerpf(-36.,-6.,phase/12.),-.07,-13.5)
            car.rotation.y = 0.
        elif phase<18.:
            var t := smoothstep(0.,1.,(phase-12.)/6.)
            car.position = Vector3(lerpf(-6.,-2.,t),-.07,lerpf(-13.5,-9.,t))
            car.rotation.y = -PI*.5*t
        elif phase<42.:
            car.position = Vector3(-2.,-.07,-9.)
            car.rotation.y = -PI*.5
        elif phase<49.:
            var t := smoothstep(0.,1.,(phase-42.)/7.)
            car.position = Vector3(lerpf(-2.,2.,t),-.07,lerpf(-9.,-13.5,t))
            car.rotation.y = lerpf(-PI*.5,0.,t)
        else:
            car.position = Vector3(2.+(phase-49.)*3.7,-.07,-13.5)
            car.rotation.y = 0.
        var passing_phase := fmod(time+15.,33.)
        cars[1].position = Vector3(44.-passing_phase*6.,-.07,-19.)
        cars[1].rotation.y = PI
        cars[1].visible = passing_phase<15.
        # Parked headlamps switch off, then on again before reversing.
        cars[0].get_node("CarLamps").visible = phase<20. or phase>40.
    for material in materials:
        material.set_shader_parameter("scene_time",time)
        if not is_reservoir:
            var car := cars[0]
            material.set_shader_parameter("car_position",car.position if car.visible and cars[0].get_node("CarLamps").visible else Vector3(500,0,500))
            material.set_shader_parameter("car_direction",car.basis.x)
    if reflection_camera:
        reflection_camera.position = Vector3(camera.position.x,-camera.position.y,camera.position.z)
        reflection_camera.rotation = Vector3(-camera.rotation.x,camera.rotation.y,0)
        reflection_camera.fov = camera.fov
        reflection_camera.keep_aspect = camera.keep_aspect
    if audio: audio.stream_paused = paused

func _process(delta: float) -> void:
    super._process(delta)
    _animate()

func _resize() -> void:
    super._resize()
    if reflection_view: reflection_view.size = Vector2i(Vector2(view.size)*(.3 if mobile else .45)).max(Vector2i(1,1))
