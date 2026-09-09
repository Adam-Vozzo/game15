extends Control
var text := "" :
    set(value):
        if text != value: text = value; queue_redraw()
const DIGITS = [63,6,91,79,102,109,125,7,127,111]
func _draw() -> void:
    var now := Time.get_time_dict_from_system()
    var digits := "%02d%02d" % [now.hour,now.minute]
    var scale_factor := minf(size.x/200.,size.y/48.)
    draw_set_transform(Vector2((size.x-200.*scale_factor)*.5,0),0,Vector2.ONE*scale_factor)
    for i in range(4):
        var origin := Vector2(i*43.+(12. if i>1 else 0.),0)
        var segments := [Rect2(7,0,24,5),Rect2(31,5,5,17),Rect2(31,26,5,17),Rect2(7,43,24,5),Rect2(2,26,5,17),Rect2(2,5,5,17),Rect2(7,21.5,24,5)]
        for j in range(7):
            var r: Rect2 = segments[j]
            var c := Color(.47,.50,.51) if (DIGITS[int(digits[i])] & (1<<j)) else Color(.47,.50,.51,.035)
            var a := r.position+origin
            var b := r.end+origin
            var cut := 2.0
            draw_colored_polygon(PackedVector2Array([a+Vector2(cut,0),Vector2(b.x-cut,a.y),Vector2(b.x,a.y+cut),b-Vector2(0,cut),b-Vector2(cut,0),Vector2(a.x+cut,b.y),Vector2(a.x,b.y-cut),a+Vector2(0,cut)]),c)
    draw_circle(Vector2(91,15),2.5,Color(.47,.50,.51))
    draw_circle(Vector2(91,33),2.5,Color(.47,.50,.51))
