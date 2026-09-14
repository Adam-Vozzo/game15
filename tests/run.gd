extends SceneTree
const Controls = preload("res://scripts/touch_controls.gd")
var touch: Control
var movement := [Vector2.ZERO]
var looking := [Vector2.ZERO]

func press(index: int, point: Vector2, down: bool = true, canceled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = point
    event.pressed = down
    event.canceled = canceled
    touch._input(event)

func drag(index: int, point: Vector2, relative: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index = index
    event.position = point
    event.relative = relative
    touch._input(event)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    touch = Controls.new()
    root.add_child(touch)
    touch.size = Vector2(540,900)
    touch._resize()
    touch.movement_changed.connect(func(value: Vector2): movement[0] = value)
    touch.look_changed.connect(func(value: Vector2): looking[0] = value)
    var center: Vector2 = touch.joystick_center
    press(7, center)
    press(8, Vector2(350,300))
    drag(7,center+Vector2(0,-42),Vector2(0,-42))
    drag(8,Vector2(375,290),Vector2(25,-10))
    assert(movement[0].is_equal_approx(Vector2(0,-1)),"Walking finger must move forward")
    assert(looking[0] == Vector2(25,-10),"Second finger must look while walking")
    press(9,Vector2(400,250))
    drag(9,Vector2(450,250),Vector2(50,0))
    assert(touch.look_finger == 8,"Third touch must not steal look gesture")
    assert(looking[0] == Vector2(25,-10),"Unowned finger must not change view")
    press(8,Vector2(375,290),false)
    assert(touch.move_finger == 7 and movement[0].y == -1,"Releasing look must preserve walking")
    press(7,center,false,true)
    assert(movement[0] == Vector2.ZERO and touch.move_finger == -1,"Canceled walking must stop immediately")
    press(2,center+Vector2(30,0))
    touch._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    assert(movement[0] == Vector2.ZERO and touch.move_finger == -1,"Backgrounding must release all input")
    touch.blocked_rects = [Rect2(300,750,220,70)]
    press(3,Vector2(350,780))
    assert(touch.look_finger == -1,"UI button touches must not rotate the camera")
    assert(Controls.movement_vector(Vector2(2,2)) == Vector2.ZERO,"Dead zone must stop resting thumbs")
    assert(is_equal_approx(Controls.movement_vector(Vector2(100,-100)).length(),1.0),"Diagonal speed must be capped")
    assert(Controls.movement_vector(Vector2(0,-21)).length() < 1.0,"Joystick must support partial speed")
    touch.reset_input()
    var scene = load("res://scripts/main.gd").new()
    scene.touch=touch
    touch.look_changed.connect(scene._look)
    press(0,center)
    press(1,Vector2(350,300))
    # Reproduce a backend delta measured from the movement finger, and ordinary
    # device-ID compatibility mouse events arriving alongside real touch drags.
    for i in range(20):
        drag(0,center+Vector2(0,-42),Vector2(0,-42))
        drag(1,Vector2(352+i*2,299-i),Vector2(268,-500))
        scene.dragging=true
        var mouse := InputEventMouseMotion.new()
        mouse.device=0
        mouse.relative=Vector2(268,-500)
        scene._unhandled_input(mouse)
    assert(is_equal_approx(scene.target_pitch,.085),"Interleaved touch and mouse must produce only the look finger's 20px pitch change")
    assert(movement[0].y==-1,"Looking must preserve continuous walking")
    press(1,Vector2(390,280),false)
    press(1,Vector2(430,600))
    drag(1,Vector2(434,602),Vector2(-800,900))
    assert(looking[0]==Vector2(4,2),"A reused finger ID must start a fresh position baseline")
    press(0,center,false)
    press(1,Vector2(434,602),false)
    var before: float=scene.target_pitch
    var release_mouse := InputEventMouseMotion.new()
    release_mouse.relative=Vector2(0,-700)
    scene._unhandled_input(release_mouse)
    assert(scene.target_pitch==before,"Compatibility mouse events after touch release must not snap the view")
    touch.last_touch_msec=-1000
    release_mouse.relative=Vector2(4,2)
    scene._unhandled_input(release_mouse)
    assert(is_equal_approx(scene.target_pitch,before-.005),"Real mouse drag must work again after the touch gesture")
    scene.free()
    print("PASS: simultaneous touch, per-finger deltas, duplicate mouse suppression, pointer reuse, cancel, focus loss, UI exclusion, desktop recovery")
    touch.queue_free()
    quit(0)
