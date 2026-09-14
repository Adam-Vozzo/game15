extends SceneTree
func _initialize() -> void:call_deferred("run")
func capture(label: String) -> Image:
    for i in range(5):await process_frame
    await RenderingServer.frame_post_draw
    var img:Image=current_scene.view.get_texture().get_image()
    img.save_png("res://build-logs/roccella-"+label+".png")
    return img
func difference(a:Image,b:Image) -> float:
    var total:=0.
    for y in range(0,a.get_height(),3):
        for x in range(0,a.get_width(),3):
            var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
            total+=absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)
    return total/(a.get_width()*a.get_height()/9.)
func brightness(a:Image) -> float:
    var total:=0.
    for y in range(0,a.get_height(),3):
        for x in range(0,a.get_width(),3):
            var p:=a.get_pixel(x,y);total+=(p.r+p.g+p.b)/3.
    return total/(a.get_width()*a.get_height()/9.)
func run() -> void:
    change_scene_to_file("res://roccella.tscn")
    for i in range(8):await process_frame
    var s:Node=current_scene
    s.set_process(false);s.paused=true;s.time=5.;s._process(0.)
    var dark:=await capture("dark")
    s._process(.04)
    var frozen:=await capture("paused")
    assert(difference(dark,frozen)<.00001,"Pause must freeze actual rendered rain, fog and water")
    s.time=7.08;s._process(0.)
    var flash:=await capture("lightning")
    assert(brightness(flash)>brightness(dark)*1.35,"Lightning must visibly reveal architecture")
    s.time=6.;s._process(0.)
    var rain:=await capture("rain-evolved")
    assert(difference(dark,rain)>.001,"Rain and fog must visibly move between strikes")
    var shots:={
        "piazza":[Vector3(6,23.87,6),Vector3(-.18,.72,0)],
        "piazza-reverse":[Vector3(-5,19.91,-13),Vector3(.15,PI,0)],
        "church-foundation":[Vector3(-18,22,-45),Vector3(.25,2.4,0)],
        "rose-door":[Vector3(-9,21.89,-2),Vector3(.1,1.68,0)],
        "sky-bolt":[Vector3(27,37.85,17.8),Vector3(.78,.38,0)],
        "landing-edge":[Vector3(8,17.93,-23),Vector3(-.6,-1.8,0)],
        "stairs":[Vector3(0,s.surface_height(0,-9)+1.85,-9),Vector3(-.22,0,0)],
        "reverse":[Vector3(0,s.surface_height(0,-24)+1.85,-24),Vector3(.35,PI,0)],
        "church":[Vector3(-3.5,25.85,14),Vector3(.22,.75,0)],
        "balcony-under":[Vector3(-7,21,4),Vector3(.65,0,0)],
        "lookout-side":[Vector3(36,27,28),Vector3(.40,.86,0)],
        "coast":[Vector3(0,s.surface_height(0,-45)+1.85,-45),Vector3(-.05,-.1,0)]}
    s.time=7.08;s._process(0.)
    for label in shots:
        s.camera.position=shots[label][0];s.camera.rotation=shots[label][1]
        await capture(label)
    s._reset();s._process(0.)
    for moment in [6.9,7.08,7.3,7.8,9.0,18.48,28.57,34.08,50.08]:
        s.time=moment;s._process(0.)
        await capture("sequence-"+str(moment).replace(".","-"))
    s.time=7.08;s._process(0.)
    root.size=Vector2i(390,844)
    for i in range(15):await process_frame
    await capture("portrait")
    print("PASS La Burrasca GPU: frozen Pause, lightning reveal, evolving storm, sides, underside and portrait captures")
    quit(0)
