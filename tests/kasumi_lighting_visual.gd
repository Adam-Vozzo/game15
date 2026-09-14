extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func settle() -> void:
    for i in range(8):await process_frame
    await RenderingServer.frame_post_draw

func run() -> void:
    change_scene_to_file("res://town.tscn")
    await process_frame
    await process_frame
    var town: Node=current_scene
    town.paused=true
    var materials: Array[ShaderMaterial]=[]
    for node in town.world.find_children("*","MeshInstance3D",true,false):
        for i in range(node.mesh.get_surface_count()):
            var mat=node.get_active_material(i)
            if mat is ShaderMaterial and mat.shader.resource_path.ends_with("kasumi_surface.gdshader") and not materials.has(mat):materials.append(mat)
    for view in ["lamplight","opening","crossing","loop-north","roofs"]:
        if view=="opening":town._reset()
        else:town._composition(view)
        town.heading=town.target_heading;town.pitch=town.target_pitch
        await settle()
        var lit: Image=town.view.get_texture().get_image()
        lit.save_png("res://build-logs/kasumi-light-%s.png"%view)
        if view!="lamplight":continue
        for mat in materials:mat.set_shader_parameter("light_spill",0.)
        await settle()
        var dark: Image=town.view.get_texture().get_image()
        dark.save_png("res://build-logs/kasumi-light-disabled.png")
        var changed:=0
        for y in range(lit.get_height()):
            for x in range(lit.get_width()):
                var a:=lit.get_pixel(x,y);var b:=dark.get_pixel(x,y)
                if b.r<.45 and a.r-b.r>.035 and a.r-b.r>(a.b-b.b)*1.5:changed+=1
        print("Warm spill pixels on non-emissive surfaces: ",changed)
        assert(changed>lit.get_width()*lit.get_height()*.02,"Warm light must visibly illuminate nearby surfaces, not just the emitting meshes")
        for mat in materials:mat.set_shader_parameter("light_spill",1.)
    print("PASS: native Kasumi warm light spill and multi-angle captures")
    quit(0)
