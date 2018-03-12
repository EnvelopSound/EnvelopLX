import java.awt.Color;

@LXCategory("Texture")
public class Sizzle extends LXEffect {
  
  public final CompoundParameter amount = new CompoundParameter("Amount", .5)
    .setDescription("Intensity of the effect");
    
  public final CompoundParameter speed = new CompoundParameter("Speed", .5)
    .setDescription("Speed of the effect");
  
  private final int[] buffer = new ModelBuffer(lx).getArray();
  
  private float base = 0;
  
  public Sizzle(LX lx) {
    super(lx);
    addParameter("amount", this.amount);
    addParameter("speed", this.speed);
  }
  
  public void run(double deltaMs, double amount) {
      double amt = amount * this.amount.getValue();
    if (amt > 0) {
      base += deltaMs * .01 * speed.getValuef();
      for (int i = 0; i < this.buffer.length; ++i) {
        int val = (int) min(0xff, 500 * noise(i, base));
        this.buffer[i] = 0xff000000 | val | (val << 8) | (val << 16);
      }
      MultiplyBlend.multiply(this.colors, this.buffer, amt, this.colors);
    }
  }
}

@LXCategory("Form")
public static class Strobe extends LXEffect {
  
  public enum Waveshape {
    TRI,
    SIN,
    SQUARE,
    UP,
    DOWN
  };
  
  public final EnumParameter<Waveshape> mode = new EnumParameter<Waveshape>("Shape", Waveshape.TRI);
  
  public final CompoundParameter frequency = (CompoundParameter)
    new CompoundParameter("Freq", 1, .05, 10).setUnits(LXParameter.Units.HERTZ);  
  
  public final CompoundParameter depth = (CompoundParameter)
    new CompoundParameter("Depth", 0.5)
    .setDescription("Depth of the strobe effect");
    
  private final SawLFO basis = new SawLFO(1, 0, new FunctionalParameter() {
    public double getValue() {
      return 1000 / frequency.getValue();
  }});
        
  public Strobe(LX lx) {
    super(lx);
    addParameter("mode", this.mode);
    addParameter("frequency", this.frequency);
    addParameter("depth", this.depth);
    startModulator(basis);
  }
  
  @Override
  protected void onEnable() {
    basis.setBasis(0).start();
  }
  
  private LXWaveshape getWaveshape() {
    switch (this.mode.getEnum()) {
    case SIN: return LXWaveshape.SIN;
    case TRI: return LXWaveshape.TRI;
    case UP: return LXWaveshape.UP;
    case DOWN: return LXWaveshape.DOWN;
    case SQUARE: return LXWaveshape.SQUARE;
    }
    return LXWaveshape.SIN;
  }
  
  private final float[] hsb = new float[3];
  
  @Override
  public void run(double deltaMs, double amount) {
    float amt = this.enabledDamped.getValuef() * this.depth.getValuef();
    if (amt > 0) {
      float strobef = basis.getValuef();
      strobef = (float) getWaveshape().compute(strobef);
      strobef = lerp(1, strobef, amt);
      if (strobef < 1) {
        if (strobef == 0) {
          for (int i = 0; i < colors.length; ++i) {
            colors[i] = LXColor.BLACK;
          }
        } else {
          for (int i = 0; i < colors.length; ++i) {
            LXColor.RGBtoHSB(colors[i], hsb);
            hsb[2] *= strobef;
            colors[i] = Color.HSBtoRGB(hsb[0], hsb[1], hsb[2]);
          }
        }
      }
    }
  }
}

@LXCategory("Color")
public class LSD extends LXEffect {
  
  public final BoundedParameter scale = new BoundedParameter("Scale", 10, 5, 40);
  public final BoundedParameter speed = new BoundedParameter("Speed", 4, 1, 6);
  public final BoundedParameter range = new BoundedParameter("Range", 1, .7, 2);
  
  public LSD(LX lx) {
    super(lx);
    addParameter(scale);
    addParameter(speed);
    addParameter(range);
    this.enabledDampingAttack.setValue(500);
    this.enabledDampingRelease.setValue(500);
  }
  
  final float[] hsb = new float[3];

  private float accum = 0;
  private int equalCount = 0;
  private float sign = 1;
  
  @Override
  public void run(double deltaMs, double amount) {
    float newAccum = (float) (accum + sign * deltaMs * speed.getValuef() / 4000.);
    if (newAccum == accum) {
      if (++equalCount >= 5) {
        equalCount = 0;
        sign = -sign;
        newAccum = accum + sign*.01;
      }
    }
    accum = newAccum;
    float sf = scale.getValuef() / 1000.;
    float rf = range.getValuef();
    for (LXPoint p :  model.points) {
      LXColor.RGBtoHSB(colors[p.index], hsb);
      float h = rf * noise(sf*p.x, sf*p.y, sf*p.z + accum);
      int c2 = LX.hsb(h * 360, 100, hsb[2]*100);
      if (amount < 1) {
        colors[p.index] = LXColor.lerp(colors[p.index], c2, amount);
      } else {
        colors[p.index] = c2;
      }
    }
  }
}

public class ArcsOff extends LXEffect {
  public ArcsOff(LX lx) {
    super(lx);
  }
  
  @Override
  public void run(double deltaMs, double amount) {
    if (amount > 0) {
      for (Arc arc : venue.arcs) {
        setColor(arc, #000000);
      }
    }
  }
}