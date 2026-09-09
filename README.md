# Still — Atmosphere Channels

Four atmospheric places, modeled in **Blender** and rendered in **Godot 4**. A Wii-inspired channel menu brings them together: full-frame rounded image tiles, subtle scanlines, hover titles, a curved lower dock and a segmented local clock. Selecting a tile expands it to fill the screen; leaving shrinks the current scene back into its channel.

![Channel menu](previews/menu.png)

| Experience | Atmosphere and small stories |
| --- | --- |
| **The Still Moor** | Moonlight through rolling ground fog, wind through rooted grass and ferns, twisted trees and an eroded hollow. The darker grass and ground from the earlier revision are preserved. |
| **Phuket, Blue Bay** | Sunny midday beneath a rich blue sky: towering limestone islands, an eroded sea arch, drifting mountain mist, sun flare, clear turquoise shallows, four independently steering schools of 48 fish and a swimming turtle. Coconut palms shade a working timber pier, tiled pavilion and painted stilt hut; a long-tail boat rocks at its mooring while seabirds circle overhead. |
| **Kasumi Lane** | A rural valley at late dusk: two-storey timber shops, curved tiled eaves, lattice balconies, weathered signs, warm paper windows, lanterns, gutters, delivery crates and a bicycle. Warm window and lantern halos spill light onto nearby timber and paving. Side paths lead to flooded rice paddies, wheat, drying racks, a scarecrow, kitchen gardens and a wayside shrine. Wind, rain rings, low moving mist, wooded foothills and cloud breaks carry the atmosphere beyond the lane. |

| **Night Crossing** | A weathered wheelhouse in rough night seas: steep crossing swells, broken whitecaps, wave-driven pitch/roll/heave, eroded sea stacks and a rock arch, distant navigation light, window rivulets, rain, warm cabin lamp, compass, radio and a marked sea chart. Original looping surf, engine throb and timber creaks. A huge whale makes brief moonlit surfacing passes before diving beneath the waves. |

![Night Crossing](assets/menu/sea.png)
![Phuket midday](assets/menu/coast.png)
![Kasumi Lane](assets/menu/town.png)

All four use original modeled geometry and textures in a deliberately reduced-resolution 3D viewport. Kasumi now uses researched PS1 art constraints: four 256×256 texture pages, limited palettes, vertex-colored shelter shading and stable perspective-correct architectural UVs. Its models prioritize silhouettes, joinery and readable detail. Phuket uses eight original 256×256 RGB555 material studies, stable surface mapping and authored vertex shading, with carefully modeled palm leaflets, timber joinery and limestone silhouettes. Kasumi and Phuket add no artificial vertex wobble or global film grain. Text and controls remain at display resolution. The environments are meant for slow wandering; there are no objectives or jump scares.

See [Kasumi's hardware research and art decisions](art/PS1_ART_DIRECTION.md), including primary hardware references and the deliberate modern extensions. This is a PS1-inspired Godot experience, not a hardware-accurate console build.

![The flooded lower fields](previews/kasumi-fields.png)
![The wheat fields and wooded valley](previews/kasumi-wheat.png)

Each scene has its own contrast and fog treatment. The moor retains its depth-based contact shading. Phuket uses directional sunlight, geometric shadows and cool distance haze without screen-space AO. Kasumi uses stable world-space foundation shading, with screen-space AO disabled. Night Crossing uses cabin lighting, geometric overlap and a warm lamp halo without screen-space AO.

## Play and controls

Choose a channel from the menu. **Leave** beside the settings gear in the bottom-right corner. **Leave** returns to the same menu. Sound is off initially; its setting follows you between scenes.

- **Desktop:** selecting a channel locks the pointer for mouse-look. **Esc** releases it without leaving; click the scene to capture it again. **WASD** or **arrow keys** to walk. **Tab / Enter** can select menu buttons.
- **Touch:** the left-thumb joystick walks; a second finger can drag elsewhere to look. Button taps are excluded from camera gestures. Finger ownership, cancellation, focus loss, a dead zone and capped diagonal speed prevent stuck or doubled movement.
- **Settings:** tap the bottom-right gear to expand a vertical stack of controls; tap again to collapse it. Scene titles and lower-left captions are hidden.
- **Sound:** toggles the original ambient loop for the current place. The menu has a quiet sustained chord, the moor has wind, the coast has sea wash, the town has rain, and Night Crossing has rough surf, a low engine and creaking timber.
- **Pause:** freezes the weather and environmental animation while still allowing you to look and walk. Browser reduced-motion preferences initially pause the scene.
- **Night Crossing:** movement is confined to the wheelhouse. **Full motion / Gentle motion** changes hull pitch and roll; the wave heights remain unchanged. The same wave function drives the ocean and hull, and Pause freezes both.
- **Reset:** returns to the opening viewpoint.

The menu reflows for portrait and short landscape windows. The scene camera adjusts its framing for portrait touch screens. Town building footprints block the walking camera; this is otherwise a simple terrain-following walk, not a physics-based character controller.

## GitHub Pages — manual setup

The complete web export is committed in **`docs/`**. In repository **Settings → Pages**, select **Deploy from a branch → main → /docs**, then **Save**. Pages configuration is left to the repository owner.

No build workflow or custom server headers are needed. The single-threaded Compatibility export uses WebGL 2 and WebAssembly; see [Godot's web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html). It loads approximately 40 MB of engine WebAssembly plus an approximately 20 MB game package before starting.

## Edit in Godot or Blender

Built with **Godot 4.7.2 stable** and **Blender 5.2.1 LTS**.

Open `project.godot` and press **F5** to run the channel menu. Open `main.tscn`, `coast.tscn`, `town.tscn` or `sea.tscn` and press **F6** to run one place directly.

| File | Purpose |
| --- | --- |
| `blender/hollow_moor.blend` | Editable moor, trees, roots, rocks and vegetation source |
| `blender/night_crossing.blend`, `blender/build_sea.py` | Editable wheelhouse, hull and props, deterministic texture/audio generation; export batches static parts into seven material groups |
| `blender/night_whale.blend`, `blender/build_whale.py` | Original whale with tapered body, long flippers, dorsal fin and animated tail flukes |
| `scripts/sea.gd`, `shaders/sea_*.gdshader*` | Wave geometry, matching hull motion, rain, glass, sea mist and warm lamp bloom |
| `blender/phuket_midday.blend`, `blender/build_phuket.py` | Editable midday shore, limestone islands, coconut palms, working pier, pavilion and long-tail boat |
| `blender/kasumi_town.blend` | Editable houses, roofs, lane, props, shrine and plants |
| `blender/kasumi_plants.blend` | Three branch-and-crown tree studies, rice, wheat, verge grass and lilies |
| `blender/build_kasumi.py` | Deterministic architecture, terrain, field banks, props and plant source |
| `art/kasumi_materials_0.aseprite` through `kasumi_materials_3.aseprite` | Editable 256×256 texture pages with named layers and palettes |
| `art/kasumi_foliage.aseprite` | Cedar, broadleaf and mountain-ash cutouts; crowns use only 84–114 triangles each |
| `art/build_kasumi_atlas.lua` | Aseprite script for the original material studies |
| `blender/build_assets.py` | Deterministic original moor asset generator |
| `blender/build_places.py` | Deterministic coast/town models, textures and ambient loops |
| `assets/models/` | Exported GLBs used by Godot; static objects are joined to reduce draw calls |
| `scripts/menu.gd`, `scripts/session.gd` | Responsive channels, scene transitions and shared sound preference |
| `scripts/main.gd` | Shared viewport, camera, controls and moor assembly |
| `scripts/phuket.gd`, `shaders/phuket_*.gdshader` | Midday lighting, sun flare, transparent shallows, wildlife, pier walking and surface materials |
| `blender/build_phuket_audio.py` | Original stereo surf and coastal bird loop |
| `scripts/kasumi.gd`, `assets/data/kasumi_layout.json` | Town assembly, fields, root-anchored crops, shared terrain heights and building bounds |
| `scripts/touch_controls.gd` | Independent walking and looking gestures |
| `shaders/` | Surface shading, grass/palm/cloth wind, water, fog, rain and menu background |

The `.blend` sources keep editable named objects and architectural groups. They are excluded from automatic Godot importing with `blender/.gdignore`; opening the Godot project uses the committed GLBs and does not require configuring Blender or Aseprite.

The depth-aware fog is a custom ray-marched Compatibility post-process, so it also works in the web export. The original moor uses higher-density ground fog; the coast uses cool mist against sunlit limestone; the town uses low cold mist and rain. Palm deformation is weighted outward from the crown; cloth is weighted down from its anchored top edge. Grass still uses local vertex height, keeping its roots stationary even when imported UV coordinates are flipped.

## Rebuild

Install matching Godot export templates, then use **Project → Export → Web → Export Project** and target `docs/index.html`.

Or use PowerShell:

```powershell
./tools/build.ps1 -Godot 'C:/path/to/godot.exe'
# Regenerate the generated environments from the Blender scripts as well:
./tools/build.ps1 -Godot 'C:/path/to/godot.exe' -Blender 'C:/path/to/blender.exe' -RebuildAssets
# Regenerate the Aseprite pages from Lua as well (overwrites texture-source edits):
./tools/build.ps1 -Godot 'C:/path/to/godot.exe' -Blender 'C:/path/to/blender.exe' -Aseprite 'C:/path/to/aseprite.exe' -RebuildAssets -RebuildTextures
```

The rebuild switch overwrites generated `.blend`, GLB, coast/moor texture and audio files. Kasumi reads the committed Aseprite PNG pages unless `-RebuildTextures` is explicitly supplied. Preserve manual art edits before regeneration. The town generator uses Yu Gothic if available on Windows to turn original shop signs into mesh geometry; it does not bundle the font.

Scene previews are actual Godot renders. To refresh one, run a graphical Godot instance:

```sh
godot --path . --resolution 1280x800 -- --experience=coast --clean-capture --capture=/absolute/path/to/assets/menu/coast.png
godot --path . --resolution 1280x800 -- --experience=town --view=fields --clean-capture --capture=/absolute/path/to/previews/kasumi-fields.png
# Omit --experience and --clean-capture to capture the menu.
```

Reimport preview images before exporting. Commit the source and rebuilt `docs/` together.

## Validation

```sh
godot --headless --path . --script tests/run.gd
godot --headless --path . --script tests/channels.gd
godot --headless --path . --script tests/kasumi.gd
godot --path . --script tests/kasumi_wind.gd
godot --path . --script tests/kasumi_uv.gd
godot --path . --script tests/kasumi_contact.gd
node tests/validate_web.mjs
# Imported grass root/upper-blade GPU regression, requiring a display:
godot --path . --rendering-method gl_compatibility --script tests/grass_wind.gd
# GPU occlusion: contact shading, clean flat surfaces/sky, and both sample budgets:
godot --path . --script tests/occlusion.gd
# Live native resize and touch-layout regression:
godot --path . --script tests/resize.gd
```

The build runs input tests and round trips through all four channels, checking sound persistence, UI touch exclusion, emulated-mouse suppression, pause, town building bounds and scene cleanup. Kasumi additionally checks all 18 building footprints, 30 field heights, the connected main lane, imported vegetation roots and texture-page dimensions. Shrine steps and landing heights agree with the walking surface, and solid garden walls block movement. GPU tests confirm rice, wheat and verge roots remain anchored while their tips move, and architectural UVs and world-anchored foundation shading stay fixed across camera translation and rotation. Kasumi uses authored shelter shading and soft world-space contact shade instead of screen-space AO. Its shrine cap and stair treads do not overlap, avoiding coplanar flicker. Desktop, surrounding-landscape and portrait renders are inspected for framing and script/shader errors. The browser export is checked for scene loading, return-to-menu and pause. Its canvas buffer follows CSS dimensions to avoid unnecessary high-DPI rendering cost. The package is checked for WebAssembly/package headers, sizes, relative Pages paths and single-thread configuration.

Physical iOS/Android devices have not been tested. Browser/GPU performance varies; touch devices use a smaller render budget and less moor vegetation. The imported world art remains the same on desktop and touch.

All environment geometry, textures and ambient audio were created for this project. The town and menu use original assets, with no Silent Hill or Nintendo artwork. Godot and its dependencies retain their upstream licenses in `licenses/GODOT_LICENSE.txt` and `licenses/GODOT_THIRD_PARTY.txt`.

### Night Crossing reference and implementation

Mood and first-person framing reference: [Sailing study by Ray_Ervian](https://x.com/ray_ervian/status/2097336882682380306). All shipped models, textures and audio are original; no video assets are included. The sea uses five crossing wave phases, slowly changing wave groups, warped phases and procedural crest foam with wind-carried spray cards. This is an atmospheric boat experience with bounded movement, not a vessel-navigation or fluid-dynamics simulator. The rocks include irregular stacks and an eroded arch. The model keeps named parts in Blender and exports seven material batches for the web. `tests/sea.gd` verifies motion, shared clocks, pause, gentle motion, cabin boundaries and reset.

The hull samples the sea across its footprint, keeping the deck above adjacent crests; water masking is limited to below the solid deck so it cannot cut a visible hole out of a wave. Additional rock groups surround the boat on both sides and astern. Cabin lettering and repeated dot-shaped paint chips have been removed. Rain and window rivulets run downward; glass and spray render after the opaque atmosphere pass.
