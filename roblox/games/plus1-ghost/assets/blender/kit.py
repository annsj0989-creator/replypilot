"""+1 Ghost Escape 에셋 세트 (스타일: 둥글고 두툼한 장난감 느낌, 핼러윈 밤)
사용: python kit.py -- <out> preview|export
"""
import bpy, bmesh, math, sys, os
from mathutils import Vector as V

args = sys.argv[sys.argv.index("--") + 1:]
OUT, MODE = args[0], args[1]
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


_M = {}


def M(hexc, rough=0.55, metal=0.0, emit=0.0):
    key = (hexc, rough, metal, emit)
    if key in _M:
        return _M[key]
    m = bpy.data.materials.new(hexc)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*srgb(hexc), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*srgb(hexc), 1)
        b.inputs["Emission Strength"].default_value = emit
    _M[key] = m
    return m


ASSETS = {}  # name -> [objects]
CUR = []


def begin(name):
    global CUR
    CUR = []
    ASSETS[name] = CUR


def add(o, mat, bevel=0.0, sub=0, smooth=True):
    o.data.materials.clear()
    o.data.materials.append(mat)
    if bevel:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 3
        b.limit_method = "ANGLE"
    if sub:
        s = o.modifiers.new("Sub", "SUBSURF")
        s.levels = sub
        s.render_levels = sub
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    CUR.append(o)
    return o


def cube(loc, size, mat, bevel=0.15, rot=(0, 0, 0), sub=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return add(o, mat, bevel, sub)


def sphere(loc, r, mat, scale=(1, 1, 1), seg=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return add(o, mat)


def cyl(loc, r, depth, mat, rot=(0, 0, 0), verts=24, bevel=0.05, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    return add(bpy.context.object, mat, bevel)


def prism(points2d, depth, loc, mat, bevel=0.2, axis="Y"):
    """2D 외곽선(x,z)을 Y방향으로 두께를 줘서 세움"""
    bm = bmesh.new()
    f = [bm.verts.new((x, -depth / 2, z)) for x, z in points2d]
    b = [bm.verts.new((x, depth / 2, z)) for x, z in points2d]
    bm.faces.new(f)
    bm.faces.new(list(reversed(b)))
    n = len(points2d)
    for i in range(n):
        bm.faces.new((f[i], f[(i + 1) % n], b[(i + 1) % n], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("prism")
    bm.to_mesh(me)
    o = bpy.data.objects.new("prism", me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    return add(o, mat, bevel, smooth=False)


def tube(points, radii, mat, sub=1):
    """스킨 모디파이어로 굽은 관(나뭇가지, 사슬 등)"""
    me = bpy.data.meshes.new("tube")
    me.from_pydata(points, [(i, i + 1) for i in range(len(points) - 1)], [])
    o = bpy.data.objects.new("tube", me)
    bpy.context.collection.objects.link(o)
    sk = o.modifiers.new("Skin", "SKIN")
    for i, r in enumerate(radii):
        me.skin_vertices[0].data[i].radius = (r, r)
    me.skin_vertices[0].data[0].use_root = True
    s = o.modifiers.new("Sub", "SUBSURF")
    s.levels = sub
    s.render_levels = sub
    return add(o, mat)


def coffin_outline(w_top=1.9, w_sh=2.6, w_bot=1.5, h=9.0, sh=0.72):
    return [(-w_bot, 0), (w_bot, 0), (w_sh, h * sh), (w_top, h), (-w_top, h), (-w_sh, h * sh)]


def scaled(outline, k):
    cx = 0
    cz = sum(z for _, z in outline) / len(outline)
    return [(cx + (x - cx) * k, cz + (z - cz) * k) for x, z in outline]


# =================================================================== 관 3종
def coffin(name, body, lid, trim, accent, glow=None, gold=False):
    begin(name)
    rough = 0.25 if gold else 0.6
    metal = 0.9 if gold else 0.0
    cube((0, 0, 0.35), (6.4, 4.2, 0.7), M("#3E3A48", 0.8), 0.2)  # 받침
    cube((0, 0, 0.85), (5.6, 3.6, 0.4), M(trim, 0.4, 0.6 if not gold else 0.9), 0.1)
    o = coffin_outline()
    prism([(x, z + 1.05) for x, z in o], 2.4, (0, 0, 0), M(body, rough, metal), 0.28)
    prism([(x, z + 1.05) for x, z in scaled(o, 0.84)], 2.62, (0, 0, 0), M(lid, rough, metal), 0.18)
    # 십자가
    cube((0, -1.36, 6.1), (0.5, 0.18, 3.6), M(accent, 0.35, 0.3, glow or 0), 0.08)
    cube((0, -1.36, 6.9), (2.0, 0.18, 0.5), M(accent, 0.35, 0.3, glow or 0), 0.08)
    # 모서리 장식 (금속 징)
    for x, z in [(-1.6, 1.6), (1.6, 1.6), (-2.2, 7.4), (2.2, 7.4), (-1.6, 9.7), (1.6, 9.7)]:
        sphere((x * 0.92, -1.27, z), 0.2, M(trim, 0.3, 0.8))
    return CUR


coffin("CoffinWood", "#6E4325", "#8A5631", "#B8B2A6", "#F2E8D2")
c = coffin("CoffinCursed", "#3B2257", "#4E2E74", "#7A7A86", "#8CFFB8", glow=4)
# 사슬
for side in (-1, 1):
    pts = [(side * 2.5 + side * 0.05 * i, -1.35 + 0.05 * math.sin(i), 2.0 + i * 0.7) for i in range(9)]
    tube(pts, [0.12] * 9, M("#5E5E68", 0.35, 0.8))
c = coffin("CoffinGold", "#E0AE2E", "#F2C849", "#FFF1B0", "#D9283A", glow=0, gold=True)
sphere((0, -1.45, 6.9), 0.45, M("#E0203A", 0.1, 0.0, 2))  # 루비
for x in (-1.2, 1.2):
    sphere((x, -1.4, 4.0), 0.3, M("#3FB7FF", 0.1, 0.0, 1.5))


# =================================================================== 추격 유령 (크게)
def ghost_body(name, h=10.0, r=3.6, color="#EEF5FF", hem_waves=7):
    begin(name)
    # 몸통: 회전체 (윗부분 반구 + 아래로 벌어진 치마 + 물결 밑단)
    bm = bmesh.new()
    rings = 26
    seg = 48
    prof = []
    for i in range(rings + 1):
        t = i / rings
        if t < 0.45:  # 머리 반구
            a = (t / 0.45) * (math.pi / 2)
            prof.append((r * math.sin(a), h - r * (1 - math.cos(a)) * 1.0))
        else:  # 아래로 살짝 벌어짐
            u = (t - 0.45) / 0.55
            prof.append((r * (1 + 0.28 * u * u), h - r - u * (h - r)))
    prof[0] = (0.0, h)
    verts = []
    for i, (pr, pz) in enumerate(prof):
        ring = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            z = pz
            if i == rings:  # 밑단 물결
                z += 0.55 * math.sin(a * hem_waves)
            elif i == rings - 1:
                z += 0.3 * math.sin(a * hem_waves)
            ring.append(bm.verts.new((pr * math.cos(a), pr * math.sin(a), z)))
        verts.append(ring)
    for i in range(rings):
        for j in range(seg):
            a, b = verts[i][j], verts[i][(j + 1) % seg]
            c2, d = verts[i + 1][(j + 1) % seg], verts[i + 1][j]
            if i == 0:
                if a is not b:
                    pass
            bm.faces.new((a, b, c2, d)) if len({a, b, c2, d}) == 4 else None
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    sol = o.modifiers.new("Solid", "SOLIDIFY")
    sol.thickness = 0.15
    add(o, M(color, 0.45), sub=1)
    # 팔
    for side in (-1, 1):
        sphere((side * (r + 0.4), -0.6, h * 0.48), 0.95, M(color, 0.45), scale=(1.4, 0.8, 0.7))
    # 눈 (크고 까만) + 반짝임 + 입
    for side in (-1, 1):
        sphere((side * 1.25, -r * 0.88, h - r * 0.75), 0.75, M("#14121C", 0.15), scale=(0.8, 0.5, 1.15))
        sphere((side * 1.25 - 0.22, -r * 0.88 - 0.38, h - r * 0.55), 0.22, M("#FFFFFF", 0.1, 0, 2))
        sphere((side * 2.2, -r * 0.82, h - r * 1.15), 0.4, M("#FF9DB8", 0.5), scale=(1, 0.4, 0.6))
    sphere((0, -r * 0.92, h - r * 1.3), 0.6, M("#2A0F1E", 0.3), scale=(1.1, 0.5, 0.9))
    return CUR


ghost_body("GhostChaser")


# =================================================================== 맵 소품
begin("Tombstone")
prism([(-1.6, 0), (1.6, 0), (1.6, 3.6)] + [(1.6 * math.cos(a), 3.6 + 1.6 * math.sin(a)) for a in [i * math.pi / 10 for i in range(1, 10)]] + [(-1.6, 3.6)],
      0.9, (0, 0, 0.5), M("#8A8797", 0.85), 0.18)
cube((0, 0, 0.3), (4.2, 1.8, 0.6), M("#5C5968", 0.9), 0.15)
cube((0, -0.48, 3.4), (0.35, 0.12, 2.0), M("#5C5968", 0.9), 0.04)
cube((0, -0.48, 3.9), (1.3, 0.12, 0.35), M("#5C5968", 0.9), 0.04)
for i in range(5):
    sphere((-1.6 + i * 0.8, 0.3 * ((i % 2) * 2 - 1), 0.62), 0.35, M("#3F6B3A", 0.9), scale=(1.2, 1.2, 0.6))

begin("LanternPost")
cyl((0, 0, 3.0), 0.28, 6, M("#4A3326", 0.8), verts=10)
cyl((0, 0, 6.05), 0.6, 0.2, M("#2B2B2B", 0.5), verts=16)
sphere((0, 0, 6.95), 0.85, M("#FF8A2A", 0.4, 0, 3), scale=(1, 1, 1.2))
cyl((0, 0, 7.95), 0.5, 0.25, M("#C23A2A", 0.5), verts=16)
cyl((0, 0, 6.0), 0.5, 0.2, M("#C23A2A", 0.5), verts=16)
cyl((0, 0, 8.3), 0.12, 0.5, M("#2B2B2B", 0.5), verts=8)
cyl((0, 0, 0.25), 0.7, 0.5, M("#3E3A48", 0.8), verts=12)

begin("DeadTree")
tube([(0, 0, 0), (0.2, 0, 3), (0.1, 0.2, 6), (-0.3, 0.1, 9)], [1.0, 0.7, 0.5, 0.25], M("#3A2C28", 0.9), 2)
tube([(0.15, 0.1, 4.5), (1.6, 0.3, 6.2), (2.8, 0.2, 6.8)], [0.4, 0.22, 0.08], M("#3A2C28", 0.9), 2)
tube([(0.1, 0.15, 6.2), (-1.5, -0.2, 7.6), (-2.4, -0.3, 9.0)], [0.32, 0.18, 0.06], M("#3A2C28", 0.9), 2)
tube([(-0.2, 0.1, 8.0), (0.8, -0.4, 9.6), (1.2, -0.5, 10.4)], [0.22, 0.12, 0.05], M("#3A2C28", 0.9), 2)
for a in range(5):
    ang = a * 2 * math.pi / 5
    tube([(0, 0, 0.4), (1.6 * math.cos(ang), 1.6 * math.sin(ang), 0.0)], [0.55, 0.15], M("#3A2C28", 0.9), 1)

begin("RebirthStatue")
cyl((0, 0, 0.6), 4.2, 1.2, M("#4A4658", 0.8), verts=8, bevel=0.15)
cyl((0, 0, 1.6), 3.2, 0.8, M("#5C5868", 0.8), verts=8, bevel=0.12)
cyl((0, 0, 5.5), 1.4, 7.0, M("#6E6A7C", 0.7), verts=8, bevel=0.15, r2=1.0)
# 초승달 (호를 따라 가운데가 두꺼운 관)
arc_pts = []
arc_r = []
for i in range(15):
    t = i / 14
    ang = math.radians(-130 + 260 * t)
    arc_pts.append((2.6 * math.sin(ang), 0, 12.6 + 2.6 * math.cos(ang)))
    arc_r.append(0.12 + 0.75 * math.sin(math.pi * t))
tube(arc_pts, arc_r, M("#FFE08A", 0.3, 0.2, 2.5), 2)
sphere((0, 0, 9.6), 1.0, M("#B98CFF", 0.1, 0, 3))

begin("Treadmill")
cube((0, 0, 0.6), (22, 12, 1.2), M("#2C2C36", 0.6, 0.4), 0.3)
cube((0, 0, 1.25), (19, 10, 0.2), M("#16161C", 0.9), 0.05)
for x in (-9.5, 9.5):
    cyl((x, 0, 1.25), 0.7, 10.4, M("#8A8A98", 0.3, 0.9), rot=(math.pi / 2, 0, 0), verts=20)
for y in (-5.6, 5.6):
    cube((0, y, 1.5), (21, 0.6, 0.5), M("#9BE7FF", 0.3, 0, 2.5), 0.08)
cube((-10.6, 0, 3.5), (0.8, 10, 0.6), M("#2C2C36", 0.6, 0.4), 0.15)
for y in (-4.6, 4.6):
    cube((-10.6, y, 2.2), (0.6, 0.6, 3.2), M("#2C2C36", 0.6, 0.4), 0.1)

# =================================================================== 배치 / 미리보기
ORDER = ["CoffinWood", "CoffinCursed", "CoffinGold", "GhostChaser", "Tombstone", "LanternPost", "DeadTree", "RebirthStatue", "Treadmill"]


def place_row():
    x = 0
    pos = {}
    for name in ORDER:
        objs = ASSETS[name]
        xs = []
        for o in objs:
            bpy.context.view_layer.update()
            xs += [(o.matrix_world @ V(c)).x for c in o.bound_box]
        w = max(xs) - min(xs)
        dx = x - min(xs)
        for o in objs:
            o.location.x += dx
        pos[name] = x + w / 2
        x += w + 3
    return x


if MODE == "preview":
    width = place_row()
    bpy.ops.mesh.primitive_plane_add(size=400, location=(width / 2, 0, 0))
    fl = bpy.context.object
    fl.data.materials.append(M("#2A2438", 0.9))
    w = bpy.data.worlds.new("W")
    scene.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (*srgb("#2B2344"), 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.2
    bpy.ops.object.light_add(type="SUN")
    s = bpy.context.object
    s.data.energy = 2.2
    s.data.color = srgb("#C9C2FF")
    s.rotation_euler = (math.radians(55), 0, math.radians(-25))
    bpy.ops.object.light_add(type="AREA", location=(width / 2, -30, 25))
    a = bpy.context.object
    a.data.energy = 30000
    a.data.size = 40
    a.rotation_euler = (math.radians(50), 0, 0)
    bpy.ops.object.camera_add(location=(width / 2, -120, 9))
    cam = bpy.context.object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = width + 8
    cam.rotation_euler = (math.radians(86), 0, 0)
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.render.resolution_x = 2000
    scene.render.resolution_y = 420
    scene.view_settings.view_transform = "AgX"
    scene.render.filepath = os.path.join(OUT, "kit_preview.png")
    bpy.ops.render.render(write_still=True)
    print("DONE preview")


# =================================================================== 로블록스용 내보내기 (에셋별 메시 1개 + 색 텍스처)
def apply_all(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def export_asset(name, objs, size):
    for o in objs:
        apply_all(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    # 바닥 중심을 원점으로
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    bb = [o.matrix_world @ V(c) for c in o.bound_box]
    minz = min(p.z for p in bb)
    o.location = (0, 0, o.location.z - minz)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    tri_est = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if tri_est > 18000:
        d = o.modifiers.new("Dec", "DECIMATE")
        d.ratio = 17000 / tri_est
        bpy.ops.object.modifier_apply(modifier="Dec")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")
    tris = len(o.data.polygons)

    img = bpy.data.images.new(name + "_Color", size, size, alpha=False)
    saved = []
    for slot in o.material_slots:
        nt = slot.material.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        out = nt.nodes["Material Output"]
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = tuple(bsdf.inputs["Base Color"].default_value)
        orig = out.inputs["Surface"].links[0].from_socket
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        nt.nodes.active = tex
        saved.append((nt, orig, out, em, tex))
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.render.bake.margin = 6
    scene.render.bake.use_selected_to_active = False
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.bake(type="EMIT")
    img.filepath_raw = os.path.join(OUT, name + "_Color.png")
    img.file_format = "PNG"
    img.save()
    # 재질 하나로 교체 (텍스처만)
    o.data.materials.clear()
    m = bpy.data.materials.new(name + "_Mat")
    m.use_nodes = True
    t = m.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = img
    m.node_tree.links.new(t.outputs["Color"], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    o.data.materials.append(m)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, name + ".fbx"), use_selection=True,
                             apply_scale_options="FBX_SCALE_UNITS", path_mode="COPY", embed_textures=True)
    print("%s: %d tris" % (name, tris))
    bpy.data.objects.remove(o)


if MODE == "export":
    SIZES = {"GhostChaser": 1024, "CoffinWood": 1024, "CoffinCursed": 1024, "CoffinGold": 1024}
    for name in ORDER:
        export_asset(name, ASSETS[name], SIZES.get(name, 512))
    print("DONE export")
