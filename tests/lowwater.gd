extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    change_scene_to_file("res://lowwater.tscn")
    await process_frame
    await process_frame
    var scene: Node = current_scene
    # Verify actual imported glTF V orientation, rather than assuming Blender UVs
    # survive unchanged: root UV=1 must be above the trailing UV=0 vertices.
    for name in ["LowwaterIvy","LowwaterMoss"]:
        var part: MeshInstance3D = scene.world.find_child(name,true,false)
        var arrays: Array = part.mesh.surface_get_arrays(0)
        var roots := 0.
        var tips := 0.
        var root_count := 0
        var tip_count := 0
        for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
            var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][i]
            var vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
            if uv.y>.999:
                roots+=vertex.y;root_count+=1
            if uv.y<.001:
                tips+=vertex.y;tip_count+=1
        assert(root_count>0 and tip_count>0,"Botanical mesh must contain both attachment and tip UVs")
        assert(roots/root_count>tips/tip_count+.20,"Ivy and moss must descend from their stem attachments")
    var moss_image: Image = load("res://assets/textures/LowwaterMoss.png").get_image()
    if moss_image.is_compressed(): moss_image.decompress()
    var root_coverage := 0.
    var tip_coverage := 0.
    for x in range(256):
        root_coverage+=moss_image.get_pixel(x,250).a
        tip_coverage+=moss_image.get_pixel(x,5).a
    assert(root_coverage>15. and tip_coverage<root_coverage*.15,"Moss texture must taper out at its loose lower end")
    assert(scene.reflection_view.find_world_3d()==scene.view.find_world_3d(),"Reflection must share the scene world")
    assert(scene.can_walk(scene.start),"Opening view must be on the walkable bank")
    for z in range(-85,30):
        assert(not scene.can_walk(Vector3(scene.canal_center(z),0,z)),"Water must block walking")
        assert(scene.can_walk(Vector3(scene.canal_center(z)+4.9,0,z)),"Right bank needs a continuous walking route")
    for tree in scene.layout.trees:
        assert(not scene.can_walk(Vector3(tree.x,0,tree.z)),"Imported trunks must block walking")
    # Inspect imported ground triangles independently against the runtime sampler.
    var earth: MeshInstance3D = scene.world.find_child("LowwaterEarth",true,false)
    assert(earth!=null,"Blender terrain must be loaded")
    var vertices: PackedVector3Array = earth.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    for i in range(0,vertices.size(),137):
        var p: Vector3 = earth.global_transform*vertices[i]
        assert(absf(p.y-scene.surface_height(p.x,p.z))<.002,"Walking height must match generated terrain vertices")
    scene.time=17.
    scene.paused=true
    scene._process(.03)
    assert(is_equal_approx(scene.reflection_camera.position.y,-.24-scene.camera.position.y),"Reflection camera must mirror the eye about the water")
    assert(scene.time==17.,"Pause must freeze the shared scene clock")
    assert(scene.water_material.get_shader_parameter("scene_time")==17.,"Water must share pause time")
    assert(scene.mist.get_shader_parameter("atmosphere_time")==17.,"Mist must share pause time")
    for material in scene.landscape_materials:
        assert(material.get_shader_parameter("scene_time")==17.,"Moss must share pause time")
    scene.paused=false
    scene._process(.03)
    assert(scene.time>17.,"Resume must continue animation")
    scene.camera.position=Vector3(8,3,-40)
    scene.walking=Vector2.ONE
    scene._reset()
    assert(scene.camera.position.is_equal_approx(scene.start),"Reset returns to the opening bank")
    assert(scene.walking==Vector2.ZERO and is_equal_approx(scene.heading,.16),"Reset clears walking and restores framing")
    print("PASS: Lowwater downward ivy/moss UVs, tapered tips, bank route, collision, Blender heights, pause/resume and reset")
    quit(0)
