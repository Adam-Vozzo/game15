extends "res://scripts/main.gd"

var layout: Dictionary
var fields: Array
var footprints: Array[Rect2] = []
var obstacles: Array[Rect2] = []
var moving_materials: Array[ShaderMaterial] = []
var materials: Dictionary = {}
var plant_meshes: Dictionary = {}
var water_material: ShaderMaterial
var vegetation_instances := 0

func _ready() -> void:
    experience_id = "town"
    layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/kasumi_layout.json"))
    fields = layout.fields
    bounds = Vector4(layout.bounds[0],layout.bounds[1],layout.bounds[2],layout.bounds[3])
    for building in layout.buildings:
        var r: Array = building.rect
        footprints.append(Rect2(r[0],r[1],r[2],r[3]).grow(.15))
    for r in layout.obstacles:
        obstacles.append(Rect2(r[0],r[1],r[2],r[3]))
    super._ready()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--view="):
            _composition(argument.trim_prefix("--view="))
    print("KASUMI: ",footprints.size()," buildings, ",fields.size()," fields, ",layout.trees.size()," trees, ",vegetation_instances," plant instances")

func _base_height(x: float,z: float) -> float:
    return .03+maxf(0,-z)*.007+sin(x*.032)*sin(z*.033)*.07

func surface_height(x: float,z: float) -> float:
    for surface in layout.walk_surfaces:
        var r: Array = surface.rect
        if Rect2(r[0],r[1],r[2],r[3]).has_point(Vector2(x,z)):return surface.height
    for field in fields:
        var r: Array = field.rect
        if Rect2(r[0],r[1],r[2],r[3]).has_point(Vector2(x,z)):
            return field.height+.13 if field.crop=="rice" else field.height
    return _base_height(x,z)

func can_walk(point: Vector3) -> bool:
    for rect in footprints:
        if rect.has_point(Vector2(point.x,point.z)): return false
    for rect in obstacles:
        if rect.has_point(Vector2(point.x,point.z)): return false
    return true

func _material(tile: int,cloth_motion: bool=false,plant_motion: int=0,foliage_kind: int=0) -> ShaderMaterial:
    var key := "%d:%s:%d:%d" % [tile,cloth_motion,plant_motion,foliage_kind]
    if materials.has(key): return materials[key]
    var material := ShaderMaterial.new()
    material.shader = load("res://shaders/kasumi_surface.gdshader")
    material.set_shader_parameter("atlas",load("res://assets/textures/KasumiAtlas%d.png" % (tile/4)))
    material.set_shader_parameter("tile",tile)
    if plant_motion>1:
        material.set_shader_parameter("foliage",load("res://assets/textures/KasumiFoliage.png"))
        material.set_shader_parameter("foliage_kind",foliage_kind)
    material.set_shader_parameter("cloth",1.0 if cloth_motion else 0.0)
    material.set_shader_parameter("plant",float(plant_motion))
    materials[key] = material
    if cloth_motion or plant_motion>0: moving_materials.append(material)
    return material

func _create_environment() -> void:
    world.name = "KasumiValley"
    var art = load("res://assets/models/kasumi_town.glb").instantiate()
    world.add_child(art)
    for node in art.find_children("*","MeshInstance3D",true,false):
        var cloth_motion: bool = "Noren" in node.name or "Laundry" in node.name
        for i in range(node.mesh.get_surface_count()):
            var original: Material = node.mesh.surface_get_material(i)
            var tile := int(original.resource_name.substr(1,2))
            if "Mountain_rim" in node.name:
                var material: ShaderMaterial = _material(tile).duplicate()
                material.set_shader_parameter("mountain",1.0)
                node.set_surface_override_material(i,material)
            elif "Valley_floor" in node.name:
                var material: ShaderMaterial = _material(4).duplicate()
                material.set_shader_parameter("terrain_surface",1.0)
                node.set_surface_override_material(i,material)
            else:
                node.set_surface_override_material(i,_material(tile,cloth_motion))
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(.45,.52,.55)
    environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    world.add_child(environment)
    water_material = ShaderMaterial.new()
    water_material.shader = load("res://shaders/kasumi_water.gdshader")
    for field in fields:
        if field.crop!="rice": continue
        var r: Array = field.rect
        var water := MeshInstance3D.new()
        var plane := PlaneMesh.new()
        plane.size = Vector2(r[2]-.12,r[3]-.12)
        water.mesh = plane
        water.position = Vector3(r[0]+r[2]*.5,field.height+.12,r[1]+r[3]*.5)
        water.material_override = water_material
        water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        world.add_child(water)

func _instances(mesh_name: String,transforms: Array[Transform3D],tile: int,motion: int) -> void:
    if transforms.is_empty(): return
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = plant_meshes[mesh_name]
    multi.instance_count = transforms.size()
    for i in range(transforms.size()): multi.set_instance_transform(i,transforms[i])
    var patch := MultiMeshInstance3D.new()
    patch.name = mesh_name+"Patch"
    patch.multimesh = multi
    if tile>=0: patch.material_override = _material(tile,false,motion,int(mesh_name.substr(5,1)) if motion>1 else 0)
    patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world.add_child(patch)
    vegetation_instances += transforms.size()

func _transform_at(x: float,y: float,z: float,size: float=1.0,angle: float=-1.0) -> Transform3D:
    var rotation := rng.randf()*TAU if angle<0 else angle
    return Transform3D(Basis(Vector3.UP,rotation).scaled(Vector3.ONE*size),Vector3(x,y,z))

func _create_vegetation() -> void:
    rng.seed = 91531
    var catalog = load("res://assets/models/kasumi_plants.glb").instantiate()
    for node in catalog.find_children("*","MeshInstance3D",true,false):
        var mesh: Mesh = node.mesh.duplicate()
        for i in range(mesh.get_surface_count()):
            var original: Material = mesh.surface_get_material(i)
            var tile := int(original.resource_name.substr(1,2))
            mesh.surface_set_material(i,_material(tile,false,1))
        plant_meshes[String(node.name)] = mesh
    catalog.free()
    for kind in range(3):
        var trees: Array[Transform3D] = []
        for tree in layout.trees:
            if int(tree[4])==kind: trees.append(_transform_at(tree[0],tree[1],tree[2],tree[3],tree[5]))
        _instances("Tree_%d_trunk"%kind,trees,10,2)
        _instances("Tree_%d_crown"%kind,trees,11,2)
    for field in fields:
        var r: Array = field.rect
        var transforms: Array[Transform3D] = []
        var rice: bool = field.crop=="rice"
        var spacing := (1.1 if mobile else .80) if rice else (.86 if mobile else .64)
        var nx := int((r[2]-.8)/spacing)
        var nz := int((r[3]-.8)/spacing)
        for iz in range(nz):
            for ix in range(nx):
                var x: float = r[0]+.55+ix*spacing+rng.randf_range(-.10,.10)
                var z: float = r[1]+.55+iz*spacing+rng.randf_range(-.10,.10)
                transforms.append(_transform_at(x,field.height+.02,z,rng.randf_range(.72,1.15)))
        _instances("Rice" if rice else "Wheat",transforms,11 if rice else 12,1)
    # Verge tufts grow along drainage, behind houses and over the field banks.
    for row in range(8):
        var tufts: Array[Transform3D] = []
        var flowers: Array[Transform3D] = []
        for i in range(280 if mobile else 500):
            var z := -94.+row*23.+rng.randf()*23.
            var x := rng.randf_range(-91,91)
            if absf(x)<2.5: continue
            var on_bank := false
            for field in fields:
                var r: Array = field.rect
                var rect := Rect2(r[0],r[1],r[2],r[3])
                if rect.has_point(Vector2(x,z)):
                    on_bank = true
                    break
            if on_bank or not can_walk(Vector3(x,0,z)) or _on_shrine(x,z):continue
            tufts.append(_transform_at(x,surface_height(x,z),z,rng.randf_range(.60,1.8)))
        for i in range(45):
            var z := -70.+row*17.+rng.randf()*3.
            var x := rng.randf_range(2.48,2.75)*(1 if i%2 else -1)
            flowers.append(_transform_at(x,surface_height(x,z),z,rng.randf_range(.65,1.1)))
        _instances("Verge",tufts,11,1)
        _instances("Lily",flowers,-1,1)
    for side in [-1,1]:
        var garden: Array[Transform3D] = []
        for i in range(1400 if mobile else 2400):
            var x: float = side*rng.randf_range(10.0,18.0)
            var z := rng.randf_range(-80,76)
            if absf(z-17)<1.8 or absf(z+51)<1.8 or not can_walk(Vector3(x,0,z)) or _on_shrine(x,z):continue
            garden.append(_transform_at(x,surface_height(x,z),z,rng.randf_range(.7,1.75)))
        _instances("Verge",garden,11,1)

func _create_camera() -> void:
    super._create_camera()
    camera.far = 900
    start = Vector3(.25,surface_height(.25,19)+1.85,19)
    camera.position = start
    target_pitch = .035
    pitch = target_pitch
    mist.shader = load("res://shaders/kasumi_atmosphere.gdshader")
    mist.set_shader_parameter("fog_steps",20 if mobile else 28)
    mist.set_shader_parameter("ao_strength",.68)

func _on_shrine(x: float,z: float) -> bool:
    for surface in layout.walk_surfaces:
        var r: Array = surface.rect
        if Rect2(r[0],r[1],r[2],r[3]).grow(.18).has_point(Vector2(x,z)):return true
    return false

func _create_interface() -> void:
    super._create_interface()
    top_label.text = "K A S U M I"
    subtitle.text = "THE LANE · THE LOWER FIELDS"
    footer.text = "Someone left a light on"

func _create_audio() -> void:
    audio = AudioStreamPlayer.new()
    var stream: AudioStreamWAV = load("res://assets/audio/town_rain.wav")
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_end = int(stream.get_length()*stream.mix_rate)
    audio.stream = stream
    audio.volume_db = -3
    add_child(audio)
    if sound_on: audio.play()

func _process(delta: float) -> void:
    super._process(delta)
    for material in moving_materials: material.set_shader_parameter("scene_time",time)
    if water_material: water_material.set_shader_parameter("scene_time",time)

func _composition(id: String) -> void:
    # Reproducible art review views use the same production camera and renderer.
    var views := {"fields":[Vector3(17,0,39),-.86,.055],"wheat":[Vector3(-16,0,21),.93,.04],"back":[Vector3(0,0,17),PI,.025],"shrine":[Vector3(17,0,-49),.55,-.10],"edge":[Vector3(82,0,69),-2.18,-.03],"walls":[Vector3(-14,0,8),-.37,-.32],"tree":[Vector3(-17,0,24),-.5,.43],"ground":[Vector3(-13,0,37),-.4,-.45]}
    if not views.has(id):return
    var spec: Array = views[id]
    var p: Vector3 = spec[0]
    p.y = surface_height(p.x,p.z)+1.85
    camera.position = p
    heading = spec[1]
    target_heading = heading
    pitch = spec[2]
    target_pitch = pitch
