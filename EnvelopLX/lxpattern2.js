var lfo;

function init() {
  lfo = new SquareLFO(0, 255, 1000);
  startModulator(lfo);
}

function run(deltaMs) {
  var lfoVal = lfo.getValue();
  for (var i = 0; i < colors.length; ++i) {
    colors[i] = 0xff00ff00 + lfoVal;
  }
}
