#!/usr/bin/env bash
# Re-export the STLs and preview PNGs at the parameters in the .scad file.
# Usage: ./build.sh [extra -D overrides, e.g. -D hole_d=102]
# Needs OpenSCAD 2025+ (manifold backend); xvfb-run for headless PNGs.
set -euo pipefail
cd "$(dirname "$0")"
OS=${OPENSCAD:-openscad}
SCAD=hcsr04_tank_mount.scad
mkdir -p stl img
fail=0
for p in base collar lid test_ring; do
    log=$(mktemp)
    "$OS" --backend=manifold --export-format=binstl -o "stl/$p.stl" -D "part=\"$p\"" "$@" "$SCAD" 2>"$log" || fail=1
    if grep -E "WARNING|ERROR" "$log"; then fail=1; fi
    [ "$p" = base ] && grep ECHO "$log" | sed 's/^ECHO: //'
    rm -f "$log"
done
run=("$OS")
if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then
    run=(xvfb-run -a -s "-screen 0 1600x1200x24" "$OS")
fi
img() { "${run[@]}" --render --colorscheme=Tomorrow --imgsize=1400,1100 "$@" "$SCAD" >/dev/null 2>&1 || true; }
img -o img/assembly.png     -D 'part="assembly"' --camera=0,10,0,60,0,210,330       "$@"
img -o img/exploded.png     -D 'part="exploded"' --camera=0,10,30,62,0,215,430      "$@"
img -o img/section.png      -D 'part="section"'  --camera=0,0,5,90,0,180,190 --projection=o "$@"
img -o img/print_layout.png -D 'part="all"'      --viewall --autocenter --camera=0,0,0,45,0,20,0 "$@"
exit $fail
