extends RefCounted
## Original relief geometry for the remaining domestic house themes.

const Emblem = preload("res://scripts/gameplay/house_emblem.gd")


static func build(root: Node3D, kind: String, wood: Material) -> void:
	Emblem._box(root, "Backing", Vector3.ZERO, Vector3(0.72, 0.51, 0.075), wood)
	var cream := Emblem._material(Color("cbb98e"))
	match kind:
		"weaving":
			for side: float in [-1.0, 1.0]:
				Emblem._box(root, "LoomSide%s" % side, Vector3(side * 0.25, 0, -0.075), Vector3(0.055, 0.43, 0.04), cream)
				Emblem._box(root, "LoomBeam%s" % side, Vector3(0, side * 0.185, -0.075), Vector3(0.51, 0.045, 0.04), cream)
			for thread: int in range(7):
				Emblem._box(root, "Warp%d" % thread, Vector3((thread - 3) * 0.06, 0, -0.074), Vector3(0.012, 0.34, 0.014), cream)
			var wool := Emblem._material(Color("987588"))
			for row: int in range(4):
				for column: int in range(7):
					Emblem._box(root, "Weft%d_%d" % [row, column], Vector3((column - 3) * 0.06, row * 0.045 - 0.11, -0.075 - (0.016 if (row + column) % 2 == 0 else 0.0)), Vector3(0.06, 0.029, 0.016), wool)
		"quilt":
			var colors: Array[Color] = [Color("9c6069"), Color("b49a62"), Color("567f80"), Color("887397")]
			for index: int in range(4):
				var position := Vector3((index % 2 - 0.5) * 0.185, (index / 2 - 0.5) * 0.185, -0.075)
				# Integer division intentionally selects the two patch rows.
				Emblem._box(root, "Patch%d" % index, position, Vector3(0.17, 0.17, 0.045), Emblem._material(colors[index]))
				for stitch: int in range(3):
					Emblem._box(root, "Stitch%d_%d" % [index, stitch], position + Vector3((stitch - 1) * 0.045, -0.052, -0.027), Vector3(0.017, 0.008, 0.008), cream)
		"herbs":
			var stem := Emblem._material(Color("809065"))
			Emblem._box(root, "Stem", Vector3(0, -0.012, -0.072), Vector3(0.022, 0.37, 0.025), stem)
			for index: int in range(6):
				var side: float = -1.0 if index % 2 == 0 else 1.0
				var leaf := MeshInstance3D.new()
				leaf.name = "HerbLeaf%d" % index
				var mesh := SphereMesh.new()
				mesh.radius = 0.5
				mesh.height = 1.0
				mesh.radial_segments = 8
				mesh.rings = 4
				leaf.mesh = mesh
				leaf.scale = Vector3(0.24, 0.095, 0.045)
				leaf.rotation.z = side * 0.45
				leaf.position = Vector3(side * 0.095, -0.10 + (index / 2) * 0.105, -0.095)
				leaf.material_override = Emblem._material(Color("8b9d72") if index % 2 == 0 else Color("647e67"))
				root.add_child(leaf)
		"moon":
			var disc := MeshInstance3D.new()
			disc.name = "FullMoon"
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.105
			cylinder.bottom_radius = 0.105
			cylinder.height = 0.028
			cylinder.radial_segments = 16
			disc.mesh = cylinder
			disc.rotation.x = PI * 0.5
			disc.position.z = -0.075
			disc.material_override = cream
			root.add_child(disc)
			for side: float in [-1.0, 1.0]:
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				for segment: int in range(20):
					var points: Array[Vector3] = []
					for step: int in [segment, segment + 1]:
						var t: float = float(step) / 20.0
						var angle := lerpf(PI * 0.25, PI * 1.75, t)
						var direction := Vector3(cos(angle), sin(angle), 0)
						points.append(direction * 0.105)
						points.append(direction * (0.105 - sin(t * PI) * 0.05))
					# Clockwise front faces toward local -Z; mirrored via rotation.
					if segment > 0:
						Emblem._triangle(surface, points[0], points[2], points[1], Color.WHITE)
					if segment < 19:
						Emblem._triangle(surface, points[1], points[2], points[3], Color.WHITE)
				var crescent := MeshInstance3D.new()
				crescent.name = "WaxingMoon" if side < 0 else "WaningMoon"
				crescent.mesh = surface.commit()
				crescent.rotation.z = 0 if side < 0 else PI
				crescent.position = Vector3(side * 0.225, 0, -0.095)
				crescent.material_override = cream
				root.add_child(crescent)
