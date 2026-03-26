// ============================================================
// Heavy-Duty 160mm Ventilation Duct Adapter — 45° Elbow
// ============================================================
// Designed to mate with a 160mm galvanized 45° duct elbow.
// Connector A slides into the metal pipe, Connector B receives
// flexible ducting. A 45° swept bend connects the two.
//
// Print note: Print with the flat Connector B end on the build
// plate. The bend and Connector A print upward. Use supports
// for the inner overhang of the bend if needed.
// ============================================================

$fn = 80;

// --- Tunable Parameters ---
// Adjust these if your printer over/under-extrudes.

// Connector A — Male end, slides INTO the 160mm metal pipe
pipe_id          = 160.0;   // Inner diameter of the metal pipe
conn_a_od        = 159.0;   // Print OD (1mm clearance for fit)
conn_a_length    = 50.0;    // Insertion depth into pipe

// Connector B — Hose side, 160mm flexible ducting pushes OVER this
conn_b_od        = 161.0;   // Slightly oversized for tight hose seal
conn_b_length    = 55.0;    // Length of hose connector section
barb_count       = 4;       // Number of hose barbs
barb_height      = 1.5;     // Barb protrusion height
barb_width       = 2.0;     // Axial width of each barb

// Bend
bend_angle       = 45;      // Elbow angle in degrees
bend_radius      = 120.0;   // Center-line bend radius (larger = gentler curve)

// Structural
wall_thickness   = 3.0;     // 3mm walls for rigidity at this diameter
flange_od        = 170.0;   // Stop flange outer diameter
flange_thickness = 4.0;     // Flange axial thickness

// --- Derived Values ---
conn_a_id = conn_a_od - 2 * wall_thickness;
conn_b_id = conn_b_od - 2 * wall_thickness;

// Average diameter for the bend section (transition between A and B)
bend_od = (conn_a_od + conn_b_od) / 2;
bend_id = bend_od - 2 * wall_thickness;

// Barb spacing (evenly distributed along Connector B)
barb_spacing = conn_b_length / (barb_count + 1);

// --- Modules ---

module connector_a() {
    // Plain cylinder — male end that slides into the metal pipe
    difference() {
        cylinder(d = conn_a_od, h = conn_a_length);
        translate([0, 0, -0.1])
            cylinder(d = conn_a_id, h = conn_a_length + 0.2);
    }
}

module flange() {
    // Stop flange ring — sits at the junction of Connector B and the bend
    difference() {
        cylinder(d = flange_od, h = flange_thickness);
        translate([0, 0, -0.1])
            cylinder(d = conn_b_id, h = flange_thickness + 0.2);
    }
}

module hose_barb(z_pos) {
    // Single tapered barb ring at a given Z position
    translate([0, 0, z_pos])
        difference() {
            cylinder(
                d1 = conn_b_od + 2 * barb_height,
                d2 = conn_b_od,
                h  = barb_width
            );
            translate([0, 0, -0.1])
                cylinder(d = conn_b_id, h = barb_width + 0.2);
        }
}

module connector_b() {
    // Hose side cylinder with barbs
    difference() {
        cylinder(d = conn_b_od, h = conn_b_length);
        translate([0, 0, -0.1])
            cylinder(d = conn_b_id, h = conn_b_length + 0.2);
    }

    // Add hose barbs evenly spaced
    for (i = [1 : barb_count]) {
        hose_barb(i * barb_spacing - barb_width / 2);
    }
}

module bend_section() {
    // 45° toroidal bend connecting Connector B to Connector A.
    rotate_extrude(angle = bend_angle, convexity = 10)
        translate([bend_radius, 0, 0])
            difference() {
                circle(d = bend_od);
                circle(d = bend_id);
            }
}

// --- Assembly ---
// Build from bottom up:
// 1. Connector B (hose side) — flat on build plate, pointing +Z
// 2. Flange at the top of Connector B
// 3. 45° bend curving away
// 4. Connector A (pipe side) at the end of the bend

// Step 1: Connector B — base, along Z axis
connector_b();

// Step 2: Flange at the top of Connector B
translate([0, 0, conn_b_length])
    flange();

// Step 3: Bend section
flange_top = conn_b_length + flange_thickness;

translate([0, 0, flange_top])
    rotate([90, 0, 0])
    translate([-bend_radius, 0, 0])
        bend_section();

// Step 4: Connector A at the end of the bend
// After the transforms, the bend centerline exits at:
//   X = bend_radius * (cos(angle) - 1)  (toward -X)
//   Z = bend_radius * sin(angle)         (upward)
// Exit direction is 45° from +Z toward -X.
bend_dx = bend_radius * (cos(bend_angle) - 1);
bend_dz = bend_radius * sin(bend_angle);

translate([bend_dx, 0, flange_top + bend_dz])
    rotate([0, -bend_angle, 0])
        connector_a();
