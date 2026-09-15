extends SceneTree
func _initialize() -> void:call_deferred("run")
func shot(label:String) -> Image:
    current_scene._update_reflection()
    for i in range(6):await process_frame
    await RenderingServer.frame_post_draw
    var image:Image=current_scene.view.get_texture().get_image()
    image.save_png("res://build-logs/station-"+label+".png")
    return image
func difference(a:Image,b:Image) -> float:
    var total:=0.
    for y in range(0,a.get_height(),3):
        for x in range(0,a.get_width(),3):
            var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
            total+=absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)
    return total/(a.get_width()*a.get_height()/9.)
func run() -> void:
    change_scene_to_file("res://station.tscn")
    for i in range(10):await process_frame
    var s:Node=current_scene
    s.set_process(false);s.paused=true;s.time=4.;s._process(0.)
    var first:=await shot("opening")
    s._process(.04)
    var frozen:=await shot("paused")
    assert(difference(first,frozen)<.00001,"Rendered Pause must freeze all atmospheric motion")
    for t in [5.,7.,11.,19.,31.]:
        s.time=t;s._process(0.)
        var evolved:=await shot("time-"+str(int(t)))
        assert(difference(first,evolved)>.0001,"Garden and water must visibly evolve")
    s.time=4.;s._process(0.)
    var views:={
        "clock-front":[Vector3(.4,2.9,4.4),Vector3(.06,-.49,0)],
        "clock-back":[Vector3(1.1,2.7,-1.6),Vector3(.06,-2.8,0)],
        "clock-detail-left":[Vector3(.35,3.25,2.8),Vector3(.17,-.82,0)],
        "clock-detail-right":[Vector3(3.5,3.25,2.8),Vector3(.17,.82,0)],
        "clock-root-detail":[Vector3(.5,1.75,2.5),Vector3(-.09,-.82,0)],
        "train-front":[Vector3(2.7,2.85,-5),Vector3(-.07,-.9,0)],
        "train-side":[Vector3(12.1,2.85,-15),Vector3(-.06,1.5,0)],
        "train-roof-detail":[Vector3(10.4,3.4,-14),Vector3(.04,1.3,0)],
        "train-roof-above":[Vector3(10.4,5.5,-14),Vector3(-.65,1.3,0)],
        "train-back":[Vector3(12.2,2.85,-27),Vector3(.03,2.45,0)],
        "water":[Vector3(2.9,2.85,10),Vector3(-.57,-.75,0)],
        "reverse":[Vector3(0,2.85,-18),Vector3(.05,PI,0)],
        "roof":[Vector3(0,2.85,-5),Vector3(1.13,0,0)],
        "truss-underside":[Vector3(12,2.85,-5),Vector3(.8,1.25,0)],
        "outer-platform":[Vector3(-12.7,2.85,-20),Vector3(.1,-.75,0)],
        "concourse":[Vector3(14,2.85,26),Vector3(.09,.48,0)],
        "roots":[Vector3(0,2.85,-21),Vector3(-.27,.48,0)]}
    for label in views:
        s.camera.position=views[label][0];s.camera.rotation=views[label][1]
        await shot(label)
    for t in [0.,1.,2.52,11.5,14.5,24.,25.,26.,26.5,27.,28.,29.,38.,40.,42.]:
        s.time=t;s._process(0.)
        s.camera.position=Vector3(-.7,1.83,14.0);s.camera.rotation=Vector3(-.12,.20,0)
        await shot("spirit-"+str(t))
    s.time=26.5;s._process(0.)
    s.camera.position=Vector3(.5,1.78,12.3);s.camera.rotation=Vector3(-.12,1.4,0)
    await shot("spirit-wave-side")
    s.camera.position=Vector3(-1.1,1.8,10.2);s.camera.rotation=Vector3(-.13,PI,0)
    await shot("spirit-wave-back")
    s.time=4.;s._process(0.)
    s.camera.position=views.water[0];s.camera.rotation=views.water[1]
    var wet:=await shot("water-still")
    s.water_material.set_shader_parameter("scene_time",5.)
    var ripples:=await shot("water-evolved")
    assert(difference(wet,ripples)>.0001,"Water alone must visibly animate")
    s._reset();s._process(0.)
    for shape in [Vector2i(390,844),Vector2i(640,360)]:
        root.size=shape
        for i in range(20):await process_frame
        await shot(str(shape.x)+"x"+str(shape.y))
        s._toggle_settings()
        await create_timer(.35).timeout
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://build-logs/station-settings-"+str(shape.x)+".png")
        assert(Rect2(Vector2.ZERO,Vector2(shape)).encloses(s.controls.get_global_rect()),"Touch settings must remain within viewport")
        s._toggle_settings()
        await create_timer(.3).timeout
    print("PASS station visual: rendered Pause, evolving water, five time samples, all model sides, roof underside, portrait and landscape")
    quit(0)
