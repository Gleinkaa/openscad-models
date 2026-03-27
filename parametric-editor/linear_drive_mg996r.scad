// ============================================================
// Linear Drive Mechanism — MG996R Servo + Dual Endstops
// ============================================================
// Mechanism: Rack and pinion. A pinion gear on the servo shaft
// meshes with a linear rack mounted on top of the carriage.
// The carriage slides on dovetail rails. Two micro limit
// switches at each end of travel act as endstops.
//
// Print notes:
//   - All parts lie flat on Z=0 (no supports needed).
//   - Print carriage and base separately, assemble with M3 hardware.
//   - Recommended: 0.2mm layer height, 3 perimeters, 20% infill.
// ============================================================

$fn = 64;

// --- Global Tolerances ---
tol        = 0.2;   // FDM clearance on mating surfaces
hole_tol   = 0.15;  // Extra clearance for screw holes
eps        = 0.1;   // Z-fighting prevention offset

// --- M3 Hardware ---
m3_hole_d    = 3.0 + 2 * hole_tol;   // Through-hole for M3 screw
m3_insert_d  = 4.2 + 2 * hole_tol;   // Heat-set insert or tight nut pocket
m3_nut_w     = 5.5 + 2 * tol;        // M3 nut flat-to-flat
m3_nut_h     = 2.4 + tol;            // M3 nut height
m3_head_d    = 5.5 + 2 * tol;        // Socket head cap diameter
m3_head_h    = 3.0 + tol;            // Socket head cap height

// --- MG996R Servo Dimensions ---
servo_body_l   = 40.7;   // Length (along output shaft axis direction)
servo_body_w   = 19.7;   // Width
servo_body_h   = 42.9;   // Height (shaft side up)
servo_tab_l    = 54.5;   // Total length including mounting tabs
servo_tab_w    = servo_body_w;
servo_tab_h    = 2.5;    // Tab thickness
servo_tab_z    = 27.0;   // Height from base to bottom of tab
servo_shaft_d  = 6.0;    // Output shaft diameter
servo_shaft_z  = servo_body_h;  // Shaft sits on top
servo_mount_hole_spacing_l = 49.0;  // Hole center-to-center along length
servo_mount_hole_spacing_w = 10.0;  // Hole center-to-center along width
servo_mount_hole_d = m3_hole_d;

// --- Gear Parameters (Rack & Pinion) ---
gear_module    = 1.5;    // Gear module (tooth size), mm. Larger = stronger but coarser
gear_pa        = 20;     // Pressure angle (degrees), standard involute
pinion_teeth   = 12;     // Number of teeth on pinion (on servo shaft)
gear_thickness = 8.0;    // Face width of both rack and pinion
gear_clearance = 0.1;    // Tip clearance between meshing teeth
gear_backlash  = 0.15;   // Extra gap for FDM print tolerance

// Derived gear dimensions
pinion_pd      = pinion_teeth * gear_module;          // Pitch diameter
pinion_od      = pinion_pd + 2 * gear_module;         // Outside diameter
pinion_rd      = pinion_pd - 2.5 * gear_module;       // Root diameter
rack_tooth_h   = 2.25 * gear_module;                  // Total tooth height
rack_pitch     = PI * gear_module;                     // Tooth-to-tooth distance

// --- Servo Horn Adapter ---
servo_spline_d = 5.8;    // MG996R output spline outer diameter
servo_spline_teeth = 25; // Number of spline teeth (standard MG996R)

// --- Drive Parameters ---
travel         = 50.0;   // Total linear travel of carriage (mm)
                          // With 12-tooth pinion, module 1.5:
                          // 180° servo sweep = PI * pinion_pd / 2
                          //                  = PI * 18 / 2 ≈ 28.3 mm
                          // Adjust pinion_teeth or gear_module for more travel.

// --- KW12-3 Micro Limit Switch ---
switch_body_l  = 19.8;   // Length
switch_body_w  = 6.4;    // Width
switch_body_h  = 10.0;   // Height (without lever)
switch_hole_d  = m3_hole_d;
switch_hole_spacing = 9.5;  // Between the two mounting holes
switch_hole_offset_x = 5.0; // From one end to first hole

// --- Base Chassis ---
base_length     = travel + servo_body_l + 40;  // Total rail length
base_width      = 50.0;
base_height     = 8.0;   // Thickness of base plate
rail_height     = 9.4;   // Height of dovetail rails above base
rail_width_bot  = 8.0;   // Bottom width of dovetail rail
rail_width_top  = 5.0;   // Top width of dovetail rail (narrower = dovetail)
rail_inset      = 6.0;   // Distance from base edge to rail center

// --- Carriage ---
carriage_length  = 30.0;
carriage_width   = base_width - 2 * rail_inset + 2 * rail_width_bot + 4;
carriage_height  = base_height + rail_height + 2;  // Sits above rails
carriage_plate_h = 5.0;  // Thickness of carriage top plate
groove_clearance = tol;   // Extra space in dovetail grooves

// --- Endstop Mount ---
endstop_mount_h  = switch_body_h + 4;  // Height of endstop bracket
endstop_mount_w  = switch_body_w + 8;  // Width
endstop_mount_d  = 4.0;               // Wall thickness behind switch
endstop_base_h   = 3.0;               // Base plate under switch mount

// --- Wall / Structure ---
wall = 3.0;  // General wall thickness


// ============================================================
//  UTILITY MODULES
// ============================================================

// M3 nut trap (hexagonal pocket)
module m3_nut_trap(depth = m3_nut_h) {
    cylinder(d = m3_nut_w / cos(30), h = depth + eps, $fn = 6);
}

// M3 counterbore hole (through-hole + head recess)
module m3_counterbore(length, head_depth = m3_head_h) {
    // Shaft
    cylinder(d = m3_hole_d, h = length + eps);
    // Head recess (from top)
    translate([0, 0, length - head_depth])
        cylinder(d = m3_head_d, h = head_depth + eps);
}


// ============================================================
//  PINION GEAR (mounts on servo shaft)
// ============================================================

module pinion_gear() {
    pitch_r = pinion_pd / 2;
    outer_r = pinion_od / 2;
    root_r  = pinion_rd / 2;
    tooth_angle = 360 / pinion_teeth;
    // Tooth angular widths
    base_half_a = 0.35 * tooth_angle;  // Half-width at root
    tip_half_a  = 0.15 * tooth_angle;  // Half-width at tip

    difference() {
        union() {
            // Root cylinder
            cylinder(r = root_r, h = gear_thickness);

            // Teeth: each is a hull of 4 small cylinders at the corners
            for (i = [0:pinion_teeth - 1]) {
                a = i * tooth_angle;
                hull() {
                    // Two corners at root
                    for (s = [-1, 1])
                        rotate([0, 0, a + s * base_half_a])
                            translate([root_r - 0.1, 0, 0])
                                cylinder(r = 0.1, h = gear_thickness, $fn = 8);
                    // Two corners at tip
                    for (s = [-1, 1])
                        rotate([0, 0, a + s * tip_half_a])
                            translate([outer_r - 0.1, 0, 0])
                                cylinder(r = 0.1, h = gear_thickness, $fn = 8);
                }
            }

            // Hub (thicker center for strength)
            cylinder(d = servo_spline_d + 4, h = gear_thickness + 3);
        }

        // Servo spline bore (simplified as D-shaft with flat)
        translate([0, 0, -eps])
            difference() {
                cylinder(d = servo_spline_d + 2*tol,
                         h = gear_thickness + 3 + 2*eps);
                // D-flat (one side shaved off for grip)
                translate([servo_spline_d/2 - 0.5, -servo_spline_d,
                           -eps])
                    cube([servo_spline_d, servo_spline_d * 2,
                          gear_thickness + 3 + 4*eps]);
            }

        // Set screw hole through hub (M3)
        translate([0, 0, gear_thickness/2 + 1.5])
            rotate([0, 90, 0])
                cylinder(d = m3_hole_d, h = servo_spline_d + 10,
                         center = true);
    }
}


// ============================================================
//  RACK (linear gear strip, attaches to carriage top)
// ============================================================

module gear_rack(length) {
    num_teeth  = floor(length / rack_pitch);
    rack_base_h = 3.0;  // Solid base below teeth
    total_h    = rack_base_h + rack_tooth_h;

    difference() {
        union() {
            // Base bar
            translate([-length/2, -gear_thickness/2, 0])
                cube([length, gear_thickness, rack_base_h]);

            // Teeth along the top (trapezoidal, hull-based)
            for (i = [0:num_teeth - 1]) {
                tx = -length/2 + rack_pitch/2 + i * rack_pitch;
                translate([tx, 0, rack_base_h])
                    hull() {
                        // Base (wider)
                        cube([rack_pitch * 0.5 + gear_backlash,
                              gear_thickness, eps], center = true);
                        // Tip (narrower)
                        translate([0, 0, rack_tooth_h - eps/2])
                            cube([rack_pitch * 0.3,
                                  gear_thickness, eps], center = true);
                    }
            }
        }

        // Mounting holes to attach rack to carriage
        for (dx = [-length/4, length/4])
            translate([dx, 0, -eps])
                cylinder(d = m3_hole_d, h = total_h + 2*eps);
    }
}


// ============================================================
//  DOVETAIL RAIL PROFILE (2D)
// ============================================================

module dovetail_profile(w_bot, w_top, h) {
    // Trapezoidal cross-section: wider at bottom
    offset = (w_bot - w_top) / 2;
    polygon([
        [-w_bot/2, 0],
        [ w_bot/2, 0],
        [ w_top/2, h],
        [-w_top/2, h]
    ]);
}


// ============================================================
//  BASE CHASSIS
// ============================================================

module base_chassis() {
    difference() {
        union() {
            // Main plate
            cube([base_length, base_width, base_height]);

            // Left dovetail rail (runs along X)
            // Extrude 2D profile along Z, rotate so Z→X
            translate([0, rail_inset, base_height])
                rotate([0, 90, 0])
                    linear_extrude(height = base_length)
                        rotate([0, 0, 90])
                            dovetail_profile(rail_width_bot, rail_width_top,
                                             rail_height);

            // Right dovetail rail
            translate([0, base_width - rail_inset, base_height])
                rotate([0, 90, 0])
                    linear_extrude(height = base_length)
                        rotate([0, 0, 90])
                            dovetail_profile(rail_width_bot, rail_width_top,
                                             rail_height);
        }

        // Mounting holes along base edges (4 corners + 2 mid)
        for (xi = [10, base_length/2, base_length - 10])
            for (yi = [wall, base_width - wall]) {
                translate([xi, yi, -eps])
                    cylinder(d = m3_hole_d, h = base_height + 2*eps);
                // Nut trap on bottom
                translate([xi, yi, -eps])
                    m3_nut_trap(m3_nut_h);
            }
    }
}


// ============================================================
//  SERVO MOUNT
// ============================================================
// Mounts the servo upside-down below the base plate so the
// horn/crank arm is at base level, driving the connecting rod.

module servo_mount() {
    mount_l = servo_tab_l + 2 * wall + 2 * tol;
    mount_w = servo_body_w + 2 * wall + 2 * tol;
    mount_h = servo_tab_z + servo_tab_h + wall;

    // Position: servo at one end of the base
    difference() {
        // Outer shell
        translate([-mount_l/2, -mount_w/2, 0])
            cube([mount_l, mount_w, mount_h]);

        // Servo body cavity
        translate([-(servo_body_l + 2*tol)/2,
                   -(servo_body_w + 2*tol)/2,
                   wall])
            cube([servo_body_l + 2*tol,
                  servo_body_w + 2*tol,
                  servo_body_h + tol]);

        // Tab slot
        translate([-(servo_tab_l + 2*tol)/2,
                   -(servo_tab_w + 2*tol)/2,
                   wall + servo_tab_z - tol])
            cube([servo_tab_l + 2*tol,
                  servo_tab_w + 2*tol,
                  servo_tab_h + 2*tol]);

        // Mounting screw holes through tabs
        for (sx = [-1, 1])
            for (sy = [-1, 1])
                translate([sx * servo_mount_hole_spacing_l/2,
                           sy * servo_mount_hole_spacing_w/2,
                           -eps])
                    cylinder(d = servo_mount_hole_d,
                             h = mount_h + 2*eps);

        // Shaft passthrough on top
        translate([0, 0, mount_h - wall - eps])
            cylinder(d = servo_shaft_d + 2*tol, h = wall + 2*eps);

        // Wire channel out the back
        translate([-(servo_body_l + 2*tol)/2 - wall - eps,
                   -4, wall])
            cube([wall + 2*eps, 8, 12]);
    }
}


// ============================================================
//  ENDSTOP MOUNT (single switch bracket)
// ============================================================

module endstop_bracket() {
    // L-shaped bracket: base plate + vertical back wall
    difference() {
        union() {
            // Base plate
            cube([endstop_mount_w, switch_body_l + 4, endstop_base_h]);

            // Vertical wall
            cube([endstop_mount_w, endstop_mount_d, endstop_mount_h]);
        }

        // Switch mounting holes: horizontal through vertical back wall
        for (i = [0, 1])
            translate([endstop_mount_w/2,
                       -eps,
                       endstop_base_h + 3 + i * switch_hole_spacing])
                rotate([-90, 0, 0])
                    cylinder(d = switch_hole_d, h = endstop_mount_d + 2*eps);

        // Base mounting holes (M3 to attach bracket to chassis)
        for (dx = [endstop_mount_w * 0.25, endstop_mount_w * 0.75])
            translate([dx, switch_body_l/2 + 2, -eps])
                cylinder(d = m3_hole_d, h = endstop_base_h + 2*eps);
    }
}

// Both endstop mounts positioned at ends of travel
module endstop_mounts() {
    // Near end (servo side)
    translate([servo_body_l/2 + wall, base_width/2 - endstop_mount_w/2, base_height])
        endstop_bracket();

    // Far end
    translate([base_length - servo_body_l/2 - wall - switch_body_l - 4,
               base_width/2 - endstop_mount_w/2,
               base_height])
        mirror([1, 0, 0])
            endstop_bracket();
}


// ============================================================
//  CARRIAGE
// ============================================================

module carriage() {
    groove_w_bot = rail_width_bot + 2 * groove_clearance;
    groove_w_top = rail_width_top + 2 * groove_clearance;
    groove_h     = rail_height + groove_clearance;
    total_h      = rail_height + carriage_plate_h;
    rail_span    = base_width - 2 * rail_inset;  // Center-to-center distance

    // Carriage centered at origin. Z=0 = bottom (sits on base plate top).
    // Dovetail grooves cut upward from Z=0 to wrap around the rails.
    // Print orientation: flip upside-down (grooves face up on print bed).

    difference() {
        // Solid body spanning both rails
        translate([-carriage_length/2, -carriage_width/2, 0])
            cube([carriage_length, carriage_width, total_h]);

        // Dovetail grooves (cut from bottom, run along X)
        for (side = [-1, 1]) {
            translate([-carriage_length/2 - eps,
                       side * rail_span/2,
                       0])
                rotate([0, 90, 0])
                    linear_extrude(height = carriage_length + 2*eps)
                        rotate([0, 0, 90])
                            dovetail_profile(groove_w_bot, groove_w_top,
                                             groove_h);
        }

        // Material relief between rails (lighten the middle)
        translate([-carriage_length/2 + wall,
                   -rail_span/2 + groove_w_bot/2 + wall,
                   -eps])
            cube([carriage_length - 2*wall,
                  rail_span - groove_w_bot - 2*wall,
                  rail_height - wall]);

        // Rack mounting bolt holes (center pair, M3)
        for (dx = [-8, 8])
            translate([dx, 0, -eps])
                cylinder(d = m3_hole_d, h = total_h + 2*eps);

        // Top mounting holes (for attaching payload)
        for (dx = [-carriage_length/4, carriage_length/4])
            for (dy = [-10, 10])
                translate([dx, dy, -eps])
                    cylinder(d = m3_hole_d, h = total_h + 2*eps);
    }
}


// (Connecting rod removed — drive is now rack & pinion)


// ============================================================
//  ASSEMBLED VIEW
// ============================================================

module assembled_view() {
    total_carriage_h = rail_height + carriage_plate_h;
    rack_h = 3.0 + rack_tooth_h;  // Base + teeth

    // --- Base Chassis ---
    color("SteelBlue", 0.8)
        base_chassis();

    // --- Servo Mount (at one end, centered on base width) ---
    servo_mount_x = servo_body_l/2 + wall + 5;
    servo_mount_y = base_width / 2;

    color("DarkSlateGray", 0.7)
        translate([servo_mount_x, servo_mount_y, base_height])
            rotate([180, 0, 0])  // Servo hangs below base
                servo_mount();

    // --- Endstop Brackets ---
    color("OrangeRed", 0.8)
        endstop_mounts();

    // --- Carriage (positioned mid-travel for visualization) ---
    carriage_x = servo_mount_x + travel/2;  // Mid-stroke
    color("ForestGreen", 0.6)
        translate([carriage_x, base_width/2, base_height])
            carriage();

    // --- Rack (on top of carriage, teeth face up toward pinion) ---
    color("Gold", 0.9)
        translate([carriage_x, base_width/2,
                   base_height + total_carriage_h])
            gear_rack(carriage_length - 4);

    // --- Pinion (on servo shaft, meshing with rack) ---
    // Pinion center must be at rack tooth top + pitch radius
    pinion_z = base_height + total_carriage_h + rack_h + pinion_pd/2
               - gear_module;  // Mesh at pitch circle
    color("Crimson", 0.9)
        translate([servo_mount_x, base_width/2 - gear_thickness/2,
                   pinion_z])
            rotate([-90, 0, 0])
                pinion_gear();

    // --- Ghost: Limit switches (for reference) ---
    %translate([servo_body_l/2 + wall + endstop_mount_d,
                base_width/2 - switch_body_w/2,
                base_height + endstop_base_h])
        cube([switch_body_l, switch_body_w, switch_body_h]);

    %translate([base_length - servo_body_l/2 - wall - endstop_mount_d - switch_body_l,
                base_width/2 - switch_body_w/2,
                base_height + endstop_base_h])
        cube([switch_body_l, switch_body_w, switch_body_h]);
}


// ============================================================
//  RENDER SELECTION
// ============================================================
// Uncomment ONE of the following to export individual STLs,
// or use assembled_view() for preview.

assembled_view();

// For individual STL export, uncomment one at a time:
// base_chassis();
// servo_mount();
// endstop_bracket();
// carriage();
// pinion_gear();
// gear_rack(carriage_length - 4);
