# Village expansion and lunar landmark

- Ground footprint: 38 × 32 → 46 × 40 (+51.3% area). Existing homes, doors, quest actors and saved positions retain their coordinates.
- New walkable outer garden promenade at x = ±19 and z = ±16.8, with trees and six lanterns. Boundary collisions move with the ground expansion.
- Existing plaza remains compact; paving uses smaller, warmer limestone sampling. Cool ambient and moon illumination are raised to retain detail between warm lantern pools.
- Original `moon_halo.glb` replaces the enclosed central lantern with an open golden ring, mineral shard and tapered support. It reuses original generated limestone/bronze textures. The previous asset remains available.
- Rebuild in an isolated Blender scene: `blender --background --factory-startup --python tools/art/build_moon_halo.py`.
- Quest interaction, restoration, core animation and map cleanup remain unchanged.
- A grounded crescent of ivory/purple flowers and a meadow island interrupt the paving around the base, leaving the south approach clear.
- Minimap follows actual camera yaw, including interpolated turns. Geography and heading rotate; labels and quest symbols stay upright. All four corners of every footprint are projected, with a fixed diagonal-fit scale to avoid clipping/zoom pulsing.
- Rotation regression: `godot --headless --path . --script tests/mini_map_rotation_test.gd`.
- Verification covers 96 map/yaw combinations, live camera alignment and ground rays across the old boundary. Both renderer playthroughs and Web export are required. Compatibility remains below stable 60 FPS in the capture workload; headless tests do not certify browser performance.
- Independent screenshot review: Forward+ 8.05/10, Compatibility 7.75/10. The original target remains unchanged. Remaining gaps include broad pale paving, roof color, weak cyan accent and finer-than-target foliage texture. This is an iteration checkpoint, not full visual acceptance.
