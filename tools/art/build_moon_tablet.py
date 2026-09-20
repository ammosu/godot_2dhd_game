"""Run inside Blender. Creates a new asset collection without modifying existing objects.

Execute with PROJECT_ROOT set to the repository's absolute path, then export only
Wanderlight_MoonTablet to assets/generated/moon_tablet.glb via Blender MCP.
"""
import math
from pathlib import Path
import bpy

root_path = Path(PROJECT_ROOT)
if bpy.data.objects.get("Wanderlight_MoonTablet"):
    raise RuntimeError("Tablet already exists; use a fresh Blender scene to rebuild.")
collection = bpy.data.collections.new("Wanderlight Moon Tablet")
bpy.context.scene.collection.children.link(collection)
root = bpy.data.objects.new("Wanderlight_MoonTablet", None)
collection.objects.link(root)

material = bpy.data.materials.new("Moon tablet engraved slate")
material.use_nodes = True
bsdf = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
bsdf.inputs["Roughness"].default_value = 0.96
texture = material.node_tree.nodes.new("ShaderNodeTexImage")
texture.image = bpy.data.images.load(str(root_path / "assets/generated/moon_tablet_albedo.png"), check_existing=True)
texture.interpolation = next(item.identifier for item in texture.bl_rna.properties["interpolation"].enum_items if item.identifier == "Closest")
material.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
edge_material = material.copy()
edge_material.name = "Moon tablet rough edges"
next(node for node in edge_material.node_tree.nodes if node.type == "TEX_IMAGE").image = bpy.data.images.load(str(root_path / "assets/generated/ruin_flagstone.png"), check_existing=True)


def slab(name, outline, half_depth):
    count = len(outline)
    vertices = [(x, y, z) for y in (-half_depth, half_depth) for x, z in outline]
    # Outline is CCW in X/Z; front points toward -Y, exported to Godot +Z.
    faces = [tuple(range(count)), tuple(range(count * 2 - 1, count - 1, -1))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    mesh.materials.append(edge_material)
    uv = mesh.uv_layers.new()
    for face in mesh.polygons:
        if face.index >= 2 or name == "TabletFoot":
            face.material_index = 1
        for loop in face.loop_indices:
            vertex = mesh.vertices[mesh.loops[loop].vertex_index].co
            if face.index >= 2:
                uv.data[loop].uv = (vertex.y * 1.5 + 0.5, vertex.z * 0.5 + vertex.x * 0.3)
            else:
                uv.data[loop].uv = (vertex.x / 1.3 + 0.5, (vertex.z - 0.2) / 1.8)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = root
    return obj


slab("TabletStone", [(-0.58, 0.20), (0.58, 0.20), (0.62, 1.56),
                   (0.44, 1.82), (0.12, 1.95), (-0.13, 1.88),
                   (-0.26, 1.99), (-0.53, 1.84), (-0.65, 1.58)], 0.17)
slab("TabletFoot", [(-0.78, 0.0), (0.78, 0.0), (0.72, 0.23), (-0.71, 0.23)], 0.36)
print("MOON_TABLET_READY", len(root.children), "meshes; existing scene preserved")
