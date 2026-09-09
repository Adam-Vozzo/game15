extends SceneTree
# Regression: foundation contact shading must stay attached during close camera movement.
# A flat atlas isolates contact shading from texture filtering and wet reflections.
func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var viewport := SubViewport.new()
    viewport.size=Vector2i(640,640)
    viewport.own_world_3d=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var atlas := Image.create(256,256,false,Image.FORMAT_RGB8)
    for y in range(256):
        for x in range(256):
            atlas.set_pixel(x,y,Color(.65,.65,.65))
    var material := ShaderMaterial.new()
    material.shader=load("res://shaders/kasumi_surface.gdshader")
    material.set_shader_parameter("atlas",ImageTexture.create_from_image(atlas))
    material.set_shader_parameter("tile",1)
    material.set_shader_parameter("terrain_surface",1.)
    var bounds := PackedVector4Array([Vector4(8,-1,2,2)])
    bounds.resize(20)
    material.set_shader_parameter("shelter_bounds",bounds)
    material.set_shader_parameter("shelter_count",1)
    var wall := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size=Vector2(8,8)
    wall.mesh=quad
    wall.rotation.x=-PI/2
    wall.position.x=10
    wall.material_override=material
    viewport.add_child(wall)
    var camera := Camera3D.new()
    viewport.add_child(camera)
    camera.current=true
    var baseline: Array[Color]=[]
    var maximum_error := 0.0
    for pose in [Vector3(10,1.85,2.4),Vector3(11.5,1.85,2),Vector3(9,1.85,1.8)]:
        camera.position=pose
        camera.look_at(Vector3(10,0,0))
        for i in range(4): await process_frame
        await RenderingServer.frame_post_draw
        var rendered := viewport.get_texture().get_image()
        var index := 0
        for y in [-.8,0.,.8]:
            for x in [-.8,0.,.8]:
                var screen := camera.unproject_position(Vector3(10+x,0,y))
                var color := rendered.get_pixel(int(screen.x),int(screen.y))
                if baseline.size()<9:
                    baseline.append(color)
                else:
                    var first := baseline[index]
                    maximum_error=maxf(maximum_error,maxf(absf(first.r-color.r),absf(first.g-color.g)))
                index+=1
    print("Contact-shading maximum camera-motion drift: ",maximum_error)
    if maximum_error>.018 or baseline[0].r<.02 or baseline[2].r-baseline[0].r<.025:
        push_error("Ground contact shading must remain stable under close camera motion")
        quit(1)
        return
    print("PASS: ground contact shading stays anchored through close camera movement")
    quit(0)
