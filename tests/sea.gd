extends SceneTree

func check(ok: bool,message: String) -> void:
    if not ok:
        push_error(message)
        quit(1)
        assert(ok,message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    change_scene_to_file("res://sea.tscn")
    await process_frame
    await process_frame
    var sea: Node = current_scene
    check(sea.camera.get_parent()==sea.boat_rig,"Camera must move inside the same rig as the cabin")
    var lo := 99.0
    var hi := -99.0
    var max_roll := 0.0
    sea.paused = true
    for i in range(120):
        sea.time = i*.2
        sea._process(.02)
        var h: float = sea.wave_height(Vector2.ZERO,sea.time)
        lo = minf(lo,h)
        hi = maxf(hi,h)
        max_roll = maxf(max_roll,absf(sea.boat_rig.rotation.z))
        check(is_equal_approx(sea.water_material.get_shader_parameter("sea_time"),sea.time),"Ocean must share the boat's animation clock")
        check(is_equal_approx(sea.glass_material.get_shader_parameter("sea_time"),sea.time),"Window rain must pause with the waves")
        check(is_equal_approx(sea.spray_material.get_shader_parameter("sea_time"),sea.time),"Crest spray must share the pause clock")
        for z in [-4.8,-3.2,-1.8,-.2,1.6]:
            for x in [-.45,0.,.45]:
                var deck: Vector3 = sea.boat_rig.global_transform*Vector3(x,.88,z)
                check(sea.wave_height(Vector2(deck.x,deck.z),sea.time)<deck.y+.04,"Adjacent wave crests must stay below the deck, including between buoyancy samples")
    check(hi-lo>2.5,"Sea needs substantial physical wave displacement")
    check(max_roll>.12 and max_roll<.65,"Full motion must roll visibly without overturning the cabin")
    var frozen: Transform3D = sea.boat_rig.transform
    var whale_frozen: Transform3D = sea.whale.transform
    sea._process(.03)
    check(sea.boat_rig.transform.is_equal_approx(frozen),"Pause must freeze hull motion")
    check(sea.whale.transform.is_equal_approx(whale_frozen),"Pause must freeze the whale")
    sea.time=13.
    sea._process(0.)
    var surfaced: float=sea.whale.position.y
    sea.time=32.
    sea._process(0.)
    check(surfaced-sea.whale.position.y>3.,"Whale must dive between brief surface passes")
    check(Vector2(sea.whale.position.x,sea.whale.position.z).length()>15.,"Whale must remain clear of the hull")
    sea.time = 2.4
    sea.gentle_motion = false
    sea._process(.02)
    var full: float = sea.boat_rig.rotation.length()
    sea.gentle_motion = true
    sea._process(.02)
    check(sea.boat_rig.rotation.length()<full*.5,"Gentle motion must substantially reduce pitch and roll")
    sea.walking = Vector2(1,-1)
    for i in range(200): sea._process(.04)
    check(sea.camera.position.x<=1.121 and sea.camera.position.z>=-.051,"Walking must stay inside the wheelhouse")
    sea._reset()
    check(sea.camera.position.is_equal_approx(sea.start),"Reset must return to the helm")
    print("PASS: wave amplitude, shared clocks, hull attachment, pause, gentle motion, cabin bounds and reset")
    quit(0)
