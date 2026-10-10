import bpy, math, sys, os
from mathutils import Vector as V
OUT = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, "GoldenDragon.glb"))
# 로블록스처럼: 금속도/거칠기 맵 연결
for o in bpy.context.scene.objects:
    if o.type != "MESH":
        continue
    base = o.name.split(".")[0]
    for slot in o.material_slots:
        nt = slot.material.node_tree
        b = nt.nodes.get("Principled BSDF")
        for sock, suf in (("Metallic", "Metalness"), ("Roughness", "Roughness")):
            p = os.path.join(OUT, base + "_" + suf + ".png")
            if os.path.exists(p):
                t = nt.nodes.new("ShaderNodeTexImage")
                t.image = bpy.data.images.load(p)
                t.image.colorspace_settings.name = "Non-Color"
                nt.links.new(t.outputs["Color"], b.inputs[sock])
def srgb(h):
    h=h.lstrip("#"); c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple((x/12.92) if x<=0.04045 else ((x+0.055)/1.055)**2.4 for x in c)
bpy.ops.mesh.primitive_plane_add(size=60)
fl = bpy.context.object
m = bpy.data.materials.new("F"); m.use_nodes=True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(*srgb("#3B3834"),1)
fl.data.materials.append(m)
w = bpy.data.worlds.new("W"); scene.world = w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs["Color"].default_value=(*srgb("#5A544C"),1)
w.node_tree.nodes["Background"].inputs["Strength"].default_value=0.7
bpy.ops.object.light_add(type="SUN"); s=bpy.context.object; s.data.energy=5; s.data.color=srgb("#FFE9C8")
s.rotation_euler=(math.radians(50),math.radians(-10),math.radians(-60))
bpy.ops.object.light_add(type="AREA", location=(6,6,6)); r=bpy.context.object; r.data.energy=3000; r.data.size=6
r.data.color=srgb("#BFD8FF"); r.rotation_euler=(math.radians(-50),0,math.radians(135))
# 모델 바운딩 박스 중심을 기준으로 카메라
objs=[o for o in scene.objects if o.type=="MESH" and o is not fl]
pts=[o.matrix_world @ V(c) for o in objs for c in o.bound_box]
mn=V((min(p.x for p in pts),min(p.y for p in pts),min(p.z for p in pts)))
mx=V((max(p.x for p in pts),max(p.y for p in pts),max(p.z for p in pts)))
c=(mn+mx)/2
print("bbox size", mx-mn)
cam_dir = V((-0.45,-0.85,0.25)).normalized()
bpy.ops.object.camera_add(location=c+cam_dir*(mx-mn).length*1.15)
cam=bpy.context.object; cam.data.lens=42
cam.rotation_euler=(c-cam.location).to_track_quat("-Z","Y").to_euler(); scene.camera=cam
scene.render.engine="CYCLES"; scene.cycles.samples=48
scene.render.resolution_x=900; scene.render.resolution_y=900
scene.view_settings.view_transform="AgX"
scene.render.filepath=os.path.join(OUT,"dragon_lowpoly_check.png")
bpy.ops.render.render(write_still=True)
print("DONE")
