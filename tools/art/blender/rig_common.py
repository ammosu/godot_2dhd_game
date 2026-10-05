"""Shared chibi rig, toon materials, walk poses and sprite camera.

Characters live in characters/<name>.py: a PALETTE dict and build(builder),
which adds rigid mesh parts with builder.sphere/segment/panel/torus. Render
one with render_character.py. Every part is skinned rigidly to one bone, so
the same poses drive all eight facings and the feet stay on one ground point.
Frames follow scripts/player.gd's cycle: [pass, contact, pass, contact].
"""
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

RENDER_SIZE = 352  # The game's walking canvas; no upscaling.
PIXELS_PER_METRE = 200.0
GROUND_PIXEL = 316  # SpriteGrounding baseline, from the top.
CAMERA_ELEVATION = math.radians(20.0)
OUTLINE = 0.010
# Soles sit just above the ground line so they never round into the row below it.
GROUND_CLEARANCE = 0.002

# Screen facing -> body yaw. The model faces -Y, the camera looks along +Y.
FACINGS = {
    "down": 0.0, "down_right": 45.0, "right": 90.0, "up_right": 135.0,
    "up": 180.0, "up_left": -135.0, "left": -90.0, "down_left": -45.0,
}

# Flat decals (face details) skip shading so they read at sprite scale.
FLAT = {"blush", "iris", "pupil", "lash", "white", "brow", "mouth"}
# Added to the light term: faces stay mostly lit, as in the painted sprites.
LIGHT_BIAS = {"skin": 0.22, "hair": 0.06}
OUTLINE_COLOR = (0.16, 0.09, 0.07)
# Four painted tones: cool violet shadow, mid, lit, warm highlight.
TONES = [(0.0, (0.56, 0.54, 0.72)), (0.22, (0.80, 0.80, 0.90)), (0.42, (1.0, 1.0, 1.0)), (0.80, (1.05, 1.04, 1.0))]


def linear(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


# ---------------------------------------------------------------- scene setup
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x = RENDER_SIZE
    scene.render.resolution_y = RENDER_SIZE
    scene.render.film_transparent = True
    scene.render.filter_size = 0.0
    scene.eevee.taa_render_samples = 1
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    world = bpy.data.worlds.new("World")
    world.color = (0.0, 0.0, 0.0)
    scene.world = world
    return scene


def _socket(sockets, identifier):
    return next(s for s in sockets if s.identifier == identifier)


def toon_material(name, color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    emission = nodes.new("ShaderNodeEmission")
    output = nodes.new("ShaderNodeOutputMaterial")
    links.new(emission.outputs[0], output.inputs["Surface"])
    if name in FLAT:
        emission.inputs["Color"].default_value = (*linear(color), 1.0)
        return mat
    diffuse = nodes.new("ShaderNodeBsdfDiffuse")
    to_rgb = nodes.new("ShaderNodeShaderToRGB")
    links.new(diffuse.outputs[0], to_rgb.inputs[0])
    # Object-space noise roughens the tone borders like brush strokes.
    coords = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 18.0
    noise.inputs["Detail"].default_value = 3.0
    links.new(coords.outputs["Object"], noise.inputs["Vector"])
    centred = nodes.new("ShaderNodeMath")
    centred.operation = "MULTIPLY_ADD"
    centred.inputs[1].default_value = 0.16
    centred.inputs[2].default_value = -0.08 + LIGHT_BIAS.get(name, 0.0)
    links.new(noise.outputs["Fac"], centred.inputs[0])
    shade = nodes.new("ShaderNodeMath")
    shade.operation = "ADD"
    links.new(to_rgb.outputs["Color"], shade.inputs[0])
    links.new(centred.outputs[0], shade.inputs[1])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    elements = ramp.color_ramp.elements
    while len(elements) < len(TONES):
        elements.new(0.5)
    for element, (position, tone) in zip(elements, TONES):
        element.position = position
        element.color = (*linear(tone), 1.0)
    links.new(shade.outputs[0], ramp.inputs["Fac"])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    _socket(mix.inputs, "A_Color").default_value = (*linear(color), 1.0)
    links.new(ramp.outputs["Color"], _socket(mix.inputs, "B_Color"))
    links.new(_socket(mix.outputs, "Result_Color"), emission.inputs["Color"])
    return mat


def outline_material(name, color):
    """Coloured line art: each part's outline is a deep shade of its own colour."""
    mat = bpy.data.materials.new(f"outline_{name}")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    line = tuple(0.55 * o + 0.45 * c * 0.35 for o, c in zip(OUTLINE_COLOR, color))
    if name == "hair":
        line = (0.34, 0.31, 0.36)
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (*linear(line), 1.0)
    output = nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(emission.outputs[0], output.inputs["Surface"])
    mat.use_backface_culling = True
    return mat


# ------------------------------------------------------------------- armature
# Leg joints (m). Characters model thighs and shins to these heights.
HIP, KNEE, ANKLE = 0.47, 0.27, 0.075
BONES = {
    # name: (head, tail, parent)
    "hips": ((0, 0, HIP), (0, 0, 0.54), None),
    "spine": ((0, 0, 0.54), (0, 0, 0.68), "hips"),
    "chest": ((0, 0, 0.68), (0, 0, 0.86), "spine"),
    "head": ((0, 0, 0.86), (0, 0, 1.30), "chest"),
}
for side, sx in (("L", 1.0), ("R", -1.0)):
    BONES.update({
        f"thigh.{side}": ((0.085 * sx, 0, HIP), (0.085 * sx, 0, KNEE), "hips"),
        f"shin.{side}": ((0.085 * sx, 0, KNEE), (0.085 * sx, 0, ANKLE), f"thigh.{side}"),
        f"foot.{side}": ((0.085 * sx, 0, ANKLE), (0.085 * sx, 0, 0.0), f"shin.{side}"),
        f"upper_arm.{side}": ((0.20 * sx, 0, 0.80), (0.222 * sx, 0, 0.645), "chest"),
        f"forearm.{side}": ((0.222 * sx, 0, 0.645), (0.234 * sx, 0, 0.50), f"upper_arm.{side}"),
        # Coat skirt quarters hinge at the waist and follow the thighs.
        f"skirt_front.{side}": ((0.09 * sx, 0, 0.53), (0.09 * sx, 0, 0.30), "hips"),
        f"skirt_back.{side}": ((0.09 * sx, 0, 0.531), (0.09 * sx, 0, 0.30), "hips"),
    })


def build_armature():
    data = bpy.data.armatures.new("wanderer_rig")
    rig = bpy.data.objects.new("wanderer_rig", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, parent) in BONES.items():
        bone = data.edit_bones.new(name)
        bone.head, bone.tail, bone.roll = Vector(head), Vector(tail), 0.0
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = "XYZ"
    return rig


# ---------------------------------------------------------------------- parts
class Builder:
    def __init__(self, rig, palette):
        self.rig = rig
        self.materials = {key: toon_material(key, color) for key, color in palette.items()}
        self.outlines = {key: outline_material(key, color) for key, color in palette.items()}

    def _finish(self, name, bm, bone, material, outline, shell=0.0):
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        for polygon in mesh.polygons:
            polygon.use_smooth = True
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(self.materials[material])
        obj.data.materials.append(self.outlines[material])
        obj.parent = self.rig
        group = obj.vertex_groups.new(name=bone)
        group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
        armature = obj.modifiers.new("rig", "ARMATURE")
        armature.object = self.rig
        if shell:
            cloth = obj.modifiers.new("cloth", "SOLIDIFY")
            cloth.thickness = shell
            cloth.offset = 0.0
        if outline:
            line = obj.modifiers.new("outline", "SOLIDIFY")
            line.thickness = OUTLINE * outline
            line.offset = 1.0
            line.use_flip_normals = True
            line.material_offset = 1
        return obj

    def sphere(self, name, bone, material, center, radii, outline=1.0, segments=16, axis=None):
        """Ellipsoid; with `axis`, its local Z (radii[2]) points along that direction."""
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=max(8, segments // 2), radius=1.0)
        rotation = Matrix.Identity(4)
        if axis is not None:
            rotation = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized()).to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=Matrix.Translation(center) @ rotation @ Matrix.Diagonal((*radii, 1.0)), verts=bm.verts)
        return self._finish(name, bm, bone, material, outline)

    def segment(self, name, bone, material, start, end, r1, r2=None, outline=1.0, scale_x=1.0, segments=14):
        """Tapered tube (or box when segments=4) from start to end."""
        start, end = Vector(start), Vector(end)
        axis = end - start
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=r1,
                              radius2=r1 if r2 is None else r2, depth=axis.length)
        if segments == 4:
            bmesh.ops.rotate(bm, cent=Vector(), matrix=Matrix.Rotation(math.pi / 4, 3, "Z"), verts=bm.verts)
        bmesh.ops.scale(bm, vec=Vector((scale_x, 1.0, 1.0)), verts=bm.verts)
        rotation = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=Matrix.Translation((start + end) * 0.5) @ rotation, verts=bm.verts)
        return self._finish(name, bm, bone, material, outline)

    def panel(self, name, bone, material, angles, top, bottom, outline=1.0, thickness=0.012):
        """Curved strip of a cone around Z. Angle 0 faces front (-Y), 90 is the left (+X).

        top/bottom are (z, radius); the solidified strip is `thickness` thick."""
        bm = bmesh.new()
        columns = max(3, int(abs(angles[1] - angles[0]) / 8) + 1)
        grid = []
        for z, radius in (top, bottom):
            row = []
            for i in range(columns):
                a = math.radians(angles[0] + (angles[1] - angles[0]) * i / (columns - 1))
                row.append(bm.verts.new((math.sin(a) * radius, -math.cos(a) * radius, z)))
            grid.append(row)
        for i in range(columns - 1):
            face = bm.faces.new((grid[0][i], grid[1][i], grid[1][i + 1], grid[0][i + 1]))
            centre = face.calc_center_median()
            face.normal_update()
            if face.normal.dot(Vector((centre.x, centre.y, 0.0))) < 0.0:
                face.normal_flip()
        return self._finish(name, bm, bone, material, outline, shell=thickness)

    def torus(self, name, bone, material, center, major, minor, scale=(1, 1, 1), outline=1.0):
        bm = bmesh.new()
        # bmesh has no torus primitive; sweep a ring of circles.
        rings, sides = 24, 10
        grid = []
        for i in range(rings):
            u = i / rings * math.tau
            ring = []
            for j in range(sides):
                v = j / sides * math.tau
                r = major + minor * math.cos(v)
                ring.append(bm.verts.new((r * math.cos(u) * scale[0], r * math.sin(u) * scale[1],
                                          minor * math.sin(v) * scale[2])))
            grid.append(ring)
        for i in range(rings):
            for j in range(sides):
                a, b = grid[i][j], grid[(i + 1) % rings][j]
                c, d = grid[(i + 1) % rings][(j + 1) % sides], grid[i][(j + 1) % sides]
                bm.faces.new((a, b, c, d))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
        return self._finish(name, bm, bone, material, outline)


# ---------------------------------------------------------------------- poses
def set_pitch(rig, bone, forward_degrees):
    """Local forward swing. Bones point down (legs/arms), so forward is -X."""
    rig.pose.bones[bone].rotation_euler.x = -math.radians(forward_degrees)


def apply_pose(rig, pose):
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_euler = (0.0, 0.0, 0.0)
        pose_bone.location = (0.0, 0.0, 0.0)
    for side in ("L", "R"):
        thigh, bend, foot = pose["legs"][side]
        set_pitch(rig, f"thigh.{side}", thigh)
        set_pitch(rig, f"shin.{side}", -bend)
        # Foot keeps the requested absolute pitch (0 = sole level).
        set_pitch(rig, f"foot.{side}", foot - (thigh - bend))
        # The knee pushes the front skirt out; a trailing leg lifts the back.
        knee = thigh - bend * 0.3
        set_pitch(rig, f"skirt_front.{side}", max(knee, 0.0) * 0.7)
        set_pitch(rig, f"skirt_back.{side}", min(thigh, 0.0) * 0.45 + pose.get("lean", 0.0))
        arm, elbow = pose["arms"][side]
        set_pitch(rig, f"upper_arm.{side}", arm)
        set_pitch(rig, f"forearm.{side}", elbow)
    # Upward bones: local Y is world Z, so twist is Y and a forward lean is -X.
    rig.pose.bones["hips"].rotation_euler.y = math.radians(pose.get("twist", 0.0))
    rig.pose.bones["chest"].rotation_euler.y = -math.radians(pose.get("twist", 0.0)) * 1.6
    rig.pose.bones["spine"].rotation_euler.x = -math.radians(pose.get("lean", 0.0))
    rig.pose.bones["head"].rotation_euler.x = math.radians(pose.get("lean", 0.0)) * 0.6
    bpy.context.view_layer.update()
    # Plant the lowest evaluated boot vertex (outline shell included) on the
    # ground; the hips' rise and fall is the body bob.
    rig.pose.bones["hips"].location.y = GROUND_CLEARANCE - lowest_boot_point()
    bpy.context.view_layer.update()


def lowest_boot_point():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    lowest = math.inf
    for obj in bpy.data.objects:
        if obj.type != "MESH" or not obj.name.startswith("boot"):
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        lowest = min(lowest, min((evaluated.matrix_world @ v.co).z for v in mesh.vertices))
        evaluated.to_mesh_clear()
    return lowest


def mirrored(pose):
    swap = {"L": "R", "R": "L"}
    return {**pose, "twist": -pose.get("twist", 0.0),
            "legs": {swap[k]: v for k, v in pose["legs"].items()},
            "arms": {swap[k]: v for k, v in pose["arms"].items()}}


# legs: (thigh forward deg, knee bend deg, foot pitch deg); arms: (swing, elbow)
# Frame 0 is a dedicated standing pose; frames 1-8 are one eight-frame walk
# cycle of two steps. Each step runs passing -> up -> contact -> down, the
# classic key poses: the supporting leg straightens and rises onto its toes
# (up), the swing leg strikes the heel (contact), then the new support knee
# takes the weight (down). Hips are re-grounded per pose, so these leg angles
# alone produce the body's rise and fall: measured hip height relative to
# contact is: down -5 px, passing +2 px, up +4 px (9 px, about 3 % of stature),
# with a 0.40 m contact stride: the trailing foot pushes off on its toes so
# the wide stride does not drop the hips.
STAND = {"legs": {"L": (0.0, 2.0, 0.0), "R": (0.0, 2.0, 0.0)},
         "arms": {"L": (2.0, 10.0), "R": (2.0, 10.0)}}
# The first step swings the left leg forward; arms counter-swing the legs.
PASSING = {"legs": {"R": (0.0, 2.0, 0.0), "L": (14.0, 56.0, -16.0)},
           "arms": {"R": (3.0, 12.0), "L": (-2.0, 10.0)}, "twist": 1.0, "lean": 3.0}
UP = {"legs": {"R": (-19.0, 3.0, -21.0), "L": (25.0, 30.0, 4.0)},
      "arms": {"R": (16.0, 18.0), "L": (-14.0, 8.0)}, "twist": 4.0, "lean": 3.0}
# Heel strike in front, toe-off behind: the widest stride short legs carry.
CONTACT = {"legs": {"L": (34.0, 6.0, 14.0), "R": (-30.0, 10.0, -36.0)},
           "arms": {"R": (26.0, 24.0), "L": (-24.0, 8.0)}, "twist": 7.0, "lean": 4.0}
DOWN = {"legs": {"L": (18.0, 48.0, 0.0), "R": (-18.0, 64.0, -50.0)},
        "arms": {"R": (18.0, 20.0), "L": (-16.0, 8.0)}, "twist": 5.0, "lean": 5.0}
STEP = [PASSING, UP, CONTACT, DOWN]
WALK = [STAND] + STEP + [mirrored(pose) for pose in STEP]
# Index into WALK whose ankle spread is the contact stride.
CONTACT_FRAME = 3


# --------------------------------------------------------------------- render
def build_camera(scene):
    data = bpy.data.cameras.new("sprite_camera")
    data.type = "ORTHO"
    data.ortho_scale = RENDER_SIZE / PIXELS_PER_METRE
    camera = bpy.data.objects.new("sprite_camera", data)
    scene.collection.objects.link(camera)
    # Ground origin lands on GROUND_PIXEL (from the top) of the render.
    below_centre = (GROUND_PIXEL - RENDER_SIZE * 0.5) / PIXELS_PER_METRE
    target = Vector((0.0, 0.0, below_centre / math.cos(CAMERA_ELEVATION)))
    direction = Vector((0.0, -math.cos(CAMERA_ELEVATION), math.sin(CAMERA_ELEVATION)))
    camera.location = target + direction * 12.0
    camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    # Key light from the upper left of the screen, as in the painted atlases.
    sun = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
    sun.data.energy = 3.0
    sun.data.use_shadow = False
    sun.rotation_euler = (math.radians(50.0), math.radians(-28.0), math.radians(-30.0))
    scene.collection.objects.link(sun)


def stride(rig):
    """Ankle-to-ankle distance along the heading in the current pose (m)."""
    bones = rig.pose.bones
    return abs(bones["foot.L"].head.y - bones["foot.R"].head.y)


def render(character, out_dir: Path, blend_path: str = ""):
    """Render character (a characters.* module) to out_dir/<facing>_<frame>.png.

    Also writes out_dir/metrics.json with the contact stride, which the game
    uses as the atlas's step length so feet do not slide."""
    out_dir.mkdir(parents=True, exist_ok=True)
    scene = reset_scene()
    rig = build_armature()
    character.build(Builder(rig, character.PALETTE))
    build_camera(scene)
    step = 0.0
    for facing, yaw in FACINGS.items():
        rig.rotation_euler.z = math.radians(yaw)
        for index, pose in enumerate(WALK):
            apply_pose(rig, pose)
            if index == CONTACT_FRAME:
                step = stride(rig)
            scene.render.filepath = str(out_dir / f"{facing}_{index}.png")
            bpy.ops.render.render(write_still=True)
    (out_dir / "metrics.json").write_text(json.dumps({"step_length": round(step, 4)}))
    if blend_path:
        bpy.ops.wm.save_as_mainfile(filepath=blend_path)
