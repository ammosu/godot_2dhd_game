extends RefCounted
## Scenery for the Northern Ruins: courts, moon path, boundary walls, rubble,
## crystals and supplies. Columns, relics, portals and the guardian are wired by the world.

const RUIN := Color("443d55")


## Approach, soil, courts, the moon path, cross path and boundary walls.
static func terrain(props: WorldProps) -> void:
	props.add_box("SouthApproachGround", Vector3(0, -0.35, 18.5), Vector3(12, 0.7, 7), Color("304b48"), false)
	props.add_cobble_box("SouthApproachRoad", Vector3(0, 0.025, 18.0), Vector3(2.35, 0.08, 5.5), false)
	props.add_box("RuinGround", Vector3(0.0, -0.35, 0.0), Vector3(34.0, 0.7, 32.0), Color("292b3e"), true)
	props.add_box("RuinCourt", Vector3(0.0, -0.02, -2.0), Vector3(14.0, 0.12, 17.0), RUIN, true)
	props.add_box("WestRuinCourt", Vector3(-9.0, -0.015, 4.0), Vector3(5.5, 0.1, 5.5), RUIN.darkened(0.08), true)
	props.add_box("EastRuinCourt", Vector3(9.0, -0.015, -1.5), Vector3(5.5, 0.1, 5.5), RUIN.darkened(0.08), true)
	preload("res://scripts/gameplay/ruin_surfaces.gd").configure(props.map_root)
	for z_index in range(-11, 16):
		props.add_box("MoonPath_%02d" % (z_index + 11), Vector3(0.0, 0.025, float(z_index)), Vector3(1.45, 0.08, 0.82), Color("786c8d"), false)
	for x_index in range(-9, 10):
		props.add_box("RuinCrossPath_%02d" % (x_index + 9), Vector3(float(x_index), 0.022, 3.8), Vector3(0.82, 0.07, 1.18), Color("6c617f"), false)
	for x_position in [-16.1, 16.1]:
		props.add_box("RuinBoundary", Vector3(x_position, 0.8, 0.0), Vector3(0.8, 2.0, 31.0), Color("242235"), true)
	props.add_box("RuinBoundary", Vector3(0.0, 0.8, -15.1), Vector3(33.0, 2.0, 0.8), Color("242235"), true)
	for side: float in [-1.0, 1.0]:
		props.add_box("RuinBoundary", Vector3(side * 9.125, 0.8, 15.1), Vector3(14.75, 2.0, 0.8), Color("242235"), true)


## Rubble around the given columns, glowing crystals and supply crates.
static func dressing(props: WorldProps, columns: Array[Vector3]) -> void:
	preload("res://scripts/gameplay/ruin_rubble.gd").build(props.map_root, columns)
	for crystal_data in [
		[Vector3(-11.8, 0.0, -5.2), 1.3], [Vector3(11.5, 0.0, -7.0), 1.0], [Vector3(-12.0, 0.0, 9.0), 0.75],
		[Vector3(10.5, 0.0, 7.8), 1.15], [Vector3(5.6, 0.0, 11.0), 0.72],
	]:
		props.add_crystal(crystal_data[0], crystal_data[1])
	for supply_position: Vector3 in [Vector3(-4.6, 0.01, 8.0), Vector3(4.9, 0.01, 7.2), Vector3(-9.2, 0.01, -3.8), Vector3(8.4, 0.01, 3.7), Vector3(-3.4, 0.01, -10.8)]:
		props.add_supply_crate(supply_position, supply_position.x * 0.13)
