extends Control
signal movement_changed(value: Vector2)
signal look_changed(value: Vector2)
var move_finger: int = -1
var look_finger: int = -1
var stick := Vector2.ZERO
var joystick_center := Vector2.ZERO
var radius := 52.0
var blocked_rects: Array = []
var touch_visible := false
var active_touches: Dictionary = {}
var look_position := Vector2.ZERO
var last_touch_msec: int = -1000

func suppress_mouse_look() -> bool:
    # Browsers can send compatibility mouse events with an ordinary device ID.
    return not active_touches.is_empty() or Time.get_ticks_msec()-last_touch_msec<400

static func movement_vector(offset: Vector2, max_radius: float = 42.0) -> Vector2:
    var magnitude := minf(offset.length() / max_radius, 1.0)
    var strength := maxf(0.0, (magnitude - 0.12) / 0.88)
    return offset.normalized() * strength

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    touch_visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
    resized.connect(_resize)
    _resize()

func _resize() -> void:
    joystick_center = Vector2(84, size.y - 96)
    reset_input()

func reset_input() -> void:
    if not active_touches.is_empty():last_touch_msec=Time.get_ticks_msec()
    active_touches.clear()
    move_finger = -1
    look_finger = -1
    stick = Vector2.ZERO
    movement_changed.emit(Vector2.ZERO)
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        reset_input()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        touch_visible = true
        last_touch_msec=Time.get_ticks_msec()
        if not event.pressed or event.canceled:
            active_touches.erase(event.index)
            if event.index == move_finger:
                move_finger = -1
                stick = Vector2.ZERO
                movement_changed.emit(Vector2.ZERO)
            if event.index == look_finger:
                look_finger = -1
            queue_redraw()
            return
        if active_touches.has(event.index):return
        active_touches[event.index]=true
        for rect in blocked_rects:
            if rect.has_point(event.position):
                return
        if event.position.distance_to(joystick_center) < radius * 1.6 and move_finger == -1:
            move_finger = event.index
            _update_stick(event.position)
        elif look_finger == -1:
            look_finger = event.index
            look_position = event.position
        queue_redraw()
    elif event is InputEventScreenDrag:
        last_touch_msec=Time.get_ticks_msec()
        if event.index == move_finger:
            _update_stick(event.position)
        elif event.index == look_finger:
            # Derive motion from this finger's own positions. Some web backends
            # report relative motion from the other pointer during multitouch.
            var delta: Vector2 = event.position-look_position
            look_position=event.position
            look_changed.emit(delta)

func _update_stick(point: Vector2) -> void:
    var offset := point - joystick_center
    stick = offset.limit_length(42)
    movement_changed.emit(movement_vector(offset))
    queue_redraw()

func _draw() -> void:
    if not touch_visible:
        return
    draw_circle(joystick_center, radius, Color(0.035,0.065,0.07,0.55))
    draw_arc(joystick_center, radius, 0, TAU, 64, Color(0.7,0.8,0.73,0.35), 1.0, true)
    draw_arc(joystick_center, 31, 0, TAU, 48, Color(0.7,0.8,0.73,0.14), 1.0, true)
    draw_circle(joystick_center + stick, 17, Color(0.5,0.65,0.55,0.35))
    draw_arc(joystick_center + stick, 17, 0, TAU, 32, Color(0.8,0.88,0.80,0.65), 1.0, true)

