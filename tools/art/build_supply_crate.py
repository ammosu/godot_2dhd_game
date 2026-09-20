"""Run in Blender with PROJECT_ROOT set; export only Wanderlight_SupplyCrate.

Original closed supply crate, ground-centered, approximately 0.85 x 0.824 x 0.74m.
Existing scene objects are untouched. Two joined meshes: planks and hardware.
"""
import math
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

root_path = Path(PROJECT_ROOT)
if bpy.data.objects.get("Wanderlight_SupplyCrate"):
    raise RuntimeError("Supply crate already exists; use a fresh scene to rebuild.")
collection = bpy.data.collections.new("Wanderlight Supply Crate")
bpy.context.scene.collection.children.link(collection)
root = bpy.data.objects.new("Wanderlight_SupplyCrate", None)
collection.objects.link(root)

wood = bpy.data.materials.new("Supply crate weathered walnut")
wood.use_nodes = True
bsdf = next(n for n in wood.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
bsdf.inputs["Roughness"].default_value = 0.93
tex = wood.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = bpy.data.images.load(str(root_path / "assets/generated/timber_albedo.png"), check_existing=True)
tex.interpolation = next(i.identifier for i in tex.bl_rna.properties["interpolation"].enum_items if i.identifier == "Closest")
wood.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
iron = bpy.data.materials.new("Supply crate worn iron nails")
iron.use_nodes = True
bsdf = next(n for n in iron.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
bsdf.inputs["Base Color"].default_value = (0.065, 0.071, 0.078, 1.0)
bsdf.inputs["Roughness"].default_value = 0.77
bsdf.inputs["Metallic"].default_value = 0.6


class MeshParts:
    def __init__(self):
        self.vertices, self.faces, self.uvs = [], [], []

    def board(self, center, size, rotation=None):
        offset = len(self.vertices)
        corners = [Vector((x * size[0] / 2, y * size[1] / 2, z * size[2] / 2))
                   for x, y, z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                                   (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        rotation = rotation if rotation is not None else Matrix.Identity(3)
        self.vertices += [rotation @ vertex + Vector(center) for vertex in corners]
        faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        for face in faces:
            self.faces.append(tuple(offset + i for i in face))
            a, b, c = [corners[i] for i in face[:3]]
            normal = (b-a).cross(c-a)
            axes = [i for i in range(3) if abs(normal[i]) < 0.000001]
            grain = max(axes, key=lambda i: size[i])
            cross = next(i for i in axes if i != grain)
            shift = (offset * 0.037) % 1.0
            self.uvs.append([(corners[i][cross] * 2.0 + shift,
                              corners[i][grain] * 1.3 + shift) for i in face])

    def finish(self, name, material):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.materials.append(material)
        uv = mesh.uv_layers.new()
        for face, coords in zip(mesh.polygons, self.uvs):
            for loop, coord in zip(face.loop_indices, coords):
                uv.data[loop].uv = coord
        obj = bpy.data.objects.new(name, mesh)
        collection.objects.link(obj)
        obj.parent = root
        bevel_type = next(i.identifier for i in bpy.types.Modifier.bl_rna.properties["type"].enum_items if i.identifier == "BEVEL")
        bevel = obj.modifiers.new("Small worn edge chamfer", bevel_type)
        bevel.width = 0.004
        bevel.segments = 1
        return obj


planks, nails = MeshParts(), MeshParts()
# Five recessed boards on each face, framed rather than a solid orange cube.
for side in (-1, 1):
    for index in range(5):
        planks.board(((index-2)*0.145, side*0.338, 0.365), (0.139, 0.055, 0.61))
    for x in (-0.37, 0.37):
        planks.board((x, side*0.37, 0.37), (0.10, 0.07, 0.74))
    for z in (0.055, 0.685):
        planks.board((0, side*0.37, z), (0.84, 0.07, 0.10))
        for x in (-0.365, 0.365):
            nails.board((x, side*0.408, z), (0.027, 0.008, 0.027))
    planks.board((0, side*0.377, 0.37), (0.085, 0.066, 0.83), Matrix.Rotation(side*0.78, 3, 'Y'))
    for y in (-0.28, -0.14, 0, 0.14, 0.28):
        planks.board((side*0.358, y, 0.365), (0.06, 0.132, 0.61))
    for z in (0.055, 0.685):
        planks.board((side*0.386, 0, z), (0.062, 0.67, 0.09))
        for y in (-0.25, 0.25):
            nails.board((side*0.421, y, z), (0.008, 0.027, 0.027))
for z in (0.028, 0.71):
    for index in range(5):
        planks.board(((index-2)*0.146, 0, z), (0.14, 0.66, 0.048))
planks.finish("SupplyCratePlanks", wood)
nails.finish("SupplyCrateHardware", iron)
print("SUPPLY_CRATE_READY", len(planks.faces)*2 + len(nails.faces)*2, "base triangles; chamfer modifier exported")
