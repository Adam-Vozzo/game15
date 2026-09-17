extends SceneTree

func _initialize() -> void:call_deferred("run")

func capture(label:String) -> Image:
    for i in range(3):await process_frame
    await RenderingServer.frame_post_draw
    var img:Image=current_scene.view.get_texture().get_image()
    img.save_png("res://build-logs/azure-foam-"+label+".png")
    return img

func difference(a:Image,b:Image) -> float:
    var total:=0.
    for y in range(0,a.get_height(),3):
        for x in range(0,a.get_width(),3):
            var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
            total+=absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)
    return total/(a.get_width()*a.get_height()/9.)

func run() -> void:
    change_scene_to_file("res://azure.tscn")
    for i in range(10):await process_frame
    var s:Node=current_scene
    s.set_process(false);s.paused=true;s.review_camera=true
    s.camera.reparent(s.world)
    s.camera.global_position=Vector3(37,12,85);s.camera.look_at(Vector3(-16,-22,9))
    s.time=11.;s._process(0.)
    var a:=await capture("main")
    s._process(.1)
    assert(difference(a,await capture("paused"))<.00001,"Foam, particles and colour must freeze on Pause")
    # Freeze all other animation, so this comparison can only show foam motion.
    for material in s.materials:
        if material.get_shader_parameter("kind")==4 or material.get_shader_parameter("foam")==true:
            material.set_shader_parameter("scene_time",12.4)
    var b:=await capture("main-moving")
    assert(difference(a,b)>.003,"Whitewater motion must be visible with everything else frozen")
    # Solid white on black proves that geometry really changes its silhouette;
    # moving shader marks or particles cannot satisfy this test.
    var shapes:Array[MeshInstance3D]=[]
    var visibility:Array[bool]=[]
    var foam:MeshInstance3D
    for node in s.world.find_children("*","MeshInstance3D",true,false):
        shapes.append(node);visibility.append(node.visible)
        if str(node.name)=="AzureWorldFoam":foam=node
        node.visible=node==foam
    assert(foam,"The connected source foam mesh must be present")
    var env:WorldEnvironment=s.world.find_children("*","WorldEnvironment",true,false)[0]
    var saved_env:Environment=env.environment
    env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
    env.environment.background_color=Color.BLACK
    var solid:=ShaderMaterial.new();var shader:=Shader.new()
    shader.code="shader_type spatial; render_mode unshaded,cull_disabled; uniform float scene_time=0.;\n#include \"res://shaders/azure_foam_motion.gdshaderinc\"\nvoid vertex(){VERTEX=azure_foam_position(VERTEX,NORMAL,UV,scene_time);}\nvoid fragment(){ALBEDO=vec3(1.);}\n"
    solid.shader=shader;foam.material_override=solid
    for view_name in ["main","upper"]:
        if view_name=="upper":
            s.camera.global_position=Vector3(-13,37,-99);s.camera.look_at(Vector3(-113,22,-138))
        solid.set_shader_parameter("scene_time",11.)
        a=await capture(view_name+"-silhouette-a")
        solid.set_shader_parameter("scene_time",12.4)
        b=await capture(view_name+"-silhouette-b")
        var change:=difference(a,b)
        print("FOAM_SILHOUETTE_",view_name,": ",change)
        assert(change>.004,"Both banks need clearly evolving geometry")
    foam.material_override=null;env.environment=saved_env
    for i in range(shapes.size()):shapes[i].visible=visibility[i]
    for t in [11.,11.5,12.,12.5,13.,13.5]:
        s.time=t;s._process(0.)
        await capture("upper-%d"%int(t*10))
    s.camera.global_position=Vector3(2,133,-49);s.camera.look_at(Vector3(-142,40,-173))
    await capture("high-canyon")
    s.camera.global_position=Vector3(0,75,35);s.camera.look_at(Vector3(-40,137,-160))
    await capture("sky")
    s.camera.look_at(s.camera.global_position+Vector3(-.55,.72,.36)*200.)
    await capture("sun")
    if "--foam-reel" in OS.get_cmdline_user_args():
        s.camera.global_position=Vector3(37,12,85);s.camera.look_at(Vector3(-16,-22,9))
        for i in range(96):
            s.time=11.+i/12.;s._process(0.)
            await capture("reel-%03d"%i)
    s.camera.reparent(s.bird);s.review_camera=false;s.following=true;s._reset()
    for t in [0.,35.,70.,105.,140.,175.]:
        s.time=t;s._process(0.)
        await capture("flight-%d"%int(t))
    root.size=Vector2i(390,844)
    for i in range(10):await process_frame
    await capture("portrait")
    print("PASS Azure foam: visible shape motion at both falls, isolated motion, frozen Pause, sunny sky and aerial colour review")
    quit(0)
