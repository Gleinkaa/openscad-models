# AGENTS.md — openscad-models

## What this repo is

A collection of parametric OpenSCAD models for FDM 3D printing, all dimensioned in
millimetres, plus `parametric-editor/` — a stdlib-only local web UI that turns the
top-level numeric variables of any `.scad` file into sliders, writes edits back into the
file and renders through the OpenSCAD CLI with a three.js preview. `jscad/` holds
standalone JSCAD V2 scripts for the same kind of part. README.md documents each model and
is the entry point.

## Layout (real paths)

```
linear_drive_mg996r.scad        rack-and-pinion linear stage (MG996R servo, dovetail rails, endstops)
ventilation_adapter_160mm.scad 160 mm duct adapter, 45 degree elbow
crankrockerwithanimation.scad   four-bar crank-rocker, animated via $t
hcsr04-tank-mount/
  hcsr04_tank_mount.scad        HC-SR04 level-sensor mount; part selector for assembly/exploded/section/parts
  build.sh                      re-exports stl/ and img/ (OpenSCAD 2025+, manifold backend)
  stl/                          committed STLs: base, collar, lid, test_ring
  img/                          committed renders: assembly, exploded, print_layout, section
parametric-editor/
  scad_editor.py                the editor (one file, standard library, embedded HTML/JS UI)
  linear_drive_mg996r.scad      sample model shipped with the editor
jscad/                          standalone JSCAD V2 scripts (AC-Flange, Door-Vent-Grille, Open-Tray, ...)
jscad/README.md                 per-script parameter table and known quirks
README.md, LICENSE              MIT
```

## How to build, run and test

```bash
# render from the command line
openscad -o carriage.stl linear_drive_mg996r.scad
openscad -o elbow.stl -D 'bend_angle=90' ventilation_adapter_160mm.scad
openscad -o draft.stl -D '$fn=24' linear_drive_mg996r.scad

# HC-SR04 mount: one part, or everything with parameter overrides
openscad -o stl/test_ring.stl -D 'part="test_ring"' -D hole_d=101.5 hcsr04_tank_mount/hcsr04_tank_mount.scad
cd hcsr04-tank-mount && ./build.sh -D hole_d=101.5

# parametric editor (stdlib only; serves on 127.0.0.1:8042)
python3 parametric-editor/scad_editor.py parametric-editor/linear_drive_mg996r.scad

# jscad, no package.json and no build step
npx @jscad/cli jscad/Open-Tray.js --length 120 -o big-tray.stl
```

`scad_editor.py` flags: `file`, `-p/--port` (default 8042), `-d/--dir`, `--no-browser`,
`--preview-fn` (default 24). `build.sh` honours `OPENSCAD=/path/to/openscad` and uses
`xvfb-run` when there is no display.

There is no test suite and no CI. **Untested in this audit:** no OpenSCAD binary exists on
this machine, so no render was executed. Verified here: the editor starts and answers HTTP
200 on its port, `build.sh` and the committed `stl/` + `img/` files exist. Treat every
render or export command as unverified until you run it.

## Conventions observed in the code

- Millimetres everywhere; models are written for FDM printing.
- Each `.scad` has a top-level parameter block and ends with a **render selection** block:
  an assembled/animated view is active by default and the printable parts are listed as
  commented-out calls, uncommented one at a time for STL export. Keep that block last.
- Parameter comments follow OpenSCAD's customizer form, `// [min:step:max] Label`, on the
  same line as the assignment. The editor turns those into labelled sliders.
- The editor only exposes **non-indented, top-level, single-numeric** assignments. Derived
  values (vectors, expressions, `$`-specials, variables inside modules) stay in the model
  and are recomputed on every render — do not flatten them into sliders.
- `hcsr04_tank_mount.scad` echoes the key dimensions (sensor-face height, beam clearance)
  and asserts the 15 degree beam clears the opening. Those echo lines are part of the
  contract with the firmware.
- JSCAD scripts keep the V2 CommonJS shape: `getParameterDefinitions()` plus `main(p)`, all
  dimensions in mm, 2D outlines wound counter-clockwise.

## Gotchas and do-not-touch

- **The parametric editor rewrites the `.scad` file in place** (debounced ~300 ms) as you
  drag sliders. Point it only at files under version control, and never leave a session
  open on a file someone else is editing.
- **Print-fit parameters are physics, not style.** `conn_a_od`, `conn_b_od`, `hole_d`,
  `spigot_clr`, `pcb_clr`, `tx_clr`, `lid_clr` carry real clearances for real hardware. Do
  not "tidy" them, and do not print a long part before the 15 mm `test_ring` fit check.
- **Confirmed defects, documented deliberately in `jscad/README.md`:** `Glitch-Planter.js`
  is non-deterministic (`Math.random()` per layer), `Open-Tray.js` exports a closed box
  instead of an open tray, `Art-Deco-Profile.js` ignores its `scale` parameter, and the
  `honeycomb` pattern in `Door-Vent-Grille-LowNoise.js` exports an open mesh. Do not
  "fix" these silently — either leave them or say so in the report.
- `hcsr04_tank_mount.scad` uses `rotate_extrude(angle=...)` and was built against an
  OpenSCAD 2026 snapshot; older OpenSCAD will render it differently or not at all.
- The editor's in-page 3D view loads three.js from a CDN. Sliders, saving and STL export
  work offline; only the preview needs internet.
- `stl/` and `img/` under `hcsr04-tank-mount/` are generated artefacts — regenerate with
  `build.sh` (it greps the log for WARNING/ERROR and fails on either) instead of editing
  files by hand.
- Left alone: `.gitignore` (`.claude/worktrees/`). No secrets exist in this repo; keep it
  that way (no API keys, no tokens in the editor's HTML or in parameter defaults).

## Definition of done

- The changed model renders without warnings or errors for every part it exports; STLs and
  previews regenerated where the geometry changed.
- Parameters that the docs quote (the `hcsr04-tank-mount/README.md` dimension table, the
  travel-per-sweep figure in the root README) are updated with the geometry.
- The editor still only rewrites the file it was opened on, and prints no traceback on
  load or save.
- New model: listed in the README contents table, with its print orientation and any
  supported part selection.
- Say plainly which renders you executed and which stay unverified (no OpenSCAD on the
  machine is a valid answer).
