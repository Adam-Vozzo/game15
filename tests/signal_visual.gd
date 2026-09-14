extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func capture(label: String) -> Image:
    for i in range(4): await process_frame
    await RenderingServer.frame_post_draw
    var img: Image = current_scene.view.get_texture().get_image()
    img.save_png("res://build-logs/signal-"+label+".png")
    return img

func difference(a: Image,b: Image) -> float:
    var total := 0.
    for y in range(0,a.get_height(),2):
        for x in range(0,a.get_width(),2):
            var p := a.get_pixel(x,y)
            var q := b.get_pixel(x,y)
            total+=absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)
    return total/(a.get_width()*a.get_height()/4.)

func check_gradient(img: Image,dark: Image,center_x: float) -> void:
    var counts := Vector3.ZERO
    var distances := Vector3.ZERO
    for y in range(img.get_height()):
        for x in range(img.get_width()):
            var color := img.get_pixel(x,y)
            var unlit := dark.get_pixel(x,y)
            if maxf(color.r-unlit.r,maxf(color.g-unlit.g,color.b-unlit.b))<.12: continue
            var band := -1
            if color.r>.40 and color.r>color.g+.065: band=0
            elif minf(color.r,minf(color.g,color.b))>.55 and absf(color.r-color.g)<.10: band=1
            elif color.g>.35 and color.b>color.r+.025 and color.g>color.r+.05: band=2
            if band>=0:
                counts[band]+=1.
                distances[band]+=absf(x-center_x)
    assert(counts.x>50 and counts.y>50 and counts.z>50,"Rendered tree must include red, white and cyan")
    distances/=counts
    assert(distances.x<distances.y*.8 and distances.y<distances.z*.85,"Viewer must see red at centre, white between, and cyan at edges")

func run() -> void:
    change_scene_to_file("res://signal.tscn")
    for i in range(5): await process_frame
    var scene: Node = current_scene
    scene.set_process(false);scene.paused=true;scene.time=11.;scene._process(0.)
    var first := await capture("frozen-a")
    scene._process(.04)
    var frozen := await capture("frozen-b")
    assert(difference(first,frozen)<.00001,"Rendered Pause must freeze the complete scene")
    scene.time=13.4;scene._process(0.)
    var changed := await capture("evolved")
    assert(difference(first,changed)>.0005,"The rendered glitch and atmosphere must evolve")
    scene.drift_mesh.hide()
    var no_fragments := await capture("no-fragments")
    scene.pixel_material.set_shader_parameter("light_strength",0.)
    var dark := await capture("unlit-mask")
    scene.pixel_material.set_shader_parameter("light_strength",1.25)
    check_gradient(no_fragments,dark,scene.camera.unproject_position(Vector3(1.6,5.,-3.)).x)
    scene.drift_mesh.show()
    var fragments := await capture("fragments")
    assert(difference(no_fragments,fragments)>.00005,"Detached rising pixels must visibly contribute")
    scene.drift_mesh.hide()
    scene.camera.position=Vector3(14,2,-1)
    scene.heading=1.41;scene.target_heading=1.41
    scene.pitch=.29;scene.target_pitch=.29;scene._process(0.)
    var side := await capture("gradient-side")
    scene.pixel_material.set_shader_parameter("light_strength",0.)
    var dark_side := await capture("unlit-side-mask")
    scene.pixel_material.set_shader_parameter("light_strength",1.25)
    check_gradient(side,dark_side,scene.camera.unproject_position(Vector3(1.6,5.,-3.)).x)
    scene._reset();scene._process(0.)
    # Hold atmosphere/camera still and sample only actual light-cell animation.
    # This catches sudden luminance jumps, independently of particle births.
    var previous := await capture("fade-start")
    var maximum_step := 0.
    for index in range(60):
        scene.pixel_material.set_shader_parameter("scene_time",13.4+float(index+1)/30.)
        await process_frame
        await RenderingServer.frame_post_draw
        var next: Image = scene.view.get_texture().get_image()
        maximum_step=maxf(maximum_step,difference(previous,next))
        previous=next
    print("PASS native colour gradient from opening and side; maximum 30fps fade step=",maximum_step)
    assert(maximum_step<.0003,"Light-cell glitches must fade without abrupt frame-to-frame blackouts")
    scene.drift_mesh.show()
    # Isolate the actual rendered particles against the same static forest.
    scene.pixel_material.set_shader_parameter("light_strength",0.)
    for index in range(9):
        scene.time=11.+index*.35;scene._process(0.)
        await capture("particle-cycle-%02d"%index)
    scene.pixel_material.set_shader_parameter("light_strength",1.25)
    if "--signal-clip" in OS.get_cmdline_user_args():
        DirAccess.make_dir_recursive_absolute("res://build-logs/signal-clip")
        for index in range(180):
            scene.time=11.+index/20.;scene._process(0.)
            await RenderingServer.frame_post_draw
            scene.view.get_texture().get_image().save_png("res://build-logs/signal-clip/frame-%04d.png"%index)
            await process_frame
    print("PASS native Signal Grove: frozen render, evolving glitches and visible detached fragments; draw calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
    quit(0)
