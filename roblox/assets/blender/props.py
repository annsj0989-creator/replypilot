import bpy, bmesh, math, sys, os
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp"
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, rgb, rough=0.5, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def bevel(obj, w=0.04, seg=4):
    m = obj.modifiers.new("Bevel", "BEVEL")
    m.width = w
    m.segments = seg
    m.limit_method = "ANGLE"
    return m


def smooth(obj):
    for p in obj.data.polygons:
        p.use_smooth = True


def assign(obj, m):
    obj.data.materials.clear()
    obj.data.materials.append(m)


# ---------- 삼각김밥 ----------
def rounded_triangle(name, size=1.0, depth=0.42, r=0.22, seg=10):
    bm = bmesh.new()
    pts = []
    corners = [Vector((0, size * 0.62)), Vector((-size * 0.55, -size * 0.38)), Vector((size * 0.55, -size * 0.38))]
    center = (corners[0] + corners[1] + corners[2]) / 3
    for i, c in enumerate(corners):
        prev = corners[i - 1]
        nxt = corners[(i + 1) % 3]
        d1 = (prev - c).normalized()
        d2 = (nxt - c).normalized()
        ang = math.acos(max(-1, min(1, d1.dot(d2))))
        dist = r / math.tan(ang / 2)
        p1 = c + d1 * dist
        p2 = c + d2 * dist
        bis = (d1 + d2).normalized()
        cc = c + bis * (r / math.sin(ang / 2))
        a1 = math.atan2(p1.y - cc.y, p1.x - cc.x)
        a2 = math.atan2(p2.y - cc.y, p2.x - cc.x)
        da = a2 - a1
        while da > math.pi:
            da -= 2 * math.pi
        while da < -math.pi:
            da += 2 * math.pi
        for s in range(seg + 1):
            a = a1 + da * s / seg
            pts.append(Vector((cc.x + r * math.cos(a), cc.y + r * math.sin(a))))
    # 반시계 방향 정렬
    verts_f = [bm.verts.new((p.x - center.x, -depth / 2, p.y)) for p in pts]
    verts_b = [bm.verts.new((p.x - center.x, depth / 2, p.y)) for p in pts]
    bm.faces.new(verts_f)
    bm.faces.new(list(reversed(verts_b)))
    n = len(pts)
    for i in range(n):
        bm.faces.new((verts_f[i], verts_f[(i + 1) % n], verts_b[(i + 1) % n], verts_b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return obj


rice = rounded_triangle("Onigiri_Rice")
bevel(rice, 0.08, 5)
smooth(rice)
assign(rice, mat("Rice", srgb("#F4F1EA"), 0.85))

# 김 (아래쪽 띠)
nori = rounded_triangle("Onigiri_Nori", size=1.0, depth=0.44, r=0.22)
bevel(nori, 0.08, 5)
smooth(nori)
assign(nori, mat("Nori", srgb("#1E2A22"), 0.55))
# 김은 아래 절반만 남기기
bm = bmesh.new()
bm.from_mesh(nori.data)
geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, -0.1), plane_no=(0, 0, 1), clear_outer=True)
bmesh.ops.holes_fill(bm, edges=bm.edges[:], sides=0)
bm.to_mesh(nori.data)
bm.free()
nori.scale = (1.02, 1.0, 1.02)
nori.location.z -= 0.005

# 라벨 스티커
bpy.ops.mesh.primitive_cube_add(size=1)
label = bpy.context.object
label.name = "Onigiri_Label"
label.scale = (0.42, 0.012, 0.16)
label.location = (0, -0.226, 0.06)
bevel(label, 0.01, 2)
assign(label, mat("Label", srgb("#E8352E"), 0.4))
bpy.ops.mesh.primitive_cube_add(size=1)
stripe = bpy.context.object
stripe.name = "Onigiri_LabelStripe"
stripe.scale = (0.42, 0.014, 0.045)
stripe.location = (0, -0.228, 0.06)
assign(stripe, mat("LabelStripe", srgb("#FFD23F"), 0.4))

onigiri = [rice, nori, label, stripe]
for o in onigiri:
    o.location.x -= 0.75

# ---------- 컵라면 ----------
bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=0.42, radius2=0.52, depth=0.95, location=(0.75, 0, 0.475 - 0.38))
cup = bpy.context.object
cup.name = "Ramen_Cup"
bevel(cup, 0.03, 3)
smooth(cup)
assign(cup, mat("CupRed", srgb("#D7262B"), 0.35))

bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=0.4285, radius2=0.4625, depth=0.32, location=(0.75, 0, -0.38 + 0.04 + 0.16))
band = bpy.context.object
band.name = "Ramen_Band"
smooth(band)
band.scale = (1.012, 1.012, 1)
assign(band, mat("CupWhite", srgb("#FAF7F2"), 0.4))

bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.55, depth=0.05, location=(0.75, 0, 0.95 - 0.38 + 0.02))
lid = bpy.context.object
lid.name = "Ramen_Lid"
bevel(lid, 0.02, 3)
smooth(lid)
assign(lid, mat("Lid", srgb("#C9CCD1"), 0.25, 0.8))

bpy.ops.mesh.primitive_cube_add(size=1, location=(0.75, -0.62, 0.95 - 0.38 + 0.02))
tab = bpy.context.object
tab.name = "Ramen_LidTab"
tab.scale = (0.16, 0.14, 0.012)
bevel(tab, 0.02, 2)
assign(tab, lid.data.materials[0])

# 라면 노란 줄무늬 (위쪽)
bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=0.4925, radius2=0.5045, depth=0.12, location=(0.75, 0, -0.38 + 0.68 + 0.06))
logo = bpy.context.object
logo.name = "Ramen_Stripe"
smooth(logo)
logo.scale = (1.012, 1.012, 1)
assign(logo, mat("Logo", srgb("#FFD23F"), 0.4))

ramen = [cup, band, lid, tab, logo]

# ---------- 바닥, 조명, 카메라 (미리보기용) ----------
bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, -0.38))
floor = bpy.context.object
assign(floor, mat("Floor", srgb("#2B2F3A"), 0.6))

world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (*srgb("#1A1D26"), 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6

bpy.ops.object.light_add(type="AREA", location=(-2.5, -3, 4))
key = bpy.context.object
key.data.energy = 600
key.data.size = 3
key.rotation_euler = (math.radians(50), 0, math.radians(-35))
bpy.ops.object.light_add(type="AREA", location=(3, 2, 3))
rim = bpy.context.object
rim.data.energy = 250
rim.data.color = srgb("#9FC7FF")
rim.data.size = 2
rim.rotation_euler = (math.radians(-50), 0, math.radians(140))

bpy.ops.object.camera_add(location=(0.4, -4.2, 1.9))
cam = bpy.context.object
cam.data.lens = 50
target = Vector((0, 0, 0.1))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.samples = 64
scene.cycles.device = "CPU"
scene.render.resolution_x = 960
scene.render.resolution_y = 640
scene.view_settings.view_transform = "AgX"
scene.render.filepath = os.path.join(OUT, "props_preview.png")
bpy.ops.render.render(write_still=True)


# ---------- 내보내기 (로블록스용 FBX) ----------
def export(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, name + ".fbx"),
        use_selection=True,
        apply_scale_options="FBX_SCALE_UNITS",
        use_mesh_modifiers=True,
        bake_space_transform=True,
    )


export(onigiri, "Onigiri")
export(ramen, "CupRamen")
print("DONE")
