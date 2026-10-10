import bpy, math, sys, os, random
from mathutils import Vector as V
D = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
def srgb(h):
    h=h.lstrip("#"); c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple((v/12.92) if v<=0.04045 else ((v+0.055)/1.055)**2.4 for v in c)
def mat(h, r=0.8, e=0):
    m=bpy.data.materials.new(h); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*srgb(h),1); b.inputs["Roughness"].default_value=r
    if e: b.inputs["Emission Color"].default_value=(*srgb(h),1); b.inputs["Emission Strength"].default_value=e
    return m
def rb(x,y,z): return (x,-z,y)  # 로블록스 좌표 -> 블렌더
def box(rpos, rsize, m):
    bpy.ops.mesh.primitive_cube_add(size=1, location=rb(*rpos)); o=bpy.context.object
    o.scale=(rsize[0], rsize[2], rsize[1]); o.data.materials.append(m); return o
def light(rpos, color, power, radius=0.3):
    bpy.ops.object.light_add(type="POINT", location=rb(*rpos)); l=bpy.context.object
    l.data.energy=power; l.data.color=srgb(color); l.data.shadow_soft_size=radius
def imp(name, rground, height, face_deg):
    bpy.ops.import_scene.fbx(filepath=os.path.join(D, name+".fbx"))
    o=[x for x in bpy.context.selected_objects if x.type=="MESH"][0]
    bpy.context.view_layer.update()
    zs=[(o.matrix_world@V(c)).z for c in o.bound_box]
    k=height/(max(zs)-min(zs)); o.scale=[s*k for s in o.scale]
    o.rotation_euler.z += math.radians(face_deg)
    bpy.context.view_layer.update()
    bb=[o.matrix_world@V(c) for c in o.bound_box]
    cx=(min(p.x for p in bb)+max(p.x for p in bb))/2; cy=(min(p.y for p in bb)+max(p.y for p in bb))/2; mz=min(p.z for p in bb)
    g=V(rb(*rground)); o.location += V((g.x-cx, g.y-cy, g.z-mz))
    return o
# 바닥, 길
box((-90,-1,0),(200,2,200),mat("#22262C",0.95))
box((-75,0.1,0),(150,0.2,16),mat("#56525F",0.9))
box((250,-1,0),(500,2,60),mat("#3C2F5A",0.8))  # zone1 근사
for sd in (-1,1): box((250,0.6,sd*30.5),(500,1.2,1),mat("#8CFFD2",0.3,4))
box((-120,0.3,0),(14,0.6,14),mat("#56525F",0.9))
# 관
for i,n in enumerate(["CoffinWood","CoffinCursed","CoffinGold"]):
    gx=-100+i*32
    box((gx,0.5,36),(14,1,14),mat("#46424F",0.9))
    imp(n,(gx,1,36),13,180)
    light((gx,6,30),["#FF9646","#96FFBE","#FFDC78"][i],400,1)
# 러닝머신
tc=["#78C8FF","#78FFA0","#FFDC5A","#FF78C8","#C878FF"]
for i in range(5):
    gx=-125+i*27
    imp("Treadmill",(gx,0,-38),4.6,0)
    box((gx,1.5,-31.4),(22,0.3,0.8),mat(tc[i],0.3,4))
imp("RebirthStatue",(-165,0,0),26,90)
light((-161,22,0),"#FFE18C",1500,2)
for i in range(6):
    for sd in (1,-1):
        imp("LanternPost",(-140+i*26,0,sd*10),8,0 if sd<0 else 180)
        gl=8*0.82
        bpy.ops.mesh.primitive_uv_sphere_add(radius=8*0.1, location=rb(-140+i*26,gl,sd*10)); bpy.context.object.data.materials.append(mat("#FF9646",0.4,8))
        light((-140+i*26,gl,sd*10),"#FF9646",250,0.5)
random.seed(3)
for _ in range(14):
    e=random.choice((-1,1)); imp("DeadTree",(random.uniform(-185,0),0,e*random.uniform(60,95)),random.uniform(12,20),random.uniform(0,360))
for _ in range(12):
    imp("Tombstone",(random.uniform(-180,-10),0,random.choice((-1,1))*random.uniform(55,90)),random.uniform(4,6),random.uniform(-30,30))
g=imp("GhostChaser",(-30,8,0),34,-90)
light((-24,20,0),"#BEDCFF",4000,4)
# 하늘/달빛
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs["Color"].default_value=(*srgb("#141022"),1)
w.node_tree.nodes["Background"].inputs["Strength"].default_value=1.0
bpy.ops.object.light_add(type="SUN"); s=bpy.context.object; s.data.energy=0.9; s.data.color=srgb("#AFB4FF")
s.rotation_euler=(math.radians(55),0,math.radians(140))
# 안개
vol=bpy.data.materials.new("fog"); vol.use_nodes=True; nt=vol.node_tree
nt.nodes.remove(nt.nodes["Principled BSDF"]); pv=nt.nodes.new("ShaderNodeVolumePrincipled")
pv.inputs["Density"].default_value=0.004; pv.inputs["Color"].default_value=(*srgb("#5C5678"),1)
nt.links.new(pv.outputs[0], nt.nodes["Material Output"].inputs["Volume"])
bpy.ops.mesh.primitive_cube_add(size=1, location=(0,0,20)); f=bpy.context.object; f.scale=(800,400,60); f.data.materials.append(vol)
# 카메라: 스폰 뒤에서 정면(+X) 바라봄 (로블록스 기본 3인칭 비슷하게)
bpy.ops.object.camera_add(location=rb(-140,14,0)); cam=bpy.context.object; cam.data.lens=24
tgt=V(rb(-60,5,0)); cam.rotation_euler=(tgt-cam.location).to_track_quat("-Z","Y").to_euler(); sc.camera=cam
sc.render.engine="CYCLES"; sc.cycles.samples=48; sc.cycles.use_denoising=True
sc.render.resolution_x=1280; sc.render.resolution_y=720; sc.view_settings.view_transform="AgX"
sc.render.filepath=os.path.join(D,"lobby_mock.png"); bpy.ops.render.render(write_still=True); print("DONE")
