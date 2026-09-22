/**
 * Door-Vent-Grille-LowNoise.js — low-noise, high-flow door ventilation grille.
 *
 * Why this file exists
 * --------------------
 * `Door-Vent-Grille.js` perforates a 3 mm plate with 5 mm slots between 3 mm ribs, each
 * slot about 170 mm long. Measured from its exported STL (tools/stl_check.py, rasterised
 * cross-sections): 3382.5 mm2 open inside the 171 x 31 mm insert cavity = 63.8 %.
 * What is wrong with it acoustically:
 *   - a thin, sharp lip on both sides of every slot: the classic edge-tone/whistle source,
 *   - slots 170 mm long (34:1 aspect) with only two stiffeners, i.e. a grazing-flow
 *     resonator mouth,
 *   - a 3 mm plate, flexible enough to radiate panel vibration into the room,
 *   - square-edged inlet, so the flow separates right at the lip.
 *
 * What this version changes
 * -------------------------
 * 1. FREE AREA — the dominant lever. At a fixed volume flow the jet velocity through the
 *    restriction is v = Q / A_free, and the radiated power of such a restriction scales
 *    with that velocity: DLR DAGA 2019 (Caldas, Behn, Tapken) measured perforated plates
 *    at M = 0.05-0.25 and found the spectra of different plates collapse when plotted
 *    against the jet Mach number M_jet = M / open area. Here the aperture is therefore laid
 *    out by a solver that maximises the open area (see layout()) instead of by hand.
 * 2. EDGES — every edge in contact with the flow gets a flare: a quarter-round bell-mouth
 *    on the inlet face and a 40 deg cone on the outlet face. A sharp upstream edge excites
 *    an edge-tone-like instability; an upstream chamfer suppresses it — measured on
 *    otherwise identical orifices in Acta Acustica 7 (2023) 66 (TU Eindhoven).
 * 3. CELL SIZE — small cells instead of huge slots, and a length cap. At equal open area a
 *    large number of small holes gives a lower overall level in the low/mid band than a
 *    small number of large holes (Laffay, cited in the same DAGA paper).
 * 4. STIFFNESS — thicker flange (4 mm), so the plate itself radiates less.
 *
 * Print orientation is fixed and support-free: lay the part on its outside flange face.
 * All apertures are then vertical through-holes (no bridging anywhere), the inlet
 * bell-mouth opens upward (material recedes with height, so it needs no support at any
 * curvature), and the outlet cone stays at <= 45 deg from vertical, the printable limit.
 *
 * The model prints a design report to the console:  npx @jscad/cli Door-Vent-Grille-LowNoise.js
 */

const { cuboid, polygon } = require('@jscad/modeling').primitives;
const { union, subtract } = require('@jscad/modeling').booleans;
const { translate } = require('@jscad/modeling').transforms;
const { extrudeFromSlices, extrudeLinear } = require('@jscad/modeling').extrusions;
const geom2 = require('@jscad/modeling').geometries.geom2;
const sliceMod = require('@jscad/modeling').extrusions.slice;
const mat4 = require('@jscad/modeling').maths.mat4;

const DEG = Math.PI / 180;
const SQRT3 = Math.sqrt(3);

/** Measured free area of the original slot design (see header). Report only. */
const BASELINE_FREE_AREA_MM2 = 3382.5;
const BASELINE_CAVITY_MM2 = 171 * 31;
/** Smallest wall that still prints as two clean lines with a 0.4 mm nozzle. */
const MIN_WALL = 0.8;
/** Above this slot aspect ratio (length:height) slot mouths start to whistle. */
const MAX_SLOT_ASPECT = 6;
const MAX_SLOT_LENGTH = 42;

const getParameterDefinitions = () => [
  { name: 'grp1', type: 'group', caption: 'Aussenmasse (wie Original)' },
  { name: 'width', type: 'number', initial: 200, caption: 'Max. Breite (X)' },
  { name: 'length', type: 'number', initial: 60, caption: 'Max. Hoehe (Y)' },
  { name: 'flange_h', type: 'number', initial: 4, caption: 'Flanschdicke (Z): dicker = steifer = leiser' },

  { name: 'grp2', type: 'group', caption: 'Einsteckteil (in der Tuer)' },
  { name: 'offset', type: 'number', initial: 12, caption: 'Offset nach innen (Ueberstand Rand)' },
  { name: 'insert_h', type: 'number', initial: 15, caption: 'Einstecktiefe in die Tuer' },
  { name: 'wall', type: 'number', initial: 2.5, caption: 'Wandstaerke des Einsteckteils' },

  { name: 'grp3', type: 'group', caption: 'Lochmuster' },
  { name: 'pattern', type: 'choice', caption: 'Muster (Freiflaeche wird automatisch maximiert)',
    values: ['auto', 'slots', 'honeycomb', 'hex-holes'],
    captions: ['beste Freiflaeche (empfohlen)', 'Schlitze, max. Luftdurchsatz', 'Waben, meiste Zellen', 'runde Loecher im Hex-Pack'],
    initial: 'auto' },
  { name: 'web', type: 'number', initial: 1.6, caption: 'Stegbreite (mm), min 1.2, bestimmt auch den Kantenradius' },
  { name: 'max_cell', type: 'number', initial: 12, caption: 'Max. Zellgroesse (mm) - kleinere Zellen = feineres, hoeherfrequentes Rauschen' },

  { name: 'grp4', type: 'group', caption: 'Kanten (das akustische Herzstueck)' },
  { name: 'inlet_flare', type: 'number', initial: 0.6, caption: 'Radius Einlass-Viertelrunde (mm, wird auf die Stegbreite begrenzt)' },
  { name: 'outlet_chamfer', type: 'number', initial: 0.4, caption: 'Fase Auslass (mm radial, 0 = scharfe Kante)' },
  { name: 'outlet_angle', type: 'number', initial: 40, caption: 'Fasenwinkel Auslass (Grad, max 45)' },
  { name: 'flare_layers', type: 'number', initial: 5, caption: 'Loft-Stufen pro Kante (mehr = runder)' },

  { name: 'grp5', type: 'group', caption: 'Montage und Report' },
  { name: 'gasket_w', type: 'number', initial: 0, caption: 'Dichtungsnut Breite (0 = keine Nut)' },
  { name: 'gasket_d', type: 'number', initial: 1.5, caption: 'Dichtungsnut Tiefe' },
  { name: 'flow_marker', type: 'choice', caption: 'Stroemungspfeil (Achtung: kostet Manifold-Qualitaet)', values: ['no', 'yes'], initial: 'no' },
  { name: 'flow_m3h', type: 'number', initial: 60, caption: 'Auslegungs-Volumenstrom (m3/h) fuer den Report' },
  { name: 'target_v', type: 'number', initial: 2.0, caption: 'Ziel-Geschwindigkeit im freien Querschnitt (m/s)' },
  { name: 'show_report', type: 'choice', caption: 'Report in die Konsole schreiben', values: ['yes', 'no'], initial: 'yes' }
];

/* --------------------------------------------------------------------------- *
 * cell outlines. All are generated from a "growth" offset: growth 0 is the throat
 * cross-section, growth > 0 the cross-section further out in the flared face.
 * --------------------------------------------------------------------------- */

const hexagonPoints = (inradius, cx, cy) => {
  const rc = inradius / Math.cos(30 * DEG);
  const pts = [];
  for (let k = 0; k < 6; k++) {
    const th = 30 * DEG + k * 60 * DEG;
    pts.push([cx + rc * Math.cos(th), cy + rc * Math.sin(th)]);
  }
  return pts;
};

const circlePoints = (r, cx, cy, segments) => {
  const pts = [];
  for (let k = 0; k < segments; k++) {
    const th = (k / segments) * 2 * Math.PI;
    pts.push([cx + r * Math.cos(th), cy + r * Math.sin(th)]);
  }
  return pts;
};

/** Stadium / slot with semicircular ends. halfLen = distance centre to cap centre. */
const slotPoints = (halfLen, halfH, cx, cy, segments) => {
  const r = halfH;
  const n = Math.max(4, Math.round(segments / 2));
  const pts = [];
  for (let k = 0; k <= n; k++) {
    const th = -90 * DEG + (k / n) * 180 * DEG;
    pts.push([cx + halfLen + r * Math.cos(th), cy + r * Math.sin(th)]);
  }
  for (let k = 0; k <= n; k++) {
    const th = 90 * DEG + (k / n) * 180 * DEG;
    pts.push([cx - halfLen + r * Math.cos(th), cy - 0 + r * Math.sin(th)]);
  }
  return pts;
};

const polygonArea = (pts) => {
  let a = 0;
  for (let i = 0; i < pts.length; i++) {
    const [x1, y1] = pts[i];
    const [x2, y2] = pts[(i + 1) % pts.length];
    a += x1 * y2 - x2 * y1;
  }
  return Math.abs(a) / 2;
};

/* --------------------------------------------------------------------------- *
 * layout solver
 *
 * Finds the arrangement that maximises the throat area inside the aperture window
 * [cw x cl], subject to
 *   - wall between neighbouring cells >= web,
 *   - a solid rim of M = 0.75*web (at least 0.6 mm) all around the field,
 *   - cell size cap `max_cell` (max opening extent, mm): more, smaller cells trade open
 *     area for a lower-level, higher-frequency noise spectrum, so it is explicit,
 *   - slot length capped at MAX_SLOT_LENGTH and at MAX_SLOT_ASPECT * height, because a
 *     long thin slot mouth is the geometry that whistles.
 * The solved parameters are reused for every flared lamina; only the growth offset
 * changes, so the whole bore is one consistent lofted solid.
 * --------------------------------------------------------------------------- */

/** Outline of one cell of the given pattern, offset outwards by `growth`. */
const cellOutline = (pat, q, cx, cy, growth) => {
  const g = growth;
  if (pat === 'honeycomb') {
    return hexagonPoints((q.a - q.t) / 2 + g, cx, cy);
  }
  if (pat === 'hex-holes') {
    return circlePoints(q.d / 2 + g, cx, cy, 32);
  }
  return slotPoints(q.L / 2, q.h / 2 + g, cx, cy, 28);
};

const bboxOf = (pts) => {
  let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
  for (const [x, y] of pts) {
    if (x < x0) x0 = x; if (x > x1) x1 = x;
    if (y < y0) y0 = y; if (y > y1) y1 = y;
  }
  return { x0, x1, y0, y1 };
};

/** Cells of a lattice pattern that fit completely inside availW x availH, recentred. */
const latticeCells = (pat, q, availW, availH, growth) => {
  const rowPitch = q.a * SQRT3 / 2;
  const probe = bboxOf(cellOutline(pat, q, 0, 0, 0));
  const cw_ = probe.x1 - probe.x0;
  const ch_ = probe.y1 - probe.y0;
  const nRows = Math.floor((availH - ch_) / rowPitch) + 1;
  const nCols = Math.floor((availW - cw_) / q.a) + 1;
  if (nRows < 1 || nCols < 1) return [];
  const cells = [];
  for (let r = 0; r < nRows; r++) {
    for (let c = 0; c < nCols; c++) {
      const x = (c - (nCols - 1) / 2) * q.a + (r % 2 ? q.a / 2 : 0);
      const y = (r - (nRows - 1) / 2) * rowPitch;
      const pts = cellOutline(pat, q, x, y, growth);
      const bb = bboxOf(pts);
      if (bb.x0 >= -availW / 2 - 1e-9 && bb.x1 <= availW / 2 + 1e-9 &&
          bb.y0 >= -availH / 2 - 1e-9 && bb.y1 <= availH / 2 + 1e-9) cells.push(pts);
    }
  }
  return recentre(cells, availW, availH);
};

/** Shift a cell set as close to centred as the available box allows. */
const recentre = (cells, availW, availH) => {
  if (cells.length === 0) return cells;
  let bb = { x0: Infinity, x1: -Infinity, y0: Infinity, y1: -Infinity };
  for (const pts of cells) {
    const b = bboxOf(pts);
    bb.x0 = Math.min(bb.x0, b.x0); bb.x1 = Math.max(bb.x1, b.x1);
    bb.y0 = Math.min(bb.y0, b.y0); bb.y1 = Math.max(bb.y1, b.y1);
  }
  const dx = Math.max(-availW / 2 - bb.x0, Math.min(availW / 2 - bb.x1, -(bb.x0 + bb.x1) / 2));
  const dy = Math.max(-availH / 2 - bb.y0, Math.min(availH / 2 - bb.y1, -(bb.y0 + bb.y1) / 2));
  return cells.map((pts) => pts.map(([x, y]) => [x + dx, y + dy]));
};

/** Slot field: `ncol` stadium cells per row, rows of height h separated by stiffeners. */
const slotCells = (q, availW, availH, growth) => {
  const cellW = (availW - (q.ncol - 1) * q.stiff) / q.ncol;
  // a cell is (straight length L + two end caps of radius h/2); it must keep `stiff` of
  // material to the neighbouring cell, otherwise the slots would touch and the boolean
  // would be left with a zero-width web
  const L = q.L !== undefined ? q.L : Math.min(cellW - q.h - q.stiff, MAX_SLOT_LENGTH, MAX_SLOT_ASPECT * q.h - q.h);
  if (L < 3) return [];
  const rows = Math.floor((availH + q.stiff) / (q.h + q.stiff));
  if (rows < 1) return [];
  const rowPitch = q.h + q.stiff;
  const cells = [];
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < q.ncol; c++) {
      const x = (c - (q.ncol - 1) / 2) * cellW;
      const y = (r - (rows - 1) / 2) * rowPitch;
      cells.push(cellOutline('slots', q, x, y, growth));
    }
  }
  return cells;
};

const solveLayout = (p, cw, cl) => {
  const t = Math.max(MIN_WALL, p.web);
  const M = Math.max(0.6, 0.75 * t);
  const availW = cw - 2 * M;
  const availH = cl - 2 * M;
  const maxCell = Math.max(3, p.max_cell);
  const stiff = Math.max(MIN_WALL, p.web);
  const cands = [];

  // lattice patterns
  const latticeWanted = p.pattern === 'auto' ? ['honeycomb', 'hex-holes'] : [p.pattern];
  for (const pat of latticeWanted) {
    if (pat !== 'honeycomb' && pat !== 'hex-holes') continue;
    for (let d = t + 0.6; d <= maxCell + 1e-9; d += 0.05) {
      const q = pat === 'honeycomb' ? { a: d + t, t } : { a: d + t, d, t };
      const cells = latticeCells(pat, q, availW, availH, 0);
      if (cells.length < 2) continue;
      const free = cells.reduce((s, c) => s + polygonArea(c), 0);
      cands.push({ pattern: pat, q, cells: cells.length, free, opening: d, pitch: q.a });
    }
  }

  // slots
  if (p.pattern === 'auto' || p.pattern === 'slots') {
    for (let h = 3; h <= maxCell + 1e-9; h += 0.25) {
      for (let ncol = 1; ncol <= 6; ncol++) {
        const cellW = (availW - (ncol - 1) * stiff) / ncol;
        const L = Math.min(cellW - h - stiff, MAX_SLOT_LENGTH, MAX_SLOT_ASPECT * h - h);
        if (L < 3) continue;
        const q = { h, ncol, stiff, L };
        const cells = slotCells(q, availW, availH, 0);
        if (cells.length < 1) continue;
        const free = cells.reduce((s, c) => s + polygonArea(c), 0);
        cands.push({ pattern: 'slots', q, cells: cells.length, free, opening: h, pitch: h + stiff });
      }
    }
  }

  if (cands.length === 0) throw new Error('Kein Muster passt mit dieser Stegbreite in die Aussparung.');
  cands.sort((x, y) => y.free - x.free);
  return withBox(cands[0], availW, availH);
};

const fieldCells = (L, growth) => (L.pattern === 'slots'
  ? slotCells(Object.assign({}, L.q), L.availW, L.availH, growth)
  : latticeCells(L.pattern, Object.assign({}, L.q), L.availW, L.availH, growth));

const fieldArea = (L, growth) => fieldCells(L, growth).reduce((s, c) => s + polygonArea(c), 0);

/** attach the box the layout was solved for, so the laminae use identical parameters */
const withBox = (L, availW, availH) => Object.assign(L, { availW, availH });

/* --------------------------------------------------------------------------- *
 * aperture profile along Z
 *
 * Printed on the flange OUTSIDE face:
 *   z = flange_h : INLET — faces the insert box, printed facing up. Quarter-round
 *                  bell-mouth, radius `inlet_flare`. Material recedes with height here,
 *                  so it is self-supporting at any curvature.
 *   z = 0        : OUTLET — visible face, printed on the bed. Straight cone at
 *                  `outlet_angle` <= 45 deg from vertical (printable limit).
 * --------------------------------------------------------------------------- */

const edgeDims = (p) => {
  const limit = Math.max(0, (Math.max(MIN_WALL, p.web) - MIN_WALL) / 2);
  const inR = Math.min(Math.max(0, p.inlet_flare), limit);
  const outR = Math.min(Math.max(0, p.outlet_chamfer), limit);
  const angle = Math.min(45, Math.max(20, p.outlet_angle));
  const outH = outR > 0 ? outR / Math.tan(angle * DEG) : 0;
  return { inR, outR, outH, inH: inR, cut: Math.max(0, p.inlet_flare - limit) };
};

const growthAt = (p, z) => {
  const fh = p.flange_h;
  const e = edgeDims(p);
  if (e.outH > 1e-6 && z < e.outH) return e.outR * (1 - z / e.outH);
  if (e.inR > 1e-6 && z > fh - e.inR) {
    const u = Math.min(1, (z - (fh - e.inR)) / e.inR);   // 0 at throat side, 1 at the face
    return e.inR * Math.sqrt(Math.max(0, 1 - (1 - u) * (1 - u)));
  }
  return 0;
};

const profileStations = (p) => {
  const fh = p.flange_h;
  const e = edgeDims(p);
  const n = Math.max(2, Math.round(p.flare_layers));
  // the bore overshoots both flange faces so the boolean never has to resolve coplanar
  // faces (a cut that ends exactly on a face is a classic source of mesh artifacts)
  const overshoot = 0.4;
  const zs = [-overshoot, 0, fh, fh + overshoot];
  if (e.outH > 1e-6) { for (let i = 1; i < n; i++) zs.push(e.outH * i / n); zs.push(e.outH); }
  if (e.inH > 1e-6) { for (let i = 1; i < n; i++) zs.push(fh - e.inH + e.inH * i / n); zs.push(fh - e.inH); }
  return Array.from(new Set(zs.map((z) => Math.round(z * 1e5) / 1e5))).sort((a, b) => a - b);
};

const apertureSolid = (p, cw, cl, L) => {
  const stations = profileStations(p);
  return extrudeFromSlices({
    numberOfSlices: stations.length,
    repair: false,
    callback: (progress, index) => {
      const z = stations[index];
      const sides = [];
      for (const cell of fieldCells(L, growthAt(p, z))) {
        for (const s of geom2.toSides(polygon({ points: cell }))) sides.push(s);
      }
      const sl = sliceMod.fromSides(geom2.toSides(geom2.create(sides)));
      return sliceMod.transform(mat4.fromTranslation(mat4.create(), [0, 0, z]), sl);
    }
  }, null);
};

/* --------------------------------------------------------------------------- *
 * design report
 * --------------------------------------------------------------------------- */

const f2 = (x) => (Math.round(x * 100) / 100).toFixed(2);
const flowMm3s = (q) => q * 1e9 / 3600;

const designReport = (p, L) => {
  const w = p.width, l = p.length, fh = p.flange_h;
  const iw = w - 2 * p.offset, il = l - 2 * p.offset;
  const cw = iw - 2 * p.wall, cl = il - 2 * p.wall;
  const cav = cw * cl;
  const e = edgeDims(p);
  const stations = profileStations(p);
  const cells = fieldCells(L, 0);
  const free = L.free;
  const freeIn = fieldArea(L, e.inR);
  const out = [];
  const v = (q) => flowMm3s(q) / free;                      // mm/s

  out.push('========== Door-Vent-Grille-LowNoise — Entwurfsreport ==========');
  out.push(`Flansch            : ${f2(w)} x ${f2(l)} x ${f2(fh)} mm`);
  out.push(`Einstecker         : ${f2(iw)} x ${f2(il)} x ${f2(p.insert_h)} mm, Wand ${f2(p.wall)} mm`);
  out.push(`Hohlraum           : ${f2(cw)} x ${f2(cl)} = ${f2(cav)} mm2`);
  const slotInfo = L.pattern === 'slots' ? `, Schlitz ${f2(L.q.L)} x ${f2(L.q.h)} mm, ${L.q.ncol} pro Reihe` : '';
  out.push(`Gewaehltes Muster  : ${L.pattern} — ${cells.length} Zellen, Zellmass ${f2(L.opening)} mm, Abstand ${f2(L.pitch)} mm${slotInfo}`);
  out.push(`Freier Querschnitt : ${f2(free)} mm2 = ${f2(100 * free / cav)} % des Hohlraums (Original ${f2(100 * BASELINE_FREE_AREA_MM2 / BASELINE_CAVITY_MM2)} %), ${f2(100 * free / (w * l))} % der Flanschflaeche`);
  out.push(`                     an der Einlasskante aufgeweitet auf ${f2(freeIn)} mm2 (${f2(100 * freeIn / cav)} %)`);
  out.push(`Delta freie Flaeche: ${free >= BASELINE_FREE_AREA_MM2 ? '+' : ''}${f2(100 * (free - BASELINE_FREE_AREA_MM2) / BASELINE_FREE_AREA_MM2)} %`);
  out.push(`Stegbreite         : ${f2(Math.max(MIN_WALL, p.web))} mm = ${f2(Math.max(MIN_WALL, p.web) / 0.42)} Linien`);
  out.push(`Kanten             : Einlass Viertelrunde r = ${f2(e.inR)} mm, Auslass ${f2(e.outR)} mm @ ${f2(Math.min(45, p.outlet_angle))} Grad, ${stations.length} Loft-Stufen`);
  if (e.cut > 1e-3) out.push(`   ! inlet_flare auf ${f2(e.inR)} mm begrenzt (Stegbreite laesst nicht mehr zu, sonst Restwand < ${MIN_WALL} mm)`);
  out.push('');
  out.push('Volumenstrom -> Geschwindigkeit im freien Querschnitt (Hals)');
  for (const q of [30, 60, 90, 120]) {
    const vNew = v(q) / 1000;
    const vOld = flowMm3s(q) / BASELINE_FREE_AREA_MM2 / 1000;
    const dLw = 50 * Math.log10(vNew / vOld);
    out.push(`   ${String(q).padStart(3)} m3/h : v = ${f2(vNew)} m/s  (Original ${f2(vOld)} m/s)  ->  ${dLw >= 0 ? '+' : ''}${f2(dLw)} dB breitband (50*log10(v2/v1), Schaetzung)`);
  }
  out.push('');
  const need = flowMm3s(p.flow_m3h) / (p.target_v * 1000);
  out.push(`Ziel ${f2(p.target_v)} m/s im freien Querschnitt bei ${f2(p.flow_m3h)} m3/h -> ${f2(need)} mm2 noetig`);
  if (need > cav) {
    const f = Math.sqrt(need / cav);
    out.push(`   ! groesser als der ${f2(cav)} mm2 Hohlraum. Aussparung linear x${f2(f)} groesser machen (${f2(cw * f)} x ${f2(cl * f)} mm),`);
    out.push(`     sonst passen bei ${f2(p.flow_m3h)} m3/h nur ${f2(p.target_v)} m/s mit ${f2(free * p.target_v * 1000 * 3600 / 1e9)} m3/h zusammen (mehr Durchsatz = mehr Laerm).`);
  } else {
    out.push('   -> passt in den vorhandenen Hohlraum.');
  }
  const cd = e.inR > 0.3 ? 0.82 : 0.62;
  const vHole = v(p.flow_m3h) / 1000;
  out.push(`Druckverlust grob  : v_Hals ${f2(vHole)} m/s, C_d ${f2(cd)} (${e.inR > 0.3 ? 'gerundeter' : 'scharfer'} Einlass) -> ca. ${f2(0.5 * 1.2 * Math.pow(vHole / cd, 2))} Pa`);
  out.push('');
  out.push('Alternativen (gleiche Stegbreite, automatisch berechnet):');
  for (const pat of ['auto', 'slots', 'honeycomb', 'hex-holes']) {
    const alt = solveLayout(Object.assign({}, p, { pattern: pat }), cw, cl);
    const nAlt = fieldCells(alt, 0).length;
    out.push(`   ${pat.padEnd(10)} ${f2(alt.free).padStart(8)} mm2 = ${f2(100 * alt.free / cav).padStart(5)} % | ${String(nAlt).padStart(3)} Zellen | v bei ${f2(p.flow_m3h)} m3/h = ${f2(flowMm3s(p.flow_m3h) / alt.free / 1000)} m/s`);
  }
  out.push('');
  out.push('Drucken (FDM, 0.4 mm Duese)');
  out.push('   - Flansch-AUSSENseite aufs Bett legen: alle Oeffnungen werden senkrecht gedruckt, kein Bridge, kein Support.');
  out.push(`   - Restwand an der Einlasskante: ${f2(Math.max(MIN_WALL, p.web) - 2 * e.inR)} mm (>= ${MIN_WALL} mm einhalten).`);
  out.push('   - PETG/ASA, 0.16-0.2 mm Layer, 4 Perimeter, 25 % Infill, keine Stuetzstruktur.');
  out.push('');
  out.push('Einbau');
  out.push('   - Die gerundete/aufgeweitete Seite ist der EINLASS und liegt im Druck oben.');
  out.push('   - Sie muss zum Luftstrom zeigen (dorthin, woher die Luft kommt).');
  out.push('   - Ohne Fan: die Tuer-Aussparung ist der Engpass, nicht das Muster.');
  out.push('===============================================================');
  return out.join('\n');
};

/* --------------------------------------------------------------------------- *
 * main
 * --------------------------------------------------------------------------- */

const main = (p) => {
  const w = p.width, l = p.length, fh = p.flange_h;
  const iw = w - 2 * p.offset, il = l - 2 * p.offset;
  if (iw <= 0 || il <= 0) throw new Error('Offset zu gross fuer die angegebenen Maximalmasse.');
  const cw = iw - 2 * p.wall, cl = il - 2 * p.wall;
  if (cw <= 0 || cl <= 0) throw new Error('Wandstaerke in Kombination mit Offset zu gross.');
  if (fh <= 1.5) throw new Error('Flansch zu duenn.');

  const L = solveLayout(p, cw, cl);
  const e = edgeDims(p);
  if (Math.max(MIN_WALL, p.web) - 2 * e.inR < MIN_WALL - 1e-9) {
    throw new Error('Einlass-Aufweitung frisst die Restwand — inlet_flare oder web anpassen.');
  }
  if (p.show_report === 'yes') console.log(designReport(p, L));

  // 1. flange + insert box, hollowed
  const flange = translate([0, 0, fh / 2], cuboid({ size: [w, l, fh] }));
  // the insert overlaps the flange by 0.5 mm: two boxes that merely touch would leave a
  // coplanar interface for the boolean to resolve, which is what makes meshes non-manifold
  const lap = 0.5;
  const insert = translate([0, 0, fh - lap + (p.insert_h + lap) / 2],
    cuboid({ size: [iw, il, p.insert_h + lap] }));
  // the cavity starts exactly at the flange's inner face and runs out of the top
  const cavity = translate([0, 0, fh + (p.insert_h + 2) / 2], cuboid({ size: [cw, cl, p.insert_h + 2] }));
  let frame = subtract(union(flange, insert), cavity);

  // 2. chamfer the free end of the insert walls (widens upward -> printable)
  const rim = Math.min(1.0, p.wall - 0.8);
  if (rim > 0.2) {
    const zTop = fh + p.insert_h;
    frame = subtract(frame, subtract(
      translate([0, 0, zTop - rim / 2 + 0.4], cuboid({ size: [iw + 2, il + 2, rim + 0.8] })),
      translate([0, 0, zTop - rim / 2 - 0.001], cuboid({ size: [iw - 2 * rim, il - 2 * rim, rim + 2] }))
    ));
  }

  // 3. aperture field cut straight through the flange (one boolean, no separate plate body)
  frame = subtract(frame, apertureSolid(p, cw, cl, L));

  // 4. optional gasket groove in the visible (bed side) face
  if (p.gasket_w > 0.4 && p.gasket_d > 0.2) {
    const gw = p.gasket_w, gd = p.gasket_d;
    const ox = w / 2 - Math.max(p.offset / 2, gw / 2 + 1.5);
    const oy = l / 2 - Math.max(p.offset / 2, gw / 2 + 1.5);
    if (ox > gw && oy > gw) {
      frame = subtract(frame, subtract(
        translate([0, 0, gd / 2], cuboid({ size: [2 * ox + gw, 2 * oy + gw, gd] })),
        translate([0, 0, gd / 2], cuboid({ size: [2 * ox - gw, 2 * oy - gw, gd + 2] }))
      ));
    }
  }

  // 5. flow-direction marker, cut THROUGH the flange border of the visible face.
  // Cut through, not engraved: a shallow pocket leaves the face boundary retriangulated
  // against the rest of the face and OrcaSlicer then reports open edges (T-junctions).
  // A vertical prism that overshoots both faces - the same construction as the slots -
  // stays fully manifold. One closed counter-clockwise polygon, no 2D boolean.
  if (p.flow_marker === 'yes') {
    const border = Math.min(p.offset, (l - il) / 2);
    const web = 1.6;                                   // material kept at each side
    const s = Math.max(2, Math.min(4.5, (border - 2 * web) / 2.9));
    const Ltot = 2.9 * s;
    const head = 1.0 * s;
    const shaft = 0.275 * s;
    const x0 = -w / 2 + (border - Ltot) / 2;
    const arrow = polygon({
      points: [
        [x0, -shaft],
        [x0 + Ltot - head, -shaft],
        [x0 + Ltot - head, -0.5 * s],
        [x0 + Ltot, 0],
        [x0 + Ltot - head, 0.5 * s],
        [x0 + Ltot - head, shaft],
        [x0, shaft]
      ]
    });
    frame = subtract(frame, translate([0, 0, -0.5], extrudeLinear({ height: fh + 1.0 }, arrow)));
  }

  return frame;
};

module.exports = { main, getParameterDefinitions };
