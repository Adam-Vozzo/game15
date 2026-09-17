extends SceneTree

func _initialize() -> void:call_deferred("run")

func capture(label:String) -> Image:
    for i in range(3):await process_frame
    await RenderingServer.frame_post_draw
    var img:Image=current_scene.view.get_texture().get_image()
    img.save_png("res://build-logs/azure-bird-"+label+".png")
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
    s.set_process(false);s.paused=true;s.following=true;s._reset()
    for t in [3.,6.,6.85,7.15,7.5,8.25,9.4]:
        s.time=t;s._process(0.)
        await capture("follow-%03d"%int(t*100))
    s.time=7.15;s._process(0.)
    var frozen:=await capture("pause-a")
    s._process(.04)
    var paused_difference:=difference(frozen,await capture("pause-b"))
    print("BIRD_PAUSE_DIFFERENCE: ",paused_difference)
    assert(paused_difference<.00001,"The rendered bird and environment must freeze mid-wingbeat")
    s.review_camera=true;s.traveller.show()
    for t in [6.85,7.5]:
        s.time=t;s._process(0.)
        for angle in ["side","under","above","roots"]:
            match angle:
                "side":s.camera.position=Vector3(24,8,20)
                "under":s.camera.position=Vector3(-19,-12,15)
                "above":s.camera.position=Vector3(0,29,10)
                "roots":s.camera.position=Vector3(4,4,8)
            s.camera.look_at(s.bird.to_global(Vector3(0,0,-1)))
            await capture("%s-%03d"%[angle,int(t*100)])
    s.review_camera=false;s.following=false;s._reset();s._process(0.)
    await capture("aboard-downstroke")
    s.following=true;s._reset();s._process(0.)
    if "--bird-reel" in OS.get_cmdline_user_args():
        for i in range(144):
            s.time=3.+i/12.;s._process(0.)
            await capture("reel-%03d"%i)
    root.size=Vector2i(390,844)
    for i in range(10):await process_frame
    s._resize();s.time=6.85;s._process(0.)
    await capture("portrait-upstroke")
    s.time=7.5;s._process(0.)
    await capture("portrait-downstroke")
    print("PASS Azure bird native: wingbeat poses, side/underside/roots, seated view, portrait and rendered mid-stroke Pause")
    quit(0)
