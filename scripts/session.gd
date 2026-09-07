extends Node
var sound_enabled := false
var last_scene := "moor"
var reduced_motion := false

func display_size() -> Vector2i:
    var logical := DisplayServer.window_get_size()
    if OS.has_feature("web"):
        logical = Vector2i(int(JavaScriptBridge.eval("window.innerWidth")),int(JavaScriptBridge.eval("window.innerHeight")))
    return logical.max(Vector2i(320,240))
const SCENES := {
    "moor": {"path":"res://main.tscn", "title":"The Still Moor", "subtitle":"Moonlight · wind · rolling fog", "image":"res://assets/menu/moor.png"},
    "coast": {"path":"res://coast.tscn", "title":"Phuket, Last Light", "subtitle":"Warm water · palms · salt air", "image":"res://assets/menu/coast.png"},
    "town": {"path":"res://town.tscn", "title":"Kasumi Lane", "subtitle":"Soft rain · warm windows · silence", "image":"res://assets/menu/town.png"}
}
func _ready() -> void:
    if OS.has_feature("web"):
        reduced_motion = bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches"))
