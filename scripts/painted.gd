extends "res://scripts/main.gd"

var layout: Dictionary
var painted_materials: Array[ShaderMaterial] = []
var bubbles: Array[Dictionary] = []
var flamingos: Array[Dictionary] = []
var dragonflies: Array[Dictionary] = []
var bleed_material: ShaderMaterial

func _ready() -> void:
    experience_id = "painted"
    bounds = Vector4(-5.2,5.2,-36.6,13.7)
    layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/painted_layout.json"))
    super._ready()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--painted-time="): time=float(argument.trim_prefix("--painted-time="))

func surface_height(x: float,z: float) -> float:
    return .46 if Vector2(x,z+31.7).length()<5.18 else .45

func can_walk(point: Vector3) -> bool:
    # The camera stays on the continuous deck and can enter through the door.
    for rect in layout.walkways:
        if point.x>=rect[0]+.22 and point.x<=rect[1]-.22 and point.z>=rect[2]+.22 and point.z<=rect[3]-.22:
            if point.x>2.0 and point.x<5.0 and point.z> -23.95 and point.z< -22.65: return false
            if point.z< -26.1 and absf(point.x)>.80: return false
            return true
    if point.z< -26.1:
        var radial := Vector2(point.x,point.z+31.7).length()
        if radial<4.88:
            if point.z> -27.3 and absf(point.x)>.80: return false
            return true
    return false

func _create_view() -> void:
    super._create_view()
    view.msaa_3d = Viewport.MSAA_2X
    for child in get_children():
        if child is TextureRect: child.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR

func _create_environment() -> void:
    world.name="ThePaintedMere"
    var env := WorldEnvironment.new()
    env.environment=Environment.new()
    env.environment.background_mode=Environment.BG_COLOR
    env.environment.background_color=Color(1,.995,1)
    world.add_child(env)
    var art := load("res://assets/models/painted_mere.glb").instantiate() as Node3D
    world.add_child(art)
    var kinds := ["Wash","Ink","Water","Leaf","Petal","Sun","Bleed","Bird","Pad","Timber"]
    for kind in range(kinds.size()):
        var material := ShaderMaterial.new()
        material.shader=load("res://shaders/painted_surface.gdshader")
        material.set_shader_parameter("kind",kind)
        material.set_shader_parameter("paper",load("res://assets/textures/PaintedPaper.png"))
        if kind==2:
            var centers := PackedVector3Array()
            for flower in layout.lotus: centers.append(Vector3(flower[0],flower[1],flower[2]))
            material.set_shader_parameter("lotus_centers",centers)
        if kind==3:
            material.shader=load("res://shaders/painted_crown.gdshader")
            material.set_shader_parameter("paper",load("res://assets/textures/PaintedPaper.png"))
            var outline := ShaderMaterial.new()
            outline.shader=load("res://shaders/painted_outline.gdshader")
            material.next_pass=outline
        if kind==6:
            material.shader=load("res://shaders/painted_bleed.gdshader")
            material.set_shader_parameter("paper",load("res://assets/textures/PaintedPaper.png"))
            bleed_material=material
        if kind==7:
            material.set_shader_parameter("kind",4)
            material.set_shader_parameter("local_pigment",true)
            var outline := ShaderMaterial.new()
            outline.shader=load("res://shaders/painted_bird_outline.gdshader")
            material.next_pass=outline
        painted_materials.append(material)
    for part in art.find_children("*","MeshInstance3D",true,false):
        for i in range(part.mesh.get_surface_count()):
            var original: Material=part.mesh.surface_get_material(i)
            for kind in range(kinds.size()):
                if kinds[kind] in original.resource_name:
                    part.set_surface_override_material(i,painted_materials[kind])
                    break
        if str(part.name).begins_with("Bubble"):
            bubbles.append({"mesh":part,"origin":part.position,"phase":float(bubbles.size())*.173})
            part.extra_cull_margin=4.0
    for record in layout.flamingos:
        var bird := art.find_child(record.name,true,false) as Node3D
        var neck := bird.find_child(record.name+"_neck",true,false) as Node3D
        var shapes: Array[Dictionary] = []
        for part in neck.find_children("*","MeshInstance3D",true,false):
            var indices: Dictionary = {}
            for i in range(part.mesh.get_blend_shape_count()):
                indices[str(part.mesh.get_blend_shape_name(i))]=i
            if indices.has("Feed"):
                shapes.append({"mesh":part,"index":indices.Feed,"stages":[indices.Feed_25,indices.Feed_50,indices.Feed_75,indices.Feed]})
        flamingos.append({"root":bird,"neck":neck,"shapes":shapes,"index":flamingos.size(),"origin":bird.transform})
    for record in layout.dragonflies:
        var fly := art.find_child(record.name,true,false) as Node3D
        var wings: Array[Node3D] = []
        for i in range(4):wings.append(fly.find_child(record.name+"_wing_%d"%i,true,false))
        dragonflies.append({"root":fly,"origin":fly.position,"phase":float(record.phase),"wings":wings})

func _create_vegetation() -> void:
    pass

func _create_interface() -> void:
    super._create_interface()
    # The shared light HUD needs dark ink against this channel's paper white.
    for button in [menu_button,settings_button]:
        for state in ["font_color","font_hover_color","font_pressed_color","icon_normal_color","icon_hover_color","icon_pressed_color"]:
            button.add_theme_color_override(state,Color(.28,.22,.36))
    for button in controls.get_children():
        if not button is Button:continue
        for state in ["font_color","font_hover_color","font_pressed_color"]:
            button.add_theme_color_override(state,Color(.28,.22,.36))
        var paper_style := StyleBoxFlat.new()
        paper_style.bg_color=Color(.99,.97,1,.94)
        paper_style.border_color=Color(.47,.38,.57,.6)
        paper_style.set_border_width_all(1)
        paper_style.content_margin_left=14;paper_style.content_margin_right=14
        button.add_theme_stylebox_override("normal",paper_style)
        var hover: StyleBoxFlat=paper_style.duplicate()
        hover.bg_color=Color(.88,.82,.95,.97)
        button.add_theme_stylebox_override("hover",hover)
        button.add_theme_stylebox_override("pressed",hover)
    var resolution_paper := StyleBoxFlat.new()
    resolution_paper.bg_color=Color(.99,.97,1,.94)
    resolution_paper.set_content_margin_all(10)
    resolution_panel.add_theme_stylebox_override("panel",resolution_paper)
    resolution_label.add_theme_color_override("font_color",Color(.28,.22,.36))

func _create_camera() -> void:
    super._create_camera()
    camera.far=200
    start=Vector3(.45,2.30,11.8)
    camera.position=start
    heading=.035;pitch=-.055
    mist.shader=load("res://shaders/painted_passthrough.gdshader")
    camera.get_child(0).hide() # Surface fog includes transparent pigment; no screen composite required.
    for arg in OS.get_cmdline_user_args():
        if arg=="--view=lotus": camera.position=Vector3(-1.1,2.3,7.8);heading=.93;pitch=-.28
        if arg=="--view=landing": camera.position=Vector3(0,2.3,-18);heading=0;pitch=.20
        if arg=="--view=reverse": camera.position=Vector3(0,2.3,-23);heading=PI;pitch=-.08
        if arg=="--view=inside": camera.position=Vector3(0,2.3,-32);heading=2.9;pitch=.42
        if arg=="--view=under": camera.position=Vector3(-3,.02,7);heading=-.95;pitch=.20
        if arg=="--view=canopy": camera.position=Vector3(0,2.3,0);heading=-1.30;pitch=.70
        if arg=="--view=flamingos": camera.position=Vector3(-1.25,2.3,-.5);heading=.95;pitch=-.16
        if arg=="--view=flamingos-reverse": camera.position=Vector3(-1.25,2.3,-10);heading=2.35;pitch=-.13
    target_heading=heading;target_pitch=pitch

func _create_audio() -> void:
    super._create_audio()
    audio.stop()
    var stream: AudioStreamWAV=load("res://assets/audio/painted_mere.wav")
    stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
    stream.loop_end=int(stream.get_length()*stream.mix_rate)
    audio.stream=stream
    audio.volume_db=-6
    if sound_on: audio.play()

func _render_budget() -> Vector2:
    # Fine ink needs more samples than the other channels' pixel treatment.
    return Vector2(840,840) if mobile else Vector2(1440,1000)

func _resize() -> void:
    super._resize()
    var screen := get_viewport().get_visible_rect().size
    camera.fov=58 if screen.x<screen.y else 61

func _reset() -> void:
    super._reset()
    heading=.035;target_heading=heading
    pitch=-.055;target_pitch=pitch
    camera.rotation=Vector3(pitch,heading,0)

func _process(delta: float) -> void:
    super._process(delta)
    for material in painted_materials: material.set_shader_parameter("scene_time",time)
    for bubble in bubbles:
        var phase: float=fposmod(time*.09+bubble.phase,1.0)
        bubble.mesh.position=bubble.origin+Vector3(sin(time*.4+bubble.phase)*.12,phase*2.7,0)
        bubble.mesh.scale=Vector3.ONE*sin(phase*PI)
    _animate_flamingos(time)
    _animate_dragonflies(time)
    _sync_audio_pause(audio)

func _animate_flamingos(at_time: float) -> void:
    for bird in flamingos:
        var index: float=bird.index
        var look: float=fposmod(at_time-5.-index*1.7,27.+index*1.13)
        var envelope: float=pow(sin(PI*look/7.),2.) if look<7. else 0.
        var feeding: float=fposmod(at_time-17.-index*9.7,88.+index*4.13)
        var dip: float=smoothstep(0.,2.5,feeding)*(1.-smoothstep(5.2,8.8,feeding)) if feeding<8.8 else 0.
        # Short glances, long still intervals, and a rare smooth feeding reach.
        # The two authored morphs keep the face/ink aligned with the bent neck.
        bird.neck.rotation=Vector3(0,sin(look*.75-1.)*.35*envelope*(1.-dip),sin(look)*.055*envelope*(1.-dip))
        for shape in bird.shapes:
            for stage in shape.stages:shape.mesh.set_blend_shape_value(stage,0.)
            var segment: int=mini(int(dip*4.),3)
            var blend: float=dip*4.-segment
            if segment>0:shape.mesh.set_blend_shape_value(shape.stages[segment-1],1.-blend)
            shape.mesh.set_blend_shape_value(shape.stages[segment],blend)

func _animate_dragonflies(at_time: float) -> void:
    for fly in dragonflies:
        var t: float=fposmod(at_time+fly.phase,24.)
        var flight: float=smoothstep(3.,5.,t)*(1.-smoothstep(18.,22.,t))
        fly.root.position=fly.origin+Vector3(sin(t*.67)*.72,.12+sin(t*.91)*.15,cos(t*.67)*.45)*flight
        fly.root.rotation.y=sin(t*.35)*.8*flight
        for i in range(4):
            fly.wings[i].rotation.x=sin(at_time*38.+i*.7)*.26*flight*(1. if i%2==0 else -1.)
