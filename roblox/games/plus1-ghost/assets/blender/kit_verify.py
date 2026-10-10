import bpy, math, sys, os
from mathutils import Vector as V
D = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
names = ["CoffinWood","CoffinCursed","CoffinGold","GhostChaser","Tombstone","LanternPost","DeadTree","RebirthStatue","Treadmill"]
x = 0
for n in names:
    bpy.ops.import_scene.fbx(filepath=os.path.join(D, n + ".fbx"))
    objs = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    for o in objs:
        bpy.context.view_layer.update()
        xs = [(o.matrix_world @ V(c)).x for c in o.bound_box]
        o.location.x += x - min(xs)
        x += (max(xs) - min(xs)) + 3
def srgb(h):
    h=h.lstrip("#"); c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple((v/12.92) if v<=0.04045 else ((v+0.055)/1.055)**2.4 for v in c)
w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (*srgb("#2B2344"), 1)
w.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.2
bpy.ops.object.light_add(type="SUN"); s = bpy.context.object; s.data.energy = 2.5
s.rotation_euler = (math.radians(55), 0, math.radians(-25))
bpy.ops.mesh.primitive_plane_add(size=600, location=(x/2, 0, 0))
bpy.ops.object.camera_add(location=(x/2, -120, 9)); cam = bpy.context.object
cam.data.type = "ORTHO"; cam.data.ortho_scale = x + 8; cam.rotation_euler = (math.radians(86), 0, 0); sc.camera = cam
sc.render.engine = "CYCLES"; sc.cycles.samples = 32
sc.render.resolution_x = 2000; sc.render.resolution_y = 420
sc.view_settings.view_transform = "AgX"
sc.render.filepath = os.path.join(D, "kit_lowpoly_check.png")
bpy.ops.render.render(write_still=True)
print("DONE", x)
