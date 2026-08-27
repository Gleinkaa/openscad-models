const { cylinder } = require('@jscad/modeling').primitives;
const { subtract, union } = require('@jscad/modeling').booleans;
const { translate } = require('@jscad/modeling').transforms;

const getParameterDefinitions = () => [
  { name: 'd1', type: 'float', initial: 25, caption: 'Base Outer Diameter' },
  { name: 'd2', type: 'float', initial: 15, caption: 'Top Outer Diameter' },
  { name: 'wall', type: 'float', initial: 2, caption: 'Wall Thickness' },
  { name: 'h', type: 'float', initial: 40, caption: 'Total Height' }
];

const main = (p) => {
  const outer = union(
    cylinder({radius: p.d1/2, height: p.h/2}),
    translate([0, 0, p.h/2], cylinder({radius: p.d2/2, height: p.h/2}))
  );
  const inner = union(
    cylinder({radius: (p.d1/2) - p.wall, height: p.h/2}),
    translate([0, 0, p.h/2], cylinder({radius: (p.d2/2) - p.wall, height: p.h/2}))
  );
  return subtract(outer, inner);
};

module.exports = { main, getParameterDefinitions };