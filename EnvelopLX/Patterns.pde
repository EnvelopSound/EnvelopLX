import heronarts.lx.modulator.*;
import heronarts.p3lx.ui.studio.device.*;
import java.util.Stack;

public static abstract class EnvelopPattern extends LXPattern {
  
  protected final EnvelopModel model;
  
  protected EnvelopPattern(LX lx) {
    super(lx);
    this.model = (EnvelopModel) lx.model;
  }
}

public static abstract class RotationPattern extends EnvelopPattern {
    
  protected final CompoundParameter period = (CompoundParameter)
    new CompoundParameter("Period", 2500, 1000, 10000)
    .setExponent(2)
    .setUnits(LXParameter.Units.MILLISECONDS)
    .setDescription("Period of the rotation");
  
  protected final SawLFO phase = new SawLFO(0, TWO_PI, period);
  
  protected RotationPattern(LX lx) {
    super(lx);
    startModulator(this.phase);
    addParameter("period", this.period);
  }
}

public static class Corkskrew extends RotationPattern {
    
  private final CompoundParameter size = (CompoundParameter)
    new CompoundParameter("Size", 2*FEET, 6*INCHES, 8*FEET)
    .setDescription("Size of the corkskrew");
  
  public Corkskrew(LX lx) {
    super(lx);
    addParameter("size", this.size);
    setColors(0);
  }
  
  public void run(double deltaMs) {
    float phaseV = this.phase.getValuef();
    float sizeV = this.size.getValuef();
    float falloff = 200 / sizeV;
    
    for (Rail rail : model.rails) {
      float yp = -sizeV + ((phaseV + (PI + rail.theta)) % TWO_PI) / TWO_PI * (model.yRange + 2*sizeV);
      for (LXPoint p : rail.points) {
        colors[p.index] = palette.getColor(p, max(0, 100 - falloff*abs(p.y - yp)));
      }
    }
  }
}

public static class Warble extends RotationPattern {
  
  private final CompoundParameter size = (CompoundParameter)
    new CompoundParameter("Size", 2*FEET, 6*INCHES, 8*FEET)
    .setDescription("Size of the warble");
  
  private final CompoundParameter interp = 
    new CompoundParameter("Interp", 1, 1, 3)
    .setDescription("Interpolation on the warble");
    
  private final DampedParameter interpDamped = new DampedParameter(interp, .5, .5); 
    
  public Warble(LX lx) {
    super(lx);
    startModulator(this.interpDamped);
    addParameter("interp", this.interp);
    addParameter("size", this.size);
    setColors(0);
  }
  
  public void run(double deltaMs) {
    float phaseV = this.phase.getValuef();
    float interpV = this.interpDamped.getValuef();
    int mult = floor(interpV);
    float lerp = interpV % mult;
    float falloff = 200 / size.getValuef();
    
    for (Rail rail : model.rails) {
      float y1 = model.yRange * .5 * sin(phaseV + mult * rail.theta);
      float y2 = model.yRange * .5 * sin(phaseV + (mult+1) * rail.theta);
      float yo = lerp(y1, y2, lerp);
      for (LXPoint p : rail.points) {
        colors[p.index] = palette.getColor(p, max(0, 100 - falloff*abs(p.y - model.cy - yo)));
      }
    }
  }
}

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

public static class Drops extends EnvelopPattern {
  
  private final Stack<Drop> availableDrops = new Stack<Drop>();

  public Drops(LX lx) {
    super(lx);
  }
  
  private void triggerDrop() {
    if (availableDrops.empty()) {
      Drop drop = new Drop(lx);
      addLayer(drop);
      availableDrops.push(drop);
    }
    availableDrops.pop().initialize();
  }
    
  private class Drop extends LXLayer {
    
    private final static double GRAVITY = -386;
    
    private final Accelerator accel = new Accelerator(model.yMax, 0, GRAVITY);
    
    private Rail rail;
    private boolean active = false;
    
    Drop(LX lx) {
      super(lx);
      addModulator(this.accel);
    }
    
    void initialize() {
      int railIndex = (int) Math.round(Math.random() * (Drops.this.model.rails.size()-1));
      this.rail = Drops.this.model.rails.get(railIndex);
      this.accel.trigger();
      this.active = true;
    }
    
    public void run(double deltaMs) {
      if (this.active) {
        for (LXPoint p : this.rail.points) {
          float b = 100 - (100 / 12*INCHES) * abs(p.y - this.accel.getValuef());
          if (b > 0) {
            addColor(p.index, palette.getColor(p, b));
          }
        }
        if (this.accel.getValue() < -12*INCHES) {
          this.active = false;
          availableDrops.push(this);
        }
      }
    }
  }
  
  @Override
  public void noteOnReceived(MidiNoteOn note) {
    triggerDrop();
  }
  
  public void run(double deltaMs) {
    setColors(0);
  }
}

public static class Flash extends LXPattern implements UIPattern {
  
  private final BooleanParameter manual =
    new BooleanParameter("Manual")
    .setMode(BooleanParameter.Mode.MOMENTARY)
    .setDescription("Manually triggers the flash");
  
  private final BooleanParameter midi =
    new BooleanParameter("MIDI", true)
    .setDescription("Toggles whether the flash is engaged by MIDI note events");
    
  private final CompoundParameter brightness =
    new CompoundParameter("Brt", 100, 0, 100)
    .setDescription("Sets the maxiumum brightness of the flash");
    
  private final CompoundParameter velocitySensitivity =
    new CompoundParameter("Vel>Brt", .5)
    .setDescription("Sets the amount to which brightness responds to note velocity");
    
  private final CompoundParameter attack = (CompoundParameter)
    new CompoundParameter("Attack", 50, 25, 1000)
    .setExponent(2)
    .setUnits(LXParameter.Units.MILLISECONDS)
    .setDescription("Sets the attack time of the flash");
    
  private final CompoundParameter decay = (CompoundParameter)
    new CompoundParameter("Decay", 1000, 50, 10000)
    .setExponent(2)
    .setUnits(LXParameter.Units.MILLISECONDS)
    .setDescription("Sets the decay time of the flash");
    
  private final CompoundParameter shape = (CompoundParameter)
    new CompoundParameter("Shape", 1, 1, 4)
    .setDescription("Sets the shape of the attack and decay curves");
  
  private final MutableParameter level = new MutableParameter(0);
  
  private final ADEnvelope env = new ADEnvelope("Env", 0, level, attack, decay, shape);
  
  private UIKnob velocityKnob;

  public Flash(LX lx) {
    super(lx);
    addModulator(env);
    addParameter("manual", manual);
    addParameter("midi", midi);
    addParameter("brightness", brightness);
    addParameter("attack", attack);
    addParameter("decay", decay);
    addParameter("shape", shape);
    addParameter("velocitySensitivity", velocitySensitivity);    
  }
  
  @Override
  public void onParameterChanged(LXParameter p) {
    if (p == this.midi) {
      if (this.velocityKnob != null) {
        this.velocityKnob.setEnabled(this.midi.isOn());
      }
    } else if (p == this.manual) {
      if (this.manual.isOn()) {
        level.setValue(brightness.getValue());
      }
      this.env.engage.setValue(this.manual.isOn());
    }
  }
  
  @Override
  public void noteOnReceived(MidiNoteOn note) {
    if (this.midi.isOn()) {
      level.setValue(brightness.getValue() * lerp(1, note.getVelocity() / 127., velocitySensitivity.getValuef()));
      this.env.engage.setValue(true);
    }
  }
  
  @Override
  public void noteOffReceived(MidiNote note) {
    if (this.midi.isOn()) {
      this.env.engage.setValue(false);
    }
  }
  
  public void run(double deltaMs) {
    for (LXPoint p : model.points) {
      colors[p.index] = palette.getColor(p, env.getValue());
    }
  }
    
  @Override
  public void buildDeviceUI(UI ui, UIPatternDevice device) {
    device.setContentWidth(216);
    new UIADWave(ui, 0, 0, device.getContentWidth(), 70).addToContainer(device);
    
    new UIButton(0, 72, 172, 16).setLabel("Manual Trigger").setParameter(this.manual).addToContainer(device);

    new UIKnob(0, 96).setParameter(this.brightness).addToContainer(device);
    new UIKnob(44, 96).setParameter(this.attack).addToContainer(device);
    new UIKnob(88, 96).setParameter(this.decay).addToContainer(device);
    new UIKnob(132, 96).setParameter(this.shape).addToContainer(device);
    
    new UIButton(176, 72, 40, 16).setParameter(this.midi).setLabel("Midi").addToContainer(device);
    velocityKnob = (UIKnob) new UIKnob(176, 96).setParameter(this.velocitySensitivity).setEnabled(this.midi.isOn()).addToContainer(device);
     
  }
  
  class UIADWave extends UI2dComponent {
    UIADWave(UI ui, float x, float y, float w, float h) {
      super(x, y, w, h);
      setBackgroundColor(ui.theme.getDarkBackgroundColor());
      setBorderColor(ui.theme.getControlBorderColor());

      LXParameterListener redraw = new LXParameterListener() {
        public void onParameterChanged(LXParameter p) {
          redraw();
        }
      };
      
      brightness.addListener(redraw);
      attack.addListener(redraw);
      decay.addListener(redraw);
      shape.addListener(redraw);
    }
    
    public void onDraw(UI ui, PGraphics pg) {
      double av = attack.getValue();
      double dv = decay.getValue();
      double tv = av + dv;
      double ax = av/tv * (this.width-1);
      double bv = brightness.getValue() / 100.;
      
      pg.stroke(ui.theme.getPrimaryColor());
      int py = 0;
      for (int x = 1; x < this.width-2; ++x) {
        int y = (x < ax) ?
          (int) Math.round(bv * (height-4.) * Math.pow(((x-1) / ax), shape.getValue())) :
          (int) Math.round(bv * (height-4.) * Math.pow(1 - ((x-ax) / (this.width-1-ax)), shape.getValue()));
        if (x > 1) {
          pg.line(x-1, height-2-py, x, height-2-y);
        }
        py = y;
      }
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

public class EnvelopObjects extends LXPattern implements UIPattern {
  
  public final BoundedParameter size = new BoundedParameter("Base", 4*FEET, 0, 24*FEET);
  public final BoundedParameter response = new BoundedParameter("Level", 0, 1*FEET, 24*FEET);
  
  public EnvelopObjects(LX lx) {
    super(lx);
    for (Envelop.Source.Channel object : envelop.source.channels) {
      addLayer(new Layer(lx, object));
    }
    addParameter(size);
    addParameter(response);
  }
  
  public void buildDeviceUI(UI ui, UIPatternDevice device) {
    int i = 0;
    for (LXLayer layer : getLayers()) {
      new UIButton((i % 4)*33, (i/4)*22, 28, 18).setLabel(Integer.toString(i+1)).setParameter(((Layer)layer).active).addToContainer(device);
      ++i;
    }
    int knobSpacing = UIKnob.WIDTH + 4;
    new UIKnob(0, 96).setParameter(size).addToContainer(device);
    new UIKnob(knobSpacing, 96).setParameter(response).addToContainer(device);

    device.setContentWidth(3*knobSpacing - 4);
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
  
  public final CompoundParameter xSpeed = (CompoundParameter)
    new CompoundParameter("XSpd", 0, -6, 6)
    .setPolarity(LXParameter.Polarity.BIPOLAR);
  
  public final CompoundParameter ySpeed = (CompoundParameter)
    new CompoundParameter("YSpd", 0, -6, 6)
    .setPolarity(LXParameter.Polarity.BIPOLAR);
  
  public final CompoundParameter zSpeed = (CompoundParameter)
    new CompoundParameter("ZSpd", 1, -6, 6)
    .setPolarity(LXParameter.Polarity.BIPOLAR);
  
  public final CompoundParameter floor = new CompoundParameter("Floor", 0, -2, 2);
  
  public final CompoundParameter range = new CompoundParameter("Range", 1, .2, 4);
  
  public final CompoundParameter xOffset = (CompoundParameter)
    new CompoundParameter("XOffs", 0, -1, 1)
    .setPolarity(LXParameter.Polarity.BIPOLAR);
  
  public final CompoundParameter yOffset = (CompoundParameter)
    new CompoundParameter("YOffs", 0, -1, 1)
    .setPolarity(LXParameter.Polarity.BIPOLAR);
  
  public final CompoundParameter zOffset = (CompoundParameter)
    new CompoundParameter("ZOffs", 0, -1, 1)
    .setPolarity(LXParameter.Polarity.BIPOLAR);
  
  public Noise(LX lx) {
    super(lx);
    addParameter("scale", scale);
    addParameter("floor", floor);
    addParameter("range", range);
    addParameter("xSpeed", xSpeed);
    addParameter("ySpeed", ySpeed);
    addParameter("zSpeed", zSpeed);
    addParameter("xOffset", xOffset);
    addParameter("yOffset", yOffset);
    addParameter("zOffset", zOffset);
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