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

## Lowwater — southern canal

The user's five supplied landscape photographs guide an original canal environment: enclosing oak limbs, vine-clad columns, dark banks, hanging moss and pale mist. A subsequent explicit direction emphasized deep blacks and bright whites. The scene uses a dedicated postprocess print curve, soft highlight diffusion and nearly neutral silver tones with slightly warm whites. No photographic pixels, plate damage, film-grain overlay or camera-dependent surface shading are used.

Five original 256×256 pages describe fissured bark, damp earth, twig foliage, broad climbing leaves and perforated moss. The deterministic Blender generator keeps named editable parts and exports six material batches, including the water. Branches grow from modeled attachment points; flared roots finish at sampled terrain heights. Folded botanical cards provide a deliberate reduced-resolution silhouette. All geometry, including the bending canal surface and vegetation, is generated in Blender. Runtime terrain sampling and collision derive from the same formulas/layout.

Modern extensions are world-space animated mist, a reduced-resolution planar reflection camera, photographic tonal grading and anchored moss deformation. Reflection cameras continue to follow free look while Pause freezes environmental motion. The print curve is confined to Lowwater and is captured in its menu-return image. Review the bright clearing from both directions as well as the opening; the scene intentionally moves from black canopy silhouettes into luminous mist.

Foliage follows gravity: climbing stems rise, but the broad leaf blades project outward and downward in staggered overlapping layers. Canopy sprays droop from their twigs. Hanging moss has its dense attachment at the branch and tapers to unequal strand ends, with source UVs verified after glTF conversion. Broad two-sided diffuse light prevents a thin leaf card from turning white/black solely because the camera views its opposite face. The deep blacks belong primarily to trunks and sheltered masses; luminous whites belong to mist and sky, rather than an exaggerated leaf-face lighting split.

The canopy is built as interlocking tree crowns, not a freestanding ceiling. Upper limbs spread into neighboring crowns; four near-bank oaks send lower arched boughs across the canal. Every fork and foliage spray attaches to its supporting branch. The resulting dark overhead mass frames a smaller distant opening of white mist, with irregular sky gaps visible from underneath. Canopy coverage is reviewed from the walking route, both banks and the reverse direction as well as the opening composition.

The lower bough attachments are lifted roughly 1.4–2.5 metres to give the route more headroom. Six looser crown limbs per tree and two irregular skylights admit sunlight. Blender also bakes an alpha-aware 384×384 sun-depth texture from the actual wood and leaf geometry, using packed linear RG depth; the fog samples it in world space to produce stable canopy-occluded light shafts without another runtime camera. The light direction in the geometry bake, atmosphere and directional light must stay aligned. Moss motion does not alter this static shadow bake. Thin drifting mist follows the canal surface and bank heights, while reduced general haze preserves shadow detail. All drift uses the scene clock and freezes under Pause.

## Night Laundry and Reservoir of Columns

The two channels develop the user's selected generated concepts: mint/cream enamel, pink/cyan signs and rain for Night Laundry; colossal, nearly monochrome concrete and luminous ceiling openings for Reservoir. The latter takes architectural scale cues from BLAME!'s megastructure but contains original geometry, materials and sound.

`blender/build_interiors.py` preserves named editable components before exporting material batches. Washer rims and inset drums, plumbing, ceiling suspension rods, shopfront framing, a wire cart and grounded furniture carry the laundry silhouettes. The reservoir retains complete supports and ceiling slabs with three actual cutouts; causeway slabs meet without coplanar overlaps. Its row groups contain seventy columns. The large size uses simple structural geometry and bounded draw calls rather than detailed geometry at every distance.

Five original 256×256 studies use RGB555-derived values. Texture mipmaps reduce distant floor shimmer. Water stains and formwork marks are anchored to object/world coordinates. An initial dense striping study was rejected during native review; final concrete has broader mottling and restrained vertical deposits. No camera-dependent wobble, random full-screen grain or screen-space contact shading was added.

Modern additions are low-resolution planar reflections, analytic world-space aperture scattering, scene-local highlight diffusion and deterministic weather/traffic. The aperture rectangles in `interior_common.gdshaderinc` must match the generator/layout. The openings sit between the transverse ceiling supports. Reflection rendering discards submerged reservoir geometry. Particle anchors wrap as units so falling trails do not stretch across their whole volume at cycle boundaries. Opaque atmosphere renders before glass, rain, droplets and dust. All animation reads the shared scene clock, and native review includes a frozen-Pause image comparison and a shafts-on/off comparison.
