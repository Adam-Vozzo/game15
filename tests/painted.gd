extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    change_scene_to_file("res://painted.tscn")
    for i in range(6): await process_frame
    var scene: Node=current_scene
    scene.set_process(false)
    for z in range(-36,14):
        assert(scene.can_walk(Vector3(0,0,z)),"Opening walkway must connect through the door to the conservatory")
    for x in [-1.25,0,1.25]:
        for z in range(-25,14):
            assert(scene.can_walk(Vector3(x,0,z)),"Walkable width must match the supported deck")
    assert(not scene.can_walk(Vector3(2.1,0,5)),"Walkers must not step into the mere")
    assert(not scene.can_walk(Vector3(3.5,0,-23.3)),"Bench must block walking")
    assert(not scene.can_walk(Vector3(2,0,-26.8)),"Glasshouse wall must block walking outside its doorway")
    assert(scene.can_walk(Vector3(3,0,-31)),"Conservatory interior must be accessible")
    assert(scene.bubbles.size()==35,"Authored bubble anchors must load")
    assert(scene.flamingos.size()==9,"Nine articulated flamingos must load")
    for bird in scene.flamingos:
        assert(is_instance_valid(bird.neck),"Neck and face must share an attached articulation")
        assert(bird.shapes.size()==2,"Authored feeding neck and face morphs must import together")
        assert(absf(bird.root.position.x)>5. and bird.root.position.z<0.,"Wildlife must remain deeper in the wetland, clear of the foreground")
    assert(scene.dragonflies.size()==2,"Two articulated dragonflies must load")
    scene._animate_flamingos(0.)
    assert(scene.flamingos[0].neck.rotation==Vector3.ZERO,"Birds need still intervals between gestures")
    scene._animate_flamingos(21.)
    for shape in scene.flamingos[0].shapes:
        assert(shape.mesh.get_blend_shape_value(shape.index)>.99,"Rare feeding must reach its authored water-level pose")
    assert(scene.flamingos[1].shapes[0].mesh.get_blend_shape_value(0)==0.,"The flock must not feed in unison")
    scene.audio.play()
    await process_frame
    scene.paused=true;scene.time=7.;scene._process(0.)
    var frozen: Transform3D=scene.bubbles[3].mesh.transform
    var frozen_neck: Transform3D=scene.flamingos[0].neck.transform
    var frozen_fly: Transform3D=scene.dragonflies[0].root.transform
    var frozen_wing: Transform3D=scene.dragonflies[0].wings[0].transform
    scene._process(.04)
    assert(scene.time==7. and scene.bubbles[3].mesh.transform==frozen,"Pause must freeze water, bubbles and audio")
    assert(scene.audio.stream_paused,"Pause must pause the sound")
    assert(scene.flamingos[0].neck.transform==frozen_neck,"Pause must freeze wildlife")
    assert(scene.dragonflies[0].root.transform==frozen_fly and scene.dragonflies[0].wings[0].transform==frozen_wing,"Pause must freeze dragonflies and wings")
    scene.paused=false;scene._process(.04)
    assert(scene.bubbles[3].mesh.transform!=frozen,"Bubble motion must resume")
    assert(scene.flamingos[0].neck.transform!=frozen_neck,"Flamingos must resume movement")
    assert(scene.dragonflies[0].root.transform!=frozen_fly,"Dragonflies must resume flight")
    for bird in scene.flamingos:
        assert(bird.root.transform==bird.origin,"The planted legs must not slide during neck animation")
    var saved_time: float=scene.time
    scene.camera.position=Vector3(0,2.3,-30);scene._reset()
    assert(scene.camera.position==scene.start and scene.time==saved_time,"Reset restores framing while retaining time")
    scene.paused=true;scene.time=20.;scene._process(0.)
    var feeding_shape: Dictionary=scene.flamingos[0].shapes[0]
    var frozen_feed: float=feeding_shape.mesh.get_blend_shape_value(feeding_shape.index)
    scene._process(1.)
    assert(feeding_shape.mesh.get_blend_shape_value(feeding_shape.index)==frozen_feed,"Pause must freeze feeding morphs")
    print("PASS Painted Mere: connected deck, imported feeding poses, independent wildlife, pausable animation/audio and Reset")
    scene.audio.stop()
    await create_timer(.15).timeout
    quit(0)
