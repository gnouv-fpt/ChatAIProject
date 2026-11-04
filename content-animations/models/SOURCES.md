# Vehicle assets

Both GLB files are original Innerscene models released under CC0 1.0 Universal.
Source pages and the embedded `asset.copyright` both state the public-domain dedication.
Downloaded 2026-10-31. GLB source files are retained unchanged; scene adaptations are in code.

- `hatchback.glb`: [Silver five-door compact hatchback](https://www.innerscene.com/tools/library/3d-parts/silver-five-door-compact-hatchback-6bf4a878).
  [Original download](https://files.innerscene.com/library/silver-five-door-compact-hatchback-6bf4a878/d40c0ce1ee7464556dc8/silver-five-door-compact-hatchback.glb).
  Display adaptation: red body paint, opaque dark glazing for the transparent scene overlay, wheel pivots, orientation and scale normalization. The displayed body is reshaped into a generic short city car: approximately 3.56 m long with 2.28 m wheelbase, shorter overhangs, narrower width and a higher cabin-to-length ratio. Piecewise deformation preserves circular wheel geometry. This adaptation is not an official Hyundai i10 model.
- `sport-motorcycle.glb`: [Sport motorcycle](https://www.innerscene.com/tools/library/3d-parts/sport-motorcycle-e21e8303).
  [Original download](https://files.innerscene.com/library/sport-motorcycle-e21e8303/625e0c0f4d03a83504cf/sport-motorcycle.glb).
  Display adaptation: wheel pivots, scene scale/origin normalization, original demo rider added separately.

License: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/).
These are generic vehicles selected for visual quality, not models recovered from the exam JPEG.

## Human character

- Current review: [Man by Quaternius](https://poly.pizza/m/HMnuH5geEG), downloaded 2026-11-01 and listed as animated GLTF, Public Domain (CC0 1.0). `people/man-casual-source.glb` is retained unchanged. Three local derivatives provide Walk/Idle, a custom pedalling cycle and a custom motorcycle pose with a full-face helmet, dark visor and chin guard. Blender authoring details, source/download URLs and SHA-256 records are in [`people/SOURCES.md`](people/SOURCES.md) and `people/manifest.json`. Preview: [`humans.html`](../humans.html).
- The earlier `people/hoodie-character.glb` is retained for provenance. The user's `Universal Base Characters[Standard].zip` remains unused and unchanged.

## Detailed fleet replacing the box prototypes

Downloaded 2026-10-31. Each page and each delivered GLB declares CC0-1.0. Original delivered files are kept intact. Actual download SHA-256 values, byte counts and URLs are in `vehicles-manifest.json`. The server adds a copyright field, so the delivered hash differs from the original upload hash on the page.

- `box-truck.glb`: [box-truck](https://www.innerscene.com/tools/library/3d-parts/7-5-t-class-box-truck-with-roll-up-door-12baea66).
- `city-bus.glb`: [city-bus](https://www.innerscene.com/tools/library/3d-parts/12-m-low-floor-city-bus-8e3c7229).
- `delivery-van.glb`: [delivery-van](https://www.innerscene.com/tools/library/3d-parts/high-roof-cargo-panel-van-c4d5145f).
- `ambulance.glb`: [ambulance](https://www.innerscene.com/tools/library/3d-parts/box-body-ambulance-dc8d7b19).
- `fire-engine.glb`: [fire-engine](https://www.innerscene.com/tools/library/3d-parts/fire-engine-pumper-ad69949b).
- `military-truck.glb`: [military-truck](https://www.innerscene.com/tools/library/3d-parts/generic-1940s-2-5-t-cargo-truck-6e78cb4a).
- `semi-trailer.glb`: [semi-trailer](https://www.innerscene.com/tools/library/3d-parts/semi-tractor-and-box-trailer-bc0bdac8).
- `city-bicycle.glb`: [city-bicycle](https://www.innerscene.com/tools/library/3d-parts/city-bicycle-58a2a324).
- `locomotive.glb`: [locomotive](https://www.innerscene.com/tools/library/3d-parts/small-diesel-shunting-locomotive-d53d1994).

Runtime adaptations normalize every front to +X, stand the wheels on Y=0, remove the locomotive display rails/sleepers, rig wheel meshes, and merge static meshes by material. No vehicle body is substituted by box primitives. Police lights/riders and the extra rear wheel on the three-wheel motorcycle remain scene adaptations.
