"""Bake clothed CC0 Man into walking, cycling and motorcycle rider GLBs.

Run with Blender 5.1 --background --python-exit-code 1 --python this-file.
All work happens in a separate background Blender process, never a live scene.
Vehicle contact points are measured in the renderer's +X-forward metre frame.
Blender uses Z up; glTF export converts that frame to the renderer's Y up.
"""
import bpy
import json
import math
import struct
import hashlib
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector

ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'content-animations/models/people'
SOURCE=DEST/'man-casual-source.glb'
FPS=30
_bytes=SOURCE.read_bytes()
assert hashlib.sha256(_bytes).hexdigest()=='dad8fa3ca2bc7760892f9ff47f544941179e50acb2aa772cf9f035154a37fc58'
_gltf=json.loads(_bytes[20:20+struct.unpack_from('<I',_bytes,12)[0]])
END_OFFSETS={n['name']:Vector(n['translation']) for n in _gltf['nodes'] if n.get('name','').endswith('_end')}

def update():bpy.context.view_layer.update()

def load_human():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    arm.animation_data_clear()
    for bone in arm.pose.bones:bone.matrix_basis.identity();bone.rotation_mode='QUATERNION'
    wrapper=bpy.data.objects.new('TrafficHuman',None);bpy.context.collection.objects.link(wrapper)
    for o in list(bpy.context.scene.objects):
        if o!=wrapper and not o.parent and o.type!='MESH':o.parent=wrapper
    wrapper.rotation_euler.z=math.pi/2
    wrapper.scale=(1.75/4.844610214233398,)*3
    update()
    return arm,wrapper

def world_matrix(arm,name):return arm.matrix_world@arm.pose.bones[name].matrix
def point(arm,name):
    # Blender drops glTF leaf end markers; retain their original joint offsets.
    if name not in arm.pose.bones:return world_matrix(arm,name[:-4])@END_OFFSETS[name]
    return world_matrix(arm,name).translation.copy()
def set_matrix(arm,name,matrix):
    arm.pose.bones[name].matrix=arm.matrix_world.inverted()@matrix;update()
def move_bone(arm,name,delta):
    m=world_matrix(arm,name);m.translation+=delta;set_matrix(arm,name,m)
def rotate_bone(arm,name,rotation):
    m=world_matrix(arm,name);loc=m.translation.copy();m=rotation.to_matrix().to_4x4()@m;m.translation=loc;set_matrix(arm,name,m)
def aim(arm,name,endpoint,target):
    start=point(arm,name);direction=point(arm,endpoint)-start
    rotate_bone(arm,name,direction.rotation_difference(Vector(target)-start))

def limb(arm,upper,lower,end,target,pole):
    target=Vector(target);start=point(arm,upper);middle=point(arm,lower);finish=point(arm,end)
    a=(middle-start).length;b=(finish-middle).length
    toward=target-start;distance=min(toward.length,a+b-.0001);direction=toward.normalized()
    bend=Vector(pole);bend=(bend-direction*bend.dot(direction)).normalized()
    along=(a*a-b*b+distance*distance)/(2*distance)
    joint=start+direction*along+bend*math.sqrt(max(0,a*a-along*along))
    aim(arm,upper,lower,joint);aim(arm,lower,end,target)
    return (point(arm,end)-target).length

def foot(arm,side,ankle):
    name='Foot.'+side;direction=point(arm,name+'_end')-point(arm,name)
    rotate_bone(arm,name,direction.rotation_difference(Vector((1,0,0))))
    move_bone(arm,name,Vector(ankle)-point(arm,name))

def rider_pose(arm,kind,phase):
    for p in arm.pose.bones:p.matrix_basis.identity()
    update()
    hip=Vector((-.26,0,1.075)) if kind=='cyclist' else Vector((-.40,0,.93))
    centre=(point(arm,'UpperLeg.L')+point(arm,'UpperLeg.R'))/2
    move_bone(arm,'Body',hip-centre)
    if kind=='cyclist':
        # The original stylised mesh has short legs. Fit its riding variant to
        # the measured 1.015 m saddle without letting an ankle miss a pedal.
        for side in ['L','R']:arm.pose.bones['UpperLeg.'+side].scale=(1.20,)*3
        update()
    rotate_bone(arm,'Hips',Quaternion((0,1,0),math.radians(45 if kind=='cyclist' else 42)))
    # Look along the road while the torso leans over the bars.
    rotate_bone(arm,'Neck',Quaternion((0,1,0),math.radians(-20)))
    errors=[]
    for side,sign in [('L',1),('R',-1)]:
        if kind=='cyclist':
            angle=phase+math.atan2(.14,-.075)+(0 if sign==1 else math.pi)
            pedal=Vector((-.08+.159*math.cos(angle),sign*.13,.29+.159*math.sin(angle)))
            ankle=pedal+Vector((-.065,0,.065))
            grip=Vector((.4505,sign*.2375,1.0525))
        else:
            ankle=Vector((-.35,sign*.2615,.525))
            grip=Vector((.3825,sign*.291,.99))
        errors.append(limb(arm,'UpperLeg.'+side,'LowerLeg.'+side,'LowerLeg.'+side+'_end',ankle,(1,sign*.3,0)))
        foot(arm,side,ankle)
        wrist=grip+Vector((-.035,0,.025))
        errors.append(limb(arm,'UpperArm.'+side,'LowerArm.'+side,'Palm.'+side,wrist,(-1,sign*.7,-.4)))
        direction=point(arm,'MiddleHand.'+side)-point(arm,'Palm.'+side)
        rotate_bone(arm,'Palm.'+side,direction.rotation_difference(Vector((1,0,-.3))))
        aim(arm,'MiddleHand.'+side,'Fingers.'+side,point(arm,'MiddleHand.'+side)+Vector((0,0,-1)))
        aim(arm,'Fingers.'+side,'Fingers.'+side+'_end',point(arm,'Fingers.'+side)+Vector((-1,0,0)))
    return max(errors)

def key_pose(arm,frame):
    for p in arm.pose.bones:
        for channel in ['location','rotation_quaternion','scale']:p.keyframe_insert(data_path=channel,frame=frame,group=p.name)

def helmet(arm):
    # Full-face shell: crown, side/rear coverage and a solid front chin bar.
    # The dark curved visor occupies its own opening rather than covering skin
    # with a half sphere. All three parts follow the actual head bone.
    tilt=Quaternion((0,1,0),math.radians(22))
    centre=point(arm,'Head')+tilt@Vector((.025,0,.065))
    def surface(theta,phi,expand=0):
        chin=.045*max(0,math.cos(phi))**3*math.exp(-((math.degrees(theta)-120)/18)**2)
        return centre+tilt@Vector(((.170+expand)*math.sin(theta)*math.cos(phi)+chin,(.150+expand)*math.sin(theta)*math.sin(phi),(.190+expand)*math.cos(theta)))
    def material(name,color,roughness):
        mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);mat.use_nodes=True
        node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        node.inputs['Base Color'].default_value=mat.diffuse_color;node.inputs['Roughness'].default_value=roughness
        return mat
    blue=material('HelmetBlue',(.025,.10,.23),.30)
    glass=material('FullFaceVisor',(.008,.022,.040),.14)
    vent=material('ChinVent',(.006,.009,.012),.55)
    def mesh_object(name,vertices,faces,mat):
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.data.materials.append(mat)
        for polygon in mesh.polygons:polygon.use_smooth=True
        world=obj.matrix_world.copy();obj.parent=arm;obj.parent_type='BONE';obj.parent_bone='Head';update();obj.matrix_world=world
        return obj
    vertices=[];shell=[];visor=[];rings=20;segments=48
    for i in range(rings+1):
        theta=math.radians(.5+i/rings*149)
        for j in range(segments):vertices.append(surface(theta,j/segments*math.tau))
    for i in range(rings):
        theta=math.radians(.5+(i+.5)/rings*149)
        for j in range(segments):
            phi=(j+.5)/segments*math.tau;a=i*segments+j;b=i*segments+(j+1)%segments
            face=(a,b,b+segments,a+segments)
            (visor if 50<math.degrees(theta)<104 and math.cos(phi)>.35 else shell).append(face)
    mesh_object('MotorcycleHelmet',vertices,shell,blue)
    mesh_object('FullFaceVisor',vertices,visor,glass)
    # A separate vent on the blue chin bar makes its front protection readable.
    points=[surface(math.radians(t),math.radians(p),.002) for t,p in [(116,-17),(116,17),(124,17),(124,-17)]]
    mesh_object('HelmetChinVent',points,[(0,1,2,3)],vent)

def export(arm,wrapper,name):
    bpy.context.scene.render.fps=FPS
    bpy.ops.object.select_all(action='DESELECT')
    chosen=[wrapper,arm]+[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent and not o.hide_render]
    for obj in chosen:obj.select_set(True)
    bpy.context.view_layer.objects.active=arm
    bpy.ops.export_scene.gltf(filepath=str(DEST/(name+'.glb')),export_format='GLB',use_selection=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_optimize_animation_size=True)

def render_preview(kind,arm):
    if kind!='pedestrian':
        before=set(bpy.context.scene.objects)
        name='city-bicycle' if kind=='cyclist' else 'sport-motorcycle'
        bpy.ops.import_scene.gltf(filepath=str(ROOT/f'content-animations/models/{name}.glb'))
        objects=set(bpy.context.scene.objects)-before
        wrapper=bpy.data.objects.new('PreviewVehicle',None);bpy.context.collection.objects.link(wrapper)
        for obj in objects:
            if not obj.parent:obj.parent=wrapper
        if kind=='cyclist':
            wrapper.rotation_euler.z=math.pi/2;update()
            pts=[o.matrix_world@Vector(p) for o in objects if o.type=='MESH' for p in o.bound_box]
            lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
            wrapper.location=Vector((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))
        else:wrapper.location.x=-.0171067
    scene=bpy.context.scene;mid=Vector((0,0,1))
    bpy.ops.object.camera_add(location=(3.8,-6,2.7));cam=bpy.context.object;cam.rotation_euler=(mid-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.75;scene.camera=cam
    for loc,energy in [((2,-3,5),550),((-2,-1,3),220)]:
        bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=energy;o.data.shape='DISK';o.data.size=4;o.rotation_euler=(mid-o.location).to_track_quat('-Z','Y').to_euler()
    scene.world=bpy.data.worlds.new('PreviewWorld');scene.world.color=(.3,.3,.3)
    scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=800;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(ROOT/f'output/playwright/animation-review/human-{kind}-2026-11-01.png')
    bpy.ops.render.render(write_still=True)

report=[]
for kind in ['pedestrian','cyclist','motorcyclist']:
    arm,wrapper=load_human()
    if kind=='pedestrian':
        keep=[a for a in bpy.data.actions if a.name.endswith('Man_Walk') or a.name.endswith('Man_Idle')]
        for a in list(bpy.data.actions):
            if a not in keep:bpy.data.actions.remove(a)
        for a in keep:a.name='Walk' if a.name.endswith('Man_Walk') else 'Idle';a.use_fake_user=True
        arm.animation_data_create();arm.animation_data.action=next(a for a in keep if a.name=='Walk')
        arm.animation_data.action_slot=arm.animation_data.action.slots[0]
        bpy.context.scene.frame_set(6)
        error=0
    else:
        for a in list(bpy.data.actions):bpy.data.actions.remove(a)
        arm.animation_data_clear()
        error=0;poses=[]
        for frame in range(31 if kind=='cyclist' else 2):
            error=max(error,rider_pose(arm,kind,-frame/30*math.tau))
            poses.append({p.name:p.matrix_basis.copy() for p in arm.pose.bones})
        assert error<.002,(kind,'unreachable limb target',error)
        action=bpy.data.actions.new('Pedal' if kind=='cyclist' else 'Ride');arm.animation_data_create();arm.animation_data.action=action
        for frame,pose in enumerate(poses):
            for p in arm.pose.bones:p.matrix_basis=pose[p.name]
            key_pose(arm,frame)
        bpy.context.scene.frame_set(0);update()
        if kind=='motorcyclist':helmet(arm)
    export(arm,wrapper,'traffic-'+kind)
    if kind!='pedestrian':bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/f'output/animation-review/traffic-{kind}.blend'))
    render_preview(kind,arm)
    report.append(dict(profile=kind,maxLimbTargetErrorMetres=error))
(DEST/'build-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print('TRAFFIC_HUMANS_BUILT',json.dumps(report))
manifest=dict(date='2026-11-01',name='Man',creator='Quaternius',license='CC0-1.0',source='https://poly.pizza/m/HMnuH5geEG',licenseUrl='https://creativecommons.org/publicdomain/zero/1.0/',download='https://static.poly.pizza/3746be88-6799-4817-929b-6bc067c47caa.glb.br',blender=bpy.app.version_string,files=[])
for name in ['man-casual-source.glb','traffic-pedestrian.glb','traffic-cyclist.glb','traffic-motorcyclist.glb']:
    payload=(DEST/name).read_bytes();manifest['files'].append(dict(file=name,bytes=len(payload),sha256=hashlib.sha256(payload).hexdigest(),modified=name!='man-casual-source.glb'))
(DEST/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
