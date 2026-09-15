extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
    change_scene_to_file("res://station.tscn")
    for i in range(10):await process_frame
    var s:Node=current_scene;s.paused=true
    assert(s.residents.size()==3,"Three independently phased pond spirits must inhabit the station")
    for i in range(3):
        var resident:Node3D=s.residents[i]
        var player:AnimationPlayer=s.resident_players[i]
        for clip in ["SpiritIdle","SpiritLook","SpiritWave","SpiritDoze"]:
            assert(player.has_animation(clip),"Imported Blender rig must retain every authored action")
        var skeleton:=resident.find_child("Skeleton3D",true,false) as Skeleton3D
        assert(skeleton!=null and skeleton.get_bone_count()==12,"Imported creature must have the complete skinning rig")
        assert(absf(resident.position.y-s.surface_height(resident.position.x,resident.position.z))<.001,"Creature feet must begin on the visible platform")
        assert(not s.can_walk(resident.position),"Walking must respect resident space")
    var rig:=s.residents[0].find_child("Skeleton3D",true,false) as Skeleton3D
    s.time=0.;s._update_residents()
    for i in range(2):await process_frame
    var foot:Transform3D=rig.get_bone_global_pose(rig.find_bone("Foot.L"))
    var hand:Transform3D=rig.get_bone_global_pose(rig.find_bone("Hand.L"))
    s.time=26.5;s._update_residents()
    for i in range(2):await process_frame
    assert(s.resident_players[0].current_animation=="SpiritWave","Gesture schedule must select the wave")
    assert(not hand.is_equal_approx(rig.get_bone_global_pose(rig.find_bone("Hand.L"))),"Wave must actually deform the armature")
    assert(foot.is_equal_approx(rig.get_bone_global_pose(rig.find_bone("Foot.L"))),"Waving must keep feet planted")
    var frozen:Transform3D=rig.get_bone_global_pose(rig.find_bone("Hand.L"))
    await create_timer(.15).timeout
    assert(frozen.is_equal_approx(rig.get_bone_global_pose(rig.find_bone("Hand.L"))),"Pause must freeze the creature's actual pose")
    s._reset()
    for i in range(2):await process_frame
    assert(s.time==26.5 and frozen.is_equal_approx(rig.get_bone_global_pose(rig.find_bone("Hand.L"))),"Reset keeps creature time and pose")
    s.time=40.;s._update_residents()
    for i in range(2):await process_frame
    var eye:int=rig.find_bone("Eye.L")
    var lid:Vector3=rig.get_bone_pose_scale(eye)
    assert(minf(lid.x,minf(lid.y,lid.z))<.15,"Dozing must close the independently rigged eyes")
    print("PASS station creatures: four imported actions, skin deformation, grounded feet, independent residents, collision, Pause and Reset")
    quit(0)
