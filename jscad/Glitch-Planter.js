const { cylinder } = require('@jscad/modeling').primitives;
const { subtract, union } = require('@jscad/modeling').booleans;
const { translate } = require('@jscad/modeling').transforms;

const getParameterDefinitions = () => [
  { name: 'radius', type: 'float', initial: 40, caption: 'Planter Radius' },
  { name: 'height', type: 'float', initial: 80, caption: 'Planter Height' },
  { name: 'glitchFactor', type: 'float', initial: 5, caption: 'Shift Amount' }
];

const main = (p) => {
  let layers = [];
  const layerHeight = 10;
  
  for(let i = 0; i < p.height; i += layerHeight) {
    // Pseudo-random shift for the glitch effect
    const shiftX = (Math.random() - 0.5) * p.glitchFactor;
    const shiftY = (Math.random() - 0.5) * p.glitchFactor;
    
    let layer = translate(
      [shiftX, shiftY, i], 
      cylinder({radius: p.radius, height: layerHeight})
    );
    layers.push(layer);
  }
  
  const solidBody = union(layers);
  const hollowCore = cylinder({radius: p.radius - 3, height: p.height});
  
  return subtract(solidBody, translate([0, 0, 3], hollowCore));
};

module.exports = { main, getParameterDefinitions };