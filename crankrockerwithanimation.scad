// --- PARAMETERS ---
$fn = 100; // High resolution for smooth circles
tol = 0.2; // Global tolerance for 3D printing shrinkage

// Linkage Lengths (in mm)
crank_len = 15;      // Shortest link (determines sweep distance)
rod_len = 45;        // Connecting rod
rocker_len = 35;     // Oscillating arm
base_dist = 40;      // Distance between motor shaft and rocker pivot

// Hardware Dimensions
motor_shaft_dia = 6;     // Standard geared DC motor shaft
bearing_od = 22;         // 608ZZ bearing outer diameter
bearing_id = 8;          // 608ZZ bearing inner diameter
bearing_h = 7;           // 608ZZ bearing thickness
m3_dia = 3.2;            // M3 screw clearance hole
thickness = 10;          // Standard thickness for printed arms

// --- MODULES ---

module bearing_cutout() {
    // Cutout for pressing in a 608 bearing
    cylinder(h=bearing_h + 1, d=bearing_od + tol, center=true);
    // Clearance hole for the inner axle/bolt
    cylinder(h=thickness + 2, d=bearing_id + 2, center=true);
}

module base() {
    // A simplified base plate holding the motor and rocker pivot
    difference() {
        union() {
            hull() {
                cylinder(h=5, d=30);
                translate([base_dist, 0, 0]) cylinder(h=5, d=30);
            }
            // Tall standoff to elevate the Rocker to Level 3
            translate([base_dist, 0, 0]) cylinder(h=28, d=16);
        }
        
        // Motor shaft clearance
        translate([0, 0, -1]) cylinder(h=7, d=motor_shaft_dia + 4);
        
        // Rocker pivot mounting hole (made deeper to match the tall standoff)
        translate([base_dist, 0, -1]) cylinder(h=32, d=8 + tol);
    }
    
    // Motor mounting standoffs
    translate([0, 15, 0]) cylinder(h=5, d=6);
    translate([0, -15, 0]) cylinder(h=5, d=6);
}

module crank() {
    // The crank arm with a fail-safe slip clutch
    difference() {
        hull() {
            cylinder(h=thickness, d=20);
            translate([crank_len, 0, 0]) cylinder(h=thickness, d=15);
        }
        
        // Motor shaft hole (tight fit for slip clutch)
        cylinder(h=thickness + 2, d=motor_shaft_dia + tol, center=true);
        
        // Pin hole for connecting rod (using M3 bolt as axle)
        translate([crank_len, 0, 0]) cylinder(h=thickness + 2, d=m3_dia, center=true);
        
        // Slip clutch slit
        translate([10, 0, thickness/2]) cube([20, 1.5, thickness + 2], center=true);
        
        // M3 tensioning screw hole to adjust slip friction
        translate([0, 0, thickness/2]) rotate([90, 0, 0]) cylinder(h=30, d=m3_dia, center=true);
    }
}

module connecting_rod() {
    // Connects crank to rocker
    difference() {
        hull() {
            cylinder(h=thickness, d=15);
            translate([rod_len, 0, 0]) cylinder(h=thickness, d=bearing_od + 4);
        }
        
        // Crank attachment point (M3 clearance)
        cylinder(h=thickness + 2, d=m3_dia, center=true);
        
        // Rocker attachment point (Bearing cutout)
        translate([rod_len, 0, thickness/2]) bearing_cutout();
    }
}

module rocker() {
    // The oscillating arm where the fan mounts
    difference() {
        hull() {
            cylinder(h=thickness, d=bearing_od + 6);
            translate([rocker_len, 0, 0]) cylinder(h=thickness, d=15);
        }
        
        // Base pivot point (Bearing cutout)
        translate([0, 0, thickness/2]) bearing_cutout();
        
        // Connecting rod attachment point (M8 bolt hole to match bearing ID)
        translate([rocker_len, 0, 0]) cylinder(h=thickness + 2, d=8 + tol, center=true);
    }
    
    // Extension for mounting the fan
    translate([-10, -25, 0]) cube([20, 25, thickness]);
}

module assembly() {
    // $t goes from 0.0 to 1.0 during animation. Multiply by 360 for degrees.
    theta1 = $t * 360; 

    // --- Kinematics Math ---
    a = crank_len;
    b = rod_len;
    c = rocker_len;
    d = base_dist;

    x1 = a * cos(theta1);
    y1 = a * sin(theta1);

    L = sqrt(pow(d - x1, 2) + pow(y1, 2));

    alpha = atan2(y1, x1 - d);
    
    cos_beta = (pow(c, 2) + pow(L, 2) - pow(b, 2)) / (2 * c * L);
    beta = (cos_beta >= -1 && cos_beta <= 1) ? acos(cos_beta) : 0;

    theta3 = alpha - beta; 
    x2 = d + c * cos(theta3);
    y2 = c * sin(theta3);
    theta2 = atan2(y2 - y1, x2 - x1); 

    // --- RENDER THE PARTS (with new Z-stacking) ---
    
    color("gray") base();
    
    // Level 1: Red Crank (Driven by the motor)
    translate([0, 0, 6]) 
        rotate([0, 0, theta1]) 
        color("red") crank();
        
    // Level 2: Green Connecting Rod (Sits on top of the crank)
    translate([x1, y1, 17]) 
        rotate([0, 0, theta2]) 
        color("green") connecting_rod();

    // Level 3: Blue Rocker (Sits on top of the base standoff AND the green rod)
    translate([base_dist, 0, 28]) 
        rotate([0, 0, theta3]) 
        color("blue") rocker();
}

// --- RENDER COMMAND ---
assembly(); // Shows the animated mechanism

// Comment out 'assembly();' above and uncomment the parts below when you are ready to export STLs:
// base();
// crank();
// connecting_rod();
// rocker();