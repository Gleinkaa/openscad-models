# openscad-models

A small collection of parametric [OpenSCAD](https://openscad.org/) models for 3D
printing, plus **Parametric Editor** — a self-contained local web UI that turns the
top-level variables of any `.scad` file into sliders and renders the result in the
browser as a live 3D preview.

Everything here is dimensioned in millimetres and written for FDM printing.

---

## Contents

| Path | What it is |
| --- | --- |
| `linear_drive_mg996r.scad` | Rack-and-pinion linear stage driven by an MG996R servo, with dovetail rails, sliding carriage and two KW12-3 limit switches as endstops. |
| `ventilation_adapter_160mm.scad` | 160 mm ventilation duct adapter — 45° elbow. Male end slides into a galvanized pipe, barbed end takes flexible ducting. |
| `crankrockerwithanimation.scad` | Four-bar crank-rocker mechanism (base, crank with slip clutch, connecting rod, rocker) with full kinematics, animated via `$t`. |
| `hcsr04-tank-mount/` | HC-SR04 ultrasonic level-sensor mount for a ~100 mm canister filler hole. It has a flange, a push-in centring collar with friction tabs, a snap-in PCB cradle and a drip lid. Its `part` selector exports each piece. The folder includes STLs, renders and a fit-check test ring. |
| `parametric-editor/scad_editor.py` | The parametric editor — one Python file, standard library only, embedded HTML/JS UI. |
| `parametric-editor/linear_drive_mg996r.scad` | Sample model shipped with the editor. A variant of the top-level linear drive (taller rails, servo mounted under the base rather than on its side). |

---

## Requirements

- **OpenSCAD** — needed to render or export anything.
  [Download](https://openscad.org/downloads.html), or on Debian/Ubuntu:
  `sudo apt install openscad`
- **Python 3.10+** — only for the parametric editor (uses `X | None` type syntax).
  No third-party packages required.
- The editor's browser 3D viewer loads three.js from a CDN, so it needs internet
  access. Without it the sliders, file saving and STL export still work — only the
  in-page 3D view is unavailable.

---

## Using the models

Open any `.scad` file in the OpenSCAD GUI, edit the parameter block at the top,
press **F5** to preview and **F6** to render.

Each model ends with a *render selection* block: an assembled/animated view is
active by default, and the individual printable parts are listed as commented-out
calls. Uncomment one at a time to export its STL.

```scad
// linear_drive_mg996r.scad — bottom of file
assembled_view();

// For individual STL export, uncomment one at a time:
// base_chassis();
// servo_mount();
// endstop_bracket();
// carriage();
// pinion_gear();
// gear_rack(carriage_length - 4);
```

From the command line:

```bash
# Render the currently active geometry to STL
openscad -o carriage.stl linear_drive_mg996r.scad

# Override a parameter without editing the file
openscad -o elbow.stl -D 'bend_angle=90' ventilation_adapter_160mm.scad

# Fast, low-poly draft render
openscad -o draft.stl -D '$fn=24' linear_drive_mg996r.scad
```

`crankrockerwithanimation.scad` is driven by OpenSCAD's animation variable `$t`.
In the GUI enable **View → Animate**, set FPS and Steps, and the four-bar linkage
solves its own kinematics for each frame. Its parts (`base()`, `crank()`,
`connecting_rod()`, `rocker()`) are listed commented out at the bottom for export.

### Notes per model

**Linear drive (MG996R).** All parts lie flat on Z=0, no supports needed.
Suggested: 0.2 mm layers, 3 perimeters, 20 % infill. Assembles with M3 hardware;
nut traps and counterbores are built in. Travel per 180° servo sweep is
`PI * pinion_pd / 2` ≈ 28.3 mm with the default 12-tooth, module-1.5 pinion —
increase `pinion_teeth` or `gear_module` for more.

**160 mm duct adapter.** Print with the flat Connector B end on the build plate;
the bend and Connector A print upward, and the inner overhang of the bend may want
supports. `conn_a_od`/`conn_b_od` carry the fit clearances — nudge them if your
printer over- or under-extrudes.

**HC-SR04 tank mount.** Four parts print without supports in PETG: base (flange
down), collar (insert end down), lid (roof down) and test ring (lip down). Print
the 15 mm `test_ring` first to confirm `hole_d`. Every render echoes the
sensor-face height above the rim (15 mm by default) for the firmware, and
asserts that the 15° beam cone clears the opening. This model uses
`rotate_extrude(angle=…)` and was built against an OpenSCAD 2026 snapshot
(manifold backend). See `hcsr04-tank-mount/README.md`.

**Crank-rocker.** The crank includes a slit and an M3 tensioning screw acting as a
slip clutch, so a stalled mechanism slips instead of stripping the motor. Uses two
608ZZ bearings.

---

## Parametric Editor

```bash
cd parametric-editor
python3 scad_editor.py linear_drive_mg996r.scad
```

The browser opens at `http://127.0.0.1:8042`. Started with no file argument, it
serves an empty UI where you pick a `.scad` file from the built-in file browser or
drag one onto the page.

What it does:

- Parses top-level numeric assignments into labelled sliders, grouped by the
  `prefix_` in each variable name.
- **Writes edits straight back into the `.scad` file** (debounced ~300 ms). This is
  in-place editing of your source — keep it under version control.
- Renders through the OpenSCAD CLI to STL and displays it with three.js
  (drag to rotate, scroll to zoom, right-drag to pan, plus Front/Top/Right/Iso
  presets). Shows triangle count and bounding-box size.
- **Render 3D** uses `-D '$fn=N'` (default 24) for a fast draft — roughly 7× faster
  than a full render. **Full Quality** and **Download STL** use the `$fn` written in
  the file. Results are cached by file-content hash, so re-rendering an unchanged
  model is instant.
- **Auto-render** re-renders on every slider change; **Reset All** restores the
  values the file had when it was loaded; **Open in OpenSCAD** launches the GUI on
  the current file.

### Options

```
python3 scad_editor.py [file] [-p PORT] [-d DIR] [--no-browser] [--preview-fn N]
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `file` | — | `.scad` file to open. Optional; pick one in the browser instead. |
| `-p`, `--port` | `8042` | Port to listen on (bound to `127.0.0.1` only). |
| `-d`, `--dir` | cwd | Root directory scanned recursively for `.scad` files, and where dropped files are saved. |
| `--no-browser` | off | Don't auto-open a browser window. |
| `--preview-fn` | `24` | `$fn` override for draft renders. `0` disables the override. |

### Annotating parameters

Slider bounds come from an optional comment on the same line as the assignment,
in the same `[min:step:max]` form OpenSCAD's own customizer uses:

```scad
wall = 3.0;          // [1:0.5:10] Wall thickness
barb_count = 4;      // [1:8] Number of hose barbs
bend_radius = 120.0; // Center-line bend radius
```

The text after the range becomes the slider label; without it the variable name is
title-cased. Without a range, sensible bounds are inferred from the current value.

### What gets picked up

Only **non-indented, top-level, single-numeric** assignments (`name = 42;` or
`name = -1.5e3;`) are exposed. That deliberately excludes variables inside modules
and functions, `$`-prefixed specials like `$fn`, vectors, strings and expressions —
so derived values such as `conn_a_id = conn_a_od - 2 * wall_thickness;` stay under
the model's control and are recomputed on every render.

The editor looks for OpenSCAD in the standard Windows install locations first, then
falls back to whatever `openscad` is on `PATH` (which is what happens on Linux and
macOS). If it isn't found, sliders and file saving still work but renders fail with
"OpenSCAD not found".
