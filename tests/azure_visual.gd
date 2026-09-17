extends SceneTree

func _initialize() -> void:call_deferred("run")

func capture(label: String) -> Image:
    for i in range(5):await process_frame
    await RenderingServer.frame_post_draw
    var img:Image=current_scene.view.get_texture().get_image()
    img.save_png("res://build-logs/azure-"+label+".png")
    return img

func difference(a: Image,b: Image) -> float:
    var total:=0.
    for y in range(0,a.get_height(),4):
        for x in range(0,a.get_width(),4):
            var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
            total+=absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)
    return total/(a.get_width()*a.get_height()/16.)

func run() -> void:
    change_scene_to_file("res://azure.tscn")
    for i in range(10):await process_frame
    var s:Node=current_scene
    s.set_process(false);s.paused=true;s.controls.get_child(1).text="Resume"
    s.time=0;s.following=false;s._reset();s._process(0.)
    var opening:=await capture("aboard")
    s._process(.04)
    var frozen:=await capture("paused")
    assert(difference(opening,frozen)<.00001,"Rendered Pause must be completely frozen")
    s.following=true;s._reset();s._process(0.)
    await capture("follow")
    for i in range(8):
        s.time=float(i)*1.6;s._process(0.)
        await capture("glide-%02d"%i)
    # Review a full orbit, including all reverse faces, at twelve positions.
    for i in range(12):
        s.time=float(i)*float(s.layout.orbit.period)/12.;s._process(0.)
        await capture("orbit-%02d"%i)
    s.review_camera=true;s.traveller.show()
    s.time=0;s._animate_world()
    s.camera.position=Vector3(20,9,16);s.camera.look_at(s.bird.to_global(Vector3(0,0,-2)))
    await capture("bird-side")
    s.camera.position=Vector3(-12,-5,9);s.camera.look_at(s.bird.to_global(Vector3(0,0,-2)))
    await capture("bird-under")
    s.camera.position=Vector3(0,22,8);s.camera.look_at(s.bird.to_global(Vector3(0,0,-2)))
    await capture("bird-above")
    s.camera.global_position=Vector3(5,63,63);s.camera.look_at(Vector3(-30,40,-48))
    await capture("citadel-falls")
    s.camera.global_position=Vector3(102,35,-5);s.camera.look_at(Vector3(54,19,-57))
    await capture("ferry")
    s.camera.global_position=Vector3(146,-33,142);s.camera.look_at(Vector3(137,-28,130))
    await capture("dock-under")
    s.camera.global_position=Vector3(7,19,-54);s.camera.look_at(Vector3(8,29,-67))
    await capture("bridge-under")
    # Isolate water motion from flight to prove the falls actually animate.
    s.camera.global_position=Vector3(42,16,68);s.camera.look_at(Vector3(-12,-7,8))
    var water_a:=await capture("falls-a")
    for m in s.materials:m.set_shader_parameter("scene_time",3.)
    var water_b:=await capture("falls-b")
    assert(difference(water_a,water_b)>.0005,"Waterfall flow must visibly evolve with a fixed camera")
    s.review_camera=false;s.following=false;s._reset();s._process(0.)
    for shape in [Vector2i(390,844),Vector2i(640,360)]:
        root.size=shape;s.mobile=true;s.touch.touch_visible=true
        for i in range(15):await process_frame
        s._resize()
        await capture("layout-%d"%shape.x)
        s.settings_button.pressed.emit()
        await create_timer(.3).timeout
        assert(Rect2(Vector2.ZERO,Vector2(shape)).encloses(s.controls.get_global_rect()),"Flight controls must fit both mobile layouts")
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://build-logs/azure-ui-%d.png"%shape.x)
        s.settings_button.pressed.emit();await create_timer(.3).timeout
    print("PASS Azure native: frozen Pause, waterfall motion, twelve flight positions, bird sides and mobile controls")
    print("AZURE_RENDER: ",s.view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)," draws, ",s.view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)," primitives")
    quit(0)
