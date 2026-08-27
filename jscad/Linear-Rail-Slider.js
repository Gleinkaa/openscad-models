const { cuboid, cylinder } = require('@jscad/modeling').primitives;
const { subtract, union } = require('@jscad/modeling').booleans;
const { translate } = require('@jscad/modeling').transforms;

const getParameterDefinitions = () => [
  { name: 'railLen', type: 'float', initial: 100, caption: 'Rail Length' },
  { name: 'sliderWidth', type: 'float', initial: 20, caption: 'Slider Width' }
];

const main = (p) => {
  const rail = cuboid({size: [p.railLen, 10, 5]});
  const slider = translate(
    [0, 0, 5], 
    cuboid({size: [p.sliderWidth, 14, 10]})
  );
  const railCutout = translate(
    [0, 0, 5], 
    cuboid({size: [p.railLen + 2, 10.5, 5.5]})
  );
  
  return union(rail, subtract(slider, railCutout));
};

module.exports = { main, getParameterDefinitions };