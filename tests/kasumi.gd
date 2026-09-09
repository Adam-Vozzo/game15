extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func check(condition: bool,message: String) -> void:
    if not condition:
        push_error(message)
        quit(1)
        assert(condition,message)

func run() -> void:
    change_scene_to_file("res://town.tscn")
    await process_frame
    await process_frame
    var town: Node = current_scene
    check(town.fields.size()==30,"Both sides of the valley need their complete cultivated plots")
    for building in town.layout.buildings:
        var r: Array = building.rect
        check(not town.can_walk(Vector3(r[0]+r[2]*.5,0,r[1]+r[3]*.5)),"Each modeled building footprint must block walking")
    for z in range(-95,85):
        check(town.can_walk(Vector3(0,0,z)),"The main lane must stay connected")
    check(town.layout.walk_surfaces.size()==7,"Shrine needs six steps and a solid landing")
    for surface in town.layout.walk_surfaces:
        var r: Array = surface.rect
        var x: float = r[0]+r[2]*.5
        var z: float = r[1]+r[3]*.5
        check(absf(town.surface_height(x,z)-surface.height)<.001,"Shrine walking height must follow the modeled steps and landing")
        check(town._on_shrine(x,z),"Shrine masonry must exclude garden vegetation")
    for r in town.layout.obstacles:
        check(not town.can_walk(Vector3(r[0]+r[2]*.5,0,r[1]+r[3]*.5)),"Solid garden walls and shrine body must block walking")
    # Rendering two upward faces at the same height caused the shrine platform to flicker.
    var shrine: MeshInstance3D = town.world.find_child("Inari_wayside_shrine",true,false)
    var faces: PackedVector3Array = shrine.mesh.get_faces()
    var top: float = town.layout.walk_surfaces[0].height
    for point in [Vector2(10.61,-58.13),Vector2(13.31,-56.79),Vector2(12.27,-55.81)]:
        var covers := 0
        for i in range(0,faces.size(),3):
            var a: Vector3 = shrine.global_transform*faces[i]
            var b: Vector3 = shrine.global_transform*faces[i+1]
            var c: Vector3 = shrine.global_transform*faces[i+2]
            if absf(a.y-top)>.001 or absf(b.y-top)>.001 or absf(c.y-top)>.001:continue
            if Geometry2D.is_point_in_polygon(point,PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])):covers+=1
        print("Landing sample ",point," top=",top," faces=",covers)
        check(covers==1,"Shrine landing must have exactly one visible top face at every sampled point")
    for field in town.fields:
        var r: Array = field.rect
        var x: float = r[0]+r[2]*.5
        var z: float = r[1]+r[3]*.5
        var expected: float = field.height+(.13 if field.crop=="rice" else 0.)
        check(absf(town.surface_height(x,z)-expected)<.001,"Walking and rendered field levels must agree")
    for name in ["Rice","Wheat","Verge"]:
        var mesh: Mesh = town.plant_meshes[name]
        var minimum := INF
        var maximum := -INF
        for surface in range(mesh.get_surface_count()):
            var points: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
            for point in points:
                minimum=minf(minimum,point.y)
                maximum=maxf(maximum,point.y)
        check(absf(minimum)<.0001 and maximum>.25,"Imported crop meshes must retain local roots at y=0")
    for page in range(4):
        var texture: Texture2D = load("res://assets/textures/KasumiAtlas%d.png"%page)
        check(texture.get_size()==Vector2(256,256),"Each texture page must remain 256x256")
    var time_before: float = town.time
    town.paused=true
    await process_frame
    check(town.time==time_before,"Fog, clouds, rain, cloth and crops must share the pause clock")
    check(town.camera.far>800,"Distant landscape must extend well beyond the walking boundary")
    print("PASS: Kasumi connected lane, 18 building bounds, 30 field levels, imported crop roots, texture-page dimensions and pause")
    town.queue_free()
    await process_frame
    quit(0)
