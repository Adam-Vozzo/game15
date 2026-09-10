# Project handoff

## Identity
Still — Atmosphere Channels is a browser-based collection of atmospheric, PS1-inspired 3D experiences. Repository: https://github.com/Adam-Vozzo/game15. Latest published implementation at handoff: `27f9cde` on `main` (2026-09-10). GitHub Pages uses `docs/`; the owner manages Pages configuration.

## Experiences
- **The Still Moor**: rooted grass, twisted trees, moonlight, rolling fog and tree-occluded screen-space moon shafts.
- **Phuket, Blue Bay**: sunny midday, limestone islands, palm trees, timber piers and huts, long-tail boat, four schools totalling 48 fish, turtle and birds. Boat water exclusion follows hull motion. Dock ropes, benches, roof framing and hut access were repaired.
- **Kasumi Lane**: original rural Japanese valley inspired by reference imagery, with detailed buildings, fields and wooded surroundings. Late evening, close fog, warm window halos, cloud-veiled moon and supported laundry. Earlier camera-dependent shading, shrine and foliage issues were repaired.
- **Night Crossing**: boat in rough night seas, irregular waves, buoyancy, crest spray, rain, rock archipelagos and brief surfacing passes by a large whale.
- **Lowwater**: new, unpublished southern canal channel based on the user's supplied Sally Mann landscape references. Rooted oaks, dense ivy, hanging moss, low mist, a luminous clearing and planar water reflections. User explicitly requested deep blacks and bright whites: a dedicated print curve and restrained highlight diffusion run inside this scene's viewport. Original assets only; no reference photographs bundled.

## Shared UI
Wii-inspired image channel tiles, hover labels, scanlines, segmented clock and curved footer. Channels expand into scenes and shrink back with animated corner radii. Scene UI is only Leave and a settings gear; the gear expands Sound/Pause/Reset and sea motion options. Desktop pointer lock is requested on entry, Escape releases it. The Codex in-app browser previously rejected pointer lock with WrongDocumentError; drag-look fallback remains available. Touch uses simultaneous movement and look gestures.

## Main files
- `scripts/main.gd`: shared viewport, camera, controls and moor.
- `scripts/session.gd`, `scripts/menu.gd`: session, menu transitions and sound preference.
- `scripts/kasumi.gd`, `scripts/phuket.gd`, `scripts/sea.gd`: experience behaviour.
- `blender/build_kasumi.py`, `build_phuket.py`, `build_sea.py`, `build_whale.py`: original generated assets and editable Blender outputs.
- `art/`: Kasumi Aseprite studies and documented PS1 art direction.
- `shaders/`: material, atmosphere, water and UI rendering.
- `tests/`: regression coverage for controls, transitions, scene behaviour and web packaging.

## Local tools
On the original Windows host:
- Godot: `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`
- Blender: `C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe`
- Aseprite: `E:/SteamLibrary/steamapps/common/Aseprite/Aseprite.exe`
- Node: `C:/Program Files/nodejs/node.exe`

Build from the repo root:
```powershell
./tools/build.ps1 -Godot 'C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
node tests/validate_web.mjs
```
Asset regeneration is separate; inspect the build script and relevant generator before using regeneration switches. Do not overwrite manual source edits unintentionally.

The existing localhost preview is `http://localhost:5175/`, serving this repo's `docs/` from an external helper. A new checkout may need its own static server; keep the currently running preview intact. Engine logs and review captures are under ignored `build-logs/`.

Native capture example (from repo root; absolute capture path recommended):
```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . --resolution 1280x800 --fixed-fps 60 --quit-after 100 -- --experience=coast --view=dock --clean-capture --capture=C:/Temp/coast.png
```
Experience IDs are `moor`, `coast`, `town`, `sea`. Review view names are defined in each scene script. Night Crossing supports `--sea-time=13` for reproducible whale/wave inspection.

Lowwater adds ID `lowwater`, with review views `canal`, `reverse`, `roots`, `canopy`, `west`, and `--lowwater-time=24`. Source: `blender/build_lowwater.py` and `blender/lowwater.blend`; runtime: `scripts/lowwater.gd`, `shaders/lowwater_*`. Regeneration is included in `tools/build.ps1 -RebuildAssets`. The GLB import disables mesh compression to preserve terrain vertex heights. Reflections share `view.find_world_3d()` and omit water and the main postprocess through render layers. The reflection camera is mirrored about y=-0.12; back faces are rejected in its material pass so the bank undersides do not obscure the reflected trees.

The menu now calculates enough rows for every registered channel on phones and short landscape windows. Lowwater uses shared desktop/touch controls and settings; its continuous right-bank route, water/trunk collision, terrain agreement, Pause and Reset have dedicated regression coverage. `tests/lowwater_visual.gd` requires a native display and checks the actual black/white range, frozen rendered Pause, evolving fog/moss and populated reflection. Native opening, canal, reverse, roots, canopy, west and time-offset captures are in ignored `build-logs/`. No commit or publication was requested for this channel.

Verification (2026-09-10): full `tools/build.ps1` import/regression/export passed, including all five channel round trips; native Lowwater GPU and all-scene resize tests passed; `node tests/validate_web.mjs` and `git diff --check` passed. The rebuilt `docs/` package is about 33 MB. Local browser checks passed for loading Lowwater, settings, Pause/Resume state, drag-look while paused, Reset, return to menu, and all five tiles at 390×844 and 640×360. The known Codex in-app browser pointer-lock `WrongDocumentError` remains; drag-look was verified. Physical touch devices were not tested. The final actual-render tile is `assets/menu/lowwater.png`.

Lowwater foliage correction (same day): the user identified upward-facing ivy, inverted hanging moss with a blunt bottom edge, and leaves appearing white on one side of a tree and black on the other. These were construction/lighting defects, not intentional photographic treatment. The Blender generator now makes rooted runners following the trunk profile, staggered overlapping leaves whose tips descend from the petiole, and downward canopy sprays. Leaf texture veins are restrained rather than broad repeating chevrons. Moss root-to-tip V coordinates are corrected in Blender, with tapered, unequal strand ends; after glTF's V conversion the imported attachment is UV.y=1, so the existing wind weight now actually fixes the attachment. Cutout foliage uses broad two-sided diffuse lighting invariant to normal sign; the photographic print curve remains unchanged. Reflection rendering also retains both leaf faces. New review views: `ivy-front`, `ivy-back`, `moss`. Headless regression checks imported ivy/moss orientation and moss alpha taper; the native GPU test compares opposite views of one fixed leaf under fixed illumination in addition to existing print/Pause checks. Close native review captures are `build-logs/lowwater-fixed-*.png`.

The corrected version passed the full build suite, the expanded native foliage/atmosphere checks, web-package validation and diff whitespace checks. The denser modeled runners and folded leaves increase the current web package to about 49 MB; the earlier 33 MB figure describes the first version. The source generator, editable `.blend`, GLB, textures, layout, actual-render thumbnail and `docs/` were regenerated together.

Lowwater canopy expansion (same day): the user requested enclosure like the low spreading oak canopies in their references, rather than widely separated crowns and exposed sky. Each tree now has seven connected spreading upper crown limbs with lateral twigs and overlapping drooping foliage; exposed pointed trunk tips terminate inside the crown. The four nearer canal oaks also carry three lower arching boughs apiece that knit across the canal and right-bank route. The farther clearing remains open at eye height. New growth uses a separate deterministic random seed so established lower limbs, ivy distribution and collision footprints remain stable. All additions are authored in `blender/build_lowwater.py` and regenerated into the editable Blender source and GLB. The mist clearing is slightly brighter to retain the requested white focal point under the darker canopy; leaf lighting and print grading are unchanged. Native opening, bank, overhead, reverse and west-bank review captures are `build-logs/lowwater-canopy-*.png`. The native visual regression now also checks that the overhead view is predominantly covered by canopy.

Canopy validation: full build/import/channel regressions/export passed; native visual checks passed for overhead coverage, deep blacks and bright whites, Pause, reflections and opposite leaf faces. Portrait touch-layout and multi-angle renders were inspected. `node tests/validate_web.mjs` and `git diff --check` passed. The current package is approximately 60 MB; earlier sizes above describe earlier iterations. Physical mobile hardware remains untested. No publication or commit was requested.

Lowwater canopy lift and light pass (2026-09-10): following the user's request for more headroom, light openings, god rays and subtle ground mist, the lowest established boughs were lifted about 1.4–2 m along the actual trunks and the crossing arches about 2–2.5 m. Crowns now use six slightly narrower spreading limbs, with two irregular skylights. Generator, editable Blender scene and GLB are regenerated together. `assets/textures/LowwaterSunDepth.png` is a 384×384 RG-packed linear depth bake: Blender raycasts the actual branch and foliage triangles and skips transparent leaf texels. The atmosphere samples this static sun-space map inside its existing world-space fog march; no extra runtime viewport is needed. Sun basis/extent constants in the generator and atmosphere must remain synchronized, as must the runtime directional light. Swaying moss is deliberately excluded from the static bake. Ground ribbons follow bank/water heights, drift gently with the shared clock, and Pause freezes them. Broad haze was reduced to keep the new scattered light from washing out the landscape. Desktop uses 48 near-weighted fog samples, mobile 28. New capture view: `shafts`. The native visual test additionally compares renders with shafts and ground mist disabled and checks that the overhead canopy contains both foliage and skylight gaps.

Lift/light verification: native opening, overhead, canal, reverse, west, roots, shaft and portrait views were inspected, including a time-offset mist render. The expanded native GPU tests passed. The full build passed import, all regressions and web export; its final `.nojekyll` write encountered a temporary file lock and succeeded when retried separately. Web package validation and whitespace checks passed. The current package is approximately 59 MB. The local exported scene was checked in the browser; no publication was requested.

## Decisions and next direction

Two requested channels added locally (2026-09-11): **Night Laundry** (`laundry`) and **Reservoir of Columns** (`reservoir`). Night Laundry includes washer drums, intermittent fluorescent flicker, pink/cyan neon, rain on the shopfront glass, outdoor rain, a parking/reversing/departure cycle and separate passing traffic, plus original machine/rain ambience. Reservoir has seventy columns beneath an 84 m ceiling, three modeled skylight apertures, world-space beams and drifting dust, stained concrete, quiet reflective water with drip rings and reverberant drip audio. Walkable causeways form a continuous route and loop. Both share desktop/touch input, settings, Leave and transitions. Pause also pauses their audio; Reset restores framing while retaining scene time.

Source: `blender/build_interiors.py`, `blender/night_laundry.blend`, `blender/reservoir.blend`; runtime: `scripts/interior.gd`, `laundry.tscn`, `reservoir.tscn`, `shaders/interior_*`, `shaders/laundry_glass.gdshader`, `shaders/reservoir_water.gdshader`. Five shared Interior texture studies and two original WAV loops are generated with the geometry/layouts. New GLB imports disable compression to preserve slab heights. Static shop parts batch by material and reservoir rows cull separately. Both have small reflection viewports. Aperture rectangles in the shared shader include and generator must remain synchronized. The reflection discards submerged geometry; causeways join without overlapping top faces. Trail vertices wrap around one anchor, avoiding full-volume streaks. Transparent rain/glass/dust render after the opaque atmosphere pass.

Review helper: `tools/review_interiors.ps1 -ImportAssets -Tests -AllViews`. Native captures and parking-cycle frames are in ignored `build-logs/`. The native tests verify rendered Pause and evolving lighting as well as headless collision, route continuity, imported slab height and traffic dwell/departure. Review snapshots measured approximately 27–39 draw calls and 25–28k primitives including reflection at the sampled views on the host RTX 4090; these are not mobile frame-rate guarantees. The menu and channel/resize tests now cover seven experiences. No commit or publication was requested.

Interior verification: full import/regression/export passed for all seven channels, including existing scene tests; native rendered interior tests and all-scene resize tests passed. Browser desktop checks passed for both new channels, rain/traffic/reflections/shafts, settings, Pause/Resume, drag-look, Reset and return to menu. No new browser script/shader errors were found; the existing in-app pointer-lock `WrongDocumentError` remains. A limitation was observed in the in-app browser viewport override: at 390×844 CSS pixels the capture showed content scaled into the upper-left two thirds. Diagnostic logging confirmed Godot's window, viewport and content size all reported 390×844, matching the DOM/canvas size. Resetting the override restored full rendering. This is unresolved and must not be counted as a passing browser-mobile visual check; native portrait and landscape layouts passed, but physical phones remain untested. The temporary diagnostic logging was removed. Current export is approximately 62 MB, about 2.6 MB larger than the previous five-channel package.

The workflow needs more complete authored pieces and deliberate walkthroughs before scaling procedural assembly. Many past issues were geometry/construction mistakes, not engine limitations.

A small Three.js comparison using existing Blender assets was suggested to assess browser iteration, load time and mobile performance. No comparison has been built and no engine migration has been requested. Keep the current Godot project intact unless the user chooses that work.

Git HTTPS did not automatically use the existing GitHub CLI login on this host. The approved push succeeded using a per-command GitHub CLI credential helper; no credentials are stored in this repository. Use existing authentication without printing tokens.
