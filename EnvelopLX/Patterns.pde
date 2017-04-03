import heronarts.lx.modulator.*;
import heronarts.p3lx.ui.studio.device.*;

public static class Test extends LXPattern {
  
  final CompoundParameter thing = new CompoundParameter("Thing", 0, model.yRange);
  final SinLFO lfo = new SinLFO("Stuff", 0, 1, 2000);
  
  public Test(LX lx) {
    super(lx);
    addParameter(thing);
    startModulator(lfo);
  }
  
  public void run(double deltaMs) {
    for (LXPoint p : model.points) {
      colors[p.index] = palette.getColor(max(0, 100 - 10*abs(p.y - thing.getValuef())));
    }
  }
}

public static class Palette extends LXPattern {
  public Palette(LX lx) {
    super(lx);
  }
  
  public void run(double deltaMs) {
    for (LXPoint p : model.points) {
      colors[p.index] = palette.getColor(p);
    }
  }
}

public static class MidiFlash extends LXPattern {
  
  private final LinearEnvelope brt = new LinearEnvelope("Brt", 100, 0, 1000);  
  
  public MidiFlash(LX lx) {
    super(lx);
    addModulator(brt.setValue(0));
  }
  
  @Override
  public void noteOnReceived(MidiNoteOn note) {
    brt.setValue(note.getVelocity() / 127. * 100).start();
  }
  
  public void run(double deltaMs) {
    for (LXPoint p : model.points) {
      colors[p.index] = palette.getColor(p, brt.getValuef());
    }
  }
}

public class EnvelopDecode extends LXPattern {
  
  public final BoundedParameter fade = new BoundedParameter("Fade", 1*FEET, 0.001, 4*FEET); 
  
  public EnvelopDecode(LX lx) {
    super(lx);
    addParameter(fade);
  }
  
  public void run(double deltaMs) {
    float fv = fade.getValuef();
    float falloff = 100 / fv;
    for (Column column : venue.columns) {
      float level = envelop.decode.channels[column.index].getValuef() * (model.yRange / 2.);
      for (LXPoint p : column.points) {
        float yn = abs(p.y - model.cy);
        float b = falloff * (level - yn);
        colors[p.index] = palette.getColor(p, constrain(b, 0, 100));
      }
    }
  }
}

public class SoundObjects extends LXPattern implements UIPattern {
  
  public final BoundedParameter size = new BoundedParameter("Base", 4*FEET, 0, 24*FEET);
  public final BoundedParameter response = new BoundedParameter("Level", 0, 1*FEET, 24*FEET);
  
  public SoundObjects(LX lx) {
    super(lx);
    for (Envelop.Source.Channel object : envelop.source.channels) {
      addLayer(new Layer(lx, object));
    }
    addParameter(size);
    addParameter(response);
  }
  
  public void buildControlUI(UI ui, UIPatternControl container) {
    int i = 0;
    for (LXLayer layer : getLayers()) {
      new UIButton((i % 4)*33, (i/4)*22, 28, 18).setLabel(Integer.toString(i+1)).setParameter(((Layer)layer).active).addToContainer(container);
      ++i;
    }
    int knobSpacing = UIKnob.WIDTH + 4;
    new UIKnob(0, 92).setParameter(size).addToContainer(container);
    new UIKnob(knobSpacing, 92).setParameter(response).addToContainer(container);

    container.setContentWidth(3*knobSpacing - 4);
  }
  
  class Layer extends LXLayer {
    
    private final Envelop.Source.Channel object;
    private final BooleanParameter active = new BooleanParameter("Active", true); 
    
    Layer(LX lx, Envelop.Source.Channel object) {
      super(lx);
      this.object = object;
      addParameter(active);
    }
    
    public void run(double deltaMs) {
      if (!this.active.isOn()) {
        return;
      }
      if (object.active) {
        float falloff = 100 / (size.getValuef() + response.getValuef() * object.getValuef());
        for (LXPoint p : model.points) {
          float dist = dist(p.x, p.y, p.z, object.tx, object.ty, object.tz);
          float b = 100 - dist*falloff;
          if (b > 0) {
            addColor(p.index, palette.getColor(p,  b));
          }
        }
      }
    }
  }
  
  public void run(double deltaMs) {
    setColors(LXColor.BLACK);
  }
}

public class Bouncing extends LXPattern {
  
  public CompoundParameter gravity = new CompoundParameter("Gravity", -200, -100, -400);
  public CompoundParameter size = new CompoundParameter("Length", 2*FEET, 1*FEET, 4*FEET);
  public CompoundParameter amp = new CompoundParameter("Height", model.yRange, 1*FEET, model.yRange);
  
  public Bouncing(LX lx) {
    super(lx);
    for (Column column : venue.columns) {
      addLayer(new Bouncer(lx, column));
    }
    addParameter(gravity);
    addParameter(size);
    addParameter(amp);
  }
  
  class Bouncer extends LXLayer {
    
    private final Column column;
    private final Accelerator position;
    
    Bouncer(LX lx, Column column) {
      super(lx);
      this.column = column;
      this.position = new Accelerator(column.yMax, 0, gravity);
      startModulator(position);
    }
    
    public void run(double deltaMs) {
      if (position.getValue() < 0) {
        position.setValue(-position.getValue());
        position.setVelocity(sqrt(abs(2 * (amp.getValuef() - random(0, 2*FEET)) * gravity.getValuef()))); 
      }
      float h = palette.getHuef();
      float falloff = 100. / size.getValuef();
      for (Rail rail : column.rails) {
        for (LXPoint p : rail.points) {
          float b = 100 - falloff * abs(p.y - position.getValuef());
          if (b > 0) {
            addColor(p.index, palette.getColor(p, b));
          }
        }
      }
    }
  }
    
  public void run(double deltaMs) {
    setColors(LXColor.BLACK);
  }
}

public class Movers extends LXPattern {
  
  private CompoundParameter period = new CompoundParameter("Speed", 150000, 200000, 50000); 
  
  public Movers(LX lx) {  
    super(lx);
    addParameter(period);
    for (int i = 0; i < 15; ++i) {
      addLayer(new Mover(lx));
    }
  }
  
  class Mover extends LXLayer {
    final TriangleLFO pos = new TriangleLFO(0, lx.total, period);
    
    Mover(LX lx) {
      super(lx);
      startModulator(pos.randomBasis());
    }
    
    public void run(double deltaMs) {
      for (LXPoint p : model.points) {
        float b = 100 - 3*abs(p.index - pos.getValuef());
        if (b > 0) {
          addColor(p.index, palette.getColor(p, b));
        }
      }
    }
  }
  
  public void run(double deltaMs) {
    setColors(LXColor.BLACK);
  }
}

public class Noise extends LXPattern {
  
  public final CompoundParameter scale = new CompoundParameter("Scale", 10, 5, 40);
  public final CompoundParameter xSpeed = new CompoundParameter("XSpd", 0, -6, 6);
  public final CompoundParameter ySpeed = new CompoundParameter("YSpd", 0, -6, 6);
  public final CompoundParameter zSpeed = new CompoundParameter("ZSpd", 1, -6, 6);
  public final CompoundParameter floor = new CompoundParameter("Floor", 0, -2, 2);
  public final CompoundParameter range = new CompoundParameter("Range", 1, .2, 4);
  public final CompoundParameter xOffset = new CompoundParameter("XOffs", 0, -1, 1);
  public final CompoundParameter yOffset = new CompoundParameter("YOffs", 0, -1, 1);
  public final CompoundParameter zOffset = new CompoundParameter("ZOffs", 0, -1, 1);
  
  public Noise(LX lx) {
    super(lx);
    addParameter(scale);
    addParameter(floor);
    addParameter(range);
    addParameter(xSpeed);
    addParameter(ySpeed);
    addParameter(zSpeed);
    addParameter(xOffset);
    addParameter(yOffset);
    addParameter(zOffset);
  }
  
  private class Accum {
    private float accum = 0;
    private int equalCount = 0;
    private float sign = 1;
    
    void accum(double deltaMs, float speed) {
      float newAccum = (float) (this.accum + this.sign * deltaMs * speed / 4000.);
      if (newAccum == this.accum) {
        if (++this.equalCount >= 5) {
          this.equalCount = 0;
          this.sign = -sign;
          newAccum = this.accum + sign*.01;
        }
      }
      this.accum = newAccum;
    }
  };
  
  private final Accum xAccum = new Accum();
  private final Accum yAccum = new Accum();
  private final Accum zAccum = new Accum();
    
  @Override
  public void run(double deltaMs) {
    xAccum.accum(deltaMs, xSpeed.getValuef());
    yAccum.accum(deltaMs, ySpeed.getValuef());
    zAccum.accum(deltaMs, zSpeed.getValuef());
    
    float sf = scale.getValuef() / 1000.;
    float rf = range.getValuef();
    float ff = floor.getValuef();
    float xo = xOffset.getValuef();
    float yo = yOffset.getValuef();
    float zo = zOffset.getValuef();
    for (LXPoint p :  model.points) {
      float b = ff + rf * noise(sf*p.x + xo + xAccum.accum, sf*p.y + yo + yAccum.accum, sf*p.z + zo + zAccum.accum);
      colors[p.index] = palette.getColor(p, constrain(b*100, 0, 100));
    }
  }
}