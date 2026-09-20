extends RefCounted
## Preserve imported facets while making their glow follow mineral inclusions.

static var _mineral: StandardMaterial3D


static func apply(model: Node3D) -> void:
	var facets := model.find_child("MoonCrystalFacets", true, false) as MeshInstance3D
	assert(facets != null, "Decorative crystal is missing its facet mesh")
	if _mineral == null:
		_mineral = facets.get_active_material(0).duplicate() as StandardMaterial3D
		_mineral.emission_enabled = true
		_mineral.emission_texture = _mineral.albedo_texture
		# A restrained constant floor keeps dark inclusions luminous instead of
		# reading as black cracks. The map still supplies local mineral variation.
		_mineral.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
		_mineral.emission = Color("3d7773")
		_mineral.emission_energy_multiplier = 0.55
		_mineral.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	facets.set_surface_override_material(0, _mineral)
