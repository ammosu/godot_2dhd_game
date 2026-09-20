# Original gameplay cues

## Desktop Chrome playback acceptance (2026-09-20)

The current Web export was tested with an isolated Chrome profile requiring document activation. Before a click, AudioContext was suspended with zero measured output; after a canvas click, the final bus produced nonzero PCM. M muted it to zero and restored playback, Space started another dialogue cue, and both the 24 s music and 11.5 s ambience restarted past their loop boundaries. No runtime errors were observed. Reproduce with `tests/web_audio_test.js` as described in `tests/README.md`.

This test exposed silence with dynamically added buses in this exported runtime. The project now ships `default_bus_layout.tres` so Master, SFX, Music and Ambience exist before autoload playback begins. With that layout, the same browser probe passes. This establishes Chrome signal routing and gesture unlock, not subjective sound quality, gapless seams, other browsers, or the complete audio mix. References below to pending browser acceptance now apply to those remaining scenarios, not this verified Chrome startup path.

## Original ambience (2026-09-20)

`ambience_village.wav`, `ambience_ruins.wav`, and `ambience_house.wav` are deterministic, original sample-free synthesized wind/insects, low wind, and hearth noise respectively. Rebuild with `python3 tools/art/build_ambience.py` (standard library only). Each is 11.5 s, mono 32 kHz / 16-bit PCM, peak 0.45, with a half-second overlap at the loop seam. No external recordings or samples are used. These are stylized ambience drafts, not field recordings.

GameAmbience uses one player on the Ambience bus at linear gain 0.07, fades out before switching and fades in over 0.6 s. Battle mode silences ambience; dialogue preserves the current environment. Master volume/mute applies. Automated checks cover imported loops, map routing, battle silence, rapid transitions, real desktop startup while muted, and cleanup. Subjective listening/mixing and browser gesture unlock remain pending.

## Original background music (2026-09-20)

`music_village.wav` (24 s, 80 BPM), `music_ruins.wav` (30 s, 64 BPM), and `music_battle.wav` (17.143 s, 112 BPM) are original sample-free stereo compositions authored in `tools/art/build_music.py`. Rebuild with `python3 tools/art/build_music.py`; Python standard library only. The explicit original note sequence and voicings are in that source, with synthesized bell/plucked tones, soft harmonic pads, bass, and circular stereo delay. They do not use downloaded samples, a recorded performance, or a referenced song melody.

Files are 32 kHz / 16-bit stereo PCM with peak magnitude 0.55. Instrument tails wrap across the loop boundary; Godot sets forward looping on private stream copies at runtime. The runtime uses a two-player, 0.75 s crossfade at approximately -18 dB per player beneath SFX. Village and residential interiors share the village theme; ruins and active battles have their own themes. Battle resolution fades the score away for victory/defeat cues, and exploration music resumes on leaving the result screen. Master volume and mute affect both music and SFX.

These are the initial original music set, not completed listening/mixing acceptance. Headless tests validate routing without dummy-mixer playback; the desktop music test validates actual player startup and cleanup while muted. Browser autoplay/gesture behavior and subjective listening remain to be checked. Total uncompressed music size is about 8.7 MB; mobile delivery is outside the current acceptance scope.

## Short effects

### Surface footsteps (2026-09-20)

Six original, sample-free synthesized clips were authored in `tools/art/build_footsteps.py`: `step_dirt_1.wav` / `step_dirt_2.wav` (0.18 s), `step_stone_1.wav` / `step_stone_2.wav` (0.16 s), and `step_wood_1.wav` / `step_wood_2.wav` (0.20 s). Rebuild with `python3 tools/art/build_footsteps.py`; Python standard library only, fixed seeds and explicit sole-impact, filtered-noise and material-resonance formulas. No recordings, downloaded samples or third-party synthesizers are used. Mono 48 kHz / 16-bit PCM, peak 0.32, faded zero endpoints, no looping. Dirt emphasizes low friction, stone a short bright contact, wood a damped low resonance. Alternating variants reduce exact repetition.

`scripts/gameplay/footsteps.gd` counts actual horizontal movement: one event per 1.05 m while grounded and input-active. Idle, wall blocking, airborne motion, input lock and large displacements reset the partial stride. Player map changes and between-frame teleports also reset it; there is no catch-up burst. Surface regions use actual world geometry, including non-colliding village/ruin road overlays. Ground defaults to dirt, stone paving has higher priority, house floors use wood and the entry threshold uses stone. Registrations belong to the map nodes and disappear with them. These are broad material zones; rugs do not yet have an independent fabric footstep set.

Footsteps share the existing eight-voice SFX pool and Master mute/volume without modifying saves or creating buses. Their lower PCM peak leaves them quieter than combat cues at the same -14 dB voice gain. `tests/audio_asset_test.py` checks all six distinct waveforms, format, duration, peaks and endpoints. `tests/footsteps_test.gd` checks actual map materials, physics movement, wall/idle/dialogue silence, teleport reset, variants and cleanup; its desktop run verifies real player startup while muted. These tests establish routing and integrity, not subjective listening or complete mix acceptance.

### Weapon-specific additions (2026-09-20)

The same original sample-free generator now includes `spear_thrust.wav` (0.29 s, narrow descending air sweep with a brief metallic contact), `claw_swipe.wav` (0.30 s, rougher air/noise with two short low partials), and `staff_strike.wav` (0.32 s, subdued air followed by low wooden modal contact). Contact tones begin at 0.13 s to align with the existing lunge, rather than preceding the visual hit.

Party battle routes sound and contact art through the same weapon-kind mapping. Traveler/guardian retain sword, Noah uses spear, wolf uses claw, and Elder/mage basic attacks use staff; empowered slash remains distinct. A six-actor live battle test verifies exact cue counts, including the enemy mage's zero-MP staff fallback. Mono 48 kHz / 16-bit PCM, 0.5 peak, endpoint fades and the eight-voice pool are unchanged. These are stylized synthesized effects, not recordings; subjective listening/mix acceptance remains pending.

### Role-specific additions (2026-09-20)

Six original, sample-free cues are generated by the same deterministic script:

| File | Duration | Runtime use |
| --- | --- | --- |
| moon_slash.wav | 0.36 s | Traveler empowered slash; airy descending sweep |
| moon_bolt.wav | 0.38 s | Elder single-target projectile; focused rising sweep |
| frost_nova.wav | 0.30 s | Ally/enemy AoE charge; high crystalline partials |
| frost_impact.wav | 0.52 s | One AoE burst at damage impact, independent of target count |
| protect.wav | 0.62 s | Noah's ward; low open-fifth ring |
| moon_heal.wav | 0.72 s | Elder healing; layered ascending chimes |

These retain mono 48 kHz / 16-bit PCM, peak 0.5, non-looping playback and the existing -14 dB SFX voice gain. Basic guard, potion and normal attacks retain their prior cues. The original eight outputs are unchanged. PCM tests check duration, format, non-silence, peak headroom, silent endpoints and distinct waveforms; the live party UI test checks all six routes and one burst sound for a three-target impact. This does not establish subjective mix/listening acceptance.

Created 2026-09-20 using `tools/art/build_sound_effects.py`, authored for this project. No downloaded samples, external recording, recognizable song melody, or third-party synthesizer library is used. Rebuild with `python3 tools/art/build_sound_effects.py` from the repository root. Deterministic mono 48 kHz / 16-bit PCM WAV, with explicit start/end fades; no looping.

| File | Duration | Function |
| --- | --- | --- |
| dialogue.wav | 0.14 s | Soft two-note page cue |
| slash.wav | 0.26 s | Filtered air noise and descending sweep |
| impact.wav | 0.34 s | Low modal thud and noise |
| guard.wav | 0.48 s | Inharmonic metallic ring |
| heal.wav | 0.90 s | Rising soft chime |
| skill.wav | 0.60 s | Rising sweep, air and upper partials |
| victory.wav | 1.50 s | Brief resolving chime |
| defeat.wav | 1.30 s | Descending subdued cue |

For the original eight cues above, peak magnitude is 0.25 for dialogue and 0.5 for the other seven. Footsteps use the lower peak documented in their own section. Eight pooled voices each use -14 dB gain on the dedicated SFX bus, leaving headroom even at maximum overlap. This is a first original SFX set, not completed music, ambience, mixing, or listening acceptance. `--mute-audio` forces Master mute for automated desktop runs. No audio preference is written to game saves.
