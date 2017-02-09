import heronarts.lx.modulator.*;

class Movers extends LXPattern {
  final SawLFO hBase = new SawLFO(0, 360, 60000);
  Movers(LX lx) {
    super(lx);
    startModulator(hBase);
    for (int i = 0; i < 15; ++i) {
      addLayer(new Mover(lx));
    }
  }
  
  class Mover extends LXLayer {
    final SinLFO period = new SinLFO(20000, 90000, 77000);
    final TriangleLFO pos = new TriangleLFO(0, lx.total, period);
    
    Mover(LX lx) {
      super(lx);
      startModulator(period.randomBasis());
      startModulator(pos.randomBasis());
    }
    
    public void run(double deltaMs) {
      for (LXPoint p : model.points) {
        float b = 100 - 3*abs(p.index - pos.getValuef());
        if (b > 0) {
          addColor(p.index, LX.hsb((hBase.getValuef() + p.index/2.) % 360, 0, b));
        }
      }
    }
  }
  
  public void run(double deltaMs) {
    setColors(0);
  }
}