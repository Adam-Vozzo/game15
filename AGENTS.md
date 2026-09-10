# Still — Atmosphere Channels

Read `PROJECT_CONTEXT.md`, `README.md`, and `art/PS1_ART_DIRECTION.md` before substantial changes.

## Art and workflow
- PS1-inspired means deliberate silhouettes, palettes, texture work and composition, not careless low-detail modeling. Preserve the atmosphere of each scene.
- Blender is the editable geometry source. Update source generators and regenerate GLBs when changing generated geometry; runtime-only patches must not silently diverge from the source.
- Build connected structures: supports reach the ground, braces meet beams, ropes terminate at anchors, and walkable geometry agrees with collision boundaries.
- Review accessible sides and underside/overhead views, not only the opening composition. Observe animation over time. Do not treat passing code tests as proof of visual quality.
- Keep surface coordinates anchored to geometry/world space. Avoid camera-dependent material movement, hard screen-space shading cutoffs, gratuitous vertex wobble and repetitive procedural patterns.
- Keep desktop and touch controls functional, and preserve Pause/Reset semantics for new animation.

## Implementation and verification
- Godot 4 Compatibility web export is the shipping implementation. A Three.js comparison has been discussed but is not implemented or approved as a migration.
- Use the existing scene framework and art pipeline; avoid rewriting unrelated scenes.
- Run `tools/build.ps1` with the installed Godot executable after runtime changes; it imports assets, runs regression checks and exports `docs/`.
- Run `node tests/validate_web.mjs` and `git diff --check` before delivery. Use native rendered captures for visual changes; check browser/mobile behaviour when affected.
- Keep `docs/` consistent with source when preparing a publishable commit. Do not edit generated web files directly to implement features.
- New chats do not inherit conversation history. Record significant decisions and remaining issues in `PROJECT_CONTEXT.md`.
- For simultaneous development, use separate worktrees and avoid sharing build output/server ports. Keep commits focused. Publishing should follow the user's current request.
