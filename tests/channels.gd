extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func check(condition: bool, message: String) -> void:
    if not condition:
        push_error(message)
        quit(1)
        assert(condition,message)

func run() -> void:
    # Exercise actual scene lifetimes and button signals, including animated transitions.
    change_scene_to_file("res://menu.tscn")
    await process_frame
    await process_frame
    var session: Node = root.get_node("Session")
    current_scene._toggle_sound()
    check(session.sound_enabled,"Menu audio preference must persist into an experience")
    for id in ["coast","town","moor"]:
        var menu: Control = current_scene
        check(menu.cards.size() == 12,"All channel slots must be built")
        var card: Button = menu.grid.get_node(id.capitalize()+"Channel")
        check(not card.disabled,"Experience must be available")
        card.pressed.emit()
        await create_timer(.45).timeout
        await process_frame
        var experience: Node = current_scene
        check(experience.experience_id==id,"Channel must load its matching 3D experience")
        check(experience.sound_on and experience.audio.playing,"Sound setting must follow scene transitions")
        check(experience.view.own_world_3d,"Each experience needs its own 3D world")
        check(experience.touch.blocked_rects.has(experience.menu_button.get_global_rect()),"Channels button must exclude look gestures")
        var event := InputEventMouseMotion.new()
        event.device = -1
        event.relative = Vector2(80,40)
        experience.dragging = true
        var old_heading: float = experience.target_heading
        experience._unhandled_input(event)
        check(experience.target_heading==old_heading,"Emulated mouse input must not double touch rotation")
        experience.paused = true
        var frozen_time: float = experience.time
        await process_frame
        check(experience.time==frozen_time,"Pause must freeze environmental animation")
        if id=="town":
            check(not experience.can_walk(Vector3(-8,0,5)),"Town houses must block walking")
            check(experience.can_walk(Vector3(0,0,-10)),"The main lane must remain walkable")
        if id=="coast":
            check(is_instance_valid(experience.boat),"The long-tail boat must animate as a separate mesh")
            check(experience.moving_materials.size()>6,"Palms and landscape materials must be loaded")
        experience.menu_button.pressed.emit()
        await process_frame
        await process_frame
        check(current_scene is Control,"Channels must return to the shared menu")
        check(root.get_child_count()==2,"Scene transitions must release the previous scene and its audio")
        print("PASS channel round trip: ",id)
    current_scene._toggle_sound()
    check(not session.sound_enabled,"Sound can be disabled after returning")
    print("PASS: three menu round trips, audio persistence, touch exclusion, pause, collision, scene cleanup")
    # Let the audio server release its last playback after stopping the loop.
    await create_timer(.15).timeout
    quit(0)
