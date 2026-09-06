extends Node
const TouchControls = preload("res://scripts/touch_controls.gd")
var view: SubViewport
var world: Node3D
var camera: Camera3D
var ui: Control
var controls: HBoxContainer
var touch: Control
var mist: ShaderMaterial
var grass_material: ShaderMaterial
var fern_material: ShaderMaterial
var audio: AudioStreamPlayer
var time := 0.0
var paused := false
var sound_on := false
var hidden_ui := false
var dragging := false
var heading := 0.0
var pitch := 0.035
var target_heading := 0.0
var target_pitch := 0.035
var walking := Vector2.ZERO
var start := Vector3.ZERO
var frame_count := 0
var capture_path := ""
var mobile := false
var top_label: Label
var subtitle: Label
var footer: Label
var hint: Label
var hide_button: Button
var rng := RandomNumberGenerator.new()

static func ground_height(x: float, z: float) -> float:
    var channel := exp(-pow((x - 2.0 - sin(z * .045) * 3.0) / 3.7, 2.0)) * .5
    return sin(x * .065 + z * .035) * 1.5 + cos(z * .095 - x * .03) * .8 + sin(x * .2 + z * .16) * .18 - channel

func _ready() -> void:
    rng.seed = 14015
    mobile = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture="):
            capture_path = argument.trim_prefix("--capture=")
        if argument == "--mobile-test":
            mobile = true
    if OS.has_feature("web"):
        paused = bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches"))
    _sync_display_size()
    _create_view()
    _create_environment()
    _create_vegetation()
    _create_camera()
    _create_interface()
    _create_audio()
    get_viewport().size_changed.connect(_resize)
    _resize()
    print("HOLLOW_READY: Blender assets loaded, Godot atmosphere active")

func _create_view() -> void:
    view = SubViewport.new()
    view.name = "PS1_Render_Viewport"
    view.own_world_3d = true
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    view.positional_shadow_atlas_size = 0
    add_child(view)
    world = Node3D.new()
    world.name = "Moor"
    view.add_child(world)
    var image := TextureRect.new()
    image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    image.texture = view.get_texture()
    image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_SCALE
    image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(image)

func _create_environment() -> void:
    var art = load("res://assets/models/moor.glb").instantiate()
    world.add_child(art)
    var textures := {"Bark":"Bark", "Peat":"Peat", "Stone":"Stone"}
    for node in art.find_children("*", "MeshInstance3D", true, false):
        for i in range(node.mesh.get_surface_count()):
            var original = node.mesh.surface_get_material(i)
            var name_key := "Peat"
            if original:
                for candidate in textures:
                    if candidate in original.resource_name:
                        name_key = candidate
            var material := ShaderMaterial.new()
            material.shader = load("res://shaders/surface.gdshader")
            material.set_shader_parameter("surface_texture", load("res://assets/textures/" + name_key + ".png"))
            material.set_shader_parameter("snap", .12)
            material.set_shader_parameter("surface_brightness", .80 if name_key == "Peat" else 1.0)
            node.set_surface_override_material(i, material)
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(.12,.17,.18)
    environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color = Color(.4,.5,.48)
    environment.environment.ambient_light_energy = .7
    world.add_child(environment)

func _asset_mesh(path: String) -> Mesh:
    var root = load(path).instantiate()
    var nodes = root.find_children("*", "MeshInstance3D", true, false)
    var mesh: Mesh = nodes[0].mesh
    root.free()
    return mesh

func _scatter(mesh: Mesh, count: int, material: Material, fern: bool) -> void:
    # Spatial chunks allow distant patches to be culled, keeping mobile draw cost bounded.
    for cell_z in range(6):
        for cell_x in range(5):
            var multi := MultiMesh.new()
            multi.transform_format = MultiMesh.TRANSFORM_3D
            multi.mesh = mesh
            multi.instance_count = count
            for i in range(count):
                var x := -55.0 + cell_x * 22.0 + rng.randf() * 22.0
                var z := 24.0 - cell_z * 21.0 - rng.randf() * 21.0
                var scale_factor := rng.randf_range(.48,1.02)
                var channel := absf(x - 2.0 - sin(z * .045) * 3.0)
                if channel < 2.5:
                    scale_factor *= .3
                if fern:
                    scale_factor *= 1.25
                var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale_factor)
                multi.set_instance_transform(i, Transform3D(basis, Vector3(x,ground_height(x,z),z)))
            var patch := MultiMeshInstance3D.new()
            patch.multimesh = multi
            patch.material_override = material
            patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            patch.visibility_range_end = 95.0
            world.add_child(patch)

func _create_vegetation() -> void:
    grass_material = ShaderMaterial.new()
    grass_material.shader = load("res://shaders/grass.gdshader")
    grass_material.set_shader_parameter("dry_color", Color(.12,.152,.112))
    fern_material = ShaderMaterial.new()
    fern_material.shader = load("res://shaders/grass.gdshader")
    fern_material.set_shader_parameter("dry_color", Color(.104,.132,.096))
    fern_material.set_shader_parameter("wind_height", .30)
    _scatter(_asset_mesh("res://assets/models/grass_tuft.glb"), 440 if mobile else 740, grass_material, false)
    _scatter(_asset_mesh("res://assets/models/fern.glb"), 22 if mobile else 42, fern_material, true)

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.fov = 61
    camera.near = .08
    camera.far = 180
    start = Vector3(0,ground_height(0,15)+1.85,15)
    camera.position = start
    world.add_child(camera)
    camera.current = true
    var quad := MeshInstance3D.new()
    var quad_mesh := QuadMesh.new()
    quad_mesh.size = Vector2(2,2)
    quad.mesh = quad_mesh
    quad.extra_cull_margin = 16384
    quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mist = ShaderMaterial.new()
    mist.shader = load("res://shaders/atmosphere.gdshader")
    mist.render_priority = 127
    mist.set_shader_parameter("fog_steps", 24 if mobile else 36)
    quad.material_override = mist
    camera.add_child(quad)

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(label)
    return label

func _button(text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(54,46)
    button.add_theme_font_size_override("font_size", 14)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(.03,.06,.065,.5)
    style.border_color = Color(.6,.72,.64,.25)
    style.set_border_width_all(1)
    style.content_margin_left = 14
    style.content_margin_right = 14
    button.add_theme_stylebox_override("normal", style)
    var hover = style.duplicate()
    hover.bg_color = Color(.17,.25,.21,.7)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    button.pressed.connect(callback)
    controls.add_child(button)
    return button

func _create_interface() -> void:
    ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(ui)
    top_label = _label("H O L L O W   I I", 29, Color(.8,.86,.81))
    subtitle = _label("THE STILL MOOR", 12, Color(.58,.67,.63))
    footer = _label("Where the wind remains", 23, Color(.78,.84,.79))
    hint = _label("DRAG TO LOOK  ·  WASD TO WANDER", 12, Color(.60,.69,.63))
    controls = HBoxContainer.new()
    controls.add_theme_constant_override("separation", 8)
    ui.add_child(controls)
    var sound_button := _button("Sound off", func():
        sound_on = not sound_on
        if sound_on: audio.play()
        else: audio.stop()
        controls.get_child(0).text = "Sound on" if sound_on else "Sound off"
    )
    sound_button.tooltip_text = "Enable the wind"
    _button("Pause", func():
        paused = not paused
        controls.get_child(1).text = "Resume" if paused else "Pause"
    )
    _button("Reset", _reset)
    hide_button = Button.new()
    hide_button.text = "Hide controls"
    hide_button.flat = true
    hide_button.custom_minimum_size = Vector2(120,44)
    hide_button.add_theme_font_size_override("font_size", 12)
    hide_button.pressed.connect(_toggle_ui)
    add_child(hide_button)
    touch = TouchControls.new()
    touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    touch.movement_changed.connect(func(value: Vector2): walking = value)
    touch.look_changed.connect(_look)
    add_child(touch)
    if mobile:
        touch.touch_visible = true
    if paused:
        controls.get_child(1).text = "Resume"

func _create_audio() -> void:
    audio = AudioStreamPlayer.new()
    var stream: AudioStreamWAV = load("res://assets/audio/moor_wind.wav")
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = int(stream.get_length() * stream.mix_rate)
    audio.stream = stream
    audio.volume_db = -5
    add_child(audio)

func _sync_display_size() -> void:
    var logical_size := DisplayServer.window_get_size()
    if OS.has_feature("web"):
        logical_size = Vector2i(int(JavaScriptBridge.eval("window.innerWidth")), int(JavaScriptBridge.eval("window.innerHeight")))
    logical_size.x = maxi(logical_size.x, 320)
    logical_size.y = maxi(logical_size.y, 240)
    var window := get_window()
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    if window.content_scale_size != logical_size:
        window.content_scale_size = logical_size

func _resize() -> void:
    _sync_display_size()
    var screen := get_viewport().get_visible_rect().size
    var budget := Vector2(640,480) if mobile else Vector2(960,640)
    var ratio := minf(1.0,minf(budget.x/screen.x,budget.y/screen.y))
    view.size = Vector2i(screen * ratio)
    camera.keep_aspect = Camera3D.KEEP_WIDTH if screen.x < screen.y else Camera3D.KEEP_HEIGHT
    camera.fov = 72 if screen.x < screen.y else 61
    var narrow := screen.x < 720
    top_label.position = Vector2(30,28)
    subtitle.position = Vector2(32,69)
    footer.position = Vector2(32,screen.y - (240 if narrow else 109))
    hint.position = footer.position + Vector2(0,40)
    hint.text = "LEFT THUMB TO WALK  ·  DRAG TO LOOK" if mobile else "DRAG TO LOOK  ·  WASD TO WANDER"
    controls.reset_size()
    controls.position = Vector2(screen.x-controls.size.x-26,screen.y-93)
    hide_button.position = Vector2(screen.x-150,screen.y-45)
    if screen.y < 480:
        footer.visible = false
        hint.visible = false
        subtitle.visible = false
    else:
        footer.visible = not hidden_ui
        hint.visible = not hidden_ui
        subtitle.visible = not hidden_ui
    touch.blocked_rects = [controls.get_global_rect(),hide_button.get_global_rect()]
    dragging = false

func _toggle_ui() -> void:
    hidden_ui = not hidden_ui
    ui.visible = not hidden_ui
    hide_button.text = "Show controls" if hidden_ui else "Hide controls"
    touch.blocked_rects = [hide_button.get_global_rect()] if hidden_ui else [controls.get_global_rect(),hide_button.get_global_rect()]

func _reset() -> void:
    camera.position = start
    target_heading = 0
    target_pitch = .035
    walking = Vector2.ZERO
    touch.reset_input()

func _look(delta: Vector2) -> void:
    target_heading -= delta.x*.0025
    target_pitch = clampf(target_pitch-delta.y*.0025,-.65,.65)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        dragging = event.pressed
    elif event is InputEventMouseMotion and dragging:
        _look(event.relative)
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_H:
            _toggle_ui()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        dragging = false
        walking = Vector2.ZERO

func _process(delta: float) -> void:
    delta = minf(delta,.04)
    if not paused:
        time += delta
    grass_material.set_shader_parameter("wind_time",time)
    fern_material.set_shader_parameter("wind_time",time)
    mist.set_shader_parameter("atmosphere_time",time)
    heading = lerpf(heading,target_heading,minf(delta*8,1))
    pitch = lerpf(pitch,target_pitch,minf(delta*8,1))
    var direction := walking
    direction.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
    direction.y += float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
    direction = direction.limit_length(1)
    var forward := Vector3(-sin(heading),0,-cos(heading))
    var right := Vector3(cos(heading),0,-sin(heading))
    camera.position += (right*direction.x-forward*direction.y)*delta*2.1
    camera.position.x = clampf(camera.position.x,-44,44)
    camera.position.z = clampf(camera.position.z,-72,24)
    camera.position.y = ground_height(camera.position.x,camera.position.z)+1.85+(0 if paused else sin(time*.65)*.018)
    camera.rotation = Vector3(pitch,heading+(0 if paused else sin(time*.12)*.006),0)
    frame_count += 1
    if capture_path != "" and frame_count == 40:
        _capture()

func _capture() -> void:
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(capture_path)
    print("CAPTURE_SAVED: ",capture_path)
    get_tree().quit()


