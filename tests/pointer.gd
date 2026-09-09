extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    change_scene_to_file("res://sea.tscn")
    await process_frame
    await process_frame
    var session := root.get_node("Session")
    session.capture_pointer()
    assert(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Desktop pointer must capture")
    var scene := current_scene
    var motion := InputEventMouseMotion.new()
    motion.relative = Vector2(24,9)
    var old_heading: float = scene.target_heading
    scene._unhandled_input(motion)
    assert(scene.target_heading!=old_heading,"Captured motion must look without holding a button")
    var escape := InputEventKey.new()
    escape.physical_keycode = KEY_ESCAPE
    escape.pressed = true
    scene._input(escape)
    assert(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Escape must release capture")
    assert(current_scene==scene,"Escape must remain inside the experience")
    print("PASS: native desktop capture, free mouse-look, Escape releases without leaving")
    quit(0)
