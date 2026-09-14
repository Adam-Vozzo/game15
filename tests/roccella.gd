extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
    change_scene_to_file("res://roccella.tscn")
    for i in range(8):await process_frame
    var s:Node=current_scene
    assert(s.layout.buildings.size()>=70,"The coast needs a fully populated town")
    for i in range(669):
        var z:=12.-i*.1
        assert(s.can_walk(Vector3(0,0,z)),"The stairs must connect both landings")
        if i>0:assert(absf(s.surface_height(0,z)-s.surface_height(0,z+.1))<.221,"No excessive step or disconnected flight")
    assert(s.surface_height(0,18)-s.surface_height(0,-54)>13.,"Route must have substantial elevation change")
    assert(not s.can_walk(Vector3(3.1,0,11)),"Stair retaining walls block walking")
    assert(not s.can_walk(Vector3(5.3,0,18)),"Belvedere parapet blocks walking")
    assert(s.can_walk(Vector3(12,0,-53)),"Lower terrace stays accessible")
    assert(s.lightning_at(7.08)>.6 and s.lightning_at(10)<.001,"Lightning briefly reveals then conceals town")
    s.sound_on=true;s.audio.play();s.thunder.play();s.paused=true
    var t:float=s.time
    s._process(.04)
    assert(s.time==t and s.audio.stream_paused and s.thunder.stream_paused,"Pause freezes weather and sound")
    s.camera.position=Vector3(0,0,-45);s._reset()
    assert(s.camera.position==s.start and s.time==t,"Reset restores view without rewinding the storm")
    for i in range(235):
        var x:=4.5+i*.1
        assert(s.can_walk(Vector3(x,0,21.5)),"The upper lookout must connect to the belvedere")
        if i>0:assert(absf(s.surface_height(x,21.5)-s.surface_height(x-.1,21.5))<.201,"Lookout stair risers must stay traversable")
    # Compare actual imported top triangles against the walking sampler.
    var tops:Array[float]=[]
    for part in s.world.find_children("*","MeshInstance3D",true,false):
        if "Paving" not in part.name:continue
        for surf in range(part.mesh.get_surface_count()):
            var arrays:Array=part.mesh.surface_get_arrays(surf)
            var verts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
            var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
            for j in range(0,indices.size(),3):
                var a:Vector3=part.global_transform*verts[indices[j]]
                var b:Vector3=part.global_transform*verts[indices[j+1]]
                var c:Vector3=part.global_transform*verts[indices[j+2]]
                var p:Vector3=(a+b+c)/3.
                if absf(a.y-b.y)<.001 and absf(b.y-c.y)<.001 and absf(p.x)<2.6 and p.z<12 and p.z> -55.2:
                    if absf(p.y-s.surface_height(p.x,p.z))<.01:tops.append(p.y)
    assert(tops.size()>=126,"Every actual imported stair tread must agree with walking height")
    # No retaining platform may intersect the occupied volume of another house.
    for b in s.layout.buildings:
        for f in s.layout.footings:
            var overlap:bool=f.x0<b.x+b.w/2 and f.x1>b.x-b.w/2 and f.z0<b.z+b.d/2 and f.z1>b.z-b.d/2
            assert(not overlap or f.y<=b.base+.01,"A terrace must not bury a building")
    assert(s.layout.piazzas.size()==7,"The descent opens into seven civic landings")
    for p in s.layout.piazzas:
        assert(s.can_walk(Vector3(5,0,(p.z0+p.z1)/2)),"Piazza must be accessible beyond the old alley")
    for g in s.layout.guards:
        var p:=Vector3((g.a[0]+g.b[0])/2,0,(g.a[1]+g.b[1])/2)
        assert(not s.can_walk(p),"Visible guards must block movement")
    # Terrain triangles from the exported GLB must stay below every house floor.
    var checked:=0
    for part in s.world.find_children("*","MeshInstance3D",true,false):
        if "Rock" not in part.name:continue
        for surf in range(part.mesh.get_surface_count()):
            var arrays:Array=part.mesh.surface_get_arrays(surf)
            var verts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
            for v in verts:
                var p:Vector3=part.global_transform*v
                for b in s.layout.buildings:
                    if absf(p.x-b.x)<=b.w/2+1 and absf(p.z-b.z)<=b.d/2+1:
                        assert(p.y<b.base-.1,"Imported hillside cannot clip through a doorway or wall")
                        checked+=1
    assert(checked>1000,"Terrain check must cover the actual town mesh")
    s.set_process(false)
    s.paused=false
    s._sync_audio_pause(s.audio);s._sync_audio_pause(s.thunder)
    s.audio.stop();s.thunder.stop()
    s.audio.stream=null;s.thunder.stream=null
    await create_timer(.35).timeout
    print("PASS La Burrasca: populated town, connected 13m descent, imported stair heights, collision, lightning, Pause and Reset")
    quit(0)
