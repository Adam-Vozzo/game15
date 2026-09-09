extends Control

var grid: GridContainer
var cards: Array[Control] = []
var header: Label
var caption: Label
var clock_label: Control
var date_label: Label
var sound_button: Button
var instruction: Label
var footer_rule: ColorRect
var fade: ColorRect
var audio: AudioStreamPlayer
var background: ShaderMaterial
var launching := false
var elapsed := 0.0
var last_columns := 0
var capture_path := ""
var frames := 0

func _ready() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--experience="):
            var place := argument.trim_prefix("--experience=")
            if Session.SCENES.has(place):
                get_tree().call_deferred("change_scene_to_file",Session.SCENES[place].path)
                set_process(false)
                return
        if argument.begins_with("--capture="):
            capture_path = argument.trim_prefix("--capture=")
    var backdrop := ColorRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background = ShaderMaterial.new()
    background.shader = load("res://shaders/menu.gdshader")
    backdrop.material = background
    add_child(backdrop)
    header = _label("Still",36,Color(.31,.36,.39))
    caption = _label("A T M O S P H E R E   C H A N N E L S",11,Color(.49,.55,.58))
    grid = GridContainer.new()
    grid.add_theme_constant_override("h_separation",18)
    grid.add_theme_constant_override("v_separation",18)
    add_child(grid)
    for id in Session.SCENES:
        cards.append(_channel(id))
    for i in range(12-Session.SCENES.size()):
        var placeholder := Panel.new()
        placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
        placeholder.add_theme_stylebox_override("panel",_panel(Color(.91,.925,.93,.3),Color(.70,.75,.77,.55),2))
        var mark := Label.new()
        mark.text = "•  •  •"
        mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        mark.add_theme_font_size_override("font_size",15)
        mark.add_theme_color_override("font_color",Color(.68,.73,.75,.4))
        mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        placeholder.add_child(mark)
        grid.add_child(placeholder)
        cards.append(placeholder)
    footer_rule = ColorRect.new()
    footer_rule.material = ShaderMaterial.new()
    footer_rule.material.shader = load("res://shaders/menu_dock.gdshader")
    footer_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(footer_rule)
    instruction = _label("Choose a place. Stay a while.",14,Color(.41,.49,.52))
    clock_label = load("res://scripts/menu_clock.gd").new()
    add_child(clock_label)

    date_label = _label("",13,Color(.50,.57,.59))
    date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sound_button = Button.new()
    sound_button.text = "Sound on" if Session.sound_enabled else "Sound off"
    sound_button.add_theme_font_size_override("font_size",15)
    sound_button.add_theme_color_override("font_color",Color(.32,.44,.49))
    sound_button.add_theme_color_override("font_hover_color",Color(.13,.45,.60))
    sound_button.add_theme_stylebox_override("normal",_panel(Color(.94,.97,.98),Color(.64,.75,.80),2,28))
    sound_button.add_theme_stylebox_override("hover",_panel(Color(.98,1,1),Color(.25,.72,.90),2,28))
    sound_button.add_theme_stylebox_override("focus",_panel(Color(0,0,0,0),Color(.25,.72,.90),3,28))
    sound_button.add_theme_stylebox_override("pressed",_panel(Color(.84,.94,.98),Color(.25,.72,.90),2,28))
    sound_button.pressed.connect(_toggle_sound)
    add_child(sound_button)
    audio = AudioStreamPlayer.new()
    var stream: AudioStreamWAV = load("res://assets/audio/menu_air.wav")
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_end = int(stream.get_length()*stream.mix_rate)
    audio.stream = stream
    audio.volume_db = -14
    add_child(audio)
    if Session.sound_enabled: audio.play()
    fade = ColorRect.new()
    fade.color = Color(.92,.95,.96,0)
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(fade)
    get_viewport().size_changed.connect(_resize,CONNECT_DEFERRED)
    _resize()
    _update_clock()
    if Session.return_image: call_deferred("_return_animation")
    print("CHANNEL_MENU_READY: four experiences available")

func _panel(fill: Color, border: Color, width := 2, radius := 16) -> StyleBoxFlat:
    var panel := StyleBoxFlat.new()
    panel.bg_color = fill
    panel.border_color = border
    panel.set_border_width_all(width)
    panel.set_corner_radius_all(radius)
    panel.shadow_color = Color(.30,.42,.46,.12)
    panel.shadow_size = 3
    panel.shadow_offset = Vector2(0,2)
    return panel

func _label(text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)
    return label

func _channel(id: String) -> Button:
    var data: Dictionary = Session.SCENES[id]
    var button := Button.new()
    button.name = id.capitalize()+"Channel"
    button.tooltip_text = data.subtitle
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_stylebox_override("normal",_panel(Color(.96,.975,.98),Color(.61,.71,.76),2))
    button.add_theme_stylebox_override("hover",_panel(Color(1,1,1),Color(.22,.74,.94),4))
    button.add_theme_stylebox_override("pressed",_panel(Color(.87,.96,1),Color(.17,.66,.86),4))
    button.add_theme_stylebox_override("focus",_panel(Color(0,0,0,0),Color(.22,.74,.94),3))
    var picture := TextureRect.new()
    if ResourceLoader.exists(data.image): picture.texture = load(data.image)
    picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    picture.offset_left = 3
    picture.offset_top = 3
    picture.offset_right = -3
    picture.offset_bottom = -3
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var tile_material := ShaderMaterial.new()
    tile_material.shader = load("res://shaders/channel_tile.gdshader")
    picture.material = tile_material
    picture.resized.connect(func(): tile_material.set_shader_parameter("panel_size",picture.size))
    button.add_child(picture)
    var strip := PanelContainer.new()
    strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    strip.anchor_left = 0
    strip.anchor_right = 1
    strip.anchor_top = .5
    strip.anchor_bottom = .5
    strip.offset_top = -20
    strip.offset_bottom = 20
    strip.offset_left = 4
    strip.offset_right = -4
    var shade := StyleBoxFlat.new()
    shade.bg_color = Color(0,0,0,.60)
    strip.add_theme_stylebox_override("panel",shade)
    strip.modulate.a = 0
    button.add_child(strip)
    var title := Label.new()
    title.text = data.title
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size",18)
    title.add_theme_color_override("font_color",Color.WHITE)
    title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    strip.add_child(title)
    var hover := func(on: bool):
        var tween := create_tween()
        tween.tween_property(strip,"modulate:a",1. if on else 0.,.16)
    button.mouse_entered.connect(hover.bind(true))
    button.mouse_exited.connect(hover.bind(false))
    button.focus_entered.connect(hover.bind(true))
    button.focus_exited.connect(hover.bind(false))
    button.pressed.connect(func(): _launch(id))
    grid.add_child(button)
    return button

func _launch(id: String) -> void:
    if launching or Session.transitioning: return
    launching = true
    var card := grid.get_node(id.capitalize()+"Channel") as Control
    Session.enter_channel(id,card.get_global_rect(),load(Session.SCENES[id].image))

func _return_animation() -> void:
    await get_tree().process_frame
    var card := grid.get_node(Session.last_scene.capitalize()+"Channel") as Control
    Session.finish_return(card.get_global_rect())

func _toggle_sound() -> void:
    Session.sound_enabled = not Session.sound_enabled
    sound_button.text = "Sound on" if Session.sound_enabled else "Sound off"
    if Session.sound_enabled: audio.play()
    else: audio.stop()

func _resize() -> void:
    var logical: Vector2i = Session.display_size()
    get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
    if get_window().content_scale_size != logical: get_window().content_scale_size = logical
    var screen := Vector2(logical)
    var narrow := screen.x < 700
    var short := screen.y < 540
    var columns := 2 if narrow else 4
    var rows := 2 if narrow else (1 if short else 3)
    var margin := 22.0 if narrow else screen.x*.06
    var top := 24.0 if short else 44.0
    var bottom := 100.0 if short else 170.0
    grid.columns = columns
    var card_size := Vector2((screen.x-margin*2.-18.*(columns-1))/columns,(screen.y-top-bottom-18.*(rows-1))/rows)
    grid.position = Vector2(margin,top)
    for i in range(cards.size()):
        cards[i].visible = i < columns*rows
        cards[i].custom_minimum_size = card_size
    grid.reset_size()
    header.hide()
    caption.hide()
    instruction.hide()
    footer_rule.position = Vector2(0,screen.y-bottom+4)
    footer_rule.size = Vector2(screen.x,bottom-4)
    footer_rule.material.set_shader_parameter("panel_size",footer_rule.size)
    clock_label.position = Vector2(screen.x*.5-100,screen.y-bottom+(13 if short else 21))
    clock_label.size = Vector2(200,48 if not short else 35)
    date_label.position = Vector2(screen.x*.5-115,screen.y-52)
    date_label.size = Vector2(230,30)
    date_label.add_theme_font_size_override("font_size",20 if not short else 15)
    sound_button.size = Vector2(128,44)
    sound_button.position = Vector2(screen.x-margin-128,screen.y-(70 if short else 94))
    if narrow:
        sound_button.size = Vector2(100,40)
        sound_button.position = Vector2(screen.x-112,screen.y-58)
        date_label.position.x = 12
        date_label.size.x = screen.x-130
        date_label.add_theme_font_size_override("font_size",15)
        date_label.position.y = screen.y-41

func _update_clock() -> void:
    var now := Time.get_datetime_dict_from_system()
    clock_label.text = "%02d:%02d" % [now.hour,now.minute]
    var weekdays := ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    var months := ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    date_label.text = "%s  %d/%d" % [weekdays[now.weekday].left(3),now.month,now.day]

func _process(delta: float) -> void:
    if not Session.reduced_motion: elapsed += delta
    background.set_shader_parameter("menu_time",elapsed)
    _update_clock()
    frames += 1
    if frames % 20 == 0 and get_window().content_scale_size != Session.display_size():
        _resize()
    if capture_path != "" and frames == 40:
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png(capture_path)
        print("CAPTURE_SAVED: ",capture_path)
        get_tree().quit()
