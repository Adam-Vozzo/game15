# Still — Atmosphere Channels

Three quiet places, modeled in **Blender** and rendered in **Godot 4**. A Wii-inspired channel menu brings them together: pale rounded tiles, soft blue focus rings, a local clock, and a gentle transition into each scene.

![Channel menu](previews/menu.png)

| Experience | Atmosphere and small stories |
| --- | --- |
| **The Still Moor** | Moonlight through rolling ground fog, wind through rooted grass and ferns, twisted trees and an eroded hollow. The darker grass and ground from the earlier revision are preserved. |
| **Phuket, Last Light** | Amber cloud cover, a shimmering sea and lapping foam, feathered palms, a gently rocking long-tail boat, a mooring rope, empty chairs, a forgotten cup, sandals and fading footprints. |
| **Kasumi Lane** | An original rural Japanese town inspired by the quiet unease of Ebisugaoka: mist between timber houses, soft rain, wet paving, warm shoji windows, a paper lantern, fluttering noren and laundry, delivery crates, a bicycle, red flowers and a side-path shrine. |

![Phuket sunset](assets/menu/coast.png)
![Kasumi Lane](assets/menu/town.png)

All three use low-poly geometry, original small textures, a deliberately low-resolution 3D viewport, restrained vertex snapping, quantized colors, dithering and film grain. Text and controls remain at display resolution. The environments are meant for slow wandering; there are no objectives or jump scares.

## Play and controls

Choose a channel from the menu. **Channels** in the upper-right corner, or **Esc**, returns to the same menu. Sound is off initially; its setting follows you between scenes.

- **Desktop:** drag to look; **WASD** or **arrow keys** to walk. **Tab / Enter** can select menu buttons. **H** hides the scene interface.
- **Touch:** the left-thumb joystick walks; a second finger can drag elsewhere to look. Button taps are excluded from camera gestures. Finger ownership, cancellation, focus loss, a dead zone and capped diagonal speed prevent stuck or doubled movement.
- **Sound:** toggles the original ambient loop for the current place. The menu has a quiet sustained chord, the moor has wind, the coast has sea wash, and the town has rain.
- **Pause:** freezes the weather and environmental animation while still allowing you to look and walk. Browser reduced-motion preferences initially pause the scene.
- **Reset:** returns to the opening viewpoint. **Hide controls** leaves the joystick and the Channels button accessible.

The menu reflows for portrait and short landscape windows. The scene camera adjusts its framing for portrait touch screens. Town building footprints block the walking camera; this is otherwise a simple terrain-following walk, not a physics-based character controller.

## GitHub Pages — manual setup

The complete web export is committed in **`docs/`**. In repository **Settings → Pages**, select **Deploy from a branch → main → /docs**, then **Save**. Pages configuration is left to the repository owner.

No build workflow or custom server headers are needed. The single-threaded Compatibility export uses WebGL 2 and WebAssembly; see [Godot's web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html). It loads approximately 40 MB of engine WebAssembly plus an approximately 8 MB game package before starting.

## Edit in Godot or Blender

Built with **Godot 4.7.2 stable** and **Blender 5.2.1 LTS**.

Open `project.godot` and press **F5** to run the channel menu. Open `main.tscn`, `coast.tscn` or `town.tscn` and press **F6** to run one place directly.

| File | Purpose |
| --- | --- |
| `blender/hollow_moor.blend` | Editable moor, trees, roots, rocks and vegetation source |
| `blender/phuket_coast.blend` | Editable beach, palms, boat, headlands and shore props |
| `blender/kasumi_town.blend` | Editable houses, roofs, lane, props, shrine and plants |
| `blender/build_assets.py` | Deterministic original moor asset generator |
| `blender/build_places.py` | Deterministic coast/town models, textures and ambient loops |
| `assets/models/` | Exported GLBs used by Godot; static objects are joined to reduce draw calls |
| `scripts/menu.gd`, `scripts/session.gd` | Responsive channels, scene transitions and shared sound preference |
| `scripts/main.gd` | Shared viewport, camera, controls and moor assembly |
| `scripts/place.gd` | Coast/town materials, ocean, motion, terrain and building bounds |
| `scripts/touch_controls.gd` | Independent walking and looking gestures |
| `shaders/` | Surface shading, grass/palm/cloth wind, water, fog, rain and menu background |

The `.blend` sources keep individual modeled objects. They are excluded from automatic Godot importing with `blender/.gdignore`; opening the Godot project uses the committed GLBs and does not require configuring Blender.

The depth-aware fog is a custom ray-marched Compatibility post-process, so it also works in the web export. The original moor uses higher-density ground fog; the coast uses warm distance haze; the town uses low cold mist and rain. Palm deformation is weighted outward from the crown; cloth is weighted down from its anchored top edge. Grass still uses local vertex height, keeping its roots stationary even when imported UV coordinates are flipped.

## Rebuild

Install matching Godot export templates, then use **Project → Export → Web → Export Project** and target `docs/index.html`.

Or use PowerShell:

```powershell
./tools/build.ps1 -Godot 'C:/path/to/godot.exe'
# Regenerate all three environments from the Blender scripts as well:
./tools/build.ps1 -Godot 'C:/path/to/godot.exe' -Blender 'C:/path/to/blender.exe' -RebuildAssets
```

The rebuild switch overwrites generated `.blend`, GLB, texture and audio files. Preserve manual art edits before running it. The town generator uses Yu Gothic if available on Windows to turn the short shop sign into mesh geometry; it does not bundle the font.

Scene previews are actual Godot renders. To refresh one, run a graphical Godot instance:

```sh
godot --path . --resolution 1280x800 -- --experience=coast --clean-capture --capture=/absolute/path/to/assets/menu/coast.png
# Omit --experience and --clean-capture to capture the menu.
```

Reimport preview images before exporting. Commit the source and rebuilt `docs/` together.

## Validation

```sh
godot --headless --path . --script tests/run.gd
godot --headless --path . --script tests/channels.gd
node tests/validate_web.mjs
# Imported grass root/upper-blade GPU regression, requiring a display:
godot --path . --rendering-method gl_compatibility --script tests/grass_wind.gd
# Live native resize and touch-layout regression:
godot --path . --script tests/resize.gd
```

The build runs input tests and round trips through all three channels, checking sound persistence, UI touch exclusion, emulated-mouse suppression, pause, town building bounds and scene cleanup. Desktop and portrait renders are inspected for framing, interface placement, and script/shader errors. The browser export also passed scene loading, return-to-menu and pause checks. Its canvas buffer follows CSS dimensions to avoid unnecessary high-DPI rendering cost. The exported package is checked for its WebAssembly/package headers, sizes, relative Pages paths and single-thread configuration.

Physical iOS/Android devices have not been tested. Browser/GPU performance varies; touch devices use a smaller render budget and less moor vegetation. The imported world art remains the same on desktop and touch.

All environment geometry, textures and ambient audio were created for this project. The town and menu use original assets, with no Silent Hill or Nintendo artwork. Godot and its dependencies retain their upstream licenses in `licenses/GODOT_LICENSE.txt` and `licenses/GODOT_THIRD_PARTY.txt`.
