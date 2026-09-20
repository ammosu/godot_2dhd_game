# Moon shard reward presentation

`scripts/gameplay/moon_shard.gd` builds an original, reusable 3D quest relic:
an asymmetric silver-blue faceted shard and an incomplete six-sided-section
metal ring. The two meshes total 372 triangles, with flat facet normals and
closed ring tips. Materials use Godot's standard color handling, modest core
emission and no transparency. No imported or third-party image/model is used.

The victory handler starts the relic at the guardian's former position, then
flies it along a 1.4-second eased arc to a point above the traveler during the
existing two-page reward dialogue. A small bob and limited yaw show its depth without
spinning its front entirely away from the player. This intentional magical
hover does not change actor grounding. The existing reward notification supplies
the item name; no extra panel or input is required.

GameState still awards the shard through `defeat_guardian()`. The presentation
does not grant items, change rewards, add pickups or write a new save field.
Closing the dialogue frees it. It is owned by the current map, and its completion
callback uses a weak reference so an earlier map change is safe. This is a reward
display, not a hand-held item animation or a quest turn-in cinematic.

Run `godot --headless --path . --script tests/moon_shard_test.gd` for geometry,
inventory invariance, flight start/midpoint/arrival, both dialogue pages and map-exit cleanup. For an actual
reward screenshot, omit headless and append `-- --shard-capture --mute-audio`.
Run with both `forward_plus` and `gl_compatibility`. The test disables the
world's normal victory autosave and does not overwrite a player's save.
