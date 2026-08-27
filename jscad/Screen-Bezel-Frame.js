const { cuboid } = require('@jscad/modeling').primitives;
const { subtract } = require('@jscad/modeling').booleans;

const getParameterDefinitions = () => [
  { name: 'screenWidth', type: 'float', initial: 165, caption: 'Screen Width' },
  { name: 'screenHeight', type: 'float', initial: 100, caption: 'Screen Height' },
  { name: 'bezel', type: 'float', initial: 8, caption: 'Bezel Thickness' },
  { name: 'depth', type: 'float', initial: 10, caption: 'Frame Depth' }
];

const main = (p) => {
  const outerFrame = cuboid({
    size: [p.screenWidth + (p.bezel*2), p.screenHeight + (p.bezel*2), p.depth]
  });
  const innerCutout = cuboid({
    size: [p.screenWidth, p.screenHeight, p.depth]
  });
  
  return subtract(outerFrame, innerCutout);
};

module.exports = { main, getParameterDefinitions };