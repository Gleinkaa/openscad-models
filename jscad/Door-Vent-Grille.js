const { cuboid, cylinder } = require('@jscad/modeling').primitives;
const { union, subtract, intersect } = require('@jscad/modeling').booleans;
const { translate } = require('@jscad/modeling').transforms;

const getParameterDefinitions = () => {
  return [
    { name: 'grp1', type: 'group', caption: 'Maximale Außenmaße' },
    { name: 'width', type: 'number', initial: 200, caption: 'Max. Breite (X)' },
    { name: 'length', type: 'number', initial: 60, caption: 'Max. Höhe (Y)' },
    { name: 'flange_h', type: 'number', initial: 3, caption: 'Dicke des Außenrandes (Z)' },

    { name: 'grp2', type: 'group', caption: 'Einsteckteil (In der Tür)' },
    { name: 'offset', type: 'number', initial: 12, caption: 'Offset nach innen (Überstand Rand)' },
    { name: 'insert_h', type: 'number', initial: 15, caption: 'Einstecktiefe in die Tür' },
    { name: 'wall', type: 'number', initial: 2.5, caption: 'Wandstärke des Einsteckteils' },

    { name: 'grp3', type: 'group', caption: 'Lochmuster' },
    { name: 'pattern', type: 'choice', caption: 'Muster Typ', values: ['slats', 'grid', 'circles'], captions: ['Schlitze (wie Foto)', 'Kachelgitter', 'Runde Löcher'], initial: 'slats' },
    { name: 'stegbreite', type: 'number', initial: 3, caption: 'Dicke der Stege (Plastik)' },
    { name: 'lochgroesse', type: 'number', initial: 5, caption: 'Größe der Löcher/Schlitze' }
  ];
};

const main = (params) => {
  let w = params.width;
  let l = params.length;
  let fh = params.flange_h;
  let offset = params.offset;
  let ih = params.insert_h;
  let wall = params.wall;

  // 1. Äußerer Sichtrand (Flange)
  let flange = translate([0, 0, fh/2], cuboid({size: [w, l, fh]}));

  // 2. Inneres Einsteckteil
  let iw = w - 2 * offset;
  let il = l - 2 * offset;

  if (iw <= 0 || il <= 0) {
      throw new Error("Der Offset ist zu groß für die angegebenen Maximalmaße!");
  }

  let insert = translate([0, 0, fh + ih/2], cuboid({size: [iw, il, ih]}));
  let body = union(flange, insert);

  // 3. Ausschnitt für den Luftdurchlass (Hohlraum)
  let cw = iw - 2 * wall;
  let cl = il - 2 * wall;

  if (cw <= 0 || cl <= 0) {
      throw new Error("Die Wandstärke in Kombination mit dem Offset ist zu groß!");
  }

  let cutout = translate([0, 0, (fh + ih)/2], cuboid({size: [cw, cl, fh + ih + 2]}));

  // Rahmen erstellen (Massivkörper minus Hohlraum)
  let frame = subtract(body, cutout);

  // 4. Lochmuster generieren
  let patternResult;
  let bounds = translate([0, 0, fh/2], cuboid({size: [cw, cl, fh]})); // Begrenzungsbox für das Muster

  if (params.pattern === 'circles') {
      // Bei Kreisen ist es effizienter, Zylinder aus einer massiven Platte zu stanzen
      let grillePlate = bounds;
      let holes = [];
      let step = params.stegbreite + params.lochgroesse;
      let radius = params.lochgroesse / 2;

      for (let x = -cw/2 + step/2; x <= cw/2; x += step) {
          for (let y = -cl/2 + step/2; y <= cl/2; y += step) {
              holes.push(translate([x, y, fh/2], cylinder({radius: radius, height: fh + 2})));
          }
      }
      patternResult = holes.length > 0 ? subtract(grillePlate, union(holes)) : grillePlate;

  } else {
      // Bei Schlitzen und Gittern addieren wir die positiven Stege (rechnet viel schneller)
      let struts = [];
      let step = params.stegbreite + params.lochgroesse;

      // Waagerechte Stege
      for (let y = -cl/2; y <= cl/2; y += step) {
         struts.push(translate([0, y, fh/2], cuboid({size: [cw, params.stegbreite, fh]})));
      }

      if (params.pattern === 'grid') {
          // Zusätzliche senkrechte Stege für das Kreuzgitter
          for (let x = -cw/2; x <= cw/2; x += step) {
             struts.push(translate([x, 0, fh/2], cuboid({size: [params.stegbreite, cl, fh]})));
          }
      } else if (params.pattern === 'slats') {
          // Automatische vertikale Stützen für Schlitze, damit diese nicht durchhängen/brechen
          if (cw > 120) {
              struts.push(translate([-cw/3, 0, fh/2], cuboid({size: [params.stegbreite, cl, fh]})));
              struts.push(translate([cw/3, 0, fh/2], cuboid({size: [params.stegbreite, cl, fh]})));
          } else if (cw > 60) {
              struts.push(translate([0, 0, fh/2], cuboid({size: [params.stegbreite, cl, fh]})));
          }
      }

      // Muster auf den inneren Bereich zuschneiden, damit nichts übersteht
      patternResult = struts.length > 0 ? intersect(union(struts), bounds) : bounds;
  }

  // Rahmen und Muster zusammensetzen
  return union(frame, patternResult);
};

module.exports = { main, getParameterDefinitions };