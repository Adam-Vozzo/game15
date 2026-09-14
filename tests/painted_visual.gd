extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func capture(label: String) -> Image:
    for i in range(5): await process_frame
    await RenderingServer.frame_post_draw
    var img: Image=current_scene.view.get_texture().get_image()
    img.save_png("res://build-logs/painted-"+label+".png")
    return img

func difference(a: Image,b: Image) -> float:
    var total:=0.
    for y in range(0,a.get_height(),3):
        for x in range(0,a.get_width(),3):
            var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
            total+=absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)
    return total/(a.get_width()*a.get_height()/9.)

func run() -> void:
    change_scene_to_file("res://painted.tscn")
    for i in range(8): await process_frame
    var scene: Node=current_scene
    scene.set_process(false);scene.paused=true;scene.time=7.;scene._process(0.)
    var opening:=await capture("opening")
    scene._process(.04)
    var frozen:=await capture("paused")
    assert(difference(opening,frozen)<.00001,"Rendered Pause must freeze the entire watercolour scene")
    scene.time=12.;scene._process(0.)
    var evolved:=await capture("evolved")
    assert(difference(opening,evolved)>.0001,"Water glazes and bubbles must visibly evolve")
    scene.bleed_material.set_shader_parameter("bleed_strength",0.)
    var no_bleed:=await capture("no-bleed")
    scene.bleed_material.set_shader_parameter("bleed_strength",1.)
    assert(difference(evolved,no_bleed)>.0003,"Overflow pigment must visibly extend the painted forms")
    for bird in scene.flamingos:bird.root.hide()
    var no_birds:=await capture("no-flamingos")
    for bird in scene.flamingos:bird.root.show()
    assert(difference(evolved,no_birds)>.0005,"Flamingos must be visible from the opening")
    scene.camera.position=Vector3(-1.25,2.3,-.5);scene.camera.rotation=Vector3(-.16,.95,0)
    var wildlife_a:=await capture("flamingos")
    scene._animate_flamingos(21.)
    var wildlife_b:=await capture("flamingos-moving")
    assert(difference(wildlife_a,wildlife_b)>.0002,"Attached neck animation must visibly change the birds")
    for sample in range(12):
        scene._animate_flamingos(16.+sample)
        await capture("flamingos-sequence-%02d"%sample)
    var white:=0;var coloured:=0;var ink:=0;var total:=0
    for y in range(0,opening.get_height(),4):
        for x in range(0,opening.get_width(),4):
            var c:=opening.get_pixel(x,y);total+=1
            if minf(c.r,minf(c.g,c.b))>.97:white+=1
            if c.b>c.g+.055 or c.r>c.g+.08:coloured+=1
            if c.r<.5 and c.g<.5 and c.b<.6:ink+=1
    assert(white>total*.18 and coloured>total*.18 and ink>30,"Preserve white paper, coloured washes and legible fine ink")
    var shots := {
        "lotus":[Vector3(-1.1,2.3,7.8),Vector3(-.28,.93,0)],
        "landing":[Vector3(0,2.3,-18),Vector3(.20,0,0)],
        "reverse":[Vector3(0,2.3,-23),Vector3(-.08,PI,0)],
        "flamingos-reverse":[Vector3(-1.25,2.3,-10),Vector3(-.13,2.35,0)],
        "bridge":[Vector3(.2,2.3,8),Vector3(-.62,.20,0)],
        "inside":[Vector3(0,2.31,-32),Vector3(.42,2.9,0)],
        "under":[Vector3(-3,.02,7),Vector3(.20,-.95,0)],
        "canopy":[Vector3(0,2.3,0),Vector3(.7,-1.30,0)]}
    for label in shots:
        scene.camera.position=shots[label][0];scene.camera.rotation=shots[label][1]
        await capture(label)
    scene._reset();scene.paused=true;scene._process(0.)
    root.size=Vector2i(390,844)
    for i in range(12):await process_frame
    await capture("portrait")
    print("PASS Painted Mere GPU: frozen Pause, evolving wash/bubbles, palette and all review captures")
    quit(0)
