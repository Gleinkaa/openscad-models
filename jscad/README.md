# open-jscad-scripts

A collection of standalone, parametric 3D models written as [JSCAD](https://openjscad.xyz/)
(V2) scripts. Each `.js` file in the repository root is a self-contained model — mostly
practical 3D-printing parts (an air-conditioner flange, a door vent grille, a knob, a tray)
plus a few small demo shapes.

Every script exposes UI parameters, so you can change dimensions in the JSCAD web editor and
re-export STL without touching the code.

All dimensions are in **millimetres**.

## Requirements

Nothing to install for the web workflow — just a browser. For the command-line workflow you
need Node.js (18+) and `npx`.

There is no `package.json`, no build step and no test suite in this repository. The scripts
declare `require('@jscad/modeling')`, which both the JSCAD web app and the JSCAD CLI resolve
for you.

## Setup

```bash
git clone git@github.com:Gleinkaa/open-jscad-scripts.git
cd open-jscad-scripts
```

## Usage

### Option 1 — JSCAD web editor (recommended)

1. Open <https://openjscad.xyz/> (or <https://jscad.app/>).
2. Drag a `.js` file from this repository onto the page.
3. The script's parameters appear in the left-hand panel. Adjust them and press
   **Update / Auto-reload** to re-render.
4. Use the **Export** button to save an `.stl` (or `.3mf`, `.amf`, …) for your slicer.

### Option 2 — command line

Render a script headlessly with the JSCAD CLI:

```bash
npx @jscad/cli AC-Flange-154-125mm.js -o AC-Flange.stl
```

Parameter overrides are passed as `--<name> <value>`, using the parameter names from the
script's `getParameterDefinitions()`:

```bash
npx @jscad/cli Open-Tray.js --length 120 --width 80 --wall 3 -o big-tray.stl
```

## Script anatomy

Every file follows the same JSCAD V2 CommonJS shape:

```js
const { cuboid } = require('@jscad/modeling').primitives;
const { subtract } = require('@jscad/modeling').booleans;

// Declares the parameters shown in the JSCAD UI
const getParameterDefinitions = () => [
  { name: 'wall', type: 'float', initial: 2, caption: 'Wall Thickness' }
];

// Receives the resolved parameters, returns the geometry
const main = (p) => subtract(/* ... */);

module.exports = { main, getParameterDefinitions };
```

To add a model, copy that skeleton into a new `.js` file in the repository root and list it
in the table below.

## Key files

| Script | What it makes | Notable parameters |
| --- | --- | --- |
| `AC-Flange-154-125mm.js` | The most developed model here: a hollow duct adapter that steps from a 156 mm base to a 124 mm outlet, with a snap-fit chamfered lip and an angled (`-50°`) transition built from a `hull()` between two thin discs. | `d1`, `d2`, `wall`, `angle`, `chamfer`, `len1`, `len2`, `offset_y`, `offset_z`, `snap_height`, `snap_depth`, `segments` |
| `Door-Vent-Grille.js` | Ventilation cover for a door cut-out: an outer face flange plus an insert that drops into the hole, with a choice of three perforation patterns (`slats`, `grid`, `circles`). Slats wider than 60/120 mm get automatic vertical stiffeners. Throws a descriptive error if the offset or wall thickness exceeds the outer size. | `width`, `length`, `flange_h`, `offset`, `insert_h`, `wall`, `pattern`, `stegbreite`, `lochgroesse` |
| `Door-Vent-Grille-LowNoise.js` | Low-noise, high-flow successor to `Door-Vent-Grille.js`. Its defaults are the 69 × 257 mm door cut-out (flange 81 × 269 mm, 6 mm overlap all round, 12 mm overall = 2 mm flange + 10 mm insert, web 1.6 mm, 38 flare-bore slots, measured 70.06 % open area); the earlier 200 × 60 mm part comes back with `--width 200 --length 60 --offset 12 --flange_h 4 --insert_h 15`. The aperture is laid out by a solver that maximises open area under print and acoustic constraints (wall ≥ web, cell-size cap, slot aspect ≤ 6), every flow-facing edge is flared (quarter-round bell-mouth on the inlet face, 40° cone on the outlet face), and a design report with free area, velocities and warnings is printed to the console when it renders. Measured 70.1 % open area vs 63.8 % for the original. Supports `pattern: auto/slots/honeycomb/hex-holes`. ⚠ `honeycomb` currently exports an open mesh (6,640 boundary edges at 81 × 269, 18,442 on a 2026-09-25 build) — check it before slicing; `auto`/`slots` export closed. | `width`, `length`, `flange_h`, `offset`, `insert_h`, `wall`, `pattern`, `web`, `max_cell`, `inlet_flare`, `outlet_chamfer`, `outlet_angle`, `flare_layers`, `gasket_w`, `gasket_d`, `flow_marker`, `flow_m3h`, `target_v`, `show_report` |
| `Stepped-Cone-Reducer.js` | Two-stage hollow tube reducer — a wide lower section stacked on a narrower upper one. | `d1`, `d2`, `wall`, `h` |
| `D-Shaft-Knob.js` | Control knob with a D-shaped bore for a flatted potentiometer/encoder shaft. | `knobD`, `shaftD`, `flatOffset` |
| `Open-Tray.js` | Rectangular box sized from *inner* dimensions plus a wall thickness. | `length`, `width`, `height`, `wall` |
| `Screen-Bezel-Frame.js` | Picture-frame bezel sized to a display's visible area. | `screenWidth`, `screenHeight`, `bezel`, `depth` |
| `Linear-Rail-Slider.js` | Demo of a rail with a captive slider hoop wrapped around it. | `railLen`, `sliderWidth` |
| `Art-Deco-Profile.js` | Decorative stepped Art Deco silhouette, extruded from a fixed 2D polygon. | `thickness`, `scale` |
| `Glitch-Planter.js` | Stacked cylinder layers randomly offset in X/Y for a "glitched" planter look. | `radius`, `height`, `glitchFactor` |

## Notes and known quirks

The four smallest scripts are sketches rather than finished parts — check the preview before
printing:

- **`Glitch-Planter.js` is non-deterministic.** It calls `Math.random()` per layer, so every
  render produces a different model. Seed it or hard-code the offsets if you need a
  reproducible STL. Its inner cavity is also shifted such that the upper portion stays solid.
- **`Open-Tray.js` comes out closed.** Both cuboids are origin-centred, so the cavity ends up
  fully enclosed rather than open at the top, contrary to the comment in the file. Shift the
  cavity up by `wall` to actually open it.
- **`Art-Deco-Profile.js` ignores its `scale` parameter** — the polygon points are literals.
- **`Door-Vent-Grille.js` has German UI captions** (`Breite`, `Wandstärke`, `Lochmuster`);
  the parameter names themselves are a German/English mix (`stegbreite` = strut width,
  `lochgroesse` = hole size).
- **`AC-Flange-154-125mm.js`** carries a comment referencing a source screenshot
  (`image_7100ad.png`) that is not part of this repository. Its `segments: 120` default gives
  smooth curves but makes rendering noticeably slower — drop it while iterating.
- **`Door-Vent-Grille-LowNoise.js`** lays out its aperture with a solver rather than fixed
  positions, so `pattern: 'auto'` can pick a different cell size when `web` or `max_cell`
  changes — that is intended, and the console report states what it chose. It prints that
  report on every render; set `show_report: 'no'` to silence it. `flow_marker` defaults to
  `'no'` because any marker cut into the flange face leaves the exported mesh non-manifold
  (OrcaSlicer then reports ~12–20 open edges) while the plain part reports `manifold = yes`.
  It relies on JSCAD V2 (`extrusions.slice`, `extrudeFromSlices`), and every 2D outline in it
  must be wound counter-clockwise: a clockwise polygon extrudes inside-out and the following
  boolean then returns the cutter instead of the part.
