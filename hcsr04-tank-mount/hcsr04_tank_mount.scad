// ============================================================
// HC-SR04 tank-top mount — grow room "Location A", Rechts Primärtank
// ============================================================
// Holds an HC-SR04 ultrasonic ranger above the ~100 mm filler hole
// of a water canister, transducers pointing straight down into the
// tank, electronics under a drip-shedding lid.
//
//   rim (canister top)  z = 0
//   sensor face         z = face_above_rim  (echoed, use it in firmware)
//
// Parts (all print without supports, see README.md):
//   base      flange + plinth + deck + PCB cradle + cable gland   (flange down)
//   collar    centring spigot with friction tabs, presses into the
//             groove under the flange                             (insert end down)
//   lid       hood over PCB + connector bay                       (roof down)
//   test_ring 15 mm fit-check ring for the hole, print this first (lip down)
//
// Why a separate collar: a spigot below the flange and a plinth above
// it cannot both be printed without supports. Split, both are flat.
//
// Board: "HC-SR04 2020" revision (RCWL-9300 on the back), right-angle
// 4-pin header on one long edge, pins in the PCB plane. Dimensions:
// 45 x 20 x 15 mm and <15 deg measuring angle per the ElecFreaks /
// SparkFun datasheet (cdn.sparkfun.com/datasheets/Sensors/Proximity/HCSR04.pdf);
// hole spacing ~42 x 17 mm, holes ~2 mm (SparkFun forum caliper
// measurement). Transducer Ø16 / 26 mm pitch / 12 mm height are the
// common drawing values, consistent with the user's photos. The
// corner holes are NOT used — the board is held by its edges.
//
// Material: PETG (humid headspace; PLA creeps and softens when warm+wet).
// ============================================================

/* [Selection] */
part = "assembly"; // [assembly, exploded, section, all, base, collar, lid, test_ring]

/* [Canister hole — MEASURE hole_d] */
hole_d          = 100.0; // [80:0.5:130] Filler-hole diameter (approximate! print test_ring first)
spigot_clr      = 1.0;   // [0:0.1:3] Radial gap spigot <-> hole (default Ø98 in a Ø100 hole)
spigot_drop     = 8.0;   // [3:0.5:20] How far the spigot reaches into the hole
collar_wall     = 2.4;   // [2:0.2:4] Spigot / collar wall
n_tabs          = 4;     // [0:1:6] Flexible friction tabs on the spigot (0 = none)
tab_w           = 12.0;  // [6:1:20] Tab width (arc length)
tab_interf      = 0.3;   // [0:0.1:1.5] Tab bump reach beyond the nominal hole wall
flange_margin   = 15.0;  // [8:1:30] Flange overhang beyond the hole, per side (Ø = hole_d + 2*margin)
flange_t        = 3.0;   // [2:0.2:6] Flange plate thickness
collar_insert   = 4.0;   // [2:0.5:8] Collar length pressed into the flange groove
collar_fit      = 0.15;  // [0:0.05:0.4] Radial groove clearance each side
crush_rib       = 0.25;  // [0:0.05:0.6] Crush-rib interference on the collar insert (press fit)

/* [Sensor board — measure yours] */
pcb_l           = 45.0;  // [40:0.1:50] PCB length
pcb_w           = 20.0;  // [18:0.1:24] PCB width
pcb_t           = 1.6;   // [1:0.1:2] PCB thickness
tx_d            = 16.0;  // [14:0.1:18] Transducer can diameter
tx_h            = 12.0;  // [8:0.1:15] Can height, PCB front face -> can face
tx_pitch        = 26.0;  // [20:0.1:32] Transducer centre distance
xtal_l          = 11.0;  // Crystal can (front side) length
xtal_w          = 4.5;   // Crystal can width
xtal_h          = 3.5;   // Crystal can height above PCB front
xtal_y          = -5.5;  // Crystal centre, y (header edge is +y)
ic_h            = 2.0;   // SOIC height on the back side (U1/U2/U3)
hdr_body_h      = 2.5;   // Right-angle header plastic body height on the back
hdr_pin_len     = 10.0;  // Pins sticking out past the PCB edge
dupont_len      = 14.0;  // Dupont housing length (on the pins)
hdr_x           = 0.0;   // Header centre along the long edge (0 = middle)

/* [Placement / beam] */
face_above_rim  = 15.0;  // [8:0.5:40] Transducer face height above canister top
recess          = 2.0;   // [0:0.5:5] Face recessed above the deck underside (45° flared, no tunnel)
beam_half_angle = 15.0;  // [5:1:30] HC-SR04 beam half-angle to keep clear
chimney_flare   = 30.0;  // [15:1:45] Opening flare from vertical (>= beam angle; <=45 prints unsupported)
tx_clr          = 0.3;   // [0.1:0.05:0.6] Radial clearance around cans
can_guide       = 3.0;   // [1:0.5:6] Deck thickness above the face (lateral can guide)

/* [Cradle / housing] */
pcb_clr         = 0.3;   // [0.1:0.05:0.6] Clearance around the PCB
wall            = 2.0;   // [2:0.2:4] Cradle / gland / lid wall
plinth_wall     = 2.4;   // [2:0.2:5] Min wall around the beam opening
post_w          = 3.0;   // Corner support post size along x
post_d          = 2.5;   // Corner support post size along y
hook            = 0.8;   // Snap hook overlap onto the PCB back
snap_w          = 10.0;  // Snap tongue width
hdr_notch_w     = 14.0;  // Slot in the cradle wall for the right-angle header
bay_len         = 26.0;  // Connector bay length beyond the cradle (Dupont + bend)
cable_d         = 5.0;   // [3:0.5:8] 4-core cable OD (or bundle of 4 jumpers)
cable_clr       = 0.5;   // Gland clearance on diameter
cable_z_above   = 6.0;   // Cable centre above the deck top
lid_clr         = 0.3;   // Lid skirt clearance to the plinth
lid_overlap     = 5.0;   // Skirt reaches this far below the deck top (drip edge)
lid_headroom    = 7.4;   // Free height above the PCB back side
lid_chamfer     = 8.0;   // 45° roof shoulders (sheds drips, prints roof-down)
ledge_w         = 2.0;   // Lid seat ledge width
vent_w          = 4.0;   // Labyrinth vent width (2 vents, -y side)
test_h          = 15.0;  // Test ring total height
lip_t           = 1.2;   // Test ring stop lip thickness
lip_over        = 4.0;   // Test ring lip overhang beyond the hole, per side

/* [Hidden] */
$fa = 2; $fs = 0.4;
eps = 0.01;

// ---------------- derived ----------------
hole_r     = hole_d / 2;
spigot_r   = hole_r - spigot_clr;          // collar OD / 2
collar_ir  = spigot_r - collar_wall;
flange_r   = hole_r + flange_margin;
face_z     = face_above_rim;
deck_bot   = face_z - recess;
deck_top   = face_z + can_guide;
pcb_front  = face_z + tx_h;
pcb_back   = pcb_front + pcb_t;
wall_top   = pcb_back + hook + 0.8;
ceiling    = pcb_back + lid_headroom;
lid_top    = ceiling + wall;
lid_bot    = deck_top - lid_overlap;
tx_x       = tx_pitch / 2;
hole_cr    = tx_d / 2 + tx_clr;            // can hole radius
sink_r     = hole_cr + recess;             // 45° countersink radius at deck underside
// beam-opening radius around each transducer axis at height z (z <= deck_bot)
function cav_r(z) = sink_r + (deck_bot - z) * tan(chimney_flare);
pk_x       = pcb_l / 2 + pcb_clr;          // cradle pocket half sizes
pk_y       = pcb_w / 2 + pcb_clr;
cable_z    = deck_top + cable_z_above;
cable_r    = (cable_d + cable_clr) / 2;
// plinth outline (rounded rectangle), y+ side carries the connector bay
pl_x       = max(tx_x + cav_r(flange_t) + plinth_wall, pk_x + wall + ledge_w + 2);
pl_y0      = -max(cav_r(flange_t) + plinth_wall, pk_y + wall + ledge_w + 2);
gl_y0      = pk_y + wall + bay_len;         // gland wall inner face
pl_y1      = gl_y0 + wall + ledge_w + 1;
pl_rad     = 4;
groove_ir  = collar_ir - collar_fit;
groove_or  = spigot_r + collar_fit;
groove_top = collar_insert + 0.3;
ring_top   = max(groove_top + 1.6, flange_t);
det_z      = lid_bot + 2.5;                 // lid detent height

// ---------------- checks ----------------
// Beam cone: rays leave the can rim (r = tx_d/2) at beam_half_angle.
// Clearance = opening radius - ray radius, sampled every 0.25 mm of depth.
function ray_r(d) = tx_d / 2 + d * tan(beam_half_angle);
function open_r(d) = d <= recess ? hole_cr + d            // 45° countersink
                   : cav_r(face_z - d);                   // flared chimney / flange opening
depths_open   = [for (d = [0 : 0.25 : face_z]) d];
clr_open      = min([for (d = depths_open) open_r(d) - ray_r(d)]);   // minimum is at the face (can bore)
clr_deck      = open_r(recess) - ray_r(recess);                       // at the deck underside
clr_rim       = open_r(face_z) - ray_r(face_z);                       // at canister-top level
// below the rim the collar bore is the limit (x direction is worst: axis at tx_x)
depths_collar = [for (d = [face_z : 0.25 : face_z + spigot_drop]) d];
clr_collar    = min([for (d = depths_collar) collar_ir - (tx_x + ray_r(d))]);
// the flange opening must also stay inside the collar bore
clr_flange    = collar_ir - (tx_x + cav_r(0));
// how far the cans may be too long before the face drops out of the countersink
xtal_gap      = (pcb_front - xtal_h) - deck_top;
dupont_end    = pk_y + hdr_pin_len + dupont_len * 0.4; // housing covers ~60% of the pins
bay_room      = gl_y0 - (pcb_w / 2 + 1 + dupont_len);

echo(str("SENSOR FACE HEIGHT ABOVE RIM = ", face_z, " mm  (transducer front -> canister top)"));
echo(str("  firmware: level_below_rim_mm = measured_mm - ", face_z));
echo(str("  face above flange top = ", face_z - flange_t, " mm; face recessed ", recess, " mm above deck underside"));
echo(str("DIMS flange Ø", 2 * flange_r, "  spigot Ø", 2 * spigot_r, " (hole Ø", hole_d, ")  spigot drop ", spigot_drop,
         "  top of lid ", lid_top, " mm above rim  overall ", lid_top + spigot_drop, " mm"));
echo(str("DIMS plinth ", 2 * pl_x, " x ", pl_y1 - pl_y0, " mm (y ", pl_y0, "..", pl_y1, ")"));
echo(str("BEAM ", beam_half_angle, "° cone from the can rim: clearance at face ", clr_open,
         " mm (can bore), at deck underside ", clr_deck, " mm, at rim level ", clr_rim, " mm"));
echo(str("BEAM min clearance opening = ", clr_open,
         " mm, collar bore = ", clr_collar, " mm, flange opening vs bore = ", clr_flange, " mm"));
echo(str("CLEAR crystal->deck ", xtal_gap, " mm; bay room past Dupont ", bay_room, " mm"));
assert(clr_open >= 0,   "beam cone hits the opening — raise chimney_flare or lower recess");
assert(clr_collar >= 0, "beam cone hits the collar bore — hole too small for this pitch");
assert(clr_flange >= 0, "flange opening wider than the collar bore — lower chimney_flare/face height");
assert(chimney_flare >= beam_half_angle, "chimney_flare must be >= beam_half_angle");
assert(chimney_flare <= 45, "chimney_flare > 45° will not print without supports");
assert(deck_bot > flange_t + 2, "face_above_rim too low for the flange + opening");
assert(xtal_gap > 0.5, "crystal would touch the deck");
assert(bay_room > 3, "bay_len too short for the Dupont housings");
assert(pl_x < flange_r && pl_y1 < flange_r + 10, "plinth larger than the flange");

// ---------------- helpers ----------------
module rrect(x0, x1, y0, y1, r) {
    translate([x0 + r, y0 + r]) offset(r = r) square([x1 - x0 - 2 * r, y1 - y0 - 2 * r]);
}
module plinth2d(o = 0) { rrect(-pl_x - o, pl_x + o, pl_y0 - o, pl_y1 + o, pl_rad + max(o, -pl_rad + 0.5)); }
module ring(r0, r1, z0, z1) {
    translate([0, 0, z0]) difference() {
        cylinder(r = r1, h = z1 - z0);
        translate([0, 0, -eps]) cylinder(r = r0, h = z1 - z0 + 2 * eps);
    }
}
// horizontal diamond bar along y (45° faces), reaching `depth` either side of x = 0
module vbar(depth, len) {
    rotate([90, 0, 0]) linear_extrude(height = len, center = true)
        polygon([[-depth, 0], [0, -depth], [depth, 0], [0, depth]]);
}

// ---------------- beam opening (cutter) ----------------
module beam_opening() {
    // flared chimney through plinth and flange, hull of both transducer cones
    z_lo = -eps - 1;
    hull() for (sx = [-1, 1]) translate([sx * tx_x, 0, 0]) {
        translate([0, 0, z_lo]) cylinder(r1 = cav_r(z_lo), r2 = sink_r, h = deck_bot - z_lo);
    }
    for (sx = [-1, 1]) translate([sx * tx_x, 0, 0]) {
        // 45° countersink below the face, straight can bore above it
        translate([0, 0, deck_bot - eps]) cylinder(r1 = sink_r + eps, r2 = hole_cr, h = recess + eps);
        translate([0, 0, face_z - eps]) cylinder(r = hole_cr, h = deck_top - face_z + 1);
    }
}

// ---------------- base ----------------
module flange() {
    cylinder(r = flange_r, h = flange_t);
    ring(groove_ir - 2, groove_or + 2, 0, ring_top);                // stiffening ring over the groove
}

module plinth() {
    difference() {
        translate([0, 0, flange_t - eps]) linear_extrude(deck_top - flange_t + eps) plinth2d();
        // lid detent grooves on ±x
        for (sx = [-1, 1]) translate([sx * pl_x, 0, det_z]) vbar(0.8, 14);
        // labyrinth vents: grooves up the -y wall, under the lid ledge
        for (sx = [-1, 1]) translate([sx * 12 - vent_w / 2, pl_y0 - 1, lid_bot])
            cube([vent_w, 1 + ledge_w + lid_clr + 1.5, deck_top - lid_bot + 1]);
    }
}

module cradle() {
    // pocket walls around the PCB, from the deck to just above the PCB back
    difference() {
        translate([0, 0, deck_top - eps]) linear_extrude(wall_top - deck_top + eps)
            difference() {
                rrect(-pk_x - wall, pk_x + wall, -pk_y - wall, pk_y + wall, 1);
                square([2 * pk_x, 2 * pk_y], center = true);
            }
        // header slot in the +y wall (pins + plastic body run out in-plane here)
        // (bottom stays above the PCB front face so the wall still locates the board edge)
        translate([hdr_x - hdr_notch_w / 2, pk_y - 1, pcb_front + 0.8]) cube([hdr_notch_w, wall + 2, 10]);
        // free the snap tongues on ±x
        for (sx = [-1, 1]) for (sy = [-1, 1])
            translate([sx * (pk_x + wall / 2), sy * (snap_w / 2 + 0.5), deck_top + 2 + (wall_top - deck_top) / 2])
                cube([wall + 2, 1.0, wall_top - deck_top], center = true);
    }
    // snap hooks: flat underside 0.2 mm above the PCB back, 45° lead-in
    for (sx = [-1, 1]) translate([sx * pk_x, 0, pcb_back + 0.2]) rotate([0, 0, sx > 0 ? 180 : 0])
        rotate([90, 0, 0]) linear_extrude(height = snap_w, center = true)
            polygon([[-eps, 0], [hook, 0], [hook, 0.2], [-eps, wall_top - pcb_back - 0.2]]);
    // corner posts: PCB front face rests on them (rim only, away from the cans)
    for (sx = [-1, 1]) for (sy = [-1, 1])
        translate([sx * (pk_x - post_w / 2), sy * (pk_y - post_d / 2), (deck_top + pcb_front) / 2 - eps])
            cube([post_w, post_d, pcb_front - deck_top + 2 * eps], center = true);
}

module gland() {
    gw = max(cable_d + 12, 16);
    // gland wall with an open-top U the cable drops into
    difference() {
        translate([-gw / 2, gl_y0, deck_top - eps]) cube([gw, wall, cable_z + cable_r - deck_top + eps]);
        translate([0, gl_y0 - 1, cable_z]) rotate([-90, 0, 0]) cylinder(r = cable_r, h = wall + 2);
        translate([-cable_r, gl_y0 - 1, cable_z]) cube([2 * cable_r, wall + 2, 20]);
    }
    // zip-tie bar just inside the gland: tie passes under it, around the cable
    bz0 = deck_top + 1.6;
    bz1 = max(cable_z - cable_r, bz0 + 1.2);
    translate([0, gl_y0 - 4, 0]) {
        translate([-6, 0, deck_top - eps]) cube([12, 2.5, bz1 - deck_top + eps]) ;
    }
}
module tie_tunnel() {
    translate([-4, gl_y0 - 4 - 1, deck_top - eps]) cube([8, 4.5, 1.6 + eps]);
}

module base() {
    difference() {
        union() {
            flange();
            plinth();
            cradle();
            gland();
        }
        beam_opening();
        tie_tunnel();
        ring(groove_ir, groove_or, -eps, groove_top);               // collar groove (bottom face, cut last)
    }
}

// ---------------- collar (use orientation: rim at z = 0) ----------------
module tabs_cut(z_bot, len) {
    // slots either side of each tab + inner thinning -> flexible tongues
    a_tab  = tab_w / spigot_r * 180 / PI;
    a_slot = 1.0 / spigot_r * 180 / PI;
    for (i = [0 : n_tabs - 1]) rotate([0, 0, 45 + i * 360 / n_tabs]) {
        for (s = [-1, 1]) rotate([0, 0, s * (a_tab + a_slot) / 2])
            translate([collar_ir - 1, -0.5, z_bot - 1]) cube([collar_wall + 2, 1.0, len + 1]);
        rotate([0, 0, -a_tab / 2]) rotate_extrude(angle = a_tab)
            translate([collar_ir - 1, z_bot - 1]) square([2, len + 1]);   // tongue 1 mm thinner
    }
}
module tabs_bumps(z_bot) {
    a_tab = tab_w / spigot_r * 180 / PI;
    h = hole_r + tab_interf - spigot_r;           // radial bump height
    if (h > 0) for (i = [0 : n_tabs - 1]) rotate([0, 0, 45 + i * 360 / n_tabs])
        rotate([0, 0, -a_tab / 2 + 2]) rotate_extrude(angle = a_tab - 4)
            translate([spigot_r - eps, z_bot + 1]) polygon([[0, 0], [h, h], [h, h + 1], [0, 2 * h + 1]]);
}
module collar() {
    z0 = -spigot_drop;
    difference() {
        ring(collar_ir, spigot_r, z0, collar_insert);
        if (n_tabs > 0) tabs_cut(z0, spigot_drop - 1);
    }
    if (n_tabs > 0) tabs_bumps(z0);
    // crush ribs on the insert (press fit into the flange groove)
    if (crush_rib > 0) for (i = [0 : 5]) rotate([0, 0, i * 60])
        translate([spigot_r - eps, -0.6, 0.6]) cube([crush_rib + collar_fit + eps, 1.2, collar_insert - 1.2]);
}

// ---------------- test ring (use orientation: lip bottom at z = 0) ----------------
module test_ring() {
    z0 = -(test_h - lip_t);
    difference() {
        union() {
            ring(collar_ir, spigot_r, z0, lip_t);
            ring(collar_ir, hole_r + lip_over, 0, lip_t);
        }
        if (n_tabs > 0) tabs_cut(z0, min(spigot_drop - 1, test_h - lip_t - 1));
        // notch in the lip: quick visual reference for "which way round"
        translate([hole_r + lip_over - 2, -1, -1]) cube([3, 2, lip_t + 2]);
    }
    if (n_tabs > 0) tabs_bumps(z0);
}

// ---------------- lid (use orientation) ----------------
module lid_shell_solid(o, ztop) {
    hull() {
        translate([0, 0, lid_bot]) linear_extrude(ztop - lid_chamfer - lid_bot) plinth2d(o);
        translate([0, 0, ztop - eps]) linear_extrude(eps) plinth2d(o - lid_chamfer);
    }
}
module lid() {
    oi = lid_clr;            // inner offset from the plinth
    oo = lid_clr + wall;     // outer
    difference() {
        lid_shell_solid(oo, lid_top);
        difference() {
            translate([0, 0, -eps]) lid_shell_solid(oi, ceiling);   // cavity
            // seat ledge: bears on the plinth top edge; 45° underside for roof-down printing
            difference() {
                translate([0, 0, deck_top]) linear_extrude(ledge_w) plinth2d(oi + 1);
                hull() {
                    translate([0, 0, deck_top - eps]) linear_extrude(eps) plinth2d(oi - ledge_w);
                    translate([0, 0, deck_top + ledge_w]) linear_extrude(eps) plinth2d(oi - 0.01);
                }
            }
        }
        translate([0, 0, lid_bot - 1]) linear_extrude(deck_top - lid_bot + 1) plinth2d(oi);  // skirt bore
        // cable notch (+y): inverted U, closes over the base gland U
        translate([0, pl_y1 - ledge_w - 2, cable_z]) rotate([-90, 0, 0]) cylinder(r = cable_r, h = ledge_w + oo + 4);
        translate([-cable_r, pl_y1 - ledge_w - 2, lid_bot - 1]) cube([2 * cable_r, ledge_w + oo + 4, cable_z - lid_bot + 1]);
        // labyrinth vents (-y), open downward, line up with the plinth grooves
        for (sx = [-1, 1]) translate([sx * 12 - vent_w / 2, pl_y0 - oo - 1, lid_bot - 1]) cube([vent_w, oo + 2, 3.5]);
    }
    // detent bumps on ±x (click into the plinth grooves)
    for (sx = [-1, 1]) translate([sx * (pl_x + lid_clr), 0, det_z]) vbar(0.5 + lid_clr, 10);
}

// ---------------- sensor dummy + context (preview only) ----------------
module hcsr04_dummy() {
    color("royalblue") translate([-pcb_l / 2, -pcb_w / 2, pcb_front]) cube([pcb_l, pcb_w, pcb_t]);
    color("silver") for (sx = [-1, 1]) translate([sx * tx_x, 0, face_z]) cylinder(d = tx_d, h = tx_h);
    color("silver") translate([0, xtal_y, pcb_front - xtal_h / 2])
        resize([xtal_l, xtal_w, xtal_h]) cylinder(d = 1, h = 1, center = true);
    color("black") for (x = [-12, 0, 12]) translate([x - 3, -2, pcb_back]) cube([6, 4, ic_h]);
    color("black") translate([hdr_x - 5.1, pcb_w / 2 - 2.5, pcb_back]) cube([10.2, 3.5, hdr_body_h]);
    color("gold") for (i = [0 : 3]) translate([hdr_x - 3.81 + i * 2.54, pcb_w / 2, pcb_back + hdr_body_h / 2])
        rotate([-90, 0, 0]) translate([-0.32, -0.32, 0]) cube([0.64, 0.64, hdr_pin_len]);
    color("dimgray") translate([hdr_x - 5.1, pcb_w / 2 + 1, pcb_back + hdr_body_h / 2 - 1.3]) cube([10.2, dupont_len, 2.6]);
    color("dimgray") translate([0, gl_y0 - 8, cable_z]) rotate([-90, 0, 0]) cylinder(d = cable_d, h = 30);
}
module canister_ghost() {
    difference() {
        translate([0, 0, -6]) cylinder(r = flange_r + 15, h = 6);
        translate([0, 0, -7]) cylinder(r = hole_r, h = 8);
    }
}
module beam_ghost(len = 60) {
    for (sx = [-1, 1]) translate([sx * tx_x, 0, face_z - len])
        cylinder(r1 = ray_r(len), r2 = tx_d / 2, h = len);
}
// cut = true: section through the transducer axes (y = 0), viewed from +y
// explode > 0: lid lifted and collar dropped by that many mm
module assembly(cut = false, explode = 0) {
    module cutaway(c) {
        if (cut) color(c) difference() { children(); translate([-200, 0, -100]) cube([400, 200, 300]); }
        else color(c) children();
    }
    cutaway("lightgray") base();
    cutaway("orange") translate([0, 0, -explode]) collar();
    cutaway("seagreen") translate([0, 0, 2.2 * explode]) lid();
    cutaway("royalblue") translate([0, 0, 0.9 * explode]) hcsr04_dummy();
    if (explode == 0) {
        cutaway("lightsteelblue") canister_ghost();
        // beam cone drawn as a thin shell so the section shows its boundary
        cutaway("red") difference() {
            beam_ghost();
            translate([0, 0, -0.01]) for (sx = [-1, 1]) translate([sx * tx_x, 0, face_z - 60 - 0.01])
                cylinder(r1 = ray_r(60) - 0.4, r2 = tx_d / 2 - 0.4, h = 60.03);
        }
    }
}

// ---------------- print orientation ----------------
module print_base()      base();
module print_collar()    translate([0, 0, collar_insert]) mirror([0, 0, 1]) collar();
module print_lid()       translate([0, 0, lid_top]) mirror([0, 0, 1]) lid();
module print_test_ring() translate([0, 0, lip_t]) mirror([0, 0, 1]) test_ring();

if (part == "base")           print_base();
else if (part == "collar")    print_collar();
else if (part == "lid")       print_lid();
else if (part == "test_ring") print_test_ring();
else if (part == "section")   assembly(cut = true);
else if (part == "exploded")  assembly(explode = 30);
else if (part == "all") {
    print_base();
    translate([flange_r + spigot_r + 5, 0, 0]) print_collar();
    translate([0, flange_r + pl_x + 8, 0]) rotate([0, 0, 90]) print_lid();
    translate([flange_r + spigot_r + 5, flange_r + hole_r + lip_over + 2, 0]) print_test_ring();
}
else assembly();
