const { polygon } = require('@jscad/modeling').primitives;
const { extrudeLinear } = require('@jscad/modeling').operations.extrusions;

const getParameterDefinitions = () => [
  { name: 'thickness', type: 'float', initial: 3, caption: 'Material Thickness' },
  { name: 'scale', type: 'float', initial: 1, caption: 'Design Scale' }
];

const main = (p) => {
  // Classic stepped Art Deco geometry
  const decoProfile = polygon({points: [
    [0, 0], [50, 0], [50, 10], [40, 10], [40, 30], 
    [30, 30], [30, 60], [20, 60], [20, 100], [0, 100]
  ]});
  
  // Extrude the 2D shape into 3D
  return extrudeLinear({height: p.thickness}, decoProfile);
};

module.exports = { main, getParameterDefinitions };