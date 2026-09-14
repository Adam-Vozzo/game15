extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    change_scene_to_file("res://signal.tscn")
    await process_frame
    await process_frame
    var scene: Node = current_scene
    scene.set_process(false)
    assert(scene.can_walk(scene.start),"Opening camera must be on accessible ground")
    for z in range(-63,27):
        assert(scene.can_walk(Vector3(-2.9+sin(z*.095)*2.1,0,z)),"The winding trail must remain continuous")
    for tree in scene.layout.trees:
        assert(not scene.can_walk(Vector3(tree.x,0,tree.z)),"Rooted trunks must block the walker")
    var earth: MeshInstance3D = scene.world.find_child("SignalEarth",true,false)
    var vertices: PackedVector3Array = earth.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    for i in range(0,vertices.size(),139):
        var p: Vector3 = earth.global_transform*vertices[i]
        assert(absf(p.y-scene.surface_height(p.x,p.z))<.002,"Imported terrain must match the walking sampler")
    assert(scene.pixel_mesh.mesh.get_aabb().size.y>10.,"The light cells must describe the full tree")
    var foliage: MeshInstance3D = scene.world.find_child("SignalNeedles",true,false)
    var arrays: Array = foliage.mesh.surface_get_arrays(0)
    var roots := 0.
    var tips := 0.
    var root_count := 0
    var tip_count := 0
    for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
        var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][i]
        var vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
        if uv.y>.999: roots+=vertex.y;root_count+=1
        if uv.y<.001: tips+=vertex.y;tip_count+=1
    assert(roots/root_count>tips/tip_count+.12,"Imported conifer sprays must hang down from their branch attachments")
    assert(scene.drift_mesh.extra_cull_margin>=8.,"Rising fragments must not be culled above their source bounds")
    scene.audio.play()
    await create_timer(.15).timeout
    scene.time=17.;scene.paused=true;scene._process(.03)
    assert(scene.time==17.,"Pause must freeze the clock")
    assert(scene.pixel_material.get_shader_parameter("scene_time")==17.,"Tree glitches must share Pause")
    assert(scene.drift_material.get_shader_parameter("scene_time")==17.,"Rising pixels must share Pause")
    assert(scene.audio.stream_paused,"Pause must freeze audio")
    scene.paused=false;scene._process(.03)
    assert(scene.time>17.,"Resume must advance the effect")
    await create_timer(.15).timeout
    var before: float = scene.time
    scene.camera.position=Vector3(14,2,-12);scene.walking=Vector2.ONE;scene._reset()
    assert(scene.camera.position.is_equal_approx(scene.start),"Reset must restore the opening")
    assert(scene.walking==Vector2.ZERO and scene.time==before,"Reset must clear movement and retain time")
    print("PASS: Signal Grove trail, trunk collision, imported terrain, fragment bounds, Pause/Resume and Reset")
    scene.audio.stop()
    await create_timer(.15).timeout
    quit(0)
