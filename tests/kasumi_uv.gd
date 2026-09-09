extends SceneTree
# Compare the same surface points under three actual perspective camera poses.
# A diagnostic gradient makes camera-dependent UV drift measurable without fog.
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
            atlas.set_pixel(x,y,Color(.15+.7*float(x%128)/127.,.15+.7*float(y%128)/127.,.4))
    var material := ShaderMaterial.new()
    material.shader=load("res://shaders/kasumi_surface.gdshader")
    material.set_shader_parameter("atlas",ImageTexture.create_from_image(atlas))
    material.set_shader_parameter("tile",1)
    var wall := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size=Vector2(4,4)
    wall.mesh=quad
    wall.material_override=material
    viewport.add_child(wall)
    var camera := Camera3D.new()
    viewport.add_child(camera)
    camera.current=true
    var baseline: Array[Color]=[]
    var maximum_error := 0.0
    for pose in [Vector3(0,0,6),Vector3(3,.5,5),Vector3(-2,-.3,4.5)]:
        camera.position=pose
        camera.look_at(Vector3.ZERO)
        for i in range(4): await process_frame
        await RenderingServer.frame_post_draw
        var rendered := viewport.get_texture().get_image()
        var index := 0
        for y in [-.8,0.,.8]:
            for x in [-.8,0.,.8]:
                var screen := camera.unproject_position(Vector3(x,y,0))
                var color := rendered.get_pixel(int(screen.x),int(screen.y))
                if baseline.size()<9:
                    baseline.append(color)
                else:
                    var first := baseline[index]
                    maximum_error=maxf(maximum_error,maxf(absf(first.r-color.r),absf(first.g-color.g)))
                index+=1
    print("UV camera-motion maximum color drift: ",maximum_error)
    if maximum_error>.018 or baseline[0].r<.02:
        push_error("Architectural UVs drift with camera position or angle")
        quit(1)
        return
    print("PASS: architectural surface coordinates stay fixed through translation and rotation")
    quit(0)
