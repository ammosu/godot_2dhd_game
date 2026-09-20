# Interior background color regression

## Observed on Godot 4.7.1, Apple M4 desktop

The same room rendered with a bright purple exterior void in Compatibility,
but a dark void in Forward+. The environment used `BG_COLOR`, color `141119`,
Filmic tonemapping and glow. Fog was already disabled indoors.

Controlled runtime probes sampled the unobstructed pixel (10, 350):

| Pipeline | Forward+ RGB | Compatibility RGB |
| --- | --- | --- |
| Original color background + glow | .090, .071, .106 | .384, .310, .455 |
| Glow disabled | .086, .071, .102 | .075, .059, .086 |
| Canvas background + unchanged glow | .090, .071, .106 | .071, .055, .090 |

Reducing Bloom to zero, increasing the glow threshold, and setting glow
intensity to zero did not remove the Compatibility lift while the glow pass
remained enabled. Changing tonemapping alone also did not correct it. Thus the
evidence localizes the discrepancy to the color-background path with the glow
pass active, rather than light bleeding from a particular prop. This is an
observed renderer interaction, not a claim that its internal engine cause has
been fully proven. Godot documents that Compatibility uses a different glow
implementation: [Environment reference](https://docs.godotengine.org/en/latest/classes/class_environment.html#class-environment-property-glow-enabled).

## Project correction

`world.gd` creates one full-viewport ColorRect at CanvasLayer -10, with the same
art-directed color and ignored mouse input. Indoors, `BG_CANVAS` consumes only
that background layer; HUD and post-processing layers remain above it. Outdoors,
the canvas is hidden and `BG_COLOR` is restored. Anchors cover viewport resizing.
No renderer switch, glow removal, material retint, lighting reduction or save
schema change is used. Small residual renderer color differences remain.

## Reproduction and regression checks

Run both with a real renderer, not headless:

```bash
godot --path . --rendering-method forward_plus --script tests/interior_backdrop_test.gd -- --mute-audio --backdrop-capture
godot --path . --rendering-method gl_compatibility --script tests/interior_backdrop_test.gd -- --mute-audio --backdrop-capture
```

The test visits two interiors between outdoor maps, checks three unobstructed
background samples at 1280×720 and a resized 960-pixel-wide viewport, verifies
dark-but-not-black output, preserves glow and checks layer/input behavior.
Project stretch settings render 960×540 content within the requested 960×640
window. Captures include renderer names. A headless run checks structure only
and explicitly omits pixel acceptance. `house_interior_test.gd` additionally
checks background restoration across all eight house entry/exit/save cycles.

These tests cover this backdrop regression, not complete visual parity, browser
GPU coverage, full environmental art acceptance or performance certification.
