# Exterior house windows

All eight windows per house retain their original glass positions and dimensions.
The original procedural `shaders/house_window.gdshader` replaces uniform high
emission with a warm center, darker edges and subtle fixed grain. Local mesh
coordinates avoid BoxMesh atlas UV seams. These are opaque stylized panes, not
views into the separately loaded house interiors. No new textures or third-party
assets are used, and no scene lights or collision shapes are changed.

Front and rear crossbars now match their glass centers (±1.25 m and ±1.15 m).
The duplicate front crossbars were removed. All four elevations have outer
side jambs, top frame and existing sills, preserving the village timber material.

`tests/house_window_test.gd` checks all eight frame positions on the reusable
architectural component. Actual Forward+ and Compatibility village captures
are additionally required to evaluate glow and frame readability.
