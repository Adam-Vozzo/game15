extends SceneTree

func _initialize() -> void:call_deferred("run")

func run() -> void:
    change_scene_to_file("res://azure.tscn")
    for i in range(8):await process_frame
    var s:Node=current_scene
    s.set_process(false)
    assert(s.bird and s.wings.size()==2 and s.ferries.size()==4,"Imported bird, shoulder groups and ferries must be present")
    assert(s.camera.get_parent()==s.bird,"The player must travel aboard the actual bird")
    assert(s.materials.size()==11,"All source material groups, including contact foam, need their ink rendering")
    assert(s.water_effects and s.particle_materials.size()==4,"Four source-authored water particle layers must load")
    var water_data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/azure_water.json"))
    var anchor_count:=0
    for part in s.water_effects.find_children("*","MeshInstance3D",true,false):
        assert(part.material_override is ShaderMaterial,"Imported emitter batches need the particle shader")
        assert(part.extra_cull_margin>=53.,"Animated drops must remain inside their expanded visibility bounds")
        for surface in range(part.mesh.get_surface_count()):
            var arrays:Array=part.mesh.surface_get_arrays(surface)
            anchor_count+=arrays[Mesh.ARRAY_VERTEX].size()/4
    assert(anchor_count==water_data.total,"Every authored particle anchor must survive GLB import")
    # Imported waterline ribbons must remain attached to moving hulls and flat
    # on the water through a full rocking cycle, rather than hovering with it.
    for t in [0.,24.,91.,210.,840.]:
        s.time=t;s._process(0.)
        for ferry in s.ferries:
            assert(ferry.rim is MeshInstance3D,"Each source ferry needs an actual contact-foam mesh")
            for vertex in ferry.rim.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
                var p:Vector3=ferry.rim.to_global(vertex)
                assert(absf(p.y-18.055)<.015,"Ferry foam must stay on the receiving water plane")
            assert(Vector2(ferry.rim.global_position.x-ferry.node.global_position.x,ferry.rim.global_position.z-ferry.node.global_position.z).length()<.01,"Foam must follow the current ferry position")
    var period:float=s.layout.orbit.period
    assert(s.flight_position(0).distance_to(s.flight_position(period))<.001,"The orbit must close without a jump")
    # Continuous swept clearance of the full wingspan from every primary rock.
    for i in range(840):
        var p:Vector3=s.flight_position(i*period/840.)
        for rock in s.layout.rocks:
            var flat:=Vector2((p.x-float(rock.x))/float(rock.width),(p.z-float(rock.z))/float(rock.depth))
            if p.y<float(rock.base)+float(rock.height)+7:
                assert(flat.length()>1.65,"The flight must clear the surrounding cliffs")
    var roots:Array[Vector3]=[s.wings[0].position,s.wings[1].position]
    var active_beats:=0
    for i in range(780):
        var t:=i*.1
        if s.wingbeat_pose(t).length()>.001:active_beats+=1
        s.time=t;s._process(0.)
        for k in range(2):
            assert(s.wings[k].position==roots[k],"Flapping must rotate around the embedded source shoulders")
        assert(absf(s.bird.position.y-s.flight_position(t).y)<.6,"Aboard motion must stay gentle even during a power stroke")
    assert(active_beats>85 and active_beats<115,"Broad wingbeats should occupy only a small part of the glide")
    s.time=6.85;s._process(0.)
    var raised:Vector3=s.wings[1].to_global(Vector3(15.3,2.12,-4.6))-s.bird.global_position
    s.time=7.5;s._process(0.)
    var lowered:Vector3=s.wings[1].to_global(Vector3(15.3,2.12,-4.6))-s.bird.global_position
    assert(raised.y-lowered.y>10.,"A wingbeat must visibly move the full source wing, not just shader colour")
    for onset in s.WINGBEAT_STARTS:
        for knot in s.WINGBEAT_KEYS:
            var t:float=onset+knot
            assert(s.wingbeat_pose(t-.0001).distance_to(s.wingbeat_pose(t+.0001))<.0001,"Wingbeat transitions must not snap")
    assert(s.wingbeat_pose(77.999).is_equal_approx(s.wingbeat_pose(78.001)),"The idle schedule must wrap continuously")
    s.time=7.1;s._process(0.);s.paused=true
    var stroke:Array[Transform3D]=[s.bird.transform,s.wings[0].transform,s.wings[1].transform,s.traveller.transform]
    s._process(.04);s._reset();s._process(0.)
    assert(s.time==7.1 and stroke==[s.bird.transform,s.wings[0].transform,s.wings[1].transform,s.traveller.transform],"Pause and Reset must preserve a mid-stroke pose, including the rider")
    s.paused=false;s._process(.04)
    assert(stroke[1]!=s.wings[0].transform,"Resume must continue the interrupted wingbeat")
    s.following=false;s._reset();s.time=24.;s._process(0.)
    var pose:Transform3D=s.bird.transform
    var wing:Transform3D=s.wings[0].transform
    var ferry:Transform3D=s.ferries[0].node.transform
    s.paused=true;s._process(.04)
    for material in s.particle_materials:assert(material.get_shader_parameter("scene_time")==24.,"Every particle layer must follow the frozen scene clock")
    assert(s.time==24. and s.bird.transform==pose and s.wings[0].transform==wing and s.ferries[0].node.transform==ferry,"Pause must freeze flight, wings and boats")
    s._look(Vector2(150,90));s._process(.04)
    assert(s.heading!=0 and s.bird.transform==pose,"Free look must remain available during Pause")
    s._reset();s._process(0.)
    for material in s.particle_materials:assert(material.get_shader_parameter("scene_time")==24.,"Reset cannot restart particle lifetimes")
    assert(s.time==24. and s.bird.transform==pose and s.heading==0,"Reset restores the seat framing and preserves the journey clock")
    var seat:Vector3=s.camera.position
    s.view_button.pressed.emit();s._process(0.)
    assert(s.following and s.traveller.visible and s.camera.position.distance_to(seat)>15,"Follow view reveals the complete rider and bird")
    s.view_button.pressed.emit();s._process(0.)
    assert(not s.following and not s.traveller.visible and s.camera.position==seat,"Aboard view restores the seat without a head intersecting the camera")
    s.paused=false;s._process(.04)
    assert(s.bird.transform!=pose and s.wings[0].transform!=wing,"Resume advances flight and actual wing geometry")
    s.sound_on=true;s.audio.play()
    await create_timer(.2).timeout
    s.paused=true;s._process(0.)
    assert(s.audio.stream_paused,"Pause freezes the streaming ambient bed")
    s.paused=false;s._process(0.)
    await create_timer(.1).timeout
    s.audio.stop()
    await create_timer(.15).timeout
    print("PASS Azure: source hierarchy, orbit clearance, glide/occasional wingbeats, mid-stroke Pause/Reset, attached viewpoints and audio")
    quit(0)
