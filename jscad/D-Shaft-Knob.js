const { cylinder, cuboid } = require('@jscad/modeling').primitives;
const { subtract } = require('@jscad/modeling').booleans;
const { translate } = require('@jscad/modeling').transforms;

const getParameterDefinitions = () => [
  { name: 'knobD', type: 'float', initial: 25, caption: 'Knob Diameter' },
  { name: 'shaftD', type: 'float', initial: 6, caption: 'Shaft Diameter' },
  { name: 'flatOffset', type: 'float', initial: 2, caption: 'Flat Offset from Center' }
];

const main = (p) => {
  const knobBody = cylinder({radius: p.knobD/2, height: 15});
  
  // Create the D-shaft negative space
  const roundHole = cylinder({radius: p.shaftD/2, height: 15});
  const flatCut = translate([p.flatOffset, 0, 0], cuboid({size: [5, p.shaftD, 15]}));
  const dShaft = subtract(roundHole, flatCut);
  
  return subtract(knobBody, dShaft);
};

module.exports = { main, getParameterDefinitions };