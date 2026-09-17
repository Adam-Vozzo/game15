extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
    change_scene_to_file("res://station.tscn")
    for i in range(10):await process_frame
    var s:Node=current_scene;s.set_process(false);s.paused=true
    root.size=Vector2i(960,600)
    for i in range(10):await process_frame
    var clocks:Array[float]=[]
    for frame in range(48):clocks.append(float(frame)/12.)
    for frame in range(72):clocks.append(10.+float(frame)/12.)
    for frame in range(60):clocks.append(24.+float(frame)/12.)
    for frame in range(96):clocks.append(36.+float(frame)/12.)
    for frame in range(clocks.size()):
        s.time=clocks[frame];s._process(0.)
        s.camera.position=Vector3(-.7,1.83,14.);s.camera.rotation=Vector3(-.12,.20,0)
        s._update_reflection()
        for i in range(2):await process_frame
        await RenderingServer.frame_post_draw
        s.view.get_texture().get_image().save_png("res://build-logs/spirit-reel-%04d.png"%frame)
    print("SPIRIT_REEL_READY ",clocks.size()," native frames at 12 fps")
    quit(0)
