extends "res://scripts/main.gd"

var boat_rig: Node3D
var water_material: ShaderMaterial
var beacon: OmniLight3D
var lantern: OmniLight3D
var gentle_motion := false
var glass_material: ShaderMaterial
var spray_material: ShaderMaterial
var whale: Node3D
var whale_material: ShaderMaterial

func _ready() -> void:
    experience_id = "sea"
    bounds = Vector4(-1.12,1.12,-.05,1.8)
    gentle_motion = Session.reduced_motion
    super._ready()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--sea-time="): time = float(argument.trim_prefix("--sea-time="))

func surface_height(_x: float,_z: float) -> float:
    return .91

static func wave_height(p: Vector2,t: float) -> float:
    var group := .78+.22*sin(p.dot(Vector2(.043,-.027))-t*.31)
    var a := p.dot(Vector2(.23,.34))-t*1.65+.38*sin(p.dot(Vector2(.065,-.11))-t*.47)
    var b := p.dot(Vector2(-.41,.19))-t*1.97+.29*sin(p.dot(Vector2(.13,.049))+t*.38)
    var c := p.dot(Vector2(.68,.53))-t*2.8
    return group*1.10*(sin(a)+.22*cos(2*a))+.55*(sin(b)+.20*cos(2*b))+.19*sin(c)+.24*sin(p.dot(Vector2(-.17,.073))-t*.91)+.12*sin(p.dot(Vector2(.91,-.38))-t*3.43)

func _sea_stack(height: float,width: float) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rings: Array[Vector3] = []
    var facets := 9
    var radii: Array[float] = []
    for j in range(facets): radii.append(rng.randf_range(.65,1.2))
    for level in range(5):
        var f := float(level)/4.
        var taper := [1.0,.91,.70,.48,.13][level] as float
        for j in range(facets):
            var angle := TAU*float(j)/facets
            rings.append(Vector3(cos(angle)*width*radii[j]*taper+f*f*width*.65,height*f-2.+rng.randf_range(-.4,.4),sin(angle)*width*radii[j]*taper*.72))
    for level in range(4):
        for j in range(facets):
            var a := level*facets+j
            var b := level*facets+(j+1)%facets
            var c := b+facets
            var d := a+facets
            var tint := rng.randf_range(.055,.115)
            for index in [a,c,b,a,d,c]:
                st.set_color(Color(tint*.7,tint*.90,tint))
                st.add_vertex(rings[index])
    st.generate_normals()
    return st.commit()

func _sea_arch() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var points: Array[Vector3] = []
    for j in range(13):
        var a := PI*float(j)/12.
        var outer := 1.+rng.randf_range(-.075,.075)
        for offset in [-2.5,2.5]:
            points.append(Vector3(cos(a)*10.*outer,sin(a)*23.*outer-1.,offset))
            points.append(Vector3(cos(a)*5.8,sin(a)*15.5-1.,offset))
    for j in range(12):
        var k := j*4
        for face in [[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]:
            var shade := rng.randf_range(.075,.13)
            for index in [face[0],face[1],face[2],face[0],face[2],face[3]]:
                st.set_color(Color(shade*.7,shade*.9,shade))
                st.add_vertex(points[k+index])
    st.generate_normals()
    return st.commit()

func _create_environment() -> void:
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color(.03,.06,.07)
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color(.27,.39,.42)
    env.environment.ambient_light_energy = .55
    env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    world.add_child(env)
    whale=load("res://assets/models/night_whale.glb").instantiate() as Node3D
    whale.name="PassingWhale"
    world.add_child(whale)
    whale_material=ShaderMaterial.new()
    whale_material.shader=load("res://shaders/whale.gdshader")
    for part in whale.find_children("*","MeshInstance3D",true,false):
        part.material_override=whale_material
    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-33,-24,0)
    moon.light_color = Color(.49,.66,.68)
    moon.light_energy = .40
    world.add_child(moon)
    boat_rig = Node3D.new()
    boat_rig.name = "WaveDrivenBoat"
    world.add_child(boat_rig)
    var model := load("res://assets/models/night_crossing.glb").instantiate() as Node3D
    boat_rig.add_child(model)
    glass_material = ShaderMaterial.new()
    glass_material.shader = load("res://shaders/sea_glass.gdshader")
    for pane in [Vector3(-1.16,2.72,-1.265),Vector3(.52,2.72,-1.265)]:
        var glass := MeshInstance3D.new()
        var quad := QuadMesh.new()
        quad.size = Vector2(.90 if pane.x < 0 else 2.16,1.28)
        glass.mesh = quad
        glass.position = pane
        glass.material_override = glass_material
        boat_rig.add_child(glass)
    lantern = OmniLight3D.new()
    lantern.position = Vector3(-1.28,3.15,-.62)
    lantern.light_color = Color(1.,.57,.23)
    lantern.light_energy = 1.65
    lantern.omni_range = 5.5
    boat_rig.add_child(lantern)
    water_material = ShaderMaterial.new()
    water_material.shader = load("res://shaders/sea_water.gdshader")
    # Dense near field catches sharp wave profiles; distant rings preserve horizon.
    var ocean := MeshInstance3D.new()
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(220,220)
    mesh.subdivide_width = 220 if mobile else 340
    mesh.subdivide_depth = 220 if mobile else 340
    ocean.mesh = mesh
    ocean.material_override = water_material
    ocean.extra_cull_margin = 8
    world.add_child(ocean)
    spray_material = ShaderMaterial.new()
    spray_material.shader = load("res://shaders/sea_spray.gdshader")
    var spray := MultiMeshInstance3D.new()
    spray.name = "WindTornCrestSpray"
    var cards := MultiMesh.new()
    cards.transform_format = MultiMesh.TRANSFORM_3D
    cards.use_custom_data = true
    var card := QuadMesh.new()
    card.size = Vector2(2.2,1.65)
    cards.mesh = card
    cards.instance_count = 350 if mobile else 650
    cards.custom_aabb = AABB(Vector3(-75,-8,-105),Vector3(150,25,140))
    for i in range(cards.instance_count):
        var point := Vector3(rng.randf_range(-65,65),0,rng.randf_range(-95,25))
        if absf(point.x)<3.8 and point.z>-8. and point.z<5.: point.x += 8.
        cards.set_instance_transform(i,Transform3D(Basis.IDENTITY,point))
        cards.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
    spray.multimesh = cards
    spray.material_override = spray_material
    spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world.add_child(spray)
    for pos in [Vector3(0,0,-310),Vector3(-310,0,0),Vector3(310,0,0),Vector3(0,0,310)]:
        var far_water := MeshInstance3D.new()
        var far_mesh := PlaneMesh.new()
        far_mesh.size = Vector2(620,620)
        far_mesh.subdivide_width = 90
        far_mesh.subdivide_depth = 90
        # Separate far patches begin outside the near field, with no overlap.
        if pos.x == 0: far_mesh.size = Vector2(220,400); pos.z = signf(pos.z)*310
        else: far_mesh.size = Vector2(400,1020)
        far_water.mesh = far_mesh
        far_water.position = pos
        far_water.material_override = water_material
        far_water.extra_cull_margin = 8
        world.add_child(far_water)
    var rock_material := StandardMaterial3D.new()
    rock_material.albedo_color = Color(.55,.67,.65)
    rock_material.vertex_color_use_as_albedo = true
    rock_material.roughness = .96
    rock_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    var arch := MeshInstance3D.new()
    arch.mesh = _sea_arch()
    arch.material_override = rock_material
    arch.position = Vector3(-24,0,-48)
    arch.rotation.y = -.18
    world.add_child(arch)
    # Unequal island groups on both sides and astern, with open channels between.
    for cluster in [Vector3(51,0,-66),Vector3(92,0,-135),Vector3(-108,0,-164),Vector3(62,0,62),Vector3(-65,0,86)]:
        for i in range(7):
            var island := MeshInstance3D.new()
            island.mesh = _sea_stack(rng.randf_range(8.,28.),rng.randf_range(5.,12.))
            island.material_override = rock_material
            island.position = cluster+Vector3(rng.randf_range(-18,18),-1.,rng.randf_range(-17,17))
            island.rotation.y = rng.randf()*TAU
            world.add_child(island)
    var far_arch := MeshInstance3D.new()
    far_arch.mesh = _sea_arch()
    far_arch.material_override = rock_material
    far_arch.position = Vector3(42,0,-78)
    far_arch.rotation.y = -.7
    far_arch.scale = Vector3(1.3,.8,1.1)
    world.add_child(far_arch)
    for i in range(15):
        var rock := MeshInstance3D.new()
        var height := 9.+rng.randf()*25.
        rock.mesh = _sea_stack(height,3.+rng.randf()*5.)
        rock.material_override = rock_material
        rock.position = Vector3(-24.-rng.randf()*35.,0,-32.-i*7.)
        rock.rotation = Vector3(rng.randf_range(-.15,.15),rng.randf()*6.,rng.randf_range(-.2,.2))
        world.add_child(rock)
    # Broad, eroded stacks below the needles make a readable broken coastline.
    for i in range(6):
        var stack := MeshInstance3D.new()
        stack.mesh = _sea_stack(10.+i*1.6,8.+rng.randf()*4.)
        stack.material_override = rock_material
        stack.position = Vector3(-31.-i*5.,-1.,-42.-i*15.)
        stack.rotation.y = rng.randf()*TAU
        world.add_child(stack)
    # A lonely navigation tower beyond the rocks, not a populated shoreline.
    var tower := MeshInstance3D.new()
    var tower_mesh := CylinderMesh.new()
    tower_mesh.bottom_radius = 1.5
    tower_mesh.top_radius = 1.0
    tower_mesh.height = 15
    tower_mesh.radial_segments = 8
    tower.mesh = tower_mesh
    tower.position = Vector3(-48,17,-91)
    tower.material_override = rock_material
    world.add_child(tower)
    var light_dot := MeshInstance3D.new()
    var dot_mesh := SphereMesh.new()
    dot_mesh.radius = .45
    dot_mesh.height = .9
    light_dot.mesh = dot_mesh
    light_dot.position = Vector3(-48,24.8,-91)
    var dot_mat := StandardMaterial3D.new()
    dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dot_mat.albedo_color = Color(.86,.71,.39)
    light_dot.material_override = dot_mat
    world.add_child(light_dot)

func _create_vegetation() -> void:
    pass

func _create_camera() -> void:
    super._create_camera()
    camera.reparent(boat_rig,false)
    start = Vector3(.25,2.76,.9)
    camera.position = start
    camera.far = 700
    mist.shader = load("res://shaders/sea_atmosphere.gdshader")
    # Composite opaque sea/sky first; real transparent spray and glass follow it.
    mist.render_priority = -100

func _create_interface() -> void:
    super._create_interface()
    top_label.text = ""
    subtitle.text = "THE LAST BOAT HOME"
    footer.text = "Keep the light in sight"
    _button("Gentle motion" if gentle_motion else "Full motion",func():
        gentle_motion = not gentle_motion
        controls.get_child(3).text = "Gentle motion" if gentle_motion else "Full motion"
    )

func _resize() -> void:
    super._resize()
    if get_viewport().get_visible_rect().size.x < get_viewport().get_visible_rect().size.y:
        camera.keep_aspect = Camera3D.KEEP_HEIGHT
        camera.fov = 70
    hint.text = "DRAG TO LOOK · MOVE AROUND THE HELM" if not mobile else "LEFT THUMB TO MOVE · DRAG TO LOOK"

func _create_audio() -> void:
    super._create_audio()
    var stream := load("res://assets/audio/night_sea.wav") as AudioStreamWAV
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_end = int(stream.get_length()*stream.mix_rate)
    audio.stream = stream
    audio.volume_db = -3
    if sound_on: audio.play()

func _process(delta: float) -> void:
    super._process(delta)
    var angle := time*.027+.4
    var track := Vector3(sin(angle)*20.,0,-26.+cos(angle)*8.)
    var cycle := fmod(time,78.)
    var surface := exp(-pow((cycle-13.)/6.,2.))+exp(-pow((cycle-51.)/4.5,2.))
    track.y=-5.3+surface*4.5+wave_height(Vector2(track.x,track.z),time)*.22
    whale.position=track
    whale.rotation.y=atan2(-20.*cos(angle),8.*sin(angle))
    whale.rotation.x=sin(time*.12)*.035
    whale_material.set_shader_parameter("sea_time",time)
    water_material.set_shader_parameter("sea_time",time)
    glass_material.set_shader_parameter("sea_time",time)
    spray_material.set_shader_parameter("sea_time",time)
    var h := wave_height(Vector2.ZERO,time)
    var roll := atan2(wave_height(Vector2(1.7,0),time)-wave_height(Vector2(-1.7,0),time),3.4)
    var tilt := atan2(wave_height(Vector2(0,-3),time)-wave_height(Vector2(0,3),time),6.)
    var strength := .24 if gentle_motion else .62
    boat_rig.rotation = Vector3(tilt*strength,0,roll*strength)
    # Support the full hull footprint, not only the wave at its centre. The old
    # centre sample could sink the bow through an adjacent crest and expose its mask.
    var support := h*.75
    for z in [-5.3,-4.,-2.5,-1.,.5,2.2]:
        var width := .35 if z < -5. else (1.0 if z < -3. else 1.45)
        for x in [-width,0.,width]:
            var deck := boat_rig.basis*Vector3(x,.66,z)
            support = maxf(support,wave_height(Vector2(deck.x,deck.z),time)-deck.y)
    boat_rig.position.y = support
    water_material.set_shader_parameter("boat_inverse",boat_rig.global_transform.affine_inverse())
    lantern.light_energy = 1.65+sin(time*5.3)*.035+sin(time*8.1)*.02
