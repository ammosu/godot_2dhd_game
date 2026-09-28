# UI window art

Original UI art generated on 2026-09-28 with the OpenAI built-in image generation tool (via Codex CLI 0.156.1), using an in-game screenshot of this project only as a palette/style reference. No third-party or commercial game assets were used.

| File | Size | Use |
| --- | --- | --- |
| `panel_frame.png` | 384 × 384 | 9-slice window frame (`Presentation.ornate_panel()`): texture margin 52, expand margin 14 for the transparent rim. Dialogue box and battle preparation. |
| `nameplate.png` | 192 × 48 | Speaker tab (`Presentation.nameplate()`): left cap 44 px holds the crescent gem, right cap 22 px. |
| `continue_arrow.png` | 32 × 32 | Bobbing "continue" gem shown once a dialogue page finishes typing. |

Post-processing: generator output was normalized to 512 × 512, 512 × 128 and 64 × 64 with transparent exteriors and a flat `#0b1624` interior, then downscaled with Lanczos to the sizes above. UI frames are drawn 1:1 and are not stretched sprites, so they do not rely on nearest-neighbor filtering.

## Prompts

**panel_frame.png**
> Create original HD-2D pixel JRPG UI art: panel_frame.png, a 512x512 square dialogue/menu window. Deep midnight-navy fill, exact solid #0b1624 across the whole interior. Thin double border in antique brass/gold with #c9a66c highlights and darker bronze shading. Small ornate crescent-moon filigree ONLY at the four corners, each fully within its 96x96 corner square. PERFECTLY STRAIGHT, uniform, unornamented edges between corners for 9-slice stretching. Symmetric left/right and top/bottom. Crisp pixel-art-adjacent rendering, front-on flat UI asset. Frame nearly fills canvas with a narrow transparent outer margin. Truly transparent alpha background outside frame, not a checkerboard drawing. No text, icons, exterior shadow, gradients or texture in navy interior.

**nameplate.png**
> Create original HD-2D pixel JRPG UI art: nameplate.png, a 512x128 horizontal speaker-name tab. Solid deep midnight-navy #0b1624 interior, thin antique brass/gold double border with #c9a66c highlights and darker bronze shading, tiny crescent-moon gem at left end. Perfectly straight uniform unornamented middle section suitable for horizontal 3-slice stretching. Refined crisp pixel-art-adjacent rendering, flat front-on UI asset, wide 4:1 proportions, narrow transparent outer margin. Truly transparent alpha outside the tab, not a checkerboard drawing. No text, no additional icons, no exterior drop shadow, no texture or gradient in navy fill.

**continue_arrow.png**
> Create original HD-2D pixel JRPG UI art: continue_arrow.png, 64x64. One small downward-pointing chevron-shaped brass/gold gem for a dialogue press-to-continue indicator. Antique brass #c9a66c highlights, darker bronze facets, soft moonlight highlight on the gem surface. Crisp pixel-art-adjacent rendering, symmetric silhouette, centered with generous transparent margin. Truly transparent alpha background, not a checkerboard drawing. No text, no other icons, no frame, no exterior drop shadow or background glow.
