extends Node
var sound_enabled := false
var last_scene := "moor"
var reduced_motion := false
var transitioning := false
var return_image: Texture2D
var cover_layer: CanvasLayer
var cover: TextureRect

func show_cover(texture: Texture2D,rect: Rect2) -> void:
    if not is_instance_valid(cover_layer):
        cover_layer = CanvasLayer.new()
        cover_layer.layer = 100
        add_child(cover_layer)
        cover = TextureRect.new()
        cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        cover.material = ShaderMaterial.new()
        cover.material.shader = load("res://shaders/channel_tile.gdshader")
        cover.material.set_shader_parameter("scanline_strength",0.)
        cover.resized.connect(func(): cover.material.set_shader_parameter("panel_size",cover.size))
        cover_layer.add_child(cover)
    cover.texture = texture
    cover.position = rect.position
    cover.size = rect.size
    cover.modulate.a = 1
    cover.material.set_shader_parameter("corner_radius",0.)
    cover.show()

func enter_channel(id: String,rect: Rect2,texture: Texture2D) -> void:
    if transitioning: return
    transitioning = true
    capture_pointer()
    show_cover(texture,rect)
    cover.material.set_shader_parameter("corner_radius",15.)
    var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(cover,"position",Vector2.ZERO,.58)
    tween.tween_property(cover,"size",Vector2(display_size()),.58)
    tween.tween_property(cover.material,"shader_parameter/corner_radius",0.,.58)
    await tween.finished
    last_scene = id
    get_tree().change_scene_to_file(SCENES[id].path)
    await get_tree().process_frame
    if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
    var reveal := create_tween()
    reveal.tween_property(cover,"modulate:a",0.,.28)
    await reveal.finished
    cover.hide()
    transitioning = false

func finish_return(rect: Rect2) -> void:
    var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(cover,"position",rect.position,.62)
    tween.tween_property(cover,"size",rect.size,.62)
    tween.tween_property(cover.material,"shader_parameter/corner_radius",15.,.62)
    await tween.finished
    var reveal := create_tween()
    reveal.tween_property(cover,"modulate:a",0.,.18)
    await reveal.finished
    cover.hide()
    return_image = null
    transitioning = false

func capture_pointer() -> void:
    if DisplayServer.get_name()=="headless" or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"): return
    if OS.has_feature("web") and not bool(JavaScriptBridge.eval("window.matchMedia('(hover: hover) and (pointer: fine)').matches")): return
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func display_size() -> Vector2i:
    var logical := DisplayServer.window_get_size()
    if OS.has_feature("web"):
        logical = Vector2i(int(JavaScriptBridge.eval("window.innerWidth")),int(JavaScriptBridge.eval("window.innerHeight")))
    return logical.max(Vector2i(320,240))
const SCENES := {
    "moor": {"path":"res://main.tscn", "title":"The Still Moor", "subtitle":"Moonlight · wind · rolling fog", "image":"res://assets/menu/moor.png"},
    "coast": {"path":"res://coast.tscn", "title":"Phuket, Blue Bay", "subtitle":"Midday sun · limestone islands · a working pier", "image":"res://assets/menu/coast.png"},
    "town": {"path":"res://town.tscn", "title":"Kasumi Lane", "subtitle":"Soft rain · warm windows · silence", "image":"res://assets/menu/town.png"},
    "sea": {"path":"res://sea.tscn", "title":"Night Crossing", "subtitle":"Rough seas · a small boat · the last light", "image":"res://assets/menu/sea.png"},
    "lowwater": {"path":"res://lowwater.tscn", "title":"Lowwater", "subtitle":"Old oaks · silver mist · a quiet canal", "image":"res://assets/menu/lowwater.png"},
    "laundry": {"path":"res://laundry.tscn", "title":"Night Laundry", "subtitle":"Rain on glass · neon · the rumble of machines", "image":"res://assets/menu/laundry.png"},
    "reservoir": {"path":"res://reservoir.tscn", "title":"Reservoir of Columns", "subtitle":"Immense concrete · still water · distant daylight", "image":"res://assets/menu/reservoir.png"}
}
func _ready() -> void:
    if OS.has_feature("web"):
        reduced_motion = bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches"))
