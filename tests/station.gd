extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
    change_scene_to_file("res://station.tscn")
    for i in range(8):await process_frame
    var s:Node=current_scene
    assert(s.experience_id=="station" and s.materials.size()>10,"Complete station must load")
    assert(s.can_walk(s.start),"Opening viewpoint must be on accessible paving")
    # A continuous route from the island via the concourse to both outer platforms.
    for x in range(-16,17):assert(s.can_walk(Vector3(x,2.85,26)),"Concourse must connect all three platforms")
    for z in range(-36,26):
        assert(s.can_walk(Vector3(0,2.85,z)),"Island's central walking route must be continuous")
        assert(s.surface_height(0,z)==1.,"Walk floor must match the paving")
    assert(not s.can_walk(Vector3(7,2.85,10)),"Flooded tracks must block walking")
    assert(not s.can_walk(Vector3(2,2.85,1.4)),"Generated root clock must have collision")
    assert(not s.can_walk(Vector3(-2.1,2.85,-25)),"Tree trunks must block walking")
    assert(not s.can_walk(Vector3(3.7,2.85,14)),"Visible edge guard must match collision")
    var train_count:=0;var clock_count:=0;var platform_top:=false;var footings:=false
    var layout:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/station_layout.json"))
    for part in s.world.find_children("*","MeshInstance3D",true,false):
        if "Hunyuan" in part.name and "train" in part.name:
            train_count+=1
            var body_hits:=0
            for surface in range(part.mesh.get_surface_count()):
                var arrays:Array=part.mesh.surface_get_arrays(surface)
                var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
                var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
                for j in range(0,indices.size(),3):
                    if Geometry3D.segment_intersects_triangle(Vector3(-3,2,0),Vector3(3,2,0),vertices[indices[j]],vertices[indices[j+1]],vertices[indices[j+2]])!=null:body_hits+=1
            assert(body_hits>=2,"Reduced Hunyuan carriage must retain both physical side panels, not only a bounding box and fragments")
            # Check actual imported roof triangles, not a shared nominal height.
            # Each fixed grass base is buried 12 mm into the uneven shell.
            var roof_body:=StaticBody3D.new()
            roof_body.collision_layer=1<<30
            var roof_shape:=CollisionShape3D.new()
            roof_shape.shape=part.mesh.create_trimesh_shape()
            roof_body.add_child(roof_shape);part.add_child(roof_body)
            roof_body.global_transform=part.global_transform
            await physics_frame
            await physics_frame
            var checked:=0
            for attachment in layout.roof_attachments:
                var origin:=Vector3(attachment.train[0],attachment.train[1],attachment.train[2])
                if part.global_position.distance_to(origin)>.1:continue
                for root_point in attachment.grass_roots+attachment.vine_roots:
                    var p:=Vector3(root_point[0],root_point[1],root_point[2])
                    var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.10,p-Vector3.UP*.10,1<<30)
                    var hit:Dictionary=part.get_world_3d().direct_space_state.intersect_ray(query)
                    assert(not hit.is_empty(),"Every roof plant base must intersect the imported carriage roof")
                    assert(absf(hit.position.y-p.y-.012)<.006,"Roof vegetation must follow the shell within six millimetres")
                    checked+=1
            assert(checked>700,"Check the substantial roof garden on each of the three carriages")
            roof_body.free()
        if "Hunyuan" in part.name and "clock" in part.name:clock_count+=1
        if part.name=="StationPaving":
            for index in range(part.mesh.get_surface_count()):
                var vertices:PackedVector3Array=part.mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX]
                for v in vertices:
                    if absf((part.global_transform*v).y-1.)<.001:platform_top=true
        if part.name=="StationStone":footings=part.get_aabb().position.y<-.9
    assert(train_count==3 and clock_count==1,"Both bespoke Hunyuan assets must be placed in the world")
    assert(platform_top and footings,"Imported platforms must have correct paving and submerged footings")
    s.paused=true
    var frozen:float=s.time
    await create_timer(.12).timeout
    assert(s.time==frozen,"Pause freezes the scene clock")
    for mat in s.materials:assert(mat.get_shader_parameter("scene_time")==frozen,"All water, plants and particles use the paused clock")
    s.camera.position=Vector3(14,2.85,24);s._reset()
    assert(s.camera.position==s.start and s.time==frozen,"Reset restores the viewpoint and retains time")
    s.resolution_slider.value=50
    await process_frame
    assert(s.reflection_view.size.x<s.view.size.x,"Reflection scales with the scene render target")
    print("PASS station: three connected platforms, imported geometry, Hunyuan assets, water/prop/guard collision, shared Pause and Reset")
    quit(0)
