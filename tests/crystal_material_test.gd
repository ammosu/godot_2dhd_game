extends SceneTree

const Presentation = preload("res://scripts/gameplay/crystal_materials.gd")


func _initialize() -> void:
	var scene := load("res://assets/generated/moon_crystal.glb") as PackedScene
	var first := scene.instantiate() as Node3D
	var second := scene.instantiate() as Node3D
	var facets := first.find_child("MoonCrystalFacets", true, false) as MeshInstance3D
	var bedrock := first.find_child("MoonCrystalBedrock", true, false) as MeshInstance3D
	var original := facets.get_active_material(0) as StandardMaterial3D
	var original_rock := bedrock.get_active_material(0)
	var original_mesh := facets.mesh
	Presentation.apply(first)
	Presentation.apply(second)
	var material := facets.get_active_material(0) as StandardMaterial3D
	assert(material != original and original.emission_texture == null, "Imported shared material was changed")
	assert(material.emission_enabled and material.emission_texture == material.albedo_texture)
	assert(material.emission_operator == BaseMaterial3D.EMISSION_OP_ADD)
	assert(material.emission == Color("3d7773"))
	assert(is_equal_approx(material.emission_energy_multiplier, 0.55))
	assert(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	assert(material.albedo_texture == original.albedo_texture and material.roughness == original.roughness)
	assert(facets.mesh == original_mesh and bedrock.get_active_material(0) == original_rock)
	assert((second.find_child("MoonCrystalFacets", true, false) as MeshInstance3D).get_active_material(0) == material, "Instances must share the prepared material")
	assert(first.find_children("*", "CollisionObject3D", true, false).is_empty())
	first.free()
	second.free()
	print("CRYSTAL_MATERIAL_TEST_PASS textured_emission shared_material original_preserved")
	quit()
