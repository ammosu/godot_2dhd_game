"""Run in Blender with PROJECT_ROOT set; export only Wanderlight_EarthenwareJar.

Original hollow terracotta vessel with rolled rim, a real inner wall, and two
loop handles. Z-up source, ground-centered origin; Godot import is Y-up.
"""
import math
from pathlib import Path
import bpy

root_path = Path(PROJECT_ROOT)
if bpy.data.objects.get("Wanderlight_EarthenwareJar"):
    raise RuntimeError("Jar already exists; rebuild in a fresh scene.")
collection = bpy.data.collections.new("Wanderlight Earthenware Jar")
bpy.context.scene.collection.children.link(collection)
root = bpy.data.objects.new("Wanderlight_EarthenwareJar", None)
collection.objects.link(root)
material = bpy.data.materials.new("Warm unglazed pottery")
material.use_nodes = True
bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
bsdf.inputs["Roughness"].default_value = 0.92
texture = material.node_tree.nodes.new("ShaderNodeTexImage")
texture.image = bpy.data.images.load(str(root_path / "assets/generated/terracotta_albedo.png"), check_existing=True)
texture.interpolation = next(i.identifier for i in texture.bl_rna.properties["interpolation"].enum_items if i.identifier == "Closest")
material.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])


def mesh_object(name, vertices, faces, uvs):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    uv = mesh.uv_layers.new()
    for polygon, coords in zip(mesh.polygons, uvs):
        for loop, coord in zip(polygon.loop_indices, coords):
            uv.data[loop].uv = coord
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = root
    return obj


# Radius/height cross-section continues over the lip and down the inner wall.
profile = [(0.17,0.0),(0.19,0.035),(0.255,0.12),(0.31,0.29),
           (0.30,0.40),(0.265,0.50),(0.205,0.57),(0.195,0.61),
           (0.22,0.625),(0.23,0.65),(0.225,0.685),(0.205,0.70),
           (0.175,0.69),(0.17,0.655),(0.167,0.61),(0.17,0.57),
           (0.23,0.49),(0.267,0.39),(0.274,0.29),(0.22,0.14),(0.13,0.075)]
segments = 20
vertices = [(radius*math.cos(j*math.tau/segments), radius*math.sin(j*math.tau/segments), z)
            for radius,z in profile for j in range(segments)]
faces, uvs = [], []
for ring in range(len(profile)-1):
    for j in range(segments):
        k = (j+1) % segments
        faces.append((ring*segments+j, ring*segments+k, (ring+1)*segments+k, (ring+1)*segments+j))
        uvs.append([(j/segments, profile[ring][1]), ((j+1)/segments, profile[ring][1]),
                    ((j+1)/segments, profile[ring+1][1]), (j/segments, profile[ring+1][1])])
for ring, reverse in [(0, True), (len(profile)-1, False)]:
    face = list(range(ring*segments, (ring+1)*segments))
    if reverse:
        face.reverse()
    faces.append(tuple(face))
    uvs.append([(vertices[i][0]+0.5, vertices[i][1]+0.5) for i in face])
mesh_object("JarBodyAndInnerWall", vertices, faces, uvs)

vertices, faces, uvs = [], [], []
steps, sides, tube = 20, 6, 0.026
for sign in (-1, 1):
    offset = len(vertices)
    for step in range(steps):
        angle = step*math.tau/steps
        for side in range(sides):
            section = side*math.tau/sides
            vertices.append((sign*(0.25+(0.13+tube*math.cos(section))*math.cos(angle)),
                             tube*math.sin(section),
                             0.43+(0.145+tube*math.cos(section))*math.sin(angle)))
    for step in range(steps):
        for side in range(sides):
            a = offset+step*sides+side
            b = offset+((step+1)%steps)*sides+side
            c = offset+((step+1)%steps)*sides+(side+1)%sides
            d = offset+step*sides+(side+1)%sides
            face = (d,c,b,a) if sign == 1 else (a,b,c,d)
            faces.append(face)
            coords = [(step/steps,side/sides),((step+1)/steps,side/sides),
                      ((step+1)/steps,(side+1)/sides),(step/steps,(side+1)/sides)]
            uvs.append(list(reversed(coords)) if sign == 1 else coords)
mesh_object("JarLoopHandles", vertices, faces, uvs)
print("EARTHENWARE_JAR_READY", len(root.children), "meshes; hollow rim and ground origin")
