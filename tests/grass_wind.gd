extends SceneTree
# Run with a graphics driver (not --headless); checks the real imported mesh and shader.
func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(320,320)
    viewport.own_world_3d = true
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var imported = load("res://assets/models/grass_tuft.glb").instantiate()
    var mesh: Mesh = imported.find_children("*","MeshInstance3D",true,false)[0].mesh
    var plant := MeshInstance3D.new()
    plant.mesh = mesh
    var material := ShaderMaterial.new()
    material.shader = load("res://shaders/grass.gdshader")
    material.set_shader_parameter("dry_color",Color.WHITE)
    plant.material_override = material
    viewport.add_child(plant)
    imported.free()
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 1.10
    camera.position = Vector3(0,.40,3)
    viewport.add_child(camera)
    camera.current = true
    material.set_shader_parameter("wind_time",0.0)
    for i in range(4): await process_frame
    await RenderingServer.frame_post_draw
    var first := viewport.get_texture().get_image()
    material.set_shader_parameter("wind_time",1.3)
    for i in range(4): await process_frame
    await RenderingServer.frame_post_draw
    var second := viewport.get_texture().get_image()
    var root_row := int(floor(camera.unproject_position(Vector3.ZERO).y))-1
    var root_pixels := 0
    var root_changes := 0
    var total_changes := 0
    for y in range(320):
        for x in range(320):
            var a := first.get_pixel(x,y).a > .5
            var b := second.get_pixel(x,y).a > .5
            if a != b: total_changes += 1
            if y == root_row:
                if a: root_pixels += 1
                if a != b: root_changes += 1
    print("ROOT_PIXELS=",root_pixels," ROOT_CHANGES=",root_changes," MOVING_PIXELS=",total_changes)
    if root_pixels < 5 or root_changes > 1 or total_changes < 30:
        push_error("Grass wind regression: roots must stay anchored while upper blades move")
        quit(1)
        return
    print("PASS: actual imported grass roots stay anchored while tips sway across wind phases")
    viewport.queue_free()
    quit(0)
