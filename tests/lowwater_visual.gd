extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func settle() -> void:
    for i in range(6): await process_frame
    await RenderingServer.frame_post_draw

func run() -> void:
    change_scene_to_file("res://lowwater.tscn")
    await process_frame
    await process_frame
    var scene: Node = current_scene
    scene.paused=true
    scene.time=0.
    await settle()
    var first: Image = scene.view.get_texture().get_image()
    var low := 1.
    var high := 0.
    for y in range(0,first.get_height(),8):
        for x in range(0,first.get_width(),8):
            var value := first.get_pixel(x,y).get_luminance()
            low=minf(low,value)
            high=maxf(high,value)
    assert(low<.025 and high>.94,"Print must contain deep blacks and bright whites")
    await settle()
    var frozen: Image = scene.view.get_texture().get_image()
    assert(first.get_data()==frozen.get_data(),"Paused fog, moss and reflection must remain visually frozen")
    scene.mist.set_shader_parameter("shaft_strength",0.)
    await settle()
    var without_shafts: Image=scene.view.get_texture().get_image()
    assert(image_difference(first,without_shafts)>.003,"Canopy sunlight must contribute visible shafts to the actual render")
    scene.mist.set_shader_parameter("shaft_strength",.72)
    scene.mist.set_shader_parameter("ground_mist_strength",0.)
    await settle()
    var without_ground_mist: Image=scene.view.get_texture().get_image()
    assert(image_difference(first,without_ground_mist)>.0005,"Low ground ribbons must be visible in the actual render")
    scene.mist.set_shader_parameter("ground_mist_strength",.095)
    scene.time=24.
    await settle()
    var later: Image = scene.view.get_texture().get_image()
    assert(first.get_data()!=later.get_data(),"Fog and moss must evolve over time")
    later.save_png("res://build-logs/lowwater-time24.png")
    var reflection: Image = scene.reflection_view.get_texture().get_image()
    var reflection_low := 1.
    var reflection_high := 0.
    for y in range(0,reflection.get_height(),5):
        for x in range(0,reflection.get_width(),5):
            var value := reflection.get_pixel(x,y).get_luminance()
            reflection_low=minf(reflection_low,value)
            reflection_high=maxf(reflection_high,value)
    assert(reflection_high-reflection_low>.15,"Reflection viewport must contain landscape detail")
    await check_leaf_faces()
    scene.camera.position=Vector3(6.8,2.5,3)
    scene.heading=.6
    scene.target_heading=.6
    scene.pitch=1.05
    scene.target_pitch=1.05
    await settle()
    var overhead: Image=scene.view.get_texture().get_image()
    var canopy_pixels := 0
    var samples := 0
    for y in range(0,overhead.get_height(),6):
        for x in range(0,overhead.get_width(),6):
            samples+=1
            if overhead.get_pixel(x,y).get_luminance()<.6: canopy_pixels+=1
    var coverage:=float(canopy_pixels)/samples
    assert(coverage>.65 and coverage<.97,"Overhead foliage needs both enclosure and visible skylight gaps")
    print("PASS: rendered black/white range, frozen Pause, visible canopy shafts and ground mist, evolving atmosphere, planar reflection, balanced leaf faces and porous overhead canopy")
    quit(0)

func image_difference(a: Image,b: Image) -> float:
    var difference:=0.
    var count:=0
    for y in range(0,a.get_height(),4):
        for x in range(0,a.get_width(),4):
            difference+=absf(a.get_pixel(x,y).get_luminance()-b.get_pixel(x,y).get_luminance())
            count+=1
    return difference/count

func check_leaf_faces() -> void:
    # View the same leaf from opposite sides under one fixed light. Both views
    # must retain comparable diffuse values; the print curve cannot hide a flip.
    var viewport := SubViewport.new()
    viewport.size=Vector2i(128,128)
    viewport.own_world_3d=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var environment := WorldEnvironment.new()
    environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR
    environment.environment.background_color=Color(.01,.01,.01)
    environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color=Color(.70,.71,.62)
    environment.environment.ambient_light_energy=.48
    viewport.add_child(environment)
    var light := DirectionalLight3D.new()
    light.rotation_degrees=Vector3(-49,-26,0)
    light.light_energy=.62
    viewport.add_child(light)
    var leaf := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size=Vector2(1.5,1.5)
    leaf.mesh=quad
    leaf.position.y=1.
    var material := ShaderMaterial.new()
    material.shader=load("res://shaders/lowwater_surface.gdshader")
    material.set_shader_parameter("base_texture",load("res://assets/textures/LowwaterIvy.png"))
    material.set_shader_parameter("cutout",true)
    leaf.material_override=material
    viewport.add_child(leaf)
    var camera := Camera3D.new()
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=2.
    camera.position=Vector3(0,1,3)
    viewport.add_child(camera)
    await settle()
    var front: Image=viewport.get_texture().get_image()
    camera.position.z=-3
    camera.rotation.y=PI
    await settle()
    var back: Image=viewport.get_texture().get_image()
    var front_value := 0.
    var back_value := 0.
    for y in range(128):
        for x in range(128):
            front_value+=front.get_pixel(x,y).get_luminance()
            back_value+=back.get_pixel(x,y).get_luminance()
    assert(front_value>200.,"Leaf study must be visible")
    assert(absf(front_value-back_value)/front_value<.035,"Opposite leaf faces must not split into white and black")
    front.save_png("res://build-logs/lowwater-leaf-face-front.png")
    back.save_png("res://build-logs/lowwater-leaf-face-back.png")
    viewport.queue_free()
