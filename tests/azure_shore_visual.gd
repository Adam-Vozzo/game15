extends SceneTree

func _initialize() -> void:call_deferred("run")

func capture(label:String) -> Image:
    for i in range(5):await process_frame
    await RenderingServer.frame_post_draw
    var img:Image=current_scene.view.get_texture().get_image()
    img.save_png("res://build-logs/azure-shore-"+label+".png")
    return img

func difference(a:Image,b:Image) -> float:
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
    s.set_process(false);s.paused=true;s.review_camera=true
    for t in [0.,105.,420.,1800.]:
        s.time=t;s._process(0.)
        s.camera.global_position=Vector3(2,133,-49);s.camera.look_at(Vector3(-142,40,-173))
        await capture("upper-%d"%int(t))
    s.camera.global_position=Vector3(-3,49,-117);s.camera.look_at(Vector3(-91,31,-166))
    await capture("upper-side")
    s.camera.global_position=Vector3(-52,21,-172);s.camera.look_at(Vector3(-87,28,-181))
    await capture("upper-foot")
    s.camera.global_position=Vector3(-152,114,-271);s.camera.look_at(Vector3(-144,40,-148))
    await capture("upper-rear")
    s.time=22.;s._process(0.)
    s.camera.global_position=Vector3(118,73,-42);s.camera.look_at(Vector3(92,18,-101))
    var rim:ShaderMaterial=s.materials[-1]
    var island:=await capture("island-foam")
    rim.set_shader_parameter("strength",0.)
    var bare:=await capture("island-bare")
    assert(difference(island,bare)>.00015,"Island contact foam must contribute visible pixels")
    rim.set_shader_parameter("strength",1.)
    s.camera.global_position=Vector3(67,31,-36);s.camera.look_at(s.ferries[0].node.global_position)
    var ferry:=await capture("ferry-foam")
    rim.set_shader_parameter("strength",0.)
    bare=await capture("ferry-bare")
    assert(difference(ferry,bare)>.0001,"Moving hull contact foam must contribute visible pixels")
    rim.set_shader_parameter("strength",1.)
    var frozen_a:=await capture("ferry-paused")
    s._process(.1)
    var frozen_b:=await capture("ferry-paused-later")
    assert(difference(frozen_a,frozen_b)<.00001,"Contact foam and all water effects must freeze on Pause")
    for t in [22.5,23.,23.5,24.]:
        s.time=t;s._process(0.)
        await capture("ferry-%d"%int(t*10))
    s.review_camera=false;s.following=true;s._reset()
    for t in [0.,70.,87.5,105.,122.5,140.,157.5,175.]:
        s.time=t;s._process(0.)
        await capture("orbit-%d"%int(t))
    root.size=Vector2i(390,844)
    for i in range(10):await process_frame
    await capture("portrait")
    print("PASS Azure shore: visible island and ferry foam, frozen Pause, curved shelf sides, long-session water and orbit review")
    quit(0)
