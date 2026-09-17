# Azure Pilgrimage

The user's supplied Moebius illustration is the visual reference: a very long
white bird with a saffron-to-vermilion bill and green crest, small ochre rider,
cyan reservoirs, curved falls, salmon and lavender rounded cliffs, tiny ferry
boats and settlements. The channel translates that composition into a complete
three-dimensional canyon. The reference image is not a skybox or runtime asset.

`blender/build_azure.py` is the deterministic source. It creates the editable
`blender/azure_pilgrimage.blend`, `assets/models/azure_pilgrimage.glb`, flight
metadata and an original wind / distant waterfall loop. Named source objects
preserve the cliffs, fissures, settlements, bridges, docks, boats, traveller,
bird body, wings and feather contours. Only static same-material objects are
batched for export. No runtime geometry substitutes for the source.

Colour is deliberately flat, with restrained directional colour modelling,
thin closed-mesh silhouette passes and actual three-dimensional pen paths.
Fissures sample the same rock equation as their underlying surface. Bird pen
marks are local to the articulating shoulders. Water marks and waterfall flow
use world coordinates. There is no screen-space grain or vertex jitter.

The water shader carries ink ripples downstream and draws mint currents toward
each lip. Falling ribbons accelerate with depth. `blender/build_azure_water.py`
creates a separate editable `blender/azure_water.blend` and exported
`assets/models/azure_water.glb`: 6,810 tiny source quads across the main curtain
and curved western falls. Four batches become falling threads, ballistic
impact droplets, rising mist and drifting foam curls. Their independent phase,
speed and size seeds survive import as vertex colours; disable mesh compression
and LOD generation for this asset to preserve its anchors. Expanded culling
bounds include the full drop. `shaders/azure_particles.gdshader` evaluates all
motion from the shared scene clock, so Pause and Reset remain deterministic in
Compatibility/WebGL. Mobile uses 65% particle density. Sprite billboarding only
changes orientation; currents and emission positions stay attached to the world.

The upper reservoir must not become a square slab. Its irregular continuous
shore, bedrock, water surface and emitter normals share
`blender/azure_water_geometry.py`. Falling marks use metres along that curve;
the upper water carries distance-to-shore in UV.x. Surface flow is a translation
with bounded distortion: never multiply a spatially varying velocity by elapsed
time, which stretches the drawing more with every orbit.

The whitewater at both waterfall bases is a connected closed mesh with unequal
billows, a submerged underside, rolling colour and animated curls. Separate
oval beads were rejected by the user. Keep the continuous mass between crests.
`azure_foam_motion.gdshaderinc` gives the banks coherent travelling surges and
outward rolls, with larger displacement on the main fall. The waterline and
submerged underside stay pinned. Both the colour and outline passes use that
same function. Foam-only silhouette renders must visibly change; a difference
caused just by particles or moving texture does not prove billowing motion.
Rock contact foam samples each source rock lobe at the actual water plane;
overlapping rocks occlude internal rims. Each ferry owns a source foam ribbon,
and its keel penetrates the water. The ribbon follows X/Z and yaw while staying
flat on the receiving water plane during hull rocking. The shore shader shares
the same pausable clock as the rest of the scene.

Daylight uses a blue sky gradient with a pale blue horizon, deeper zenith and a
small warm sun. The rock shader blends warm illuminated surfaces into cool
shadows and a restrained elevation gradient. Shared aerial colour gradually
reduces distant contrast and shifts it toward sky blue, including contours,
shore foam and particles. Keep the foreground's coral/cyan colour and clean
ink; no blanket bloom, screen grain or camera-dependent surface coordinates.

The bird circles in 210 seconds. Both viewpoints travel with its transform:
the seated view and an initial follow view showing the traveller and complete
wingspan. Mouse / drag look and WASD / arrows / the touch stick turn the view;
flight is automatic. The traveller mesh is hidden in the seated view to avoid
the camera intersecting a head. Pause freezes the flight, shoulder flex,
ferries, water, spray and audio, while free look remains available. Reset
centres the view and keeps the current journey time and selected view mode.

The carrier's idle has slow shoulder lift, slight unequal balancing corrections,
gentle body heave/bank and a small seated rider response. Occasional broad
wingbeats start after six seconds, then recur with unequal 22–31-second gaps.
Each 3.4-second beat gathers upward, pushes down faster and eases back into
the glide. Quintic pose transitions keep velocity and acceleration continuous.
These transforms animate the existing Blender shoulder pivots: both wing
shells and their pen geometry move together, and the roots stay embedded.
No geometry or source rig changes are required. All motion is a deterministic
function of the journey clock, including body response and rider lean; Pause
can hold any point of a downstroke and Reset must preserve it. Keep the seated
camera's additional vertical movement below 0.6 m.

The scene intentionally uses a higher render budget, antialiasing and linear
presentation for ink clarity, as with The Painted Mere. The shared resolution
slider and responsive controls still apply. Godot Compatibility remains the
shipping renderer.

Regenerate the world with Blender's `--background --python blender/build_azure.py`
and the water effects with `--background --python blender/build_azure_water.py`.
`tests/azure.gd` exercises source hierarchy, full orbit clearance, attachment,
camera modes, Pause/Reset and audio. `tests/azure_visual.gd` renders twelve
positions over the complete orbit, both viewpoints, bird side / underside /
overhead, fixed-camera waterfall motion and portrait / landscape controls.
`tests/azure_water_visual.gd` isolates each particle layer, compares frozen Pause
frames, samples a fixed-camera motion sequence and checks basin currents,
close spray, the upper return, overhead and portrait views.
`tests/azure_shore_visual.gd` checks visible island/hull rims, frozen contact
foam, curved shelf elevations and fixed-camera water at 0, 105, 420 and 1,800
seconds. `tests/azure.gd` checks imported ferry-rim vertices at several phases.
`tests/azure_foam_visual.gd` independently checks both banks' changing silhouettes,
isolated foam animation, exact Pause frames, daylight and six orbit views.
Add `-- --foam-reel` to render a fixed-camera 96-frame sequence at 12 fps.
`tests/azure_bird_visual.gd` reviews raised/lowered wings, shoulders, underside,
overhead, both viewpoints, portrait and frozen mid-stroke rendering. Add
`-- --bird-reel` for a 144-frame glide/wingbeat sequence at 12 fps.
Use `--experience=azure --view=follow --azure-time=0` for the menu render;
`--view=aboard` starts at the seat instead.
