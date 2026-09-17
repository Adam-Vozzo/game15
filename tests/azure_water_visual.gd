extends SceneTree

func _initialize() -> void:call_deferred("run")

func capture(label: String) -> Image:
    for i in range(4):await process_frame
    await RenderingServer.frame_post_draw
    var img:Image=current_scene.view.get_texture().get_image()
    img.save_png("res://build-logs/azure-water-"+label+".png")
    return img

func difference(a: Image,b: Image) -> float:
    var total:=0.
    for y in range(0,a.get_height(),3):
        for x in range(0,a.get_width(),3):
            var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
            total+=absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)
    return total/(a.get_width()*a.get_height()/9.)

func run() -> void:
    change_scene_to_file("res://azure.tscn")
    for i in range(10):await process_frame
    var s:Node=current_scene
    s.set_process(false);s.paused=true;s.time=11.;s._process(0.)
    s.review_camera=true
    s.camera.global_position=Vector3(37,27,94);s.camera.look_at(Vector3(-16,-8,8))
    var opening:=await capture("main")
    s._process(.04)
    var frozen:=await capture("paused")
    assert(difference(opening,frozen)<.00001,"Pause must freeze shader currents and every particle layer")
    for material in s.particle_materials:material.set_shader_parameter("strength",0.)
    var bare:=await capture("no-particles")
    print("WATER_PARTICLE_DIFFERENCE: ",difference(opening,bare))
    assert(difference(opening,bare)>.0002,"Spray and falling threads must contribute visible pixels")
    # Isolate each effect at its useful viewing distance; no moving flight camera.
    for kind in range(4):
        s.particle_materials[kind].set_shader_parameter("strength",1.)
        var layer:=await capture("layer-%d"%kind)
        print("WATER_LAYER_",kind," difference: ",difference(layer,bare))
        assert(difference(layer,bare)>.000003,"Each of the four particle passes must actually render")
        s.particle_materials[kind].set_shader_parameter("strength",0.)
    for material in s.particle_materials:material.set_shader_parameter("strength",1.)
    for i in range(9):
        for material in s.materials:material.set_shader_parameter("scene_time",11.+i*.25)
        for material in s.particle_materials:material.set_shader_parameter("scene_time",11.+i*.25)
        await capture("sequence-%02d"%i)
    var moved:=await capture("moving")
    assert(difference(opening,moved)>.001,"Water and spray must visibly move while the camera stays fixed")
    s.camera.global_position=Vector3(25,29,-28);s.camera.look_at(Vector3(-3,18,-54))
    var basin_a:=await capture("basin-a")
    for material in s.materials:material.set_shader_parameter("scene_time",16.)
    var basin_b:=await capture("basin-b")
    assert(difference(basin_a,basin_b)>.0005,"Surface ink ripples must travel with the current")
    s.camera.global_position=Vector3(-10,46,-99);s.camera.look_at(Vector3(-47,28,-139))
    await capture("upper-return")
    s.camera.global_position=Vector3(11,-19,53);s.camera.look_at(Vector3(-12,-25,17))
    await capture("spray-close")
    s.camera.global_position=Vector3(19,89,27);s.camera.look_at(Vector3(-4,-28,19))
    await capture("overhead")
    s.review_camera=false;s.following=true;s._reset();s._process(0.)
    await capture("flight")
    root.size=Vector2i(390,844)
    for material in s.particle_materials:material.set_shader_parameter("density",.65)
    for i in range(10):await process_frame
    await capture("portrait")
    print("PASS Azure water: frozen Pause, all four visible particle passes, fixed-camera motion, currents and review views")
    quit(0)
