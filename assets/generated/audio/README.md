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

Peak magnitude is 0.25 for dialogue and 0.5 for other files. Eight pooled voices each use -14 dB gain on the dedicated SFX bus, leaving headroom even at maximum overlap. This is a first original SFX set, not completed music, ambience, mixing, or listening acceptance. `--mute-audio` mutes this bus for automated desktop runs. No audio preference is written to game saves.
