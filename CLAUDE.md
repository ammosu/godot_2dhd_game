# CLAUDE.md

Read and follow [`AGENTS.md`](AGENTS.md) before modifying this repository. It is the canonical repository-wide instruction file and contains the project architecture, Godot/Web constraints, verification commands, asset licensing requirements, and delivery rules.

Claude-specific reminders:

- Inspect the relevant scene and its attached scripts together; many nodes are constructed dynamically in GDScript rather than serialized in `.tscn` files.
- Never treat a zero Godot exit code as sufficient verification. Reject output containing `ERROR:` or `SCRIPT ERROR:`.
- Preserve Forward+ desktop behavior while separately validating the Compatibility Web path.
- Do not replace or regenerate third-party assets without updating `THIRD_PARTY_ASSETS.md` and retaining the required license text.
