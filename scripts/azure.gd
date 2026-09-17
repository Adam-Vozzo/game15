extends "res://scripts/main.gd"

var layout: Dictionary
var bird: Node3D
var traveller: Node3D
var companion: Node3D
var wings: Array[Node3D] = []
var ferries: Array[Dictionary] = []
var materials: Array[ShaderMaterial] = []
var water_effects: Node3D
var particle_materials: Array[ShaderMaterial] = []
var following := true
var view_button: Button
var review_camera := false
const OPEN_PITCH := -.24
const FOLLOW_HEADING := -1.12
const WINGBEAT_CYCLE := 78.
const WINGBEAT_STARTS := [6.,28.,53.]
const WINGBEAT_KEYS := [0.,.85,1.5,2.25,3.4]
# Shoulder lift, sweep and feather pitch. The downstroke is quicker than the
# gathering upstroke; a long recovery lets this broad-winged bird coast.
const WINGBEAT_POSES := [Vector3.ZERO,Vector3(.46,.025,.06),Vector3(-.42,-.02,-.035),Vector3(-.14,-.012,-.015),Vector3.ZERO]

func _ready() -> void:
    experience_id="azure"
    layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/azure_layout.json"))
    super._ready()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--azure-time="):time=float(arg.trim_prefix("--azure-time="))
        if arg=="--view=aboard":following=false;_reset()
    _animate_world()
    _update_camera()

func _create_view() -> void:
    super._create_view()
    view.msaa_3d=Viewport.MSAA_2X
    for child in get_children():
        if child is TextureRect:child.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR

func _render_budget() -> Vector2:
    return Vector2(840,640) if mobile else Vector2(1440,960)

func _create_environment() -> void:
    world.name="AzurePilgrimage"
    var env:=WorldEnvironment.new()
    env.environment=Environment.new()
    env.environment.background_mode=Environment.BG_SKY
    env.environment.sky=Sky.new()
    var sky_material:=ShaderMaterial.new()
    sky_material.shader=load("res://shaders/azure_sky.gdshader")
    env.environment.sky.sky_material=sky_material
    world.add_child(env)
    var art:=load("res://assets/models/azure_pilgrimage.glb").instantiate() as Node3D
    world.add_child(art)
    var names:=["Colour","Ink","Water","Falls","Foam","Bird","BirdInk","Rim"]
    for kind in range(names.size()):
        var material:=ShaderMaterial.new()
        material.shader=load("res://shaders/azure_shore.gdshader") if kind==7 else load("res://shaders/azure_surface.gdshader")
        if kind!=7:material.set_shader_parameter("kind",kind)
        if kind in [0,4,5]:
            var outline:=ShaderMaterial.new()
            outline.shader=load("res://shaders/azure_outline.gdshader")
            outline.set_shader_parameter("thickness",.018 if kind==5 else .105)
            outline.set_shader_parameter("foam",kind==4)
            material.next_pass=outline
            materials.append(outline)
        materials.append(material)
        for part in art.find_children("*","MeshInstance3D",true,false):
            for i in range(part.mesh.get_surface_count()):
                var original:Material=part.mesh.surface_get_material(i)
                if original and original.resource_name=="Azure"+names[kind]:
                    part.set_surface_override_material(i,material)
                    if kind==4:part.extra_cull_margin=3.0
                    part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    bird=art.find_child("GreatWhiteBird",true,false)
    traveller=bird.find_child("Traveller",true,false)
    companion=art.find_child("SmallCompanion",true,false)
    for name in layout.wings:wings.append(bird.find_child(name,true,false))
    for record in layout.boats:
        var ferry:Node3D=art.find_child(record.name,true,false)
        ferries.append({"node":ferry,"origin":ferry.position,"phase":float(record.phase),"rim":ferry.find_child(record.rim,true,false)})
    water_effects=load("res://assets/models/azure_water.glb").instantiate() as Node3D
    world.add_child(water_effects)
    var particle_names:=["Threads","Spray","Mist","Foam"]
    for kind in range(particle_names.size()):
        var material:=ShaderMaterial.new()
        material.shader=load("res://shaders/azure_particles.gdshader")
        material.set_shader_parameter("kind",kind)
        material.set_shader_parameter("density",.65 if mobile else 1.)
        material.render_priority=2 if kind==2 else 1
        particle_materials.append(material)
        for part in water_effects.find_children("*","MeshInstance3D",true,false):
            if str(part.name)=="AzureWater"+particle_names[kind]:
                part.material_override=material
                part.extra_cull_margin=64
                part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _create_vegetation() -> void:
    pass

func _create_camera() -> void:
    super._create_camera()
    camera.reparent(bird)
    camera.near=.08;camera.far=850
    camera.get_child(0).hide()
    start=Vector3(layout.seat[0],layout.seat[1],layout.seat[2])
    heading=FOLLOW_HEADING;pitch=OPEN_PITCH;target_heading=heading;target_pitch=pitch

func _create_interface() -> void:
    super._create_interface()
    view_button=_button("View · Follow",func():
        following=not following
        view_button.text="View · Follow" if following else "View · Aboard"
        _reset()
    )
    view_button.tooltip_text="Switch between the seated view and a view behind the bird"
    # The flight is automatic. The shared stick becomes an alternate look input.
    touch.touch_visible=mobile
    for button in [menu_button,settings_button]:
        for state in ["font_color","font_hover_color","font_pressed_color","icon_normal_color","icon_hover_color","icon_pressed_color"]:
            button.add_theme_color_override(state,Color(.20,.26,.33))
    for button in controls.get_children():
        if not button is Button:continue
        for state in ["font_color","font_hover_color","font_pressed_color"]:button.add_theme_color_override(state,Color(.23,.27,.34))
        var style:=StyleBoxFlat.new()
        style.bg_color=Color(.94,.90,.79,.96);style.border_color=Color(.39,.43,.48,.7)
        style.set_border_width_all(1);style.content_margin_left=14;style.content_margin_right=14
        button.add_theme_stylebox_override("normal",style)
        var hover:StyleBoxFlat=style.duplicate();hover.bg_color=Color(.81,.90,.85,.98)
        button.add_theme_stylebox_override("hover",hover);button.add_theme_stylebox_override("pressed",hover)

func _create_audio() -> void:
    audio=AudioStreamPlayer.new()
    var stream:AudioStreamWAV=load("res://assets/audio/azure_falls.wav")
    stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin=0;stream.loop_end=int(stream.get_length()*stream.mix_rate)
    audio.stream=stream;audio.volume_db=-7
    audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
    add_child(audio)
    if sound_on:audio.play()

func flight_position(t: float) -> Vector3:
    var orbit:Dictionary=layout.orbit
    var angle:float=orbit.phase+t*TAU/float(orbit.period)
    return Vector3(float(orbit.center[0])+cos(angle)*float(orbit.radii[0]),float(orbit.center[1])+2.2*sin(angle*2.),float(orbit.center[2])+sin(angle)*float(orbit.radii[1]))

func wingbeat_pose(t: float) -> Vector3:
    var cycle_time:=fposmod(t,WINGBEAT_CYCLE)
    for onset in WINGBEAT_STARTS:
        var phase:float=cycle_time-onset
        if phase<0. or phase>=WINGBEAT_KEYS[-1]:continue
        for k in range(WINGBEAT_KEYS.size()-1):
            if phase>WINGBEAT_KEYS[k+1]:continue
            var u:float=(phase-WINGBEAT_KEYS[k])/(WINGBEAT_KEYS[k+1]-WINGBEAT_KEYS[k])
            # Zero velocity and acceleration at the joins prevents pose snaps,
            # including when an occasional beat blends back into the glide.
            u=u*u*u*(u*(u*6.-15.)+10.)
            return WINGBEAT_POSES[k].lerp(WINGBEAT_POSES[k+1],u)
    return Vector3.ZERO

func _animate_world() -> void:
    var angle:float=float(layout.orbit.phase)+time*TAU/float(layout.orbit.period)
    var beat:=wingbeat_pose(time)
    var lift:=wingbeat_pose(time-.18).x
    bird.position=flight_position(time)
    bird.position.y+=.23*sin(time*.82)+.08*sin(time*.31)-.55*lift
    var velocity:=Vector3(-sin(angle)*float(layout.orbit.radii[0]),0,cos(angle)*float(layout.orbit.radii[1]))
    bird.rotation=Vector3(.015*sin(angle*2)+.009*sin(time*.82+.6)-.025*lift,atan2(-velocity.x,-velocity.z),-.045+.013*sin(time*.61+1.3))
    traveller.rotation.x=.012*sin(time*.82-.35)+.025*lift
    companion.position=Vector3(27*sin(time*.032+.7),39+2*sin(time*.24),-49+22*cos(time*.032+.7))
    companion.rotation.y=atan2(-27*cos(time*.032+.7),22*sin(time*.032+.7))
    for i in range(wings.size()):
        # Animate the authored shoulders, carrying both shells and pen paths.
        # The small unequal corrections feel like balancing on a rising current.
        var side:float=-1. if i==0 else 1.
        var glide:=.05*sin(time*.82)+.021*sin(time*.31)+side*.012*sin(time*.61+1.3)
        wings[i].rotation=Vector3(.007*sin(time*.82+.4)+beat.z,side*(.014*sin(time*.46)+beat.y),side*(glide+beat.x))
    for record in ferries:
        var phase:float=record.phase
        record.node.position=record.origin+Vector3(5.5*sin(time*.018+phase),.09*sin(time*.73+phase),3.3*cos(time*.018+phase))
        record.node.rotation=Vector3(.013*sin(time*.5+phase),atan2(5.5*cos(time*.018+phase),3.3*sin(time*.018+phase)),.014*sin(time*.63+phase))
        # The ribbon follows the hull in X/Z and yaw, but stays on the water
        # plane while the boat rocks. Its source vertices sit at local -.195.
        var rim:Node3D=record.rim
        rim.global_transform=Transform3D(Basis(Vector3.UP,record.node.rotation.y),Vector3(record.node.position.x,18.25,record.node.position.z))
    for material in materials:material.set_shader_parameter("scene_time",time)
    for material in particle_materials:material.set_shader_parameter("scene_time",time)

func _update_camera() -> void:
    if review_camera:return
    traveller.visible=following
    if following:
        # Orbit behind the carrier while retaining the same user look controls.
        var offset:=Basis(Vector3.UP,heading)*Vector3(layout.follow[0],layout.follow[1],layout.follow[2])
        camera.position=offset
        camera.rotation=Vector3(pitch-.10,heading,0)
    else:
        camera.position=start
        camera.rotation=Vector3(pitch,heading,0)

func _look(delta: Vector2) -> void:
    target_heading-=delta.x*.0025
    target_pitch=clampf(target_pitch-delta.y*.0025,-1.30,1.15)

func _reset() -> void:
    target_heading=FOLLOW_HEADING if following else 0.;heading=target_heading
    target_pitch=OPEN_PITCH;pitch=OPEN_PITCH
    walking=Vector2.ZERO
    if touch:touch.reset_input()
    if view_button:view_button.text="View · Follow" if following else "View · Aboard"
    _update_camera()

func can_walk(_point: Vector3) -> bool:
    return false

func _process(delta: float) -> void:
    delta=minf(delta,.04)
    if not paused:time+=delta
    var direction:=walking
    if not settings_open:
        direction.x+=float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
        direction.y+=float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
        direction=direction.limit_length(1.)
        target_heading-=direction.x*delta*.7
        target_pitch=clampf(target_pitch-direction.y*delta*.5,-1.30,1.15)
    heading=lerpf(heading,target_heading,minf(delta*8,1))
    pitch=lerpf(pitch,target_pitch,minf(delta*8,1))
    _animate_world();_update_camera();_sync_audio_pause(audio)
    frame_count+=1
    if frame_count%20==0 and get_window().content_scale_size!=Session.display_size():_resize()
    if capture_path!="" and frame_count==40:_capture()
