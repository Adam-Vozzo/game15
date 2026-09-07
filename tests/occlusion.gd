extends SceneTree
# GPU fixture: actual shared depth AO must darken a box/floor contact, leave an
# isolated flat surface and the sky clean, and work at both quality budgets.
func _initialize() -> void:
    call_deferred("run")

func average(image: Image, pixel: Vector2, radius: int) -> float:
    var sum := 0.0
    var count := 0
    for y in range(int(pixel.y)-radius,int(pixel.y)+radius+1):
        for x in range(int(pixel.x)-radius,int(pixel.x)+radius+1):
            if x>=0 and y>=0 and x<image.get_width() and y<image.get_height():
                sum+=image.get_pixel(x,y).r
                count+=1
    return sum/maxi(count,1)

func run() -> void:
    var view := SubViewport.new()
    view.size=Vector2i(480,360)
    view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var floor := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size=Vector2(20,20)
    floor.mesh=plane
    view.add_child(floor)
    var box := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size=Vector3.ONE
    box.mesh=cube
    box.position.y=.5
    view.add_child(box)
    var camera := Camera3D.new()
    camera.position=Vector3(2.8,2.5,4.5)
    camera.far=100
    view.add_child(camera)
    camera.look_at(Vector3(0,.1,0))
    camera.current=true
    var post := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size=Vector2(2,2)
    post.mesh=quad
    post.extra_cull_margin=16384
    var material := ShaderMaterial.new()
    material.shader=load("res://tests/ao_fixture.gdshader")
    material.render_priority=127
    post.material_override=material
    camera.add_child(post)
    for samples in [8,12]:
        material.set_shader_parameter("ao_samples",samples)
        for i in range(4): await process_frame
        await RenderingServer.frame_post_draw
        var image := view.get_texture().get_image()
        var contact := average(image,camera.unproject_position(Vector3(0,0,.63)),3)
        var flat := average(image,camera.unproject_position(Vector3(-2,0,1)),5)
        var sky := average(image,Vector2(240,8),4)
        print("AO samples=",samples," contact=",contact," flat=",flat," sky=",sky)
        if contact>=.98 or contact<.60 or flat<.99 or sky<.99:
            push_error("AO must add local contact shading without dirtying flat surfaces or sky")
            quit(1)
            return
    material.set_shader_parameter("ao_strength",0.0)
    for i in range(3): await process_frame
    await RenderingServer.frame_post_draw
    var disabled := view.get_texture().get_image()
    assert(average(disabled,camera.unproject_position(Vector3(0,0,.63)),3)>.99,"Zero AO strength must bypass the effect")
    print("PASS: GPU contact occlusion, flat-surface rejection, clean sky, desktop/mobile budgets, disable control")
    view.queue_free()
    quit(0)
