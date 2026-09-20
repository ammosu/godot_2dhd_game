"""Original fractured limestone column. Run with Blender --background --factory-startup.

Exports only this script's collection; never edits the user's live Blender scene.
The previous GLB is preserved. Godot owns collision and the persistent low footing.
"""
import math
import random
from pathlib import Path
import bpy
from mathutils import Vector

project = Path(__file__).resolve().parents[2]
output = project / "assets/generated/weathered_pillar_v2.glb"
collection = bpy.data.collections.new("Wanderlight fractured pillar v2")
bpy.context.scene.collection.children.link(collection)
root = bpy.data.objects.new("WeatheredPillarV2", None)
collection.objects.link(root)
material = bpy.data.materials.new("Original lichen limestone")
material.use_nodes = True
bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
bsdf.inputs["Roughness"].default_value = 0.96
texture = material.node_tree.nodes.new("ShaderNodeTexImage")
texture.image = bpy.data.images.load(str(project / "assets/generated/pillar_lichen_albedo.png"))
texture.interpolation = "Closest"
material.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])

rng = random.Random(73019)
# Irregular twelve-sided mass: rounded stone, not a broad concrete slab.
count = 12
profile = [(math.cos(i * math.tau / count) * (0.455 + rng.uniform(-0.018, 0.018)),
            math.sin(i * math.tau / count) * (0.455 + rng.uniform(-0.018, 0.018)))
           for i in range(count)]
levels = [0.0, 0.38, 0.88, 1.36, 1.80]
crown = [1.88, 1.94, 1.91, 1.86, 1.82, 1.87, 1.92, 1.90, 1.84, 1.88, 1.93, 1.89]
vertices, faces = [], []
for row, z in enumerate(levels):
    for index, (x, y) in enumerate(profile):
        scale = [1.0, 0.97, 1.0, 0.94, 0.91][row]
        x = x * scale + rng.uniform(-0.02, 0.02)
        y = y * scale + rng.uniform(-0.02, 0.02)
        radius = math.hypot(x, y)
        if radius > 0.485:
            x, y = x * 0.485 / radius, y * 0.485 / radius
        height = 0.0 if row == 0 else crown[index] if row == 4 else z + rng.uniform(-0.09, 0.09)
        vertices.append((x, y, height))
for row in range(len(levels) - 1):
    for index in range(count):
        a, b = row * count + index, row * count + (index + 1) % count
        # Alternating diagonals produce chipped, non-coplanar facets without
        # horizontal mortar stripes or a repeating brick wall wrapped around it.
        if (row + index) % 2:
            faces += [(a, b, a + count), (b, b + count, a + count)]
        else:
            faces += [(a, b, b + count), (a, b + count, a + count)]
faces.append(tuple(reversed(range(count))))
center = len(vertices)
vertices.append((0.035, -0.02, 1.865))
for index in range(count):
    faces.append((4 * count + index, 4 * count + (index + 1) % count, center))
mesh = bpy.data.meshes.new("Fractured limestone shaft")
mesh.from_pydata(vertices, [], faces)
mesh.update()
mesh.materials.append(material)
uv = mesh.uv_layers.new(name="StoneUV")
for face in mesh.polygons:
    # Use dominant-axis projection at a consistent physical texture scale.
    normal = face.normal
    axis = max(range(3), key=lambda i: abs(normal[i]))
    axes = [i for i in range(3) if i != axis]
    for loop in face.loop_indices:
        coordinate = mesh.vertices[mesh.loops[loop].vertex_index].co
        uv.data[loop].uv = (coordinate[axes[0]] * 0.35 + 0.23 * axis,
                            coordinate[axes[1]] * 0.35 + 0.11 * axis)
obj = bpy.data.objects.new("FracturedShaft", mesh)
collection.objects.link(obj)
obj.parent = root
# Chamfer the worn section edges while retaining a sharply fractured crown.
bevel = obj.modifiers.new("Worn limestone edges", "BEVEL")
bevel.width = 0.018
bevel.segments = 1
bevel.limit_method = "ANGLE"
bevel.angle_limit = math.radians(32)

for existing in bpy.context.selected_objects:
    existing.select_set(False)
root.select_set(True)
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True,
                          export_apply=True, export_yup=True, export_texcoords=True,
                          export_normals=True, export_materials="EXPORT")
assert output.exists()
print("WEATHERED_PILLAR_V2_EXPORTED", output)
