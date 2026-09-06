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
    print("PASS: simultaneous touch, ownership, cancel, focus loss, UI exclusion, dead zone, speed cap")
    touch.queue_free()
    quit(0)
