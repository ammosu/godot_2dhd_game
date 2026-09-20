"""Run in Blender with PROJECT_ROOT set; export only Wanderlight_MoonCrystal.

Creates a separate collection, preserving existing scene objects. Refuses to
overwrite an existing asset. Godot receives a ground-centered Y-up model.
"""
import math
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

root_path = Path(PROJECT_ROOT)
if bpy.data.objects.get("Wanderlight_MoonCrystal"):
    raise RuntimeError("Moon crystal already exists; rebuild in a fresh scene.")
collection = bpy.data.collections.new("Wanderlight Moon Crystal")
bpy.context.scene.collection.children.link(collection)
root = bpy.data.objects.new("Wanderlight_MoonCrystal", None)
collection.objects.link(root)


def material(name, filename, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = roughness
    texture = mat.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(root_path / "assets/generated" / filename), check_existing=True)
    texture.interpolation = next(i.identifier for i in texture.bl_rna.properties["interpolation"].enum_items if i.identifier == "Closest")
    mat.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


crystal_mat = material("Moon crystal mineral", "moon_crystal_albedo.png", 0.32)
bsdf = next(n for n in crystal_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
bsdf.inputs["Emission Color"].default_value = (0.025, 0.28, 0.20, 1.0)
bsdf.inputs["Emission Strength"].default_value = 0.8
stone_mat = material("Moon crystal bedrock", "ruin_flagstone.png", 0.95)


def make_mesh(name, vertices, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    uv = mesh.uv_layers.new()
    for face in mesh.polygons:
        # Each vertical facet gets a narrow strip rather than wrapping the
        # whole texture onto every triangle. Flat normals retain crisp planes.
        for loop_index in face.loop_indices:
            co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            uv.data[loop_index].uv = (co.x * 0.8 + co.y * 0.6 + 0.5, co.z * 0.8)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = root
    return obj


vertices, faces = [], []
for radius, height, x, y, tilt in [
    (0.21, 1.20, 0.0, 0.0, -0.10),
    (0.15, 0.72, -0.29, 0.03, 0.34),
    (0.13, 0.57, 0.25, -0.11, -0.36),
    (0.11, 0.46, 0.08, 0.23, 0.24),
]:
    offset = len(vertices)
    rotation = Matrix.Rotation(tilt, 3, 'Y')
    for z, taper in [(0.08, 0.82), (height * 0.72, 1.0)]:
        for index in range(6):
            angle = index * math.tau / 6 + 0.18
            co = rotation @ Vector((math.cos(angle) * radius * taper, math.sin(angle) * radius * taper, z))
            vertices.append((co.x + x, co.y + y, co.z))
    tip = rotation @ Vector((radius * 0.16, 0, height))
    vertices.append((tip.x + x, tip.y + y, tip.z))
    faces.append(tuple(offset + i for i in reversed(range(6))))
    for index in range(6):
        nxt = (index + 1) % 6
        faces.append((offset + index, offset + nxt, offset + nxt + 6, offset + index + 6))
        faces.append((offset + index + 6, offset + nxt + 6, offset + 12))
make_mesh("MoonCrystalFacets", vertices, faces, crystal_mat)

vertices, faces = [], []
for z, radius in [(0.0, 0.43), (0.14, 0.39)]:
    for index in range(9):
        angle = index * math.tau / 9
        r = radius * (1.0 + 0.08 * math.sin(index * 2.3))
        vertices.append((r * math.cos(angle), r * math.sin(angle), z))
faces.extend([tuple(reversed(range(9))), tuple(range(9, 18))])
for index in range(9):
    nxt = (index + 1) % 9
    faces.append((index, nxt, nxt + 9, index + 9))
make_mesh("MoonCrystalBedrock", vertices, faces, stone_mat)
print("MOON_CRYSTAL_READY", len(root.children), "meshes; existing scene preserved")
