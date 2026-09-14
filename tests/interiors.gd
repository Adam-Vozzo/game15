extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    for id in ["laundry","reservoir"]:
        change_scene_to_file("res://"+id+".tscn")
        await process_frame
        await process_frame
        var scene: Node = current_scene
        assert(scene.experience_id==id and scene.can_walk(scene.start),"Channel starts on a valid walking surface")
        if id=="laundry":
            assert(scene.drums.size()==5 and scene.dryers.size()==5 and scene.cars.size()==2,"All authored moving pieces must import")
            for node in scene.art.find_children("*","MeshInstance3D",true,false):
                if not (str(node.name).begins_with("WasherFabric") or str(node.name).begins_with("Dryer")):continue
                for p in node.mesh.get_faces():
                    assert((node.global_transform*p).x< -4.65,"Every cloth fold stays behind the cabinet face and door glass")
            # A ray through the centre of each opening must reach the rear shell.
            # The former closed cabinet face made a physically inset load invisible.
            for y in [.75,2.40]:
                var origin := Vector3(-4.,y,-3.65)
                var nearest := 9.
                for name in ["Enamel","Metal","Dark"]:
                    var shell: MeshInstance3D = scene.art.find_child(name,true,false)
                    var faces := shell.mesh.get_faces()
                    for i in range(0,faces.size(),3):
                        var hit = Geometry3D.ray_intersects_triangle(origin,Vector3.LEFT,shell.global_transform*faces[i],shell.global_transform*faces[i+1],shell.global_transform*faces[i+2])
                        if hit!=null:nearest=minf(nearest,origin.distance_to(hit))
                assert(nearest>.90,"Washer and dryer shells need real open apertures")
            for p in [Vector3(-5,0,0),Vector3(0,0,-5),Vector3(5.2,0,1),Vector3(0,0,5.3)]:
                assert(not scene.can_walk(p),"Machines, windows, benches and counters block the camera")
            assert(not scene.can_walk(Vector3(.4,0,2.8)),"New folding island blocks walking")
            scene.time=25.;scene._animate()
            var parked: Transform3D = scene.cars[0].transform
            scene.time=35.;scene._animate()
            assert(scene.cars[0].transform.is_equal_approx(parked),"Car remains parked during dwell")
            scene.time=46.;scene._animate()
            assert(not scene.cars[0].transform.is_equal_approx(parked),"Car reverses out before departing")
        else:
            assert(scene.layout.columns.size()==70,"Full column rows must load")
            for row in scene.art.find_children("ColumnRow*","MeshInstance3D",true,false):
                var arrays: Array = row.mesh.surface_get_arrays(0)
                var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
                for index in range(positions.size()):
                    var p: Vector3 = row.global_transform*positions[index]
                    assert(not (absf(p.y)<.01 and absf(normals[index].y)>.9),"No horizontal column footing face may coincide with water")
            assert(scene.art.find_child("OutletStream",true,false)!=null and scene.art.find_child("OutletSplash",true,false)!=null,"Drain outlet has connected flow and impact spray")
            for z in range(-150,25): assert(scene.can_walk(Vector3(0,0,z)),"Main causeway is continuous")
            for x in range(0,35):
                assert(scene.can_walk(Vector3(x,0,-34)),"First crossway connects")
                assert(scene.can_walk(Vector3(x,0,-90)),"Second crossway connects")
            for z in range(-90,-33):assert(scene.can_walk(Vector3(34,0,z)),"Return causeway connects both branches")
            assert(not scene.can_walk(Vector3(6,0,-20)),"Water blocks walking")
            assert(scene.reflection_view.find_world_3d()==scene.view.find_world_3d(),"Reflection shares its scene world")
            var causeway: MeshInstance3D = scene.art.find_child("Causeways",true,false)
            var points: PackedVector3Array = causeway.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
            var top := -100.
            for p in points:top=maxf(top,(causeway.global_transform*p).y)
            assert(absf(top-scene.surface_height(0,0))<.003,"Imported walkable slab matches eye-height sampler")
        scene.paused=true;scene.time=17.;scene._process(.02)
        assert(scene.time==17.,"Pause freezes scene time")
        for material in scene.materials:assert(material.get_shader_parameter("scene_time")==17.,"All moving materials share Pause")
        if id=="laundry":
            var before: Transform3D = scene.cars[0].transform
            var drum_before: Transform3D = scene.drums[0].transform
            var dryer_before: Transform3D = scene.dryers[0].transform
            scene._process(.04)
            assert(scene.cars[0].transform==before and scene.drums[0].transform==drum_before,"Pause freezes cars and drums")
            assert(scene.dryers[0].transform==dryer_before,"Pause freezes upper dryer loads")
        else:
            assert(is_equal_approx(scene.reflection_camera.position.y,-scene.camera.position.y),"Reflection mirrors the camera around the water")
        scene.camera.position=Vector3(0,4,-20);scene.walking=Vector2.ONE;scene._reset()
        assert(scene.camera.position.is_equal_approx(scene.start) and scene.walking==Vector2.ZERO,"Reset restores the opening and clears input")
        scene.paused=false;scene._process(.02)
        assert(scene.time>17.,"Resume continues the scene clock")
        print("PASS interior: ",id," source geometry, connected routes, collision, animation cycles, Pause and Reset")
    quit(0)
