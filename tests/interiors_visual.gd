extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func settle() -> void:
    for i in range(4): await process_frame
    await RenderingServer.frame_post_draw

func difference(a: Image,b: Image) -> float:
    var sum := 0.
    for y in range(0,a.get_height(),4):
        for x in range(0,a.get_width(),4):
            var p := a.get_pixel(x,y)
            var q := b.get_pixel(x,y)
            sum+=absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)
    return sum/(a.get_width()*a.get_height()/16.)

func capture(scene: Node,label: String) -> Image:
    await settle()
    var img: Image = scene.view.get_texture().get_image()
    img.save_png("res://build-logs/"+label+".png")
    return img

func run() -> void:
    for id in ["laundry","reservoir"]:
        change_scene_to_file("res://"+id+".tscn")
        await settle()
        var scene: Node = current_scene
        scene.set_process(false)
        scene.paused=true
        scene.time=11.
        scene._process(0.)
        var first: Image = await capture(scene,id+"-frozen-a")
        scene._process(.04)
        var frozen: Image = await capture(scene,id+"-frozen-b")
        assert(difference(first,frozen)<.00001,"Rendered Pause must freeze all environmental motion")
        scene.time=12.08;scene._process(0.)
        var changed: Image = await capture(scene,id+"-time-change")
        if id=="laundry":
            assert(difference(first,changed)>.005,"Fluorescent state, rain and drums visibly change")
            for t in [12.,15.,25.,46.,55.,65.]:
                scene.time=t;scene._process(0.)
                await capture(scene,"laundry-cycle-%02d"%int(t))
        else:
            # Compare the same camera with only aperture scattering disabled.
            scene.camera.position=Vector3(0,2.65,-4)
            scene.heading=-.44;scene.target_heading=-.44
            scene.pitch=1.34;scene.target_pitch=1.34
            scene._process(0.)
            var shafts: Image = await capture(scene,"reservoir-shafts-on")
            scene.mist.set_shader_parameter("shaft_strength",0.)
            var plain: Image = await capture(scene,"reservoir-shafts-off")
            assert(difference(shafts,plain)>.005,"Ceiling openings cast visible world-space shafts")
            scene.mist.set_shader_parameter("shaft_strength",1.)
            # Review alternative opening compositions before choosing the final.
            for index in range(3):
                scene.camera.position=[Vector3(0,2.65,24),Vector3(0,2.65,-20),Vector3(34,2.65,-74)][index]
                scene.heading=[-.27,.30,.78][index];scene.target_heading=scene.heading
                scene.pitch=.14;scene.target_pitch=.14;scene._process(0.)
                await capture(scene,"reservoir-composition-%d"%index)
            var reflect: Image = scene.reflection_view.get_texture().get_image()
            reflect.save_png("res://build-logs/reservoir-reflection.png")
            assert(not reflect.is_empty(),"Reflection contains a rendered scene")
        print("PASS native interior: ",id," frozen render, changing atmosphere; draw calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
    quit(0)
