# The Painted Mere — watercolour and ink

The four user-supplied images guide the white paper horizon, lavender/cyan/pink water, fine violet-black pen work, transparent colour, lotus shapes and conservatory silhouette. This is an original walkable composition, not a reproduction or a bundled reference-image backdrop. Its deliberate illustration treatment takes precedence over the other channels' PS1 texture budgets.

## Tools and rendering decisions

- **Blender:** `blender/build_painted.py` is the complete geometry source. The editable `painted_mere.blend` keeps individual named architectural and botanical groups. The GLB batches opaque materials, retains separate crowns for transparent sorting, and retains separate bubble anchors. Deck boards, piles, cross-braces, bench, glasshouse ribs, petal outlines and seed heads are actual geometry.
- **Ink:** authored narrow tube paths describe seams and internal detail. Closed crowns also have a faint expanded backface contour pass. This provides control over what is drawn; it avoids outlining every triangle or shading transition. Pen width varies along fixed paths, not over time.
- **Pigment:** several scales of smooth, warped noise control overlapping violet, pink and cyan glazes. A narrow density band suggests pigment deposition. The water has local mint bleed around the lotus clusters. This is an artistic real-time approximation, not a fluid or pigment transport simulation.
- **Paper:** an original deterministic 256×256 cold-press height study contributes small pigment-density changes. Material coordinates are fixed in world space. There is no moving screen-grain layer, UV swim, vertex jitter, or camera-driven pigment flow.
- **Soft crowns:** closed three-dimensional crowns use transparent pigment, which reveals the internal branch drawing. Smooth normals soften only the apparent silhouette opacity; the material field stays attached to the world. The faint ink contour is deliberately slightly offset from the colour edge. This optical view-dependent silhouette is intentional, as in ordinary outline rendering; it does not move surface coordinates.
- **White distance:** each material fades gradually into the white background with distance, including transparent crowns. No full-screen fog composite is needed. The sun retains its small vermilion accent. Fine lines use scene-local MSAA and a higher render budget (up to 1440×1000 desktop, 840×840 touch) with linear presentation.
- **Motion:** slow wet glazes and sparse rising bubble outlines use the shared scene clock. Bubble scale is local to each Blender-authored anchor. Pause freezes visuals and sound while controls remain active; Reset restores framing without rewinding time.

Godot's normal/roughness screen texture is available only in Forward+, not the shipping Compatibility renderer. A normal-buffer Sobel outline or compute compositor would therefore require an unsuitable renderer change. Explicit line geometry and ordinary spatial shaders work with the existing WebGL 2 export. See [Godot screen-reading shader documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html).

The pigment vocabulary follows effects described by Curtis et al., *Computer-Generated Watercolor* (SIGGRAPH 1997): glazing, granulation, edge darkening and irregular pigment density. Their physical simulation is research context, not code incorporated into this scene. See [the authors' paper](https://grail.cs.washington.edu/wp-content/uploads/2015/08/curtis-1997-cgw.pdf).

Image generation was not needed for the shipped assets: editable geometry, explicit pen paths and a reproducible paper study allow consistent review from both sides and beneath the structures. A painted texture atlas could be a useful future art pass, but a single generated concept image would not establish the free-walking rendering or geometry.

## Regeneration and review

Run Blender with `--background --python blender/build_painted.py`, then `tools/build.ps1` with the installed Godot executable. Asset regeneration is also included in `-RebuildAssets`. GLB mesh compression is disabled to preserve fine lines and walking heights. The generated layout supplies route bounds and lotus positions to runtime.

`tests/painted.gd` checks the continuous deck/doorway route, water and bench collision, bubble anchors, Pause/audio and Reset. `tests/painted_visual.gd` requires a native display and checks rendered Pause, visible motion and the white/colour/ink balance; it saves opening, lotus, landing, reverse, inside, underside, canopy and portrait views in ignored `build-logs/`. Inspect these images as well as test results. Shared channel and resize tests include the ninth channel.

The path is intentionally confined to the walkway, landing and glasshouse interior. Physical mobile performance remains a device-validation task; desktop GPU results are not a phone performance guarantee.

## Pigment overflow and flamingos — September 2026

The user asked for occasional fill outside the ink outlines and wildlife like the reference flamingos. Their correction explicitly preserves the existing trees and focuses the drawing pass on the bridge, lily pads and lotus flowers. Tree overflow experiments were removed. The generator authors gently bowed/chipped plank contours, sparse pen knots, asymmetric cupped petals, uneven leaf edges and fine veins. Transparent spill ribbons extend selected plank, petal and pad edges; three flamingos retain slight body overflow. `painted_bleed.gdshader` feathers the ribbons outward and at their endpoints after accounting for glTF's V reversal. Dedicated pad/timber pigment fields add pooled green margins, pale dry-paper breaks and lavender/cyan/pink wood washes, all anchored in world space.

`blender/build_painted_wildlife.py`, executed by `build_painted.py`, builds nine original 3D flamingos with tapered S-shaped necks, hooked black-tipped bills, eyes, folded wings, tails, long legs and toes. Some rest on one leg. Each bird stands on a modeled submerged shoal, now farther from the opening and at least five metres from the path centre. Separate Blender neck groups keep the breast attachment, head, bill, eyes, ink and fill connected. The editable neck/face `Feed` shape keys lower the bill to water level. Seven-second looks occur every 27–36 seconds; rare feeding gestures last 8.8 seconds every 88–121 seconds. Different start offsets keep the flock independent, with long still intervals. Planted bodies and feet do not slide. Bird pigment uses local coordinates so it follows the articulation.

Two small source-authored turquoise dragonflies hover in short loops above the closest lotus flowers, with independent wing pivots and quiet stationary intervals. Every gesture and flight uses the shared pausable clock. Reset restores the opening camera while retaining animation time, matching the other channels.

Native verification adds visible spill on/off and wildlife on/off comparisons, a wildlife-only animation comparison, a twelve-frame complete feeding sequence, bridge close-up and reverse flock views. Headless tests check imported neck/face morphs, independent schedules, route clearance, planted roots and Pause/Resume for looks, feeding, flight and wings. All geometry and ink remain in the regenerated editable Blender source and GLB.

Feeding uses additional Feed_25, Feed_50 and Feed_75 source poses. These re-sweep round neck sections along a forward-reaching arc, avoiding the pinching and apparent shortening of a direct rest-to-feed blend. Runtime mixes adjacent poses and applies the same progression to the face details.
