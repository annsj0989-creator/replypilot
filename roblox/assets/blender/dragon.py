import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else "/tmp/dragon"
MODE = args[1] if len(args) > 1 else "preview"  # preview | export
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
V = Vector


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def link(obj):
    bpy.context.collection.objects.link(obj)
    return obj


def apply_mods(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def smooth_all(obj):
    for p in obj.data.polygons:
        p.use_smooth = True


# ---------------------------------------------------------------- 재질
def node_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    return m, nt, nt.nodes["Principled BSDF"]


def scale_material():
    m, nt, bsdf = node_mat("GoldScales")
    N = nt.nodes
    L = nt.links
    tc = N.new("ShaderNodeTexCoord")
    mapping = N.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (8, 8, 10)
    L.new(tc.outputs["Object"], mapping.inputs["Vector"])
    vor = N.new("ShaderNodeTexVoronoi")
    vor.feature = "F1"
    vor.inputs["Scale"].default_value = 1.0
    vor.inputs["Randomness"].default_value = 0.85
    L.new(mapping.outputs["Vector"], vor.inputs["Vector"])
    edge = N.new("ShaderNodeTexVoronoi")
    edge.feature = "DISTANCE_TO_EDGE"
    edge.inputs["Scale"].default_value = 1.0
    edge.inputs["Randomness"].default_value = 0.85
    L.new(mapping.outputs["Vector"], edge.inputs["Vector"])

    # 비늘 색: 가운데 밝은 금 -> 가장자리 진한 금, 비늘 사이 틈은 어둡게
    body_ramp = N.new("ShaderNodeValToRGB")
    body_ramp.color_ramp.elements[0].position = 0.0
    body_ramp.color_ramp.elements[0].color = (*srgb("#F7D98A"), 1)
    body_ramp.color_ramp.elements[1].position = 0.6
    body_ramp.color_ramp.elements[1].color = (*srgb("#A86E1E"), 1)
    L.new(vor.outputs["Distance"], body_ramp.inputs["Fac"])
    gap = N.new("ShaderNodeMapRange")
    gap.inputs["From Min"].default_value = 0.0
    gap.inputs["From Max"].default_value = 0.06
    gap.inputs["To Min"].default_value = 0.18
    gap.inputs["To Max"].default_value = 1.0
    L.new(edge.outputs["Distance"], gap.inputs["Value"])
    ramp = N.new("ShaderNodeMix")
    ramp.data_type = "RGBA"
    ramp.blend_type = "MULTIPLY"
    ramp.inputs["Factor"].default_value = 1.0
    L.new(body_ramp.outputs["Color"], ramp.inputs[6])
    L.new(gap.outputs["Result"], ramp.inputs[7])
    ramp.outputs[2].name  # noqa

    # 배 쪽: 밝은 크림색 가로 띠
    geo = N.new("ShaderNodeNewGeometry")
    sep = N.new("ShaderNodeSeparateXYZ")
    vt = N.new("ShaderNodeVectorTransform")
    vt.vector_type = "NORMAL"
    vt.convert_from = "WORLD"
    vt.convert_to = "OBJECT"
    L.new(geo.outputs["Normal"], vt.inputs["Vector"])
    L.new(vt.outputs["Vector"], sep.inputs["Vector"])
    belly = N.new("ShaderNodeMapRange")
    belly.inputs["From Min"].default_value = -0.15
    belly.inputs["From Max"].default_value = -0.55
    L.new(sep.outputs["Z"], belly.inputs["Value"])
    wave = N.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "X"
    wave.inputs["Scale"].default_value = 1.6
    wave.inputs["Distortion"].default_value = 0.3
    L.new(tc.outputs["Object"], wave.inputs["Vector"])
    band = N.new("ShaderNodeValToRGB")
    band.color_ramp.elements[0].color = (*srgb("#9C7A45"), 1)
    band.color_ramp.elements[0].position = 0.05
    band.color_ramp.elements[1].color = (*srgb("#EEDDB3"), 1)
    band.color_ramp.elements[1].position = 0.3
    L.new(wave.outputs["Fac"], band.inputs["Fac"])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    L.new(belly.outputs["Result"], mix.inputs["Factor"])
    L.new(ramp.outputs[2], mix.inputs[6])
    L.new(band.outputs["Color"], mix.inputs[7])
    L.new(mix.outputs[2], bsdf.inputs["Base Color"])

    metal = N.new("ShaderNodeMapRange")
    metal.inputs["To Min"].default_value = 0.9
    metal.inputs["To Max"].default_value = 0.15
    L.new(belly.outputs["Result"], metal.inputs["Value"])
    L.new(metal.outputs["Result"], bsdf.inputs["Metallic"])
    bsdf.inputs["Roughness"].default_value = 0.3

    # 비늘 입체감 (bump)
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.8
    bump.inputs["Distance"].default_value = 0.025
    scalebump = N.new("ShaderNodeMapRange")
    scalebump.inputs["From Min"].default_value = 0.0
    scalebump.inputs["From Max"].default_value = 0.55
    scalebump.inputs["To Min"].default_value = 1.0
    scalebump.inputs["To Max"].default_value = 0.0
    L.new(vor.outputs["Distance"], scalebump.inputs["Value"])
    bandbump = N.new("ShaderNodeMix")
    bandbump.data_type = "FLOAT"
    L.new(belly.outputs["Result"], bandbump.inputs["Factor"])
    L.new(scalebump.outputs["Result"], bandbump.inputs[2])
    L.new(wave.outputs["Fac"], bandbump.inputs[3])
    L.new(bandbump.outputs[0], bump.inputs["Height"])
    L.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def membrane_material():
    m, nt, bsdf = node_mat("WingMembrane")
    N, L = nt.nodes, nt.links
    tc = N.new("ShaderNodeTexCoord")
    noise = N.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 1.4
    noise.inputs["Detail"].default_value = 8
    noise.inputs["Roughness"].default_value = 0.6
    L.new(tc.outputs["Object"], noise.inputs["Vector"])
    vein = N.new("ShaderNodeTexVoronoi")
    vein.feature = "DISTANCE_TO_EDGE"
    vein.inputs["Scale"].default_value = 2.2
    L.new(tc.outputs["Object"], vein.inputs["Vector"])
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*srgb("#3A0806"), 1)
    ramp.color_ramp.elements[1].color = (*srgb("#9E1E12"), 1)
    e = ramp.color_ramp.elements.new(0.85)
    e.color = (*srgb("#C8401E"), 1)
    L.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    veinramp = N.new("ShaderNodeMapRange")
    veinramp.inputs["From Min"].default_value = 0.0
    veinramp.inputs["From Max"].default_value = 0.025
    veinramp.inputs["To Min"].default_value = 0.8
    veinramp.inputs["To Max"].default_value = 1.0
    L.new(vein.outputs["Distance"], veinramp.inputs["Value"])
    mul = N.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    L.new(ramp.outputs["Color"], mul.inputs[6])
    L.new(veinramp.outputs["Result"], mul.inputs[7])
    L.new(mul.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.65
    bsdf.inputs["Subsurface Weight"].default_value = 0.2
    bsdf.inputs["Subsurface Radius"].default_value = (0.8, 0.2, 0.1)
    return m


def simple_mat(name, hexc, rough=0.4, metal=0.0, emit=None):
    m, nt, bsdf = node_mat(name)
    bsdf.inputs["Base Color"].default_value = (*srgb(hexc), 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*srgb(emit), 1)
        bsdf.inputs["Emission Strength"].default_value = 6
    return m


SCALES = scale_material()
MEMBRANE = membrane_material()
HORN = simple_mat("Horn", "#E9D3A2", 0.35, 0.3)
CLAW = simple_mat("Claw", "#F1E6CC", 0.3, 0.1)
EYE = simple_mat("Eye", "#FF2A10", 0.1, 0.0, emit="#FF3A10")
MOUTH = simple_mat("Mouth", "#5A0E0E", 0.5)
TOOTH = simple_mat("Tooth", "#FBF6EA", 0.25)


# ---------------------------------------------------------------- 스킨 모디파이어로 몸 만들기
def skin_body(name, chains, root):
    """chains: [[(pos, radius), ...], ...] 같은 좌표는 하나의 정점으로 합쳐짐"""
    verts, radii, edges = [], [], []
    index = {}

    def vid(p, r):
        key = tuple(round(c, 4) for c in p)
        if key not in index:
            index[key] = len(verts)
            verts.append(V(p))
            radii.append(r)
        return index[key]

    for chain in chains:
        prev = None
        for p, r in chain:
            i = vid(p, r)
            if prev is not None and prev != i:
                edges.append((prev, i))
            prev = i
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], edges, [])
    obj = link(bpy.data.objects.new(name, me))
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    for i, r in enumerate(radii):
        sv = me.skin_vertices[0].data[i]
        sv.radius = (r[0], r[1]) if isinstance(r, tuple) else (r, r)
    me.skin_vertices[0].data[index[tuple(round(c, 4) for c in root)]].use_root = True
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    obj.data.materials.append(SCALES)
    return obj


def lerp_chain(points, steps=3):
    """점 사이를 촘촘하게 (반지름도 보간). 부드러운 몸통을 위해."""
    out = []
    for i in range(len(points) - 1):
        (p0, r0), (p1, r1) = points[i], points[i + 1]
        for s in range(steps):
            t = s / steps
            p = V(p0).lerp(V(p1), t)
            if isinstance(r0, tuple):
                r = (r0[0] + (r1[0] - r0[0]) * t, r0[1] + (r1[1] - r0[1]) * t)
            else:
                r = r0 + (r1 - r0) * t
            out.append((tuple(p), r))
    out.append(points[-1])
    return out


def catmull(points, steps=4):
    """부드러운 곡선 경로 (Catmull-Rom)."""
    pts = [V(p) for p, _ in points]
    rs = [r for _, r in points]
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[max(i - 1, 0)]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[min(i + 2, len(pts) - 1)]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            p = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            r0, r1 = rs[i], rs[i + 1]
            if isinstance(r0, tuple):
                r = (r0[0] + (r1[0] - r0[0]) * t, r0[1] + (r1[1] - r0[1]) * t)
            else:
                r = r0 + (r1 - r0) * t
            out.append((tuple(p), r))
    out.append((tuple(pts[-1]), rs[-1]))
    return out


# 머리는 -X 방향을 본다. 반지름 (가로, 세로)
SPINE = catmull([
    ((-3.7, 0, 6.45), (0.18, 0.14)),    # 코끝
    ((-3.15, 0, 6.62), (0.34, 0.27)),
    ((-2.6, 0, 6.85), (0.48, 0.42)),    # 눈 위치
    ((-2.1, 0, 6.95), (0.55, 0.5)),     # 뒷머리
    ((-1.75, 0, 6.5), (0.45, 0.48)),    # 목 (S자)
    ((-1.6, 0, 5.75), (0.52, 0.56)),
    ((-1.95, 0, 4.95), (0.62, 0.68)),
    ((-1.7, 0, 4.05), (0.95, 1.0)),     # 가슴
    ((-0.9, 0, 3.35), (1.15, 1.2)),
    ((0.3, 0, 3.15), (1.2, 1.2)),       # 배
    ((1.5, 0, 3.15), (1.0, 1.0)),       # 골반
    ((2.6, 0, 2.75), (0.78, 0.75)),     # 꼬리 시작
    ((3.8, 0.1, 2.0), (0.56, 0.52)),
    ((5.0, 0.35, 1.3), (0.4, 0.36)),
    ((6.1, 0.8, 0.95), (0.27, 0.24)),
    ((6.9, 1.4, 1.1), (0.18, 0.16)),
    ((7.25, 1.9, 1.65), (0.11, 0.1)),
    ((7.2, 2.1, 2.2), (0.04, 0.04)),    # 꼬리 끝 말림
], steps=4)

ROOT = (0.3, 0, 3.15)

FRONT_TOE = (-2.0, 1.05, 0.2)
HIND_TOE = (0.9, 1.15, 0.22)

chains = [SPINE]
for side in (1, -1):
    # 앞다리: 굵은 어깨 -> 팔꿈치 -> 손목 -> 발 -> 발가락
    chains.append(catmull([
        ((-1.1, side * 0.25, 3.4), 0.7),
        ((-1.15, side * 0.75, 3.0), 0.7),
        ((-0.85, side * 1.05, 1.95), 0.48),
        ((-1.25, side * 1.05, 0.65), 0.32),
        ((-1.6, side * 1.05, 0.3), 0.36),
        ((FRONT_TOE[0], side * FRONT_TOE[1], FRONT_TOE[2]), 0.26),
    ], 3))
    # 뒷다리: 두꺼운 허벅지, 무릎 앞, 발목 뒤
    chains.append(catmull([
        ((1.5, side * 0.25, 3.1), 0.85),
        ((1.45, side * 0.8, 2.85), 0.9),
        ((0.8, side * 1.15, 1.9), 0.62),
        ((1.65, side * 1.15, 0.95), 0.36),
        ((1.3, side * 1.15, 0.32), 0.38),
        ((HIND_TOE[0], side * HIND_TOE[1], HIND_TOE[2]), 0.26),
    ], 3))
    # 날개 팔 (어깨에서) - 별도 뼈 메시에서 처리
def tube(name, chain):
    root = chain[0][0]
    o = skin_body(name, [chain], root)
    o.modifiers["Sub"].levels = 1
    apply_mods(o)
    return o


parts = [tube("Spine", SPINE)]
for i, c in enumerate(chains[1:]):
    parts.append(tube("Limb%d" % i, c))


def fuse(name, objs, voxel=0.045, smooth_iter=6):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    rm = o.modifiers.new("Remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = voxel
    sm = o.modifiers.new("Smooth", "SMOOTH")
    sm.factor = 0.6
    sm.iterations = smooth_iter
    apply_mods(o)
    smooth_all(o)
    o.data.materials.clear()
    o.data.materials.append(SCALES)
    return o


body = fuse("DragonBody", parts)

# 아래턱 (살짝 벌린 입)
jaw = skin_body("DragonJaw", [catmull([
    ((-2.2, 0, 6.6), (0.36, 0.24)),
    ((-2.75, 0, 6.38), (0.28, 0.16)),
    ((-3.3, 0, 6.22), (0.18, 0.1)),
], steps=3)], (-2.2, 0, 6.6))

# ---------------------------------------------------------------- 날개
WING_SHOULDER = V((-0.9, 0.6, 4.0))
WING_ELBOW = V((0.2, 1.7, 5.65))
WING_WRIST = V((0.6, 2.4, 7.85))
FINGER_TIPS = [V((-0.6, 3.6, 9.05)), V((3.4, 4.6, 8.65)), V((5.4, 4.4, 5.85)), V((5.3, 3.7, 3.15)), V((3.6, 2.9, 2.2))]
WING_BODY = V((1.4, 0.8, 3.6))


def mirror(v, side):
    return V((v.x, v.y * side, v.z))


def wing(side):
    sh, el, wr = mirror(WING_SHOULDER, side), mirror(WING_ELBOW, side), mirror(WING_WRIST, side)
    tips = [mirror(t, side) for t in FINGER_TIPS]
    # 뼈대
    bones = [catmull([(tuple(sh), 0.3), (tuple(el), 0.2), (tuple(wr), 0.16)], 3)]
    for t in tips:
        mid = wr.lerp(t, 0.5) + V((0, 0, 0.25))
        bones.append(catmull([(tuple(wr), 0.13), (tuple(mid), 0.08), (tuple(t), 0.03)], 3))
    bone_obj = skin_body("WingBones" + ("R" if side > 0 else "L"), bones, tuple(sh))
    # 꼭짓점 발톱
    claw_mesh(wr + V((-0.25, 0, 0.3)), V((-0.6, 0, 1.0)), 0.12, 0.5)

    # 막: 손가락 사이를 안쪽으로 휜 가장자리로 채움
    bm = bmesh.new()
    center = bm.verts.new(wr)
    def scallop(a, b, k=10, sag=0.3):
        ctrl = a.lerp(b, 0.5).lerp(wr, sag)
        pts = []
        for i in range(k + 1):
            t = i / k
            p = (1 - t) ** 2 * a + 2 * (1 - t) * t * ctrl + t * t * b
            pts.append(p)
        return pts
    ring = []
    for i in range(len(tips) - 1):
        seg = scallop(tips[i], tips[i + 1])
        ring.extend(seg if i == 0 else seg[1:])
    # 마지막 손가락 → 몸통 → 팔꿈치 → 손목
    tail_seg = scallop(tips[-1], mirror(WING_BODY, side), 10, 0.25)
    ring.extend(tail_seg[1:])
    body_to_elbow = [mirror(WING_BODY, side).lerp(el, t / 6) for t in range(1, 7)]
    ring.extend(body_to_elbow)
    rv = [bm.verts.new(p) for p in ring]
    for i in range(len(rv) - 1):
        bm.faces.new((center, rv[i], rv[i + 1]))
    # 손목-첫 손가락 사이 (앞쪽 막)
    front = [el.lerp(wr, t / 4) for t in range(0, 5)]
    # 세분화
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
    me = bpy.data.meshes.new("WingMembrane")
    bm.to_mesh(me)
    bm.free()
    mem = link(bpy.data.objects.new("WingMembrane" + ("R" if side > 0 else "L"), me))
    # 바람에 부푼 느낌: 뒤쪽으로 살짝 볼록
    for v in mem.data.vertices:
        d = (v.co - wr).length
        v.co += V((0.0, -side * 0.12 * math.sin(min(d / 5.5, 1) * math.pi), 0))
    sol = mem.modifiers.new("Solid", "SOLIDIFY")
    sol.thickness = 0.04
    mem.modifiers.new("Sub", "SUBSURF").levels = 1
    smooth_all(mem)
    mem.data.materials.append(MEMBRANE)
    return bone_obj, mem


EXTRA = []


def cone_between(a, b, r, mat, verts=10):
    a, b = V(a), V(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=0.0, depth=d.length,
                                    location=(a + b) / 2)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(mat)
    smooth_all(o)
    EXTRA.append(o)
    return o


def claw_mesh(base, direction, r, length):
    return cone_between(base, V(base) + V(direction).normalized() * length, r, CLAW)


def curved_horn(points, r0, mat):
    cu = bpy.data.curves.new("Horn", "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (*p, 1)
        sp.points[i].radius = max(0.02, 1 - i / (len(points) - 1))
    cu.bevel_depth = r0
    cu.bevel_resolution = 3
    cu.use_fill_caps = True
    o = link(bpy.data.objects.new("Horn", cu))
    o.data.materials.append(mat)
    EXTRA.append(o)
    return o


def arc(a, b, lift, n=8):
    a, b, lift = V(a), V(b), V(lift)
    return [tuple(a.lerp(b, i / (n - 1)) + lift * math.sin(math.pi * i / (n - 1))) for i in range(n)]


HEAD_START = len(EXTRA)
# 뿔: 뒤로 휘어진 큰 뿔 2쌍 + 작은 가시
for side in (1, -1):
    curved_horn(arc((-2.25, side * 0.28, 7.75), (-0.9, side * 0.55, 8.9), (0.15, 0, 0.35), 10), 0.13, HORN)
    curved_horn(arc((-2.0, side * 0.36, 7.6), (-1.1, side * 0.75, 8.2), (0.1, 0, 0.2), 8), 0.08, HORN)
    for i in range(4):
        base = V((-2.55 + i * 0.18, side * 0.38, 7.25 - i * 0.05))
        cone_between(base, base + V((0.35, side * 0.25, -0.1)), 0.05, HORN, 6)
    # 눈
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.08, location=(-2.72, side * 0.27, 7.5))
    eye = bpy.context.object
    eye.scale = (1.3, 0.6, 0.7)
    eye.data.materials.append(EYE)
    EXTRA.append(eye)
    # 눈썹 뼈
    cone_between((-2.85, side * 0.25, 7.62), (-2.35, side * 0.32, 7.72), 0.07, SCALES, 8)
    # 이빨
    for i in range(6):
        x = -3.55 + i * 0.2
        up = V((x, side * (0.09 + i * 0.025), 6.98 + i * 0.03))
        cone_between(up, up + V((0, 0, -0.14)), 0.03, TOOTH, 6)
        lo = V((x + 0.08, side * (0.07 + i * 0.022), 6.86 + i * 0.03))
        cone_between(lo, lo + V((0, 0, 0.12)), 0.025, TOOTH, 6)

for side in (1, -1):
    for j in range(7):
        ang = math.radians(-35 + j * 14)
        base = V((-2.05 + j * 0.05, side * 0.42, 7.35 - j * 0.12))
        d = V((math.cos(ang) * 0.55 + 0.25, side * 0.45, math.sin(ang) * 0.5))
        cone_between(base, base + d * (0.9 - j * 0.07), 0.07, HORN, 6)
for o in EXTRA[HEAD_START:]:
    o.location += V((0.05, 0, -0.55))

# 등/목/꼬리 가시
for i, (p, r) in enumerate(SPINE):
    if i < 18 or i % 3:
        continue
    p = V(p)
    rz = r[1] if isinstance(r, tuple) else r
    if rz < 0.06:
        continue
    nxt = V(SPINE[min(i + 1, len(SPINE) - 1)][0])
    back = (nxt - p).normalized() if (nxt - p).length > 0 else V((1, 0, 0))
    up = V((0, 0, 1))
    tip = p + up * (rz * 1.3 + 0.1) + back * 0.3
    cone_between(p + up * (rz * 0.85), tip, max(0.05, rz * 0.18), HORN, 6)

# 발톱
for side in (1, -1):
    for toe in (FRONT_TOE, HIND_TOE):
        toe = V((toe[0], side * toe[1], toe[2]))
        for k in (-1, 0, 1):
            base = toe + V((-0.12, k * 0.17, 0.0))
            claw_mesh(base, V((-1, k * 0.3, -0.5)), 0.07, 0.36)

wings = [wing(1), wing(-1)]

# ---------------------------------------------------------------- 미리보기
if MODE == "preview":
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    floor = bpy.context.object
    floor.data.materials.append(simple_mat("Floor", "#3B3834", 0.7))
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (*srgb("#5A544C"), 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
    bpy.ops.object.light_add(type="SUN", location=(0, 0, 10))
    sun = bpy.context.object
    sun.data.energy = 5.0
    sun.data.color = srgb("#FFE9C8")
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(50), math.radians(-10), math.radians(-60))
    bpy.ops.object.light_add(type="AREA", location=(6, 6, 6))
    rim = bpy.context.object
    rim.data.energy = 3000
    rim.data.color = srgb("#BFD8FF")
    rim.data.size = 6
    rim.rotation_euler = (math.radians(-50), 0, math.radians(135))

    cam_pos = V(args[2].split(",")) if len(args) > 2 else None
    bpy.ops.object.camera_add(location=tuple(float(c) for c in cam_pos) if cam_pos else (-9.5, -15.5, 6.0))
    cam = bpy.context.object
    cam.data.lens = 42
    target = V((1.0, 0.5, 4.2))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.samples = int(args[3]) if len(args) > 3 else 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.view_settings.view_transform = "AgX"
    scene.render.filepath = os.path.join(OUT, "dragon_preview.png")
    bpy.ops.render.render(write_still=True)
    print("DONE preview")


# ================================================================ 로블록스용 내보내기
def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def join(name, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        if o.type == "CURVE":
            bpy.context.view_layer.objects.active = o
            o.select_set(True)
            bpy.ops.object.convert(target="MESH")
            o = bpy.context.object
        o.select_set(True)
    for o in objs:
        if o.type == "MESH":
            apply_mods(o)
    bpy.ops.object.select_all(action="DESELECT")
    meshes = [o for o in bpy.data.objects if o in objs or o.name in [x.name for x in objs]]
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    out = bpy.context.object
    out.name = name
    return out


def decimate_to(o, target):
    t = tri_count(o)
    if t > target:
        d = o.modifiers.new("Dec", "DECIMATE")
        d.ratio = target / t
        apply_mods(o)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.object.mode_set(mode="OBJECT")
    return o


def uv_unwrap(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")


def new_image(name, size, non_color=False):
    img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def set_bake_target(objs, img):
    for o in objs:
        for slot in o.material_slots:
            nt = slot.material.node_tree
            for n in [n for n in nt.nodes if n.name == "BakeTarget"]:
                nt.nodes.remove(n)
            n = nt.nodes.new("ShaderNodeTexImage")
            n.name = "BakeTarget"
            n.image = img
            nt.nodes.active = n


def bake(low, high, kind, img, extrusion=0.06):
    set_bake_target([low] + ([high] if high else []), img)
    bpy.ops.object.select_all(action="DESELECT")
    if high:
        high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    sb = scene.render.bake
    sb.use_selected_to_active = high is not None
    sb.cage_extrusion = extrusion
    sb.margin = 8
    if kind == "DIFFUSE":
        sb.use_pass_direct = False
        sb.use_pass_indirect = False
        sb.use_pass_color = True
    bpy.ops.object.bake(type=kind)
    img.filepath_raw = os.path.join(OUT, img.name + ".png")
    img.file_format = "PNG"
    img.save()


def swap_to_emission(objs, socket_name):
    """금속도/거칠기를 굽기 위해 해당 값을 Emission으로 잠깐 연결"""
    saved = []
    for o in objs:
        for slot in o.material_slots:
            nt = slot.material.node_tree
            bsdf = nt.nodes.get("Principled BSDF")
            out = nt.nodes.get("Material Output")
            em = nt.nodes.new("ShaderNodeEmission")
            em.name = "TmpEmit"
            src = bsdf.inputs[socket_name]
            if src.is_linked:
                nt.links.new(src.links[0].from_socket, em.inputs["Color"])
            else:
                v = src.default_value
                if hasattr(v, "__len__"):
                    em.inputs["Color"].default_value = tuple(v)
                else:
                    em.inputs["Color"].default_value = (v, v, v, 1)
            orig = out.inputs["Surface"].links[0].from_socket
            nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
            saved.append((nt, orig, out, em))
    return saved


def restore(saved):
    for nt, orig, out, em in saved:
        nt.links.new(orig, out.inputs["Surface"])
        nt.nodes.remove(em)


def bake_set(name, low, high, size, normal=True):
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 4
    color = new_image(name + "_Color", size)
    src = [high] if high else [low]
    saved = swap_to_emission(src, "Base Color")
    bake(low, high, "EMIT", color)
    restore(saved)
    if normal:
        nrm = new_image(name + "_Normal", size, True)
        bake(low, high, "NORMAL", nrm)
    src = [high] if high else [low]
    for socket, suffix in (("Metallic", "Metalness"), ("Roughness", "Roughness")):
        img = new_image(name + "_" + suffix, size // 2, True)
        saved = swap_to_emission(src, socket)
        bake(low, high, "EMIT", img)
        restore(saved)


if MODE == "export":
    report = []
    # 1) 몸통 (몸 + 턱): 고해상도 -> 저해상도로 굽기
    high = join("BodyHigh", [body, jaw])
    low = high.copy()
    low.data = high.data.copy()
    low.name = "DragonBody"
    bpy.context.collection.objects.link(low)
    decimate_to(low, 18000)
    uv_unwrap(low)
    bake_set("DragonBody", low, high, 2048)

    # 2) 날개 (좌/우 각각 뼈 + 막)
    wing_objs = []
    for (bones, mem), tag in zip(wings, ("R", "L")):
        w = join("Wing" + tag, [bones, mem])
        decimate_to(w, 12000)
        uv_unwrap(w)
        bake_set("Wing" + tag, w, None, 1024, normal=False)
        wing_objs.append(w)

    # 3) 뿔, 발톱, 이빨, 눈, 가시
    det = join("DragonDetails", [o for o in EXTRA if o.name in bpy.data.objects])
    decimate_to(det, 15000)
    uv_unwrap(det)
    bake_set("DragonDetails", det, None, 1024, normal=False)

    bpy.data.objects.remove(high)
    finals = [low] + wing_objs + [det]
    for o in finals:
        # 구운 텍스처를 쓰는 단순 재질로 교체 (glTF가 그대로 가져가도록)
        o.data.materials.clear()
        m = bpy.data.materials.new(o.name + "_Mat")
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images[o.name + "_Color"]
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if (o.name + "_Normal") in bpy.data.images:
            nm = nt.nodes.new("ShaderNodeNormalMap")
            ntex = nt.nodes.new("ShaderNodeTexImage")
            ntex.image = bpy.data.images[o.name + "_Normal"]
            nt.links.new(ntex.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        o.data.materials.append(m)
        report.append("%s: %d tris" % (o.name, tri_count(o)))

    bpy.ops.object.select_all(action="DESELECT")
    for o in finals:
        o.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "GoldenDragon.fbx"), use_selection=True,
                             apply_scale_options="FBX_SCALE_UNITS", bake_space_transform=True,
                             path_mode="COPY", embed_textures=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "GoldenDragon.glb"), use_selection=True, export_format="GLB")
    print("\n".join(report))
    print("DONE export")
