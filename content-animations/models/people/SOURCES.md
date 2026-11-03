# Traffic human — 2026-11-01

Current source: [Man by Quaternius](https://poly.pizza/m/HMnuH5geEG). The source page lists animated FBX/GLTF and Public Domain ([CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)). It has a shirt, shorts, shoes, a skinned rig and 11 original clips.

`man-casual-source.glb` is the unmodified download. Its CDN URL ends in `.glb.br`, but the delivered bytes are an ordinary GLB (glTF magic/header verified). SHA-256: `dad8fa3ca2bc7760892f9ff47f544941179e50acb2aa772cf9f035154a37fc58`. Download URL, sizes and hashes of every current output are in `manifest.json`.

| File | Adaptation |
| --- | --- |
| `traffic-pedestrian.glb` | Original Walk and Idle clips, normalized to approximately 1.75 m and facing +X. Joint translation channels are retained: the source feet are separate targets, so stripping all positions breaks its walking motion. |
| `traffic-cyclist.glb` | Custom 30 fps Pedal loop, baked with a two-link limb solver to the actual city bicycle grips/pedals. Riding leg proportions are adjusted to reach the high saddle. This clip was authored locally; it was not included in the downloaded model. |
| `traffic-motorcyclist.glb` | Custom Ride pose matching the actual sport motorcycle saddle, grips and footpegs, plus a locally built full-face helmet attached to the head, with a dark visor and chin guard/vent. This pose/helmet was authored locally. |

The bicycle crank and pedal meshes rotate with the baked rider using the same travelled distance (5.5 model metres per pedal revolution). Waiting does not advance the cycle. Pedestrians use Idle outside a move step. The renderer does not apply the old standing-rider offset/scale/neutral animation.

## Rebuild

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' -b --python-exit-code 1 --python scripts/build-review-humans.py
python -X utf8 scripts/author-animation-scenes.py
python -X utf8 scripts/report-animation-feedback.py
```

Run from the repository root. The builder uses a separate background process; it does not alter a live Blender scene. It also writes editable riding scenes to `output/animation-review/traffic-cyclist.blend` and `traffic-motorcyclist.blend`, renders previews, and checks limb-target reachability. It must stop if a target cannot be reached within 2 mm. Those calculated joint targets are distinct from visual verification of the skinned surface.

Open `humans.html` to inspect the three profiles from different angles. Actual source scenes to review: 573 (pedestrian), 577 (three cyclists), 486 (motorcycle). No animation is approved automatically.

## Earlier asset retained

`hoodie-character.glb`: [Hoodie Character by Quaternius](https://poly.pizza/m/gKLBoRsyKe), downloaded 2026-10-31, listed CC0. Retained for provenance; the current review renderer uses the Man profiles above.

The user's Universal Base Characters ZIP is not used or modified. The alternate Casual Character download inspected during selection is stored separately under `output/animation-review/human-candidates/`, not served as the selected character.
