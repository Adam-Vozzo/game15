extends SceneTree
func _initialize() -> void:call_deferred("run")
func settle() -> void:
    for i in range(6):await process_frame
func run() -> void:
    var session:Node=root.get_node("Session")
    session.sound_enabled=false
    session.render_scale=.5
    var rendered:=DisplayServer.get_name()!="headless"
    for id in session.SCENES:
        change_scene_to_file(session.SCENES[id].path)
        await settle()
        var s:Node=current_scene
        assert(s.resolution_slider.value==50,"Resolution must persist between all scenes")
        s.paused=true
        var time:float=s.time
        var ui_size:Vector2=root.get_visible_rect().size
        s.resolution_slider.value=100
        await settle()
        var original:Vector2i=s.view.size
        s.resolution_slider.value=50
        await settle()
        assert((Vector2(s.view.size)-Vector2(original)*.5).length()<2,"Slider must change actual render dimensions")
        assert(root.get_visible_rect().size==ui_size,"Resolution must not resize the interface")
        assert(s.time==time,"Changing resolution during Pause must not advance the scene")
        if id in ["lowwater","laundry","reservoir"]:
            assert(s.reflection_view.size.x<s.view.size.x,"Reflection target must follow render size")
        s.resolution_slider.value=200
        await settle()
        assert(s.view.size.x>=original.x and s.view.size.y>=original.y,"Higher resolution must increase detail")
        assert(s.view.size.x<=ui_size.x and s.view.size.y<=ui_size.y,"Resolution must be capped at the display size")
        s.settings_button.pressed.emit()
        await create_timer(.3).timeout
        var finger:=InputEventScreenTouch.new()
        finger.index=7;finger.pressed=true
        finger.position=s.resolution_slider.get_global_rect().get_center()
        s.touch._input(finger)
        assert(s.touch.look_finger==-1 and s.touch.move_finger==-1,"Slider touches cannot rotate or move the scene")
        s.touch.reset_input()
        s.resolution_slider.value=50
        if rendered:
            for shape in [Vector2i(390,844),Vector2i(640,360),Vector2i(320,240)]:
                root.size=shape
                await create_timer(.3).timeout
                assert(Rect2(Vector2.ZERO,Vector2(shape)).encloses(s.controls.get_global_rect()),"All options must fit portrait and short landscape")
                assert(not s.controls.get_global_rect().intersects(s.settings_button.get_global_rect()),"Options must not cover the close control")
            root.size=Vector2i(960,640)
            await create_timer(.3).timeout
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("res://build-logs/resolution-"+str(id)+".png")
        print("PASS resolution: ",id," actual pixels, bounds, Pause, touch exclusion and shared preference")
    session.render_scale=1.
    quit(0)
