extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func settle() -> void:
    for i in range(35): await process_frame

func run() -> void:
    for id in ["menu","coast","town","sea","lowwater","laundry","reservoir","main"]:
        change_scene_to_file("res://"+id+".tscn")
        await settle()
        for shape in [Vector2i(390,844),Vector2i(640,360),Vector2i(844,390),Vector2i(1280,800)]:
            root.size = shape
            await settle()
            assert(root.content_scale_size == shape,"Logical size must follow native window changes")
            assert(root.get_visible_rect().size.is_equal_approx(Vector2(shape)),"Viewport must keep the current aspect")
            if id=="menu":
                for i in range(root.get_node("Session").SCENES.size()): assert(current_scene.cards[i].visible,"Every experience must remain visible")
                for card in current_scene.cards:
                    if card.visible:
                        assert(Rect2(Vector2.ZERO,Vector2(shape)).encloses(card.get_global_rect()),"Visible channel cards must fit the window")
            else:
                assert(current_scene.menu_button.get_global_rect().end.x <= shape.x,"Channels control must stay on screen")
                if shape.x==390:
                    var joystick := Rect2(current_scene.touch.joystick_center-Vector2.ONE*52,Vector2.ONE*104)
                    assert(not joystick.intersects(current_scene.controls.get_global_rect()),"Scene buttons must not overlap the touch joystick")
            print("PASS resize: ",id," ",shape)
    print("PASS: live portrait, landscape and desktop resizing across the menu and all seven scenes")
    quit(0)
