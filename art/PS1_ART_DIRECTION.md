# Kasumi — hardware research and art direction

The brief is an atmospheric, carefully modeled PS1-inspired place. Limited geometry and texture space are design constraints, not a justification for crude assets. The reference images guide composition and environmental density; no game assets were copied.

## Verified constraints

Sony's 1998 **PlayStation Hardware** manual describes 2 MB main memory, 1 MB graphics memory shared by display buffers and texture data, flat/Gouraud shading, and paletted 4-bit/8-bit or direct 15-bit textures. Texture pages are 256×256 texels. Resolution is configurable: 320×240 is one mode, not a universal requirement. Shading colors can be specified per vertex. These facts support reusable material pages and modeled silhouettes with vertex-colored shelter shading, rather than uniformly tiny, noisy textures. [Sony developer reference, chapters 2–3](https://psx.arthus.net/sdk/Psy-Q/DOCS/Devrefs/Hardware.pdf).

The hardware GPU interpolates texture coordinates in screen space, without perspective correction. Subdividing large polygons reduces the resulting distortion. Its optional 4×4 dither adds small signed offsets before reducing color channels to five bits; that is different from arbitrary full-screen film grain. [PSX-SPX GPU research: perspective interpolation and dithering](https://psx-spx.consoledev.net/graphicsprocessingunitgpu/#perspective-in-correct-rendering).

There is no single useful “maximum polygons per model” implied by these facts. Visible geometry, overdraw, texture use and software work all consume a frame budget. This project does not claim a console-compatible polygon budget.

## Decisions in this scene

- Four **256×256** material pages, each containing four 128×128 studies, plus a fifth 256×256 foliage page. Material studies use 16-step RGB555-derived ramps; each page has at most 64 colors. The hypothetical 8-bit indexed pages would occupy 320 KiB, plus palettes. Godot actually uploads regular textures; this is an art budget, not emulated VRAM allocation.
- Native Aseprite files preserve named material layers and palettes. Cedar grain, weather streaks, ceramic tile profiles, mortar, paper, cotton and corrosion each have distinct mark-making. The Lua source regenerates these deterministic original studies; they are not hand-painted scans.
- Geometry is spent on eave profiles, tile ridges, recessed glazing, latticework, balconies, gutters, catenary cables and readable prop silhouettes. Architecture uses perspective-correct object UVs: the earlier affine approximation caused distracting camera-dependent swimming and has been removed. Terrain blends offset earth and moss samples in world space to soften material boundaries and suppress obvious repetition.
- Tree branches combine angled two-triangle cards with original cedar sprays, broadleaf clusters and mountain-ash leaflets from `kasumi_foliage.aseprite`. Each authored stem is anchored to a modeled twig, and branches and foliage share the same wind deformation. Transparent cutouts provide silhouette detail without large solid polygon fans.
- The glTF `Shelter` color attribute carries designed shading beneath overhangs and around foundations. Kasumi adds soft ground contact shading anchored to building and shrine footprints; screen-space AO is disabled to avoid view-dependent contact artifacts. Godot interpolates vertex lighting. No added random vertex wobble or global grain is applied to Kasumi.
- Composition progresses from dark foreground joinery and a few amber lights, through a dark blue dusk lane, to low field banks, groves, foothills and three mountain profiles. The world surrounds the walking area in all directions. Low evening sky light and close, dark mist leave warm windows and lanterns as focal points. Eye-height haze builds smoothly over the first 2.5–9 metres, with thicker moving ribbons obscuring the far end of the lane and surrounding fields. A warm-highlight halo and bounded world-space light spill make those lights luminous without brightening the entire scene.
- Crops bend from modeled roots. Cloth hangs from fixed upper edges. Rain rings, cloud drift and fog advection share the scene clock and pause together.

## Deliberate modern extensions

The existing higher-resolution viewport, free camera, depth buffer, world-space foundation shading, shader water, ray-marched fog and instanced vegetation exceed original hardware capabilities. Keeping them is consistent with the requested fidelity. This is a researched artistic interpretation in Godot, not a claim of exact PS1 emulation. The other two channels retain their established rendering.

## Edit and regenerate

`kasumi_materials_0.aseprite` through `kasumi_materials_3.aseprite` are the editable pages. Preserve manual edits before regeneration. Export them to `assets/textures/KasumiAtlas0.png` through `KasumiAtlas3.png`; the material index and tile positions are recorded in `assets/data/kasumi_layout.json`.

Use `tools/build.ps1 -RebuildAssets` to regenerate geometry from the committed texture pages. Add `-RebuildTextures -Aseprite <exe>` only when deliberately regenerating the pages from Lua. `blender/kasumi_town.blend` retains named architecture and landscape groups, while `blender/kasumi_plants.blend` contains the reusable root-anchored vegetation.

## Phuket — midday rebuild

The coast is an original Andaman-inspired composition rather than a geographic replica. Regional reference: the Tourism Authority of Thailand describes Phang Nga's vertical limestone islands and caverns (https://www.tourismthailand.org/Destinations/Provinces/Phang-Nga/348), while the Thailand Film Office documents the coastal stilt architecture of Ko Panyi (https://tfo.dot.go.th/locations/koh-panyi/). The working pier borrows the practical language of timber piles, cross braces, broad roof overhangs and painted boards without copying a specific building.

Eight original 256×256 RGB555 texture studies keep material detail deliberate. Folded palm leaflets, individual deck planks, engine geometry, roof courses and asymmetric rock silhouettes carry the design. Surface mapping remains anchored to the geometry. No fake camera-dependent wobble or grain is added.

Modern extensions are explicit: transparent animated water, geometric sun shadows, depth-based mountain mist, occlusion-aware lens flare, procedural wildlife and positional walking constraints. Fish and turtle remain between the seabed and water surface; Pause freezes their animation with the weather. The editable Blender source preserves individual named objects; the GLB batches static geometry for the runtime.
