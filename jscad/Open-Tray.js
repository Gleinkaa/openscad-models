const { cuboid } = require('@jscad/modeling').primitives;
const { subtract } = require('@jscad/modeling').booleans;

const getParameterDefinitions = () => [
  { name: 'length', type: 'float', initial: 60, caption: 'Inner Length' },
  { name: 'width', type: 'float', initial: 30, caption: 'Inner Width' },
  { name: 'height', type: 'float', initial: 15, caption: 'Inner Height' },
  { name: 'wall', type: 'float', initial: 2, caption: 'Wall Thickness' }
];

const main = (p) => {
  const outerBox = cuboid({
    size: [p.length + (p.wall*2), p.width + (p.wall*2), p.height + p.wall]
  });
  const innerCavity = cuboid({
    size: [p.length, p.width, p.height]
  });
  // Subtracting the cavity, leaving the top open
  return subtract(outerBox, innerCavity);
};

module.exports = { main, getParameterDefinitions };