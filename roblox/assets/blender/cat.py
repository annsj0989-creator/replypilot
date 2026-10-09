import bpy, math, sys, os
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


MATS = {}


def mat(name, hexc, rough=0.55, sss=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*srgb(hexc), 1)
    b.inputs["Roughness"].default_value = rough
    MATS[name] = m
    return m


PARTS = []


def finish(obj, m, sub=2, name=None):
    if name:
        obj.name = name
    obj.data.materials.clear()
    obj.data.materials.append(m)
    if sub:
        mod = obj.modifiers.new("Sub", "SUBSURF")
        mod.levels = sub
        mod.render_levels = sub
    for p in obj.data.polygons:
        p.use_smooth = True
    PARTS.append(obj)
    return obj


def sphere(name, loc, scale, m, sub=1):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1, location=loc)
    o = bpy.context.object
    o.scale = scale
    return finish(o, m, sub, name)


def cube(name, loc, scale, m, sub=2, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=2, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = scale
    return finish(o, m, sub, name)


def cone(name, loc, r1, r2, depth, m, rot=(0, 0, 0), sub=2):
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    return finish(bpy.context.object, m, sub, name)


FUR = mat("Fur", "#F2A65A", 0.7)  # 치즈냥
FUR_LIGHT = mat("FurLight", "#FFF3E2", 0.7)
PINK = mat("Pink", "#FF9AA8", 0.6)
BLACK = mat("Eye", "#15131A", 0.15)
WHITE = mat("White", "#FFFFFF", 0.2)
VEST = mat("Vest", "#2FA36B", 0.6)  # 편의점 조끼 초록
SHIRT = mat("Shirt", "#F7F7F2", 0.6)
TAG = mat("Tag", "#FFD23F", 0.4)
PANTS = mat("Pants", "#2B2F3A", 0.7)

# 몸통 (셔츠 + 조끼)
cube("Body", (0, 0, 1.15), (0.55, 0.42, 0.62), SHIRT, sub=3)
cube("Vest", (0, 0, 1.1), (0.58, 0.45, 0.55), VEST, sub=3)
cube("VestGap", (0, -0.38, 1.16), (0.1, 0.1, 0.42), SHIRT, sub=2)
cube("NameTag", (-0.3, -0.44, 1.3), (0.16, 0.03, 0.09), TAG, sub=1)

# 다리
for side in (-1, 1):
    cube("Leg", (side * 0.27, 0, 0.32), (0.2, 0.22, 0.32), PANTS, sub=2)
    sphere("Foot", (side * 0.27, -0.06, 0.08), (0.24, 0.3, 0.14), FUR_LIGHT, sub=1)

# 팔 + 손
for side in (-1, 1):
    cube("Arm", (side * 0.6, 0, 1.18), (0.16, 0.17, 0.4), VEST, sub=2, rot=(0, side * math.radians(16), 0))
    sphere("Paw", (side * 0.72, -0.02, 0.76), (0.18, 0.18, 0.18), FUR_LIGHT, sub=1)

# 머리 (크게: 2.2등신)
sphere("Head", (0, 0, 2.28), (0.95, 0.85, 0.82), FUR, sub=1)
sphere("Muzzle", (0, -0.62, 2.05), (0.42, 0.3, 0.28), FUR_LIGHT, sub=1)
sphere("Nose", (0, -0.9, 2.19), (0.08, 0.05, 0.06), PINK, sub=1)
# 줄무늬 (머리 위 납작한 무늬)
STRIPE = mat("Stripe", "#D9813A", 0.7)
for x in (-0.25, 0, 0.25):
    sphere("Stripe", (x, -0.25, 2.98), (0.08, 0.3, 0.06), STRIPE, sub=1).rotation_euler = (math.radians(-28), 0, 0)
# 귀
for side in (-1, 1):
    cone("Ear", (side * 0.58, 0.02, 2.95), 0.4, 0.05, 0.7, FUR, rot=(math.radians(-6), side * math.radians(-22), 0))
    cone("EarIn", (side * 0.57, -0.12, 2.93), 0.25, 0.03, 0.5, PINK, rot=(math.radians(-6), side * math.radians(-22), 0))
# 눈 (반짝이 포함)
for side in (-1, 1):
    sphere("Eye", (side * 0.34, -0.72, 2.38), (0.13, 0.08, 0.17), BLACK, sub=1)
    sphere("EyeShine", (side * 0.34 - 0.04, -0.79, 2.45), (0.04, 0.02, 0.05), WHITE, sub=1)
    sphere("Cheek", (side * 0.55, -0.62, 2.11), (0.13, 0.05, 0.08), PINK, sub=1)
# 꼬리
bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0.45, 0.9))
tail = bpy.context.object
sp = tail.data.splines[0]
sp.bezier_points[0].co = (0, 0, 0)
sp.bezier_points[0].handle_right = (0, 0.5, 0.1)
sp.bezier_points[0].handle_left = (0, -0.2, 0)
sp.bezier_points[1].co = (0.25, 0.55, 0.9)
sp.bezier_points[1].handle_left = (0.1, 0.8, 0.4)
sp.bezier_points[1].handle_right = (0.35, 0.4, 1.2)
tail.data.bevel_depth = 0.09
tail.data.bevel_resolution = 4
tail.data.use_fill_caps = True
bpy.ops.object.convert(target="MESH")
finish(bpy.context.object, FUR, sub=1, name="Tail")

# ---- 미리보기 렌더 ----
bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
floor = bpy.context.object
floor.data.materials.append(mat("Floor", "#E6E8EE", 0.8))
world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (*srgb("#DDE3F0"), 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8

bpy.ops.object.light_add(type="AREA", location=(-3, -4, 5))
k = bpy.context.object
k.data.energy = 1200
k.data.size = 4
k.rotation_euler = (math.radians(45), 0, math.radians(-35))
bpy.ops.object.light_add(type="AREA", location=(3, 3, 4))
r = bpy.context.object
r.data.energy = 500
r.data.size = 3
r.rotation_euler = (math.radians(-45), 0, math.radians(140))

bpy.ops.object.camera_add(location=(2.6, -6.2, 2.6))
cam = bpy.context.object
cam.data.lens = 50
t = Vector((0, 0, 1.55))
cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.samples = 64
scene.render.resolution_x = 720
scene.render.resolution_y = 900
scene.view_settings.view_transform = "AgX"
scene.render.filepath = os.path.join(OUT, "cat_preview.png")
bpy.ops.render.render(write_still=True)

bpy.ops.object.select_all(action="DESELECT")
for o in PARTS:
    o.select_set(True)
bpy.context.view_layer.objects.active = PARTS[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "CatClerk.fbx"), use_selection=True,
                         apply_scale_options="FBX_SCALE_UNITS", use_mesh_modifiers=True, bake_space_transform=True)
print("DONE")
