const { cylinder, cylinderElliptic } = require('@jscad/modeling').primitives;
const { translate, rotateX } = require('@jscad/modeling').transforms;
const { hull } = require('@jscad/modeling').hulls;
const { union, subtract } = require('@jscad/modeling').booleans;

// Matches the UI parameters from image_7100ad.png
const getParameterDefinitions = () => {
    return [
        { name: 'd1', type: 'float', initial: 156, caption: 'Base OD (mm)' },
        { name: 'd2', type: 'float', initial: 124, caption: 'End OD (mm)' },
        { name: 'wall', type: 'float', initial: 1.9, caption: 'Wall Thickness (mm)' },
        { name: 'angle', type: 'float', initial: -50, caption: 'Flange Angle (deg)' },
        { name: 'chamfer', type: 'float', initial: 3, caption: 'Chamfer (mm)' },
        { name: 'len1', type: 'float', initial: 30, caption: 'Base Length (mm)' },
        { name: 'len2', type: 'float', initial: 39, caption: 'End Length (mm)' },
        { name: 'offset_y', type: 'float', initial: 56, caption: 'Transition Offset Y (mm)' },
        { name: 'offset_z', type: 'float', initial: 78, caption: 'Transition Offset Z (mm)' },
        { name: 'snap_height', type: 'float', initial: 6, caption: 'Snap Height (mm)' },
        { name: 'snap_depth', type: 'float', initial: 2, caption: 'Snap Depth (mm)' },
        { name: 'segments', type: 'int', initial: 120, caption: 'Resolution ($fn)' }
    ];
};

const main = (p) => {
    // Helper function to mimic OpenSCAD's default bottom-centered cylinder behavior 
    // and handle both straight and tapered cylinders smoothly.
    const oscadCyl = (h, r1, r2 = r1) => {
        if (r1 === r2) {
            return cylinder({
                height: h,
                radius: r1,
                center: [0, 0, h / 2],
                segments: p.segments
            });
        } else {
            return cylinderElliptic({
                height: h,
                startRadius: [r1, r1],
                endRadius: [r2, r2],
                center: [0, 0, h / 2],
                segments: p.segments
            });
        }
    };

    // Convert degrees to radians for JSCAD transforms
    const angleRad = -p.angle * (Math.PI / 180);

    // --- Outer Shell ---
    const r1_base_bottom = ((p.d1 + p.snap_depth * 2) - p.chamfer * 2) / 2;
    const r1_base_top = (p.d1 + p.snap_depth * 2) / 2;

    // 1. Snapping Edge Base
    const out_chamfer = oscadCyl(p.chamfer, r1_base_bottom, r1_base_top);
    
    const out_snap = translate([0, 0, p.chamfer], 
        oscadCyl(p.snap_height - p.chamfer, r1_base_top)
    );

    // 2. Main base cylinder
    const out_base = translate([0, 0, p.snap_height], 
        oscadCyl(p.len1 - p.snap_height, p.d1 / 2)
    );

    // Transition bend
    const t1 = translate([0, 0, p.len1 - 0.1], oscadCyl(0.1, p.d1 / 2));
    const t2 = translate([0, -p.offset_y, p.offset_z], 
        rotateX(angleRad, oscadCyl(0.1, p.d2 / 2))
    );
    const trans_bend = hull(t1, t2);

    // Angled End Piece
    const end_piece = translate([0, -p.offset_y, p.offset_z], 
        rotateX(angleRad, oscadCyl(p.len2, p.d2 / 2))
    );

    const outer = union(out_chamfer, out_snap, out_base, trans_bend, end_piece);

    // --- Inner Shell ---
    const inner_d1 = p.d1 - p.wall * 2;
    const inner_d2 = p.d2 - p.wall * 2;

    // Inner Base
    const in_base_bottom = translate([0, 0, -1], 
        oscadCyl(p.chamfer + 1, (inner_d1 - p.chamfer * 2) / 2, inner_d1 / 2)
    );

    const in_base_top = translate([0, 0, p.chamfer], 
        oscadCyl(p.len1 - p.chamfer, inner_d1 / 2)
    );

    // Inner Transition
    const it1 = translate([0, 0, p.len1 - 0.1], oscadCyl(0.1, inner_d1 / 2));
    const it2 = translate([0, -p.offset_y, p.offset_z], 
        rotateX(angleRad, oscadCyl(0.1, inner_d2 / 2))
    );
    const inner_trans_bend = hull(it1, it2);

    // Inner Angled End Piece
    const inner_end_piece = translate([0, -p.offset_y, p.offset_z], 
        rotateX(angleRad, 
            translate([0, 0, -0.1], oscadCyl(p.len2 + 2, inner_d2 / 2))
        )
    );

    const inner = union(in_base_bottom, in_base_top, inner_trans_bend, inner_end_piece);

    // Return the final hollowed part
    return subtract(outer, inner);
};

module.exports = { main, getParameterDefinitions };