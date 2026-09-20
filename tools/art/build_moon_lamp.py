"""Run in Blender with PROJECT_ROOT set; export Wanderlight_MoonLamp only.

Original measured lantern geometry. Existing scene objects remain untouched.
The separate core has its pivot at the light center for runtime rotation.
"""
import math
from pathlib import Path
import bpy
from mathutils import Vector

project_root = Path(PROJECT_ROOT)
if bpy.data.objects.get("Wanderlight_MoonLamp"):
    raise RuntimeError("Moon lamp already exists; rebuild in a fresh scene.")
collection = bpy.data.collections.new("Wanderlight Moon Lamp")
bpy.context.scene.collection.children.link(collection)
root = bpy.data.objects.new("Wanderlight_MoonLamp", None)
collection.objects.link(root)


def material(name, filename, roughness, metallic=0.0):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    shader = next(node for node in result.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    texture = result.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(project_root / "assets/generated" / filename), check_existing=True)
    texture.interpolation = next(item.identifier for item in texture.bl_rna.properties["interpolation"].enum_items if item.identifier == "Closest")
    result.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    return result


stone = material("Moon lamp dressed stone", "cut_limestone_albedo.png", 0.95)
bronze = material("Moon lamp aged bronze", "aged_bronze_albedo.png", 0.62, 0.55)
roof_metal = material("Moon lamp patinated panels", "aged_bronze_albedo.png", 0.8, 0.20)
crystal = material("Moon lamp cut moonstone", "cut_limestone_albedo.png", 0.32)
stone_geometry = ([], [])
metal_geometry = ([], [])
roof_geometry = ([], [])


def lathe(geometry, profile, segments=16, center=(0, 0, 0), phase=0.0):
    vertices, faces = geometry
    start = len(vertices)
    for radius, height in profile:
        for index in range(segments):
            angle = math.tau * index / segments + phase
            vertices.append((center[0] + radius * math.cos(angle), center[1] + radius * math.sin(angle), center[2] + height))
    for ring in range(len(profile) - 1):
        for index in range(segments):
            nxt = (index + 1) % segments
            a = start + ring * segments
            faces.append((a + index, a + nxt, a + nxt + segments, a + index + segments))
    faces.append(tuple(start + index for index in reversed(range(segments))))
    last = start + (len(profile) - 1) * segments
    faces.append(tuple(last + index for index in range(segments)))


def tube(geometry, points, radius, segments=6):
    vertices, faces = geometry
    start = len(vertices)
    for index, point in enumerate(points):
        previous = Vector(points[max(0, index - 1)])
        following = Vector(points[min(len(points) - 1, index + 1)])
        tangent = (following - previous).normalized()
        normal = tangent.cross(Vector((1, 0, 0)))
        if normal.length < 0.01:
            normal = tangent.cross(Vector((0, 1, 0)))
        normal.normalize()
        binormal = tangent.cross(normal).normalized()
        for side in range(segments):
            angle = math.tau * side / segments
            vertex = Vector(point) + radius * (normal * math.cos(angle) + binormal * math.sin(angle))
            vertices.append(tuple(vertex))
    for index in range(len(points) - 1):
        for side in range(segments):
            nxt = (side + 1) % segments
            a = start + index * segments
            faces.append((a + side, a + nxt, a + nxt + segments, a + side + segments))
    faces.append(tuple(start + side for side in reversed(range(segments))))
    last = start + (len(points) - 1) * segments
    faces.append(tuple(last + side for side in range(segments)))


def mesh_object(name, geometry, mat):
    vertices, faces = geometry
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    mesh.update()
    uv = mesh.uv_layers.new()
    for face in mesh.polygons:
        normal = face.normal
        for loop_index in face.loop_indices:
            co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            if abs(normal.z) > 0.6:
                uv.data[loop_index].uv = (co.x * 0.8 + 0.5, co.y * 0.8 + 0.5)
            elif abs(normal.x) > abs(normal.y):
                uv.data[loop_index].uv = (co.y * 0.8 + 0.5, co.z * 0.8)
            else:
                uv.data[loop_index].uv = (co.x * 0.8 + 0.5, co.z * 0.8)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = root
    return obj


# Real large cut blocks with staggered radial joints, not a pavement decal.
for radius, bottom, height, phase in [(0.82, 0.008, 0.21, math.pi / 8), (0.65, 0.224, 0.206, 0.0)]:
    for block in range(8):
        vertices, faces = stone_geometry
        start = len(vertices)
        a = math.tau * block / 8 + phase + 0.009
        b = math.tau * (block + 1) / 8 + phase - 0.009
        for r, z in [(radius - 0.02, bottom), (radius, bottom + 0.02),
                     (radius, bottom + height - 0.02), (radius - 0.02, bottom + height)]:
            vertices.extend([(0, 0, z), (r * math.cos(a), r * math.sin(a), z),
                             (r * math.cos(b), r * math.sin(b), z)])
        faces.extend([(start + 2, start + 1, start), (start + 9, start + 10, start + 11)])
        for ring in range(3):
            for edge in range(3):
                nxt = (edge + 1) % 3
                offset = start + ring * 3
                faces.append((offset + edge, offset + nxt, offset + nxt + 3, offset + edge + 3))
# Molded pedestal and collars instead of the old single cone.
lathe(roof_geometry, [(0.37, 0.43), (0.38, 0.47), (0.33, 0.52), (0.28, 0.58),
                     (0.27, 0.78), (0.30, 0.85), (0.30, 0.92)], 12)
lathe(metal_geometry, [(0.37, 0.43), (0.39, 0.45), (0.39, 0.48), (0.36, 0.50)], 12)
for height in (0.57, 0.76, 0.88):
    lathe(metal_geometry, [(0.26, height), (0.29, height + 0.016),
                          (0.29, height + 0.050), (0.26, height + 0.066)], 12)
# Shallow open bowl and lip. The inner surface slopes down to its center.
lathe(metal_geometry, [(0.18, 0.90), (0.34, 0.96), (0.46, 1.04), (0.48, 1.09),
                      (0.44, 1.12), (0.39, 1.08), (0.18, 0.96)], 16)
# Four slim ribs bow around, but do not conceal, the suspended moonstone.
for rib in range(4):
    angle = math.tau * rib / 4
    path = []
    for step in range(9):
        t = step / 8
        radius = 0.37 + math.sin(t * math.pi) * 0.15
        path.append((radius * math.cos(angle), radius * math.sin(angle), 1.09 + 0.80 * t))
    tube(metal_geometry, path, 0.035)
# Flared six-sided canopy: visible eave thickness and small finial.
lathe(roof_geometry, [(0.42, 1.88), (0.44, 1.92), (0.315, 2.00),
                      (0.14, 2.17), (0.055, 2.20)], 6)
lathe(metal_geometry, [(0.05, 2.20), (0.073, 2.235), (0.075, 2.26), (0.05, 2.29), (0.012, 2.31)], 12)
for ridge in range(6):
    angle = math.tau * ridge / 6
    tube(metal_geometry, [(radius * math.cos(angle), radius * math.sin(angle), height)
                         for radius, height in [(0.43, 1.925), (0.315, 2.01), (0.14, 2.18), (0.055, 2.21)]], 0.018)
tube(metal_geometry, [(0.44 * math.cos(math.tau * index / 6),
                      0.44 * math.sin(math.tau * index / 6), 1.92) for index in range(7)], 0.022)
for rivet in range(8):
    angle = math.tau * rivet / 8
    lathe(metal_geometry, [(0.031, 0), (0.031, 0.02), (0.017, 0.034)], 6,
          (0.39 * math.cos(angle), 0.39 * math.sin(angle), 1.068))
mesh_object("MoonLampPlinth", stone_geometry, stone)
mesh_object("MoonLampBronzework", metal_geometry, bronze)
mesh_object("MoonLampPatinaPanels", roof_geometry, roof_metal)

vertices = [(0, 0, -0.36), (0, 0, 0.36)]
for index in range(6):
    angle = math.tau * index / 6
    vertices.append((0.22 * math.cos(angle), 0.22 * math.sin(angle), 0.0))
faces = []
for index in range(6):
    nxt = (index + 1) % 6
    faces.extend([(0, 2 + nxt, 2 + index), (1, 2 + index, 2 + nxt)])
core = mesh_object("MoonLampCore", (vertices, faces), crystal)
core.location.z = 1.52
colors = core.data.color_attributes.new(name="MoonstoneFacetShades", type='FLOAT_COLOR', domain='CORNER')
for face in core.data.polygons:
    value = (0.48 if face.index % 2 == 0 else 0.94) * [1.0, 0.82, 0.68, 0.90, 0.75, 0.86][face.index // 2]
    for loop_index in face.loop_indices:
        colors.data[loop_index].color = (value, value, value, 1.0)
core.data.color_attributes.active_color = colors
# Display facet shading in Blender too. The ACTIVE export setting below is
# required separately to put these colors in glTF COLOR_0 for Godot.
shader = next(node for node in crystal.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
texture = next(node for node in crystal.node_tree.nodes if node.type == "TEX_IMAGE")
vertex_color = crystal.node_tree.nodes.new("ShaderNodeVertexColor")
vertex_color.layer_name = colors.name
multiply = crystal.node_tree.nodes.new("ShaderNodeMixRGB")
multiply.blend_type = next(item.identifier for item in multiply.bl_rna.properties["blend_type"].enum_items if item.identifier == "MULTIPLY")
multiply.inputs[0].default_value = 1.0
crystal.node_tree.links.new(texture.outputs["Color"], multiply.inputs[1])
crystal.node_tree.links.new(vertex_color.outputs["Color"], multiply.inputs[2])
crystal.node_tree.links.new(multiply.outputs[0], shader.inputs["Base Color"])
def export_moon_lamp(filepath):
    """Use ACTIVE vertex colors: Blender 5.2's material mode emits white COLOR_0."""
    selected = list(bpy.context.selected_objects)
    active = bpy.context.view_layer.objects.active
    try:
        for obj in selected:
            obj.select_set(False)
        for obj in [root] + list(root.children):
            obj.select_set(True)
        bpy.context.view_layer.objects.active = root
        bpy.ops.export_scene.gltf(filepath=str(filepath), export_format='GLB', use_selection=True,
                                  export_vertex_color='ACTIVE', export_all_vertex_colors=False)
    finally:
        for obj in bpy.context.selected_objects:
            obj.select_set(False)
        for obj in selected:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = active


print("MOON_LAMP_READY", [(obj.name, len(obj.data.polygons)) for obj in root.children])
