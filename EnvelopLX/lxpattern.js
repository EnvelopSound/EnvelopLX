var period = new BoundedParameter("Period", 2000, 5000);
var thing1 = new BoundedParameter("Thing1", 2000, 5000);
var thing2 = new BoundedParameter("Thing2", 2000, 5000);
var lfo = new SinLFO(0, 255, period);

function init() {
  	startModulator(lfo);
  	addParameter("period", period);
  	addParameter("thing1", thing1);
  	addParameter("thing2", thing2);
}

function run(deltaMs) {
	var lfoVal = lfo.getValue();
  	for (var i = 0; i < model.points.length; ++i) {
		var point = model.points.get(i);
    	colors[i] = palette.getColor(point, lfoVal * 100 / 255.);
  	}  
}
