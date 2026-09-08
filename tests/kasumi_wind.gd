extends SceneTree
# GPU regression on the imported crop geometry, including the new atlas shader.
func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(320,320)
    viewport.own_world_3d = true
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 1.5
    camera.position = Vector3(0,.6,3)
    viewport.add_child(camera)
    camera.current = true
    var imported = load("res://assets/models/kasumi_plants.glb").instantiate()
    for name in ["Rice","Wheat","Verge"]:
        var plant := MeshInstance3D.new()
        plant.mesh = imported.find_child(name,true,false).mesh
        var material := ShaderMaterial.new()
        material.shader = load("res://shaders/kasumi_surface.gdshader")
        var tile := 12 if name=="Wheat" else 11
        material.set_shader_parameter("tile",tile)
        material.set_shader_parameter("atlas",load("res://assets/textures/KasumiAtlas%d.png"%(tile/4)))
        material.set_shader_parameter("plant",1.0)
        plant.material_override = material
        viewport.add_child(plant)
        material.set_shader_parameter("scene_time",0.0)
        for i in range(4): await process_frame
        await RenderingServer.frame_post_draw
        var first := viewport.get_texture().get_image()
        material.set_shader_parameter("scene_time",1.3)
        for i in range(4): await process_frame
        await RenderingServer.frame_post_draw
        var second := viewport.get_texture().get_image()
        var root_row := int(floor(camera.unproject_position(Vector3.ZERO).y))-1
        var root_pixels := 0
        var root_changes := 0
        var moving_pixels := 0
        for y in range(320):
            for x in range(320):
                var a := first.get_pixel(x,y).a>.5
                var b := second.get_pixel(x,y).a>.5
                if a!=b:moving_pixels+=1
                if y==root_row:
                    if a:root_pixels+=1
                    if a!=b:root_changes+=1
        print(name,": root pixels=",root_pixels," root movement=",root_changes," moving tips=",moving_pixels)
        if root_pixels<3 or root_changes>1 or moving_pixels<20:
            push_error("Imported crop roots must remain fixed while tips move")
            quit(1)
            return
        plant.queue_free()
        await process_frame
    imported.free()
    viewport.queue_free()
    print("PASS: rooted rice, wheat and verge animation through the production shader")
    quit(0)
