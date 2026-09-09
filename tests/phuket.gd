extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    change_scene_to_file("res://coast.tscn")
    await process_frame
    await process_frame
    var coast := current_scene
    assert(coast.birds.size()==10 and coast.fish.size()==48 and is_instance_valid(coast.turtle),"Coastal wildlife must load")
    assert(coast.can_walk(Vector3(10,0,-30)),"Pier must be walkable")
    assert(not coast.can_walk(Vector3(1,0,-10)),"Walking must not run out into the sea")
    assert(not coast.can_walk(Vector3(-16,0,17)),"Shore building walls must block walking")
    assert(abs(coast.surface_height(10,-20)-1.08)<.001,"Dock eye height must match the modeled deck")
    var y: float = coast.surface_height(10,7.)
    assert(abs(coast.surface_height(10,7.001)-y)<.002,"Dock ramp must join continuously")
    for step in range(54):
        var x := 10.+step*.25
        assert(coast.can_walk(Vector3(x,0,-35)),"Connecting pier must lead through the hut doorway")
        assert(abs(coast.surface_height(x,-35)-1.08)<.001,"Connecting pier must maintain deck height")
    assert(not coast.can_walk(Vector3(17.5,0,-33.5)),"Hut wall beside the doorway must block walking")
    for sample in [0.,2.,6.,11.,18.]:
        coast.time=sample
        coast._process(0.)
        var inverse: Transform3D = coast.ocean_material.get_shader_parameter("boat_inverse")
        assert((inverse*coast.boat.global_transform).is_equal_approx(Transform3D.IDENTITY),"Water exclusion must follow the rocking hull")
    coast.paused = true
    coast._process(.02)
    var bird: Transform3D = coast.birds[0].transform
    var turtle: Transform3D = coast.turtle.transform
    coast._process(.04)
    assert(coast.birds[0].transform.is_equal_approx(bird) and coast.turtle.transform.is_equal_approx(turtle),"Pause must freeze wildlife")
    var fish_before: Vector3=coast.fish[0].position
    coast._process(.1)
    assert(coast.fish[0].position.is_equal_approx(fish_before),"Pause must freeze schooling simulation")
    coast.paused=false
    for step in range(600): coast._process(1./60.)
    assert(coast.fish[0].position.distance_to(fish_before)>.2,"Schools must swim")
    assert(coast.fish[0].position.distance_to(coast.fish[24].position)>10.,"Schools must occupy separate water areas")
    for swimmer in coast.fish:
        var p: Vector3 = swimmer.position
        var bottom: float = .12+.052*p.z
        assert(p.y>bottom and p.y<0.,"Fish must be below water and above the seabed")
    coast._look(Vector2(0,-500))
    assert(coast.target_pitch>.9,"Looking up must reach the midday sun and flare")
    print("PASS: Phuket wildlife, pier access, shore collisions, ramp continuity, underwater depth, pause and sun view")
    quit(0)

