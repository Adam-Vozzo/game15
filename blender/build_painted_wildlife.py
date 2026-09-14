"""Original articulated flamingos; executed by build_painted.py in its namespace.
All points use Godot axes, with each bird rooted on a submerged shallow bank.
"""

def bird_tube(batch,points,radii,col,sides=10):
    ps=[Vector(p) for p in points];rings=[]
    for j,p in enumerate(ps):
        d=(ps[min(j+1,len(ps)-1)]-ps[max(0,j-1)]).normalized()
        a=d.cross(Vector((0,0,1))).normalized();b=d.cross(a)
        rings.append([p+(a*math.cos(k*math.tau/sides)+b*math.sin(k*math.tau/sides))*radii[j] for k in range(sides)])
    for j in range(len(ps)-1):
        for k in range(sides):
            kk=(k+1)%sides
            batch.face([rings[j][k],rings[j][kk],rings[j+1][kk],rings[j+1][k]],col,[(k/sides,j/(len(ps)-1)),(kk/sides,j/(len(ps)-1)),(kk/sides,(j+1)/(len(ps)-1)),(k/sides,(j+1)/(len(ps)-1))])
    batch.face(list(reversed(rings[0])),col,[(0,0)]*sides)
    batch.face(rings[-1],col,[(1,1)]*sides)

def bird_part(batch,parent,pivot=(0,0,0)):
    p=Vector(pivot);batch.v=[Vector(v)-p for v in batch.v]
    ob=batch.finish();ob.parent=parent;ob.location=(p.x,-p.z,p.y)
    return ob

def feed_shape(ob,rest,target,name='Feed'):
    # Match the source points after welding; both poses remain editable in Blender.
    lookup={tuple(round(float(c),5) for c in p):Vector(q) for p,q in zip(rest,target)}
    if ob.data.shape_keys is None:ob.shape_key_add(name='Basis')
    key=ob.shape_key_add(name=name)
    for vertex in ob.data.vertices:
        p=vertex.co;ident=tuple(round(float(c),5) for c in (p.x,p.z,-p.y))
        q=lookup[ident];key.data[vertex.index].co=(q.x,-q.z,q.y)

flamingos=[]
places=[(-5.4,-3,.35,1.02),(-7,-4.8,-.35,.94),(-8.3,-2,.80,.90),(-6.5,-8.5,1.8,1.03),(5.4,-1.8,2.65,1.0),(6.8,-4.8,3.55,.91),(9.3,-.7,2.1,.96),(6.2,-14,2.3,.95),(-5.5,-19,-.2,.98)]
pink=(.98,.43,.68,1);dark=(.24,.18,.28,1)
for i,(x,z,angle,size) in enumerate(places):
    root=bpy.data.objects.new('Flamingo_%02d'%i,None);bpy.context.collection.objects.link(root)
    root.location=(x,-z,-.30);root.rotation_euler.z=angle;root.scale=(size,size,size)
    body=Batch('Flamingo_%02d_body'%i,'Bird')
    oval(body,(-.08,1.02,0),(.48,.25,.23),pink,32,18)
    # A pointed rear tail and soft overlap of folded wings, seen from either side.
    bird_tube(body,[(-.39,1.04,0),(-.67,1.12,0)],[.14,.005],(.88,.32,.57,1))
    for s in [-1,1]:oval(body,(-.14,1.04,s*.175),(.35,.17,.09),(.93,.34,.61,1),24,12)
    bird_part(body,root)
    if i in [0,4,6]:
        overflow=Batch('Flamingo_%02d_body_spill'%i,'Bleed')
        oval(overflow,(-.105,1.045,.015),(.545,.285,.27),(.98,.33,.66,.18),32,18)
        bird_part(overflow,root)
    pen=Batch('Flamingo_%02d_wing_ink'%i,'Ink')
    for s in [-1,1]:
        stroke([(-.41+.59*t,1.02-.115*math.sin(t*math.pi),s*(.236+.02*math.sin(t*math.pi))) for t in [j/16 for j in range(17)]],.006,dark,pen)
        for k in range(3):stroke([(-.35+k*.08,1.05-k*.025,s*.245),(-.48+k*.10,.97-k*.018,s*.24)],.004,dark,pen)
    bird_part(pen,root)
    legs=Batch('Flamingo_%02d_legs'%i,'Ink')
    for s in [-1,1]:
        if i%3==0 and s==1:
            path=[(.02,.88,s*.11),(.17,.53,s*.14),(-.15,.69,s*.16)]
        else:
            path=[(.03,.88,s*.11),(-.06,.47,s*.115),(.015,.025,s*.12)]
            for toe in [-1,0,1]:stroke([path[-1],(.18,.012,s*.12+toe*.055)],.009,dark,legs)
        stroke(path,.014,dark,legs)
    bird_part(legs,root)
    neckroot=bpy.data.objects.new('Flamingo_%02d_neck'%i,None);bpy.context.collection.objects.link(neckroot)
    neckroot.parent=root;neckroot.location=(.27,0,1.10)
    neck=Batch('Flamingo_%02d_neck_paint'%i,'Bird')
    # Cubic S profile sweeps upward from the breast into the small head.
    a=Vector((0,-.05,0));b=Vector((.54,.42,0));c=Vector((-.26,.59,0));d=Vector((.12,.94,0))
    ps=[];feeding_ps=[]
    feed_b=Vector((.66,.20,0));feed_c=Vector((.83,-.22,0));feed_d=Vector((.96,-.73,0))
    for j in range(37):
        t=j/36;ps.append(a*(1-t)**3+b*3*(1-t)**2*t+c*3*(1-t)*t*t+d*t**3)
        feeding_ps.append(a*(1-t)**3+feed_b*3*(1-t)**2*t+feed_c*3*(1-t)*t*t+feed_d*t**3)
    bird_tube(neck,ps,[.074*(1-j/36)+.039*(j/36) for j in range(37)],pink)
    feeding=Batch('feed pose','Bird')
    bird_tube(feeding,feeding_ps,[.074*(1-j/36)+.039*(j/36) for j in range(37)],pink)
    tube_count=len(neck.v)
    def lower_head(p,amount=1):
        q=Vector(p)-d;angle=-.35*amount
        reach=Vector((.5*math.sin(math.pi*amount),0,0))
        return d.lerp(feed_d,amount)+reach+Vector((q.x*math.cos(angle)-q.y*math.sin(angle),q.x*math.sin(angle)+q.y*math.cos(angle),q.z))
    oval(neck,(.18,.96,0),(.13,.105,.083),(.99,.57,.74,1),24,16)
    bird_tube(neck,[(.25,.965,0),(.37,.925,0),(.40,.865,0)],[.05,.054,.034],(.98,.80,.78,1))
    feeding.v.extend(lower_head(p) for p in neck.v[tube_count:])
    neckob=bird_part(neck,neckroot)
    feed_shape(neckob,neck.v,feeding.v)
    # Re-sweep the neck at intermediate poses: direct rest-to-feed morphing
    # collapses cross-sections where the curve reverses direction halfway down.
    for step in [.25,.5,.75]:
        pose=Batch('intermediate feed','Bird')
        # Reach forward before lowering, instead of shortening the whole neck
        # along a straight line between the standing and feeding head positions.
        pose_points=[p.lerp(q,step)+Vector((.5*math.sin(math.pi*step)*(j/36)**2,0,0)) for j,(p,q) in enumerate(zip(ps,feeding_ps))]
        bird_tube(pose,pose_points,[.074*(1-j/36)+.039*(j/36) for j in range(37)],pink)
        pose.v.extend(lower_head(p,step) for p in neck.v[tube_count:])
        feed_shape(neckob,neck.v,pose.v,'Feed_%d'%int(step*100))
    details=Batch('Flamingo_%02d_face_ink'%i,'Ink')
    bird_tube(details,[(.377,.906,0),(.43,.817,0),(.455,.805,0)],[.042,.022,.003],dark)
    for s in [-1,1]:
        oval(details,(.211,.982,s*.079),(.012,.012,.009),dark,12,8)
        stroke([(.27,.957,s*.045),(.37,.908,s*.045)],.004,dark,details)
    faceob=bird_part(details,neckroot)
    feed_shape(faceob,details.v,[lower_head(p) for p in details.v])
    for step in [.25,.5,.75]:feed_shape(faceob,details.v,[lower_head(p,step) for p in details.v],'Feed_%d'%int(step*100))
    # A low submerged shoal gives both standing feet a physical ground surface.
    shoal=Batch('Flamingo_%02d_submerged_shoal'%i,'Wash')
    oval(shoal,(x,-.69,z),(1.1,.395,1.0),(.70,.68,.83,1),20,10)
    shoal.finish()
    flamingos.append(dict(name=root.name,x=x,z=z,scale=size,angle=angle,phase=i*1.713,ground=-.30,one_leg=i%3==0))

# Two tiny ink-and-turquoise dragonflies visit the closest lotus flowers.
dragonflies=[]
for i,(x,z,s) in enumerate([lotus[0],lotus[1]]):
    root=bpy.data.objects.new('Dragonfly_%02d'%i,None);bpy.context.collection.objects.link(root)
    root.location=(x,-z,s*1.55+.22)
    body=Batch(root.name+'_body','Wash')
    bird_tube(body,[(-.19,0,0),(0,0,0),(.10,.015,0)],[.009,.022,.018],(.25,.65,.67,1),8)
    oval(body,(.11,.015,0),(.030,.022,.030),(.27,.30,.38,1),12,8)
    bird_part(body,root)
    for wing_index in range(4):
        side=1 if wing_index%2 else -1;front=1 if wing_index<2 else -1
        pivot=bpy.data.objects.new(root.name+'_wing_%d'%wing_index,None);bpy.context.collection.objects.link(pivot);pivot.parent=root
        wing=Batch(pivot.name+'_wash','Wash');pen=Batch(pivot.name+'_ink','Ink')
        ring=[]
        for j in range(25):
            a=j*math.tau/24
            ring.append(Vector((front*.045+math.cos(a)*.050,.006,side*(.11+math.sin(a)*.11))))
        wing.face(ring,(.83,.92,.94,1),[(p.x+0.5,p.z+0.5) for p in ring])
        stroke(ring,.0018,(.40,.54,.58,1),pen)
        stroke([(front*.045,0,0),(front*.045,.008,side*.20)],.0015,(.53,.68,.70,1),pen)
        bird_part(wing,pivot);bird_part(pen,pivot)
    dragonflies.append(dict(name=root.name,x=x,z=z,y=s*1.55+.22,phase=i*11.3))
