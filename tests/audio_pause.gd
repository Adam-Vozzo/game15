extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    for id in ["laundry","signal","painted","reservoir","roccella"]:
        change_scene_to_file("res://"+id+".tscn")
        for i in range(6):await process_frame
        var scene:Node=current_scene
        scene.sound_on=true
        scene.audio.play()
        await create_timer(.25).timeout
        var playing_position:float=scene.audio.get_playback_position()
        assert(playing_position>.10,"Audio must advance normally under scene updates")
        scene.paused=true
        await create_timer(.10).timeout
        assert(scene.audio.stream_paused,"Scene Pause must pause active playback")
        var frozen_position:float=scene.audio.get_playback_position()
        await create_timer(.20).timeout
        assert(absf(scene.audio.get_playback_position()-frozen_position)<.03,"Pause must freeze audio position")
        scene.paused=false
        await create_timer(.25).timeout
        assert(scene.audio.get_playback_position()>frozen_position+.10,"Resume must continue from the paused position")
        # Sound can be enabled while the environment is already paused.
        scene.audio.stop();scene.paused=true
        await process_frame
        scene.audio.play()
        await create_timer(.10).timeout
        assert(scene.audio.stream_paused,"A newly started player must inherit scene Pause")
        scene.paused=false
        await create_timer(.20).timeout
        assert(not scene.audio.stream_paused and scene.audio.get_playback_position()>.05,"Sound started during Pause must resume")
        # Exercise a real loop boundary; restarting the environment must not
        # rewind either the audio or scene clock.
        scene.audio.play(scene.audio.stream.get_length()-.12)
        await create_timer(.38).timeout
        assert(scene.audio.playing and scene.audio.get_playback_position()<1.,"Ambient audio must survive looping")
        var position_before:float=scene.audio.get_playback_position()
        scene._reset()
        assert(scene.audio.get_playback_position()>=position_before-.01,"View Reset must not rewind sound")
        scene.audio.stop()
        if id=="roccella":scene.thunder.stop()
        await create_timer(.15).timeout
        print("PASS audio lifecycle: ",id," advancement, Pause, Resume, sound-on during Pause, loop and Reset")
    quit(0)
