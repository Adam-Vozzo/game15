extends "res://scripts/place.gd"
var birds: Array[Node3D] = []
var fish: Array[Node3D] = []
var turtle: Node3D
var fish_velocities: Array[Vector3] = []
const SCHOOL_CENTRES = [Vector3(2,-.4,-14),Vector3(-17,-.7,-25),Vector3(20,-.8,-24),Vector3(-4,-1.0,-40)]

func _ready() -> void:
    super._ready()
    bounds = Vector4(-48,48,-38,35)

func surface_height(x: float,z: float) -> float:
    if x>=8.25 and x<=11.75 and z<=11.:
        if z>=7.: return lerpf(1.08,.12+.052*11.+.12*sin(x*.06)*11./25.,(z-7.)/4.)
        return 1.08
    if x>=7. and x<=13. and z>=-21. and z<=-15.: return 1.08
    if x>=10. and x<=24.5 and z>=-37. and z<=-33.: return 1.08
    return .12+.052*z+.12*sin(x*.06)*maxf(z,0.)/25.

func can_walk(p: Vector3) -> bool:
    if p.z>=1.: return not (p.x> -18.5 and p.x< -13.5 and p.z>15. and p.z<19.)
    if p.x>17.2:
        if p.x<17.8 and absf(p.z+35.)>.80: return false
        return p.x<24.15 and p.z> -36.8 and p.z< -33.2
    return (p.x>=8.35 and p.x<=11.65 and p.z>=-37.) or (p.x>=7.2 and p.x<=12.8 and p.z>=-20.8 and p.z<=-15.2) or (p.x>=10 and p.x<=24.2 and p.z>=-36.8 and p.z<=-33.2)

func _create_environment() -> void:
    var art := load("res://assets/models/phuket_midday.glb").instantiate() as Node3D
    world.add_child(art)
    for node in art.find_children("*","MeshInstance3D",true,false):
        if "BoatFloat" in node.name:
            boat = node
            boat_origin = boat.position
        for i in range(node.mesh.get_surface_count()):
            var original := node.mesh.surface_get_material(i) as StandardMaterial3D
            var material := ShaderMaterial.new()
            material.shader = load("res://shaders/phuket_surface.gdshader")
            material.set_shader_parameter("base_texture",original.albedo_texture)
            if "PalmCrown" in node.name: material.set_shader_parameter("palm_motion",1.)
            if "Sand" in original.resource_name: material.set_shader_parameter("sand_surface",1.)
            if "Limestone" in original.resource_name: material.set_shader_parameter("limestone",1.)
            node.set_surface_override_material(i,material)
            moving_materials.append(material)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color(.24,.58,.81)
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color(.68,.80,.95)
    env.environment.ambient_light_energy = .32
    env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    world.add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55,-38,0)
    sun.light_color = Color(1.,.97,.88)
    sun.light_energy = 1.05
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 100
    sun.shadow_bias = .035
    world.add_child(sun)
    var ocean := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(2400,1800)
    plane.subdivide_width = 200
    plane.subdivide_depth = 180
    ocean.mesh = plane
    ocean.position.z = -895
    ocean_material = ShaderMaterial.new()
    ocean_material.shader = load("res://shaders/phuket_ocean.gdshader")
    ocean.material_override = ocean_material
    ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world.add_child(ocean)
    _wildlife()

func _small_mesh(vertices: Array,faces: Array,color: Color) -> MeshInstance3D:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for index in faces: st.add_vertex(vertices[index])
    st.generate_normals()
    var node := MeshInstance3D.new()
    node.mesh = st.commit()
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    node.material_override = material
    return node

func _wildlife() -> void:
    for i in range(10):
        var bird := Node3D.new()
        for side in [-1.,1.]:
            var wing := _small_mesh([Vector3.ZERO,Vector3(side*.7,.07,.10),Vector3(side*1.45,0,.42),Vector3(side*.55,0,.35)],[0,1,3,1,2,3],Color(.86,.86,.74))
            bird.add_child(wing)
        bird.add_child(_small_mesh([Vector3(0,0,-.32),Vector3(-.10,0,.25),Vector3(.10,0,.25),Vector3(0,.11,.02)],[0,1,3,0,3,2,1,2,3],Color(.18,.22,.21)))
        birds.append(bird)
        world.add_child(bird)
    for i in range(48):
        var swimmer := _small_mesh([Vector3(0,0,-.24),Vector3(-.075,0,0),Vector3(0,.055,0),Vector3(.075,0,0),Vector3(0,0,.17),Vector3(-.08,0,.25),Vector3(.08,0,.25)],[0,1,2,0,2,3,1,4,2,2,4,3,4,5,6],Color(.11,.30,.31))
        fish.append(swimmer)
        world.add_child(swimmer)
        var group := i/12
        swimmer.position=SCHOOL_CENTRES[group]+Vector3(sin(i*2.4)*3.,sin(i*.7)*.1,cos(i*1.7)*2.)
        fish_velocities.append(Vector3(cos(i*.3),0,sin(i*.3))*.6)
    turtle = Node3D.new()
    var shell := MeshInstance3D.new()
    var shape := SphereMesh.new()
    shape.radius = .40
    shape.height = .28
    shape.radial_segments = 12
    shape.rings = 5
    shell.mesh = shape
    var shell_mat := StandardMaterial3D.new()
    shell_mat.albedo_color = Color(.25,.35,.15)
    shell.material_override = shell_mat
    turtle.add_child(shell)
    for side in [-1.,1.]:
        turtle.add_child(_small_mesh([Vector3(side*.25,0,-.15),Vector3(side*.84,0,.1),Vector3(side*.40,0,.23)],[0,1,2],Color(.32,.40,.19)))
    turtle.add_child(_small_mesh([Vector3(-.1,0,-.3),Vector3(.1,0,-.3),Vector3(0,.07,-.6)],[0,1,2],Color(.34,.42,.20)))
    world.add_child(turtle)

func _create_camera() -> void:
    super._create_camera()
    camera.far = 1800
    start = Vector3(0,surface_height(0,14)+1.85,14)
    camera.position = start
    target_pitch = .06
    pitch = .06
    mist.shader = load("res://shaders/phuket_atmosphere.gdshader")
    mist.render_priority = -100
    for arg in OS.get_cmdline_user_args():
        if arg=="--view=dock": start = Vector3(10,2.93,-9);camera.position=start;target_heading=-.2;heading=-.2
        if arg=="--view=sun": target_pitch=.85;pitch=.85;target_heading=.65;heading=.65
        if arg=="--view=fish": start=Vector3(10,2.93,-7);camera.position=start;target_pitch=-.8;pitch=-.8;target_heading=.6;heading=.6
        if arg=="--view=boat": start=Vector3(10,2.93,-6);camera.position=start;target_pitch=-.40;pitch=-.40;target_heading=.62;heading=.62
        if arg=="--view=hut": start=Vector3(14,2.93,-35);camera.position=start;target_pitch=.03;pitch=.03;target_heading=-PI*.5;heading=-PI*.5
        if arg=="--view=bench": start=Vector3(10,2.93,-18);camera.position=start;target_pitch=-.45;pitch=-.45;target_heading=-PI*.5;heading=-PI*.5
        if arg=="--view=shore": start=Vector3(10,2.93,3);camera.position=start;target_pitch=-.22;pitch=-.22;target_heading=PI;heading=PI

func _look(delta: Vector2) -> void:
    target_heading -= delta.x*.0025
    target_pitch = clampf(target_pitch-delta.y*.0025,-1.10,1.30)

func _reset() -> void:
    super._reset()
    target_pitch = .06

func _create_audio() -> void:
    super._create_audio()
    var stream := load("res://assets/audio/phuket_noon.wav") as AudioStreamWAV
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_end = int(stream.get_length()*stream.mix_rate)
    audio.stream = stream
    audio.volume_db = -3
    if sound_on: audio.play()

func _process(delta: float) -> void:
    super._process(delta)
    if boat and ocean_material:
        ocean_material.set_shader_parameter("boat_inverse",boat.global_transform.affine_inverse())
    for i in range(birds.size()):
        var a := time*.075+i*.72
        var bird := birds[i]
        bird.position = Vector3(cos(a)*(32.+i*4.),19.+i*2.+sin(a*.7)*3.,-80.+sin(a)*24.)
        bird.rotation = Vector3(0,-a,cos(a)*.10)
        bird.get_child(0).rotation.z = sin(time*2.7+i)*.23
        bird.get_child(1).rotation.z = -sin(time*2.7+i)*.23
    if not paused: _school_step(minf(delta,.05))
    turtle.position = Vector3(2.9+sin(time*.055)*2.3,-.13+sin(time*.4)*.025,-14.+cos(time*.055)*3.)
    turtle.rotation.y = -time*.055
    turtle.get_child(1).rotation.z = sin(time*.9)*.15
    turtle.get_child(2).rotation.z = -sin(time*.9)*.15

func _school_step(dt: float) -> void:
    # Snapshot neighbours so flock steering does not depend on update order.
    var positions: Array[Vector3] = []
    for swimmer in fish: positions.append(swimmer.position)
    var velocities := fish_velocities.duplicate()
    for i in range(fish.size()):
        var group := i/12
        var p := positions[i]
        var separation := Vector3.ZERO
        var centre := Vector3.ZERO
        var alignment := Vector3.ZERO
        var count := 0
        for j in range(group*12,group*12+12):
            if i==j: continue
            var offset := p-positions[j]
            var distance := offset.length()
            if distance<5.:
                centre+=positions[j];alignment+=velocities[j];count+=1
                if distance<1.1: separation+=offset/maxf(distance*distance,.05)
        var destination: Vector3 = SCHOOL_CENTRES[group]+Vector3(sin(time*.037+group*1.8)*6.,0,cos(time*.053+group)*3.)
        var steer := (destination-p)*.13+separation*.95
        if count>0: steer+=(centre/float(count)-p)*.10+(alignment/float(count)-velocities[i])*.5
        var boat_delta := p-boat.position
        boat_delta.y=0
        if boat_delta.length()<4.: steer+=boat_delta.normalized()*(4.-boat_delta.length())*.7
        var v: Vector3 = (velocities[i]+steer*dt).limit_length(.95+group*.1)
        v.y=0
        fish_velocities[i]=v
        p+=v*dt
        p.y=clampf(SCHOOL_CENTRES[group].y+sin(time*.8+i)*.055,.12+.052*p.z+.15,-.20)
        fish[i].position=p
        if v.length_squared()>.001: fish[i].rotation.y=atan2(-v.x,-v.z)+sin(time*7.+i)*.035
