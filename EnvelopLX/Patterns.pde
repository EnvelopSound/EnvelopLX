import heronarts.lx.modulator.*;
import java.util.Stack;

public static abstract class EnvelopPattern extends LXModelPattern<EnvelopModel> {
  
  protected EnvelopPattern(LX lx) {
    super(lx);
  }
}

@LXCategory("MIDI")
public class NotePattern extends EnvelopPattern {
  
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
    
  private final CompoundParameter size = new CompoundParameter("Size", .2)
    .setDescription("Sets the base size of notes");
    
  private final CompoundParameter pitchBendDepth = new CompoundParameter("BendAmt", 0.5)
    .setDescription("Controls the depth of modulation from the Pitch Bend wheel");
  
  private final CompoundParameter modBrightness = new CompoundParameter("Mod>Brt", 0)
    .setDescription("Sets the amount of LFO modulation to note brightness");
  
  private final CompoundParameter modSize = new CompoundParameter("Mod>Sz", 0)
    .setDescription("Sets the amount of LFO modulation to note size");
  
  private final CompoundParameter lfoRate = (CompoundParameter)
    new CompoundParameter("LFOSpd", 500, 1000, 100)
    .setExponent(2)
    .setDescription("Sets the rate of LFO modulation from the mod wheel");
  
  private final CompoundParameter velocityBrightness = new CompoundParameter("Vel>Brt", .5)
    .setDescription("Sets the amount of modulation from note velocity to brightness");
  
  private final CompoundParameter velocitySize = new CompoundParameter("Vel>Size", .5)
    .setDescription("Sets the amount of modulation from note velocity to size");
  
  private final CompoundParameter position = new CompoundParameter("Pos", .5)
    .setDescription("Sets the base position of middle C");
    
  private final CompoundParameter pitchDepth = new CompoundParameter("Note>Pos", 1, .1, 4)
    .setDescription("Sets the amount pitch modulates the position");
    
  private final DiscreteParameter soundObject = new DiscreteParameter("Object", 0, 17)
    .setDescription("Which sound object to follow");
  
  private final LXModulator lfo = startModulator(new SinLFO(0, 1, this.lfoRate));
  
  private float pitchBendValue = 0;
  private float modValue = 0;
  
  private final NoteLayer[] notes = new NoteLayer[128];
  
  public NotePattern(LX lx) {
    super(lx);
    for (int i = 0; i < notes.length; ++i) {
      addLayer(this.notes[i] = new NoteLayer(lx, i));
    }
    addParameter("attack", this.attack);
    addParameter("decay", this.decay);
    addParameter("size", this.size);
    addParameter("pitchBendDepth", this.pitchBendDepth);
    addParameter("velocityBrightness", this.velocityBrightness);
    addParameter("velocitySize", this.velocitySize);
    addParameter("modBrightness", this.modBrightness);
    addParameter("modSize", this.modSize);
    addParameter("lfoRate", this.lfoRate);
    addParameter("position", this.position);
    addParameter("pitchDepth", this.pitchDepth);
    addParameter("soundObject", this.soundObject);
  }
  
  protected class NoteLayer extends LXLayer {
    
    private final int pitch;
    
    private float velocity;
    
    private final MutableParameter level = new MutableParameter(0); 
    
    private final ADEnvelope envelope = new ADEnvelope("Env", 0, level, attack, decay);
    
    NoteLayer(LX lx, int pitch) {
      super(lx);
      this.pitch = pitch;
      addModulator(envelope);
    }
    
    public void run(double deltaMs) {
      float pos = position.getValuef() + pitchDepth.getValuef() * (this.pitch - 64) / 64.;
      float level = envelope.getValuef() * (1 - modValue * modBrightness.getValuef() * lfo.getValuef()); 
      if (level > 0) {        
        float yn = pos + pitchBendDepth.getValuef() * pitchBendValue;
        float sz =
          size.getValuef() +
          velocity * velocitySize.getValuef() +
          modValue * modSize.getValuef() * (lfo.getValuef() - .5); 
        
        Envelop.Source.Channel sourceChannel = null;
        int soundObjectIndex = soundObject.getValuei();
        if (soundObjectIndex > 0) {
          sourceChannel = envelop.source.channels[soundObjectIndex - 1];
        }
        
        float falloff = 50.f / sz;
        for (Rail rail : venue.rails) {
          float l2 = level;
          if (sourceChannel != null) {
            float l2fall = 100 / (20*FEET);
            l2 = level - l2fall * max(0, dist(sourceChannel.tx, sourceChannel.tz, rail.cx, rail.cz) - 2*FEET);
          } 
          for (LXPoint p : rail.points) {
            float b = l2 - falloff * abs(p.yn - yn);
            if (b > 0) {
              addColor(p.index, LXColor.gray(b));
            }
          }
        }
      }
    }
  }
  
  @Override
  public void noteOnReceived(MidiNoteOn note) {
    NoteLayer noteLayer = this.notes[note.getPitch()];
    noteLayer.velocity = note.getVelocity() / 127.;
    noteLayer.level.setValue(lerp(100.f, noteLayer.velocity * 100, this.velocityBrightness.getNormalizedf()));
    noteLayer.envelope.engage.setValue(true);
  }
  
  @Override
  public void noteOffReceived(MidiNote note) {
    this.notes[note.getPitch()].envelope.engage.setValue(false);
  }
  
  @Override
  public void pitchBendReceived(MidiPitchBend pb) {
    this.pitchBendValue = (float) pb.getNormalized();
  }
  
  @Override
  public void controlChangeReceived(MidiControlChange cc) {
    if (cc.getCC() == MidiControlChange.MOD_WHEEL) {
      this.modValue = (float) cc.getNormalized();
    }
  }
  
  public void run(double deltaMs) {
    setColors(#000000);
  }
}

public static abstract class RotationPattern extends EnvelopPattern {
  
  protected final CompoundParameter rate = (CompoundParameter)
  new CompoundParameter("Rate", .25, .01, 2)
    .setExponent(2)
    .setUnits(LXParameter.Units.HERTZ)
    .setDescription("Rate of the rotation");
    
  protected final SawLFO phase = new SawLFO(0, TWO_PI, new FunctionalParameter() {
    public double getValue() {
      return 1000 / rate.getValue();
    }
  });
  
  protected RotationPattern(LX lx) {
    super(lx);
    startModulator(this.phase);
    addParameter("rate", this.rate);
  }
}

@LXCategory("Form")
public static class Helix extends RotationPattern {
    
  private final CompoundParameter size = (CompoundParameter)
    new CompoundParameter("Size", 2*FEET, 6*INCHES, 8*FEET)
    .setDescription("Size of the corkskrew");
    
  private final CompoundParameter coil = (CompoundParameter)
    new CompoundParameter("Coil", 1, .25, 2.5)
    .setExponent(.5)
    .setDescription("Coil amount");
    
  private final DampedParameter dampedCoil = new DampedParameter(coil, .2);
  
  public Helix(LX lx) {
    super(lx);
    addParameter("size", this.size);
    addParameter("coil", this.coil);
    startModulator(dampedCoil);
    setColors(0);
  }
  
  public void run(double deltaMs) {
    float phaseV = this.phase.getValuef();
    float sizeV = this.size.getValuef();
    float falloff = 200 / sizeV;
    float coil = this.dampedCoil.getValuef();
    
    for (Rail rail : model.rails) {
      float yp = -sizeV + ((phaseV + (TWO_PI + PI + coil * rail.theta)) % TWO_PI) / TWO_PI * (model.yRange + 2*sizeV);
      float yp2 = -sizeV + ((phaseV + TWO_PI + coil * rail.theta) % TWO_PI) / TWO_PI * (model.yRange + 2*sizeV);
      for (LXPoint p : rail.points) {
        float d1 = 100 - falloff*abs(p.y - yp);
        float d2 = 100 - falloff*abs(p.y - yp2);
        float b = max(d1, d2);
        colors[p.index] = b > 0 ? LXColor.gray(b) : #000000;
      }
    }
  }
}

@LXCategory("Form")
public static class Warble extends RotationPattern {
  
  private final CompoundParameter size = (CompoundParameter)
    new CompoundParameter("Size", 2*FEET, 6*INCHES, 12*FEET)
    .setDescription("Size of the warble");
    
  private final CompoundParameter depth = (CompoundParameter)
    new CompoundParameter("Depth", .4, 0, 1)
    .setExponent(2)
    .setDescription("Depth of the modulation");
  
  private final CompoundParameter interp = 
    new CompoundParameter("Interp", 1, 1, 3)
    .setDescription("Interpolation on the warble");
    
  private final DampedParameter interpDamped = new DampedParameter(interp, .5, .5);
  private final DampedParameter depthDamped = new DampedParameter(depth, .4, .4);
    
  public Warble(LX lx) {
    super(lx);
    startModulator(this.interpDamped);
    startModulator(this.depthDamped);
    addParameter("size", this.size);
    addParameter("interp", this.interp);
    addParameter("depth", this.depth);
    setColors(0);
  }
  
  public void run(double deltaMs) {
    float phaseV = this.phase.getValuef();
    float interpV = this.interpDamped.getValuef();
    int mult = floor(interpV);
    float lerp = interpV % mult;
    float falloff = 200 / size.getValuef();
    float depth = this.depthDamped.getValuef();
    for (Rail rail : model.rails) {
      float y1 = model.yRange * depth * sin(phaseV + mult * rail.theta);
      float y2 = model.yRange * depth * sin(phaseV + (mult+1) * rail.theta);
      float yo = lerp(y1, y2, lerp);
      for (LXPoint p : rail.points) {
        colors[p.index] = LXColor.gray(max(0, 100 - falloff*abs(p.y - model.cy - yo)));
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

@LXCategory("Form")
public static class Raindrops extends EnvelopPattern {
  
  private static final float MAX_VEL = -180;
  
  private final Stack<Drop> availableDrops = new Stack<Drop>();
  
  public final CompoundParameter velocity = (CompoundParameter)
    new CompoundParameter("Velocity", 0, MAX_VEL)
    .setDescription("Initial velocity of drops");
    
  public final CompoundParameter randomVelocity = 
    new CompoundParameter("Rnd>Vel", 0, MAX_VEL)
    .setDescription("How much to randomize initial velocity of drops");
  
  public final CompoundParameter gravity = (CompoundParameter)
    new CompoundParameter("Gravity", -386, -1, -500)
    .setExponent(3)
    .setDescription("Gravity rate for drops to fall");
  
  public final CompoundParameter size = (CompoundParameter)
    new CompoundParameter("Size", 4*INCHES, 1*INCHES, 48*INCHES)
    .setExponent(2)
    .setDescription("Size of the raindrops");
    
  public final CompoundParameter randomSize = (CompoundParameter)
    new CompoundParameter("Rnd>Sz", 1*INCHES, 0, 48*INCHES)
    .setExponent(2)
    .setDescription("Amount of size randomization");    
  
  public final CompoundParameter negative =
    new CompoundParameter("Negative", 0)
    .setDescription("Whether drops are light or dark");
  
  public final BooleanParameter reverse =
    new BooleanParameter("Reverse", false)
    .setDescription("Whether drops fall from the ground to the sky");
  
  public final BooleanParameter auto =
    new BooleanParameter("Auto", false)
    .setDescription("Whether drops automatically fall");  
  
  public final CompoundParameter rate =
    new CompoundParameter("Rate", .5, 30)
    .setDescription("Rate at which new drops automatically fall");

  private final Click click = new Click("click", new FunctionalParameter() {
    public double getValue() {
      return 1000 / rate.getValue();
    }
  });

  public Raindrops(LX lx) {
    super(lx);
    addParameter("velocity", this.velocity);
    addParameter("randomVelocity", this.randomVelocity);
    addParameter("gravity", this.gravity);
    addParameter("size", this.size);
    addParameter("randomSize", this.randomSize);
    addParameter("negative", this.negative);
    addParameter("auto", this.auto);
    addParameter("rate", this.rate);
    addParameter("reverse", this.reverse);
    startModulator(click);
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
        
    private final Accelerator accel = new Accelerator(model.yMax, velocity, gravity);
    private float random;
    
    private Rail rail;
    private boolean active = false;
    
    Drop(LX lx) {
      super(lx);
      addModulator(this.accel);
    }
    
    void initialize() {
      int railIndex = (int) Math.round(Math.random() * (Raindrops.this.model.rails.size()-1));
      this.rail = Raindrops.this.model.rails.get(railIndex);
      this.random = (float) Math.random();
      this.accel.reset();
      this.accel.setVelocity(this.accel.getVelocity() + Math.random() * randomVelocity.getValue());
      this.accel.setValue(model.yMax + size.getValuef() + this.random * randomSize.getValuef()).start();
      this.active = true;
    }
    
    public void run(double deltaMs) {
      if (this.active) {
        float len = size.getValuef() + this.random * randomSize.getValuef();
        float falloff = 100 / len;
        float accel = this.accel.getValuef();
        float pos = reverse.isOn() ? (model.yMin + model.yMax - accel) : accel; 
        for (LXPoint p : this.rail.points) {
          float b = 100 - falloff * abs(p.y - pos);
          if (b > 0) {
            addColor(p.index, LXColor.gray(b));
          }
        }
        if (accel < -len) {
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
    setColors(#000000);
    if (this.click.click() && this.auto.isOn()) {
      triggerDrop();
    }
  }
  
  public void afterLayers(double deltaMs) {
    float neg = this.negative.getValuef();
    if (neg > 0) {
      for (LXPoint p : model.railPoints) {
        colors[p.index] = LXColor.lerp(colors[p.index], LXColor.subtract(#ffffff, colors[p.index]), neg);
      }
    }
  }
  
  public void buildDeviceUI(UI ui, UI2dContainer device) {
    device.setLayout(UI2dContainer.Layout.VERTICAL);
    device.setChildMargin(6);
    new UIKnob(this.velocity).addToContainer(device);
    new UIKnob(this.gravity).addToContainer(device);
    new UIKnob(this.size).addToContainer(device);
    new UIDoubleBox(0, 0, device.getContentWidth(), 16)
      .setParameter(this.randomVelocity)
      .addToContainer(device);
    new UIButton(0, 0, device.getContentWidth(), 16)
      .setParameter(this.auto)
      .setLabel("Auto")
      .addToContainer(device);
    new UIDoubleBox(0, 0, device.getContentWidth(), 16)
      .setParameter(this.rate)
      .addToContainer(device);      
  }
}

@LXCategory("MIDI")
public static class Flash extends LXPattern implements CustomDeviceUI {
  
  private final BooleanParameter manual =
    new BooleanParameter("Trigger")
    .setMode(BooleanParameter.Mode.MOMENTARY)
    .setDescription("Manually triggers the flash");
  
  private final BooleanParameter midi =
    new BooleanParameter("MIDI", true)
    .setDescription("Toggles whether the flash is engaged by MIDI note events");
    
  private final BooleanParameter midiFilter =
    new BooleanParameter("Note Filter")
    .setDescription("Whether to filter specific MIDI note");
    
  private final DiscreteParameter midiNote = (DiscreteParameter)
    new DiscreteParameter("Note", 0, 128)
    .setUnits(LXParameter.Units.MIDI_NOTE)
    .setDescription("Note to filter for");
    
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
  
  public Flash(LX lx) {
    super(lx);
    addModulator(this.env);
    addParameter("brightness", this.brightness);
    addParameter("attack", this.attack);
    addParameter("decay", this.decay);
    addParameter("shape", this.shape);
    addParameter("velocitySensitivity", this.velocitySensitivity);
    addParameter("manual", this.manual);
    addParameter("midi", this.midi);
    addParameter("midiFilter", this.midiFilter);
    addParameter("midiNote", this.midiNote);    
  }
  
  @Override
  public void onParameterChanged(LXParameter p) {
    if (p == this.manual) {
      if (this.manual.isOn()) {
        level.setValue(brightness.getValue());
      }
      this.env.engage.setValue(this.manual.isOn());
    }
  }
  
  private boolean isValidNote(MidiNote note) {
    return this.midi.isOn() && (!this.midiFilter.isOn() || (note.getPitch() == this.midiNote.getValuei()));
  }
  
  @Override
  public void noteOnReceived(MidiNoteOn note) {
    if (isValidNote(note)) {
      level.setValue(brightness.getValue() * lerp(1, note.getVelocity() / 127., velocitySensitivity.getValuef()));
      this.env.engage.setValue(true);
    }
  }
  
  @Override
  public void noteOffReceived(MidiNote note) {
    if (isValidNote(note)) {
      this.env.engage.setValue(false);
    }
  }
  
  public void run(double deltaMs) {
    setColors(LXColor.gray(env.getValue()));
  }
    
  @Override
  public void buildDeviceUI(UI ui, UI2dContainer device) {
    device.setContentWidth(216);
    new UIADWave(ui, 0, 0, device.getContentWidth(), 90).addToContainer(device);
    
    new UIButton(0, 92, 84, 16).setLabel("Trigger").setParameter(this.manual).setTriggerable(true).addToContainer(device);

    new UIButton(88, 92, 40, 16).setParameter(this.midi).setLabel("Midi").addToContainer(device);
    
    final UIButton midiFilterButton = (UIButton)
      new UIButton(132, 92, 40, 16)
      .setParameter(this.midiFilter)
      .setLabel("Note")
      .setEnabled(this.midi.isOn())
      .addToContainer(device);
      
    final UIIntegerBox midiNoteBox = (UIIntegerBox)
      new UIIntegerBox(176, 92, 40, 16)
      .setParameter(this.midiNote)
      .setEnabled(this.midi.isOn() && this.midiFilter.isOn())
      .addToContainer(device);

    new UIKnob(0, 116).setParameter(this.brightness).addToContainer(device);
    new UIKnob(44, 116).setParameter(this.attack).addToContainer(device);
    new UIKnob(88, 116).setParameter(this.decay).addToContainer(device);
    new UIKnob(132, 116).setParameter(this.shape).addToContainer(device);

    final UIKnob velocityKnob = (UIKnob)
      new UIKnob(176, 116)
      .setParameter(this.velocitySensitivity)
      .setEnabled(this.midi.isOn())
      .addToContainer(device);
    
    this.midi.addListener(new LXParameterListener() {
      public void onParameterChanged(LXParameter p) {
        velocityKnob.setEnabled(midi.isOn());
        midiFilterButton.setEnabled(midi.isOn());
        midiNoteBox.setEnabled(midi.isOn() && midiFilter.isOn());
      }
    }); 
    
    this.midiFilter.addListener(new LXParameterListener() {
      public void onParameterChanged(LXParameter p) {
        midiNoteBox.setEnabled(midi.isOn() && midiFilter.isOn());
      }
    });
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

@LXCategory("Envelop")
public class EnvelopDecode extends EnvelopPattern {
  
  public final CompoundParameter mode = new CompoundParameter("Mode", 0);
  public final CompoundParameter fade = new CompoundParameter("Fade", 1*FEET, 0.001, 6*FEET);
  public final CompoundParameter damping = (CompoundParameter)
    new CompoundParameter("Damping", 10, 10, .1)
    .setExponent(.25);
    
  private final DampedParameter[] dampedDecode = new DampedParameter[envelop.decode.channels.length]; 
  
  public EnvelopDecode(LX lx) {
    super(lx);
    addParameter("mode", mode);
    addParameter("fade", fade);
    addParameter("damping", damping);
    int d = 0;
    for (LXParameter parameter : envelop.decode.channels) {
      startModulator(dampedDecode[d++] = new DampedParameter(parameter, damping));
    }
  }
  
  public void run(double deltaMs) {
    float fv = fade.getValuef();
    float falloff = 100 / fv;
    float mode = this.mode.getValuef();
    float faden = fade.getNormalizedf();
    for (Column column : venue.columns) {
      float levelf = this.dampedDecode[column.index].getValuef();
      float level = levelf * (model.yRange / 2.);
      for (Rail rail : column.rails) {
        for (LXPoint p : rail.points) {
          float yn = abs(p.y - model.cy);
          float b0 = constrain(falloff * (level - yn), 0, 100);
          float b1max = lerp(100, 100*levelf, faden);
          float b1 = (yn > level) ? max(0, b1max - 80*(yn-level)) : lerp(0, b1max, yn / level); 
          colors[p.index] = LXColor.gray(lerp(b0, b1, mode));
        }
      }
    }
  }
}

@LXCategory("Envelop")
public class EnvelopObjects extends EnvelopPattern implements CustomDeviceUI {
  
  public final CompoundParameter size = new CompoundParameter("Base", 4*FEET, 0, 24*FEET);
  public final BoundedParameter response = new BoundedParameter("Level", 0, 1*FEET, 24*FEET);
  public final CompoundParameter spread = new CompoundParameter("Spread", 1, 1, .2); 
  
  public EnvelopObjects(LX lx) {
    super(lx);
    addParameter("size", this.size);
    addParameter("response", this.response);
    addParameter("spread", this.spread);
    for (Envelop.Source.Channel object : envelop.source.channels) {
      Layer layer = new Layer(lx, object);
      addLayer(layer);
      addParameter("active-" + object.index, layer.active);
    }
  }
  
  public void buildDeviceUI(UI ui, UI2dContainer device) {
    int i = 0;
    for (LXLayer layer : getLayers()) {
      new UIButton((i % 4)*33, (i/4)*28, 28, 24)
      .setLabel(Integer.toString(i+1))
      .setParameter(((Layer)layer).active)
      .setTextAlignment(PConstants.CENTER, PConstants.CENTER)
      .addToContainer(device);
      ++i;
    }
    int knobSpacing = UIKnob.WIDTH + 4;
    new UIKnob(0, 116).setParameter(this.size).addToContainer(device);
    new UIKnob(knobSpacing, 116).setParameter(this.response).addToContainer(device);
    new UIKnob(2*knobSpacing, 116).setParameter(this.spread).addToContainer(device);

    device.setContentWidth(3*knobSpacing - 4);
  }
  
  class Layer extends LXModelLayer<EnvelopModel> {
    
    private final Envelop.Source.Channel object;
    private final BooleanParameter active = new BooleanParameter("Active", true); 
    
    private final MutableParameter tx = new MutableParameter();
    private final MutableParameter ty = new MutableParameter();
    private final MutableParameter tz = new MutableParameter();
    private final DampedParameter x = new DampedParameter(this.tx, 50*FEET);
    private final DampedParameter y = new DampedParameter(this.ty, 50*FEET);
    private final DampedParameter z = new DampedParameter(this.tz, 50*FEET);
    
    Layer(LX lx, Envelop.Source.Channel object) {
      super(lx);
      this.object = object;
      startModulator(this.x);
      startModulator(this.y);
      startModulator(this.z);
    }
    
    public void run(double deltaMs) {
      if (!this.active.isOn()) {
        return;
      }
      this.tx.setValue(object.tx);
      this.ty.setValue(object.ty);
      this.tz.setValue(object.tz);
      if (object.active) {
        float x = this.x.getValuef();
        float y = this.y.getValuef();
        float z = this.z.getValuef();
        float spreadf = spread.getValuef();
        float falloff = 100 / (size.getValuef() + response.getValuef() * object.getValuef());
        for (LXPoint p : model.railPoints) {
          float dist = dist(p.x * spreadf, p.y, p.z * spreadf, x * spreadf, y, z * spreadf);
          float b = 100 - dist*falloff;
          if (b > 0) {
            addColor(p.index, LXColor.gray(b));
          }
        }
      }
    }
  }
  
  public void run(double deltaMs) {
    setColors(LXColor.BLACK);
  }
}

@LXCategory("Form")
public class Bouncing extends LXPattern {
  
  public CompoundParameter gravity = (CompoundParameter)
    new CompoundParameter("Gravity", -200, -10, -400)
    .setExponent(2)
    .setDescription("Gravity factor");
  
  public CompoundParameter size =
    new CompoundParameter("Length", 2*FEET, 1*FEET, 8*FEET)
    .setDescription("Length of the bouncers");
  
  public CompoundParameter amp =
    new CompoundParameter("Height", model.yRange, 1*FEET, model.yRange)
    .setDescription("Height of the bounce");
  
  public Bouncing(LX lx) {
    super(lx);
    addParameter("gravity", this.gravity);
    addParameter("size", this.size);
    addParameter("amp", this.amp);
    for (Column column : venue.columns) {
      addLayer(new Bouncer(lx, column));
    }
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
            addColor(p.index, LXColor.gray(b));
          }
        }
      }
    }
  }
    
  public void run(double deltaMs) {
    setColors(LXColor.BLACK);
  }
}

@LXCategory("Form")
public class Tron extends LXPattern {
  
  private final static int MIN_DENSITY = 5;
  private final static int MAX_DENSITY = 80;
  
  private CompoundParameter period = (CompoundParameter)
    new CompoundParameter("Speed", 150000, 400000, 50000)
    .setExponent(.5)
    .setDescription("Speed of movement");
    
  private CompoundParameter size = (CompoundParameter)
    new CompoundParameter("Size", 2*FEET, 6*INCHES, 5*FEET)
    .setExponent(2)
    .setDescription("Size of strips");
    
  private CompoundParameter density = (CompoundParameter)
    new CompoundParameter("Density", 25, MIN_DENSITY, MAX_DENSITY)
    .setDescription("Density of tron strips");
    
  public Tron(LX lx) {  
    super(lx);
    addParameter("period", this.period);
    addParameter("size", this.size);
    addParameter("density", this.density);    
    for (int i = 0; i < MAX_DENSITY; ++i) {
      addLayer(new Mover(lx, i));
    }
  }
  
  class Mover extends LXLayer {
    
    final int index;
    
    final TriangleLFO pos = new TriangleLFO(0, lx.total, period);
    
    private final MutableParameter targetBrightness = new MutableParameter(100); 
    
    private final DampedParameter brightness = new DampedParameter(this.targetBrightness, 50); 
    
    Mover(LX lx, int index) {
      super(lx);
      this.index = index;
      startModulator(this.brightness);
      startModulator(this.pos.randomBasis());
    }
    
    public void run(double deltaMs) {
      this.targetBrightness.setValue((density.getValuef() > this.index) ? 100 : 0);
      float maxb = this.brightness.getValuef();
      if (maxb > 0) {
        float pos = this.pos.getValuef();
        float falloff = maxb / size.getValuef();
        for (LXPoint p : model.points) {
          float b = maxb - falloff * LXUtils.wrapdistf(p.index, pos, model.points.length);
          if (b > 0) {
            addColor(p.index, LXColor.gray(b));
          }
        }
      }
    }
  }
  
  public void run(double deltaMs) {
    setColors(#000000);
  }
}

@LXCategory("MIDI")
public class Blips extends EnvelopPattern {
  
  public final CompoundParameter speed = new CompoundParameter("Speed", 500, 4000, 250); 
  
  final Stack<Blip> available = new Stack<Blip>();
    
  public Blips(LX lx) {
    super(lx);
    addParameter("speed", this.speed);
  }
  
  class Blip extends LXModelLayer<EnvelopModel> {
    
    public final LinearEnvelope dist = new LinearEnvelope(0, model.yRange, new FunctionalParameter() {
      public double getValue() {
        return speed.getValue() * lerp(1, .6, velocity);
      }
    });

    private float yStart;
    private int column;
    private boolean active = false;
    private float velocity = 0;

    public Blip(LX lx) {
      super(lx);
      addModulator(this.dist);
    }
    
    public void trigger(MidiNoteOn note) {
      this.velocity = note.getVelocity() / 127.;
      this.column = note.getPitch() % venue.columns.size();
      this.yStart = venue.cy + random(-2*FEET, 2*FEET); 
      this.dist.trigger();
      this.active = true;
    }
    
    public void run(double deltaMs) {
      if (!this.active) {
        return;
      }
      boolean touched = false;
      float dist = this.dist.getValuef();
      float falloff = 100 / (1*FEET);
      float level = lerp(50, 100, this.velocity);
      for (LXPoint p : venue.columns.get(this.column).railPoints) {
        float b = level - falloff * abs(abs(p.y - this.yStart) - dist);
        if (b > 0) {
          touched = true;
          addColor(p.index, LXColor.gray(b));
        }
      }
      if (!touched) {
        this.active = false;
        available.push(this);
      }
    }
  }
  
  @Override
  public void noteOnReceived(MidiNoteOn note) {
    // TODO(mcslee): hack to not fight with flash
    if (note.getPitch() == 72) {
      return;
    }
    
    Blip blip;
    if (available.empty()) {
      addLayer(blip = new Blip(lx));
    } else {
      blip = available.pop();
    }
    blip.trigger(note);
  }
  
  public void run(double deltaMs) {
    setColors(#000000);
  }
}

@LXCategory("Texture")
public class Noise extends LXPattern {
  
  public final CompoundParameter scale =
    new CompoundParameter("Scale", 10, 5, 40);
    
  private final LXParameter scaleDamped =
    startModulator(new DampedParameter(this.scale, 5, 10)); 
  
  public final CompoundParameter floor =
    new CompoundParameter("Floor", 0, -2, 2)
    .setDescription("Lower bound of the noise");
    
  private final LXParameter floorDamped =
    startModulator(new DampedParameter(this.floor, .5, 2));    
  
  public final CompoundParameter range =
    new CompoundParameter("Range", 1, .2, 4)
    .setDescription("Range of the noise");
  
  private final LXParameter rangeDamped =
    startModulator(new DampedParameter(this.range, .5, 4));
  
  public final CompoundParameter xSpeed = (CompoundParameter)
    new CompoundParameter("XSpd", 0, -6, 6)
    .setDescription("Rate of motion on the X-axis")
    .setPolarity(LXParameter.Polarity.BIPOLAR);
  
  public final CompoundParameter ySpeed = (CompoundParameter)
    new CompoundParameter("YSpd", 0, -6, 6)
    .setDescription("Rate of motion on the Y-axis")
    .setPolarity(LXParameter.Polarity.BIPOLAR);
  
  public final CompoundParameter zSpeed = (CompoundParameter)
    new CompoundParameter("ZSpd", 1, -6, 6)
    .setDescription("Rate of motion on the Z-axis")
    .setPolarity(LXParameter.Polarity.BIPOLAR);
  
  public final CompoundParameter xOffset = (CompoundParameter)
    new CompoundParameter("XOffs", 0, -1, 1)
    .setDescription("Offset of symmetry on the X-axis")
    .setPolarity(LXParameter.Polarity.BIPOLAR);
  
  public final CompoundParameter yOffset = (CompoundParameter)
    new CompoundParameter("YOffs", 0, -1, 1)
    .setDescription("Offset of symmetry on the Y-axis")
    .setPolarity(LXParameter.Polarity.BIPOLAR);
  
  public final CompoundParameter zOffset = (CompoundParameter)
    new CompoundParameter("ZOffs", 0, -1, 1)
    .setDescription("Offset of symmetry on the Z-axis")
    .setPolarity(LXParameter.Polarity.BIPOLAR);
  
  public Noise(LX lx) {
    super(lx);
    addParameter("scale", this.scale);
    addParameter("floor", this.floor);
    addParameter("range", this.range);
    addParameter("xSpeed", this.xSpeed);
    addParameter("ySpeed", this.ySpeed);
    addParameter("zSpeed", this.zSpeed);
    addParameter("xOffset", this.xOffset);
    addParameter("yOffset", this.yOffset);
    addParameter("zOffset", this.zOffset);
  }
  
  private class Accum {
    private float accum = 0;
    private int equalCount = 0;
    
    void accum(double deltaMs, float speed) {
      if (speed != 0) {
        float newAccum = (float) (this.accum + deltaMs * speed * 0.00025);
        if (newAccum == this.accum) {
          if (++this.equalCount >= 5) {
            this.equalCount = 0;
            newAccum = 0;
          }
        }
        this.accum = newAccum;
      }
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
    
    float sf = scaleDamped.getValuef() / 1000.;
    float rf = rangeDamped.getValuef();
    float ff = floorDamped.getValuef();
    float xo = xOffset.getValuef();
    float yo = yOffset.getValuef();
    float zo = zOffset.getValuef();
    for (LXPoint p :  model.points) {
      float b = ff + rf * noise(sf*p.x + xo - xAccum.accum, sf*p.y + yo - yAccum.accum, sf*p.z + zo - zAccum.accum);
      colors[p.index] = LXColor.gray(constrain(b*100, 0, 100));
    }
  }
}

@LXCategory("Envelop")
public class EnvelopShimmer extends EnvelopPattern {
  
  private final int BUFFER_SIZE = 512; 
  private final float[][] buffer = new float[model.columns.size()][BUFFER_SIZE];
  private int bufferPos = 0;
  
  public final CompoundParameter interp = new CompoundParameter("Mode", 0); 
  
  public final CompoundParameter speed = (CompoundParameter)
    new CompoundParameter("Speed", 1, 5, .1)
    .setDescription("Speed of the sound waves emanating from the speakers");
    
    public final CompoundParameter taper = (CompoundParameter)
    new CompoundParameter("Taper", 1, 0, 10)
    .setExponent(2)
    .setDescription("Amount of tapering applied to the signal");
  
  private final DampedParameter speedDamped = new DampedParameter(speed, 1);
  
  public EnvelopShimmer(LX lx) {
    super(lx);
    addParameter("intern", interp);
    addParameter("speed", speed);
    addParameter("taper", taper);
    startModulator(speedDamped);
    for (float[] buffer : this.buffer) {
      for (int i = 0; i < buffer.length; ++i) {
        buffer[i] = 0;
      }
    }
  }
  
  public void run(double deltaMs) {
    float speed = this.speedDamped.getValuef();
    float interp = this.interp.getValuef();
    float taper = this.taper.getValuef() * lerp(3, 1, interp); 
    for (Column column : model.columns) {
      float[] buffer = this.buffer[column.index];
      buffer[this.bufferPos] = envelop.decode.channels[column.index].getValuef();
      for (Rail rail : column.rails) {
        for (int i = 0; i < rail.points.length; ++i) {
          LXPoint p = rail.points[i];
          int i3 = i % (rail.points.length/3);
          float td = abs(i3 - rail.points.length / 6);
          float threeWay = getValue(buffer, speed * td);
          float nd = abs(i - rail.points.length / 2);
          float normal = getValue(buffer, speed * nd);
          float bufferValue = lerp(threeWay, normal, interp);
          float d = lerp(td, nd, interp);
          colors[p.index] = LXColor.gray(max(0, 100 * bufferValue - d*taper));
        }
      }      
    }
    --bufferPos;
    if (bufferPos < 0) {
      bufferPos = BUFFER_SIZE - 1;
    }
  }
  
  private float getValue(float[] buffer, float bufferOffset) {
    int offsetFloor = (int) bufferOffset;
    int bufferTarget1 = (bufferPos + offsetFloor) % BUFFER_SIZE;
    int bufferTarget2 = (bufferPos + offsetFloor + 1) % BUFFER_SIZE;
    return lerp(buffer[bufferTarget1], buffer[bufferTarget2], bufferOffset - offsetFloor);
  }
}

@LXCategory("Form")
public static class Rings extends EnvelopPattern {
  
  public final CompoundParameter amplitude =
    new CompoundParameter("Amplitude", 1);
    
  public final CompoundParameter speed = (CompoundParameter)
    new CompoundParameter("Speed", 10000, 20000, 1000)
    .setExponent(.25);
  
  public Rings(LX lx) {
    super(lx);
    for (int i = 0; i < 2; ++i) {
      addLayer(new Ring(lx));
    }
    addParameter("amplitude", this.amplitude);
    addParameter("speed", this.speed);
  }
  
  public void run(double deltaMs) {
    setColors(#000000);
  }
  
  class Ring extends LXLayer {
    
    private LXProjection proj = new LXProjection(model);
    private final SawLFO yRot = new SawLFO(0, TWO_PI, 9000 + 2000 * Math.random());
    private final SinLFO zRot = new SinLFO(-1, 1, speed);
    private final SinLFO zAmp = new SinLFO(PI / 10, PI/4, 13000 + 3000 * Math.random());
    private final SinLFO yOffset = new SinLFO(-2*FEET, 2*FEET, 12000 + 5000*Math.random());
    
    public Ring(LX lx) {
      super(lx);
      startModulator(yRot.randomBasis());
      startModulator(zRot.randomBasis());
      startModulator(zAmp.randomBasis());
      startModulator(yOffset.randomBasis());
    }
    
    public void run(double deltaMs) {
      proj.reset().center().rotateY(yRot.getValuef()).rotateZ(amplitude.getValuef() * zAmp.getValuef() * zRot.getValuef());
      float yOffset = this.yOffset.getValuef();
      float falloff = 100 / (2*FEET);
      for (LXVector v : proj) {
        float b = 100 - falloff * abs(v.y - yOffset);  
        if (b > 0) {
          addColor(v.index, LXColor.gray(b));
        }
      }
    }
  }
}

@LXCategory("Texture")
public static final class Swarm extends EnvelopPattern {
  
  private static final double MIN_PERIOD = 200;
  
  public final CompoundParameter chunkSize =
    new CompoundParameter("Chunk", 10, 5, 20)
    .setDescription("Size of the swarm chunks");
  
  private final LXParameter chunkDamped = startModulator(new DampedParameter(this.chunkSize, 5, 5));
  
  public final CompoundParameter speed =
    new CompoundParameter("Speed", .5, .01, 1)
    .setDescription("Speed of the swarm motion");
    
  public final CompoundParameter oscillation =
    new CompoundParameter("Osc", 0)
    .setDescription("Amoount of oscillation of the swarm speed");
  
  private final FunctionalParameter minPeriod = new FunctionalParameter() {
    public double getValue() {
      return MIN_PERIOD / speed.getValue();
    }
  };
  
  private final FunctionalParameter maxPeriod = new FunctionalParameter() {
    public double getValue() {
      return MIN_PERIOD / (speed.getValue() + oscillation.getValue());
    }
  };
  
  private final SawLFO pos = new SawLFO(0, 1, startModulator(
    new SinLFO(minPeriod, maxPeriod, startModulator(
      new SinLFO(9000, 23000, 49000).randomBasis()
  )).randomBasis()));
  
  private final SinLFO swarmA = new SinLFO(0, 4*PI, startModulator(
    new SinLFO(37000, 79000, 51000)
  ));
  
  private final SinLFO swarmY = new SinLFO(
    startModulator(new SinLFO(model.yMin, model.cy, 19000).randomBasis()),
    startModulator(new SinLFO(model.cy, model.yMax, 23000).randomBasis()),
    startModulator(new SinLFO(14000, 37000, 19000))
  );
  
  private final SinLFO swarmSize = new SinLFO(.6, 1, startModulator(
    new SinLFO(7000, 19000, 11000)
  ));
  
  public final CompoundParameter size =
    new CompoundParameter("Size", 1, 2, .5)
    .setDescription("Size of the overall swarm");
  
  public Swarm(LX lx) {
    super(lx);
    addParameter("chunk", this.chunkSize);
    addParameter("size", this.size);
    addParameter("speed", this.speed);
    addParameter("oscillation", this.oscillation);
    startModulator(this.pos.randomBasis());
    startModulator(this.swarmA);
    startModulator(this.swarmY);
    startModulator(this.swarmSize);
    setColors(#000000);
  }
 
  public void run(double deltaMs) {
    float chunkSize = this.chunkDamped.getValuef();
    float pos = this.pos.getValuef();
    float swarmA = this.swarmA.getValuef();
    float swarmY = this.swarmY.getValuef();
    float swarmSize = this.swarmSize.getValuef() * this.size.getValuef();
    
    for (Column column : model.columns) {
      int ri = 0;
      for (Rail rail : column.rails) {
        for (int i = 0; i < rail.points.length; ++i) {
          LXPoint p = rail.points[i];
          float f = (i % chunkSize) / chunkSize;
          if ((column.index + ri) % 3 == 2) {
            f = 1-f;
          }
          float fd = 40*LXUtils.wrapdistf(column.azimuth, swarmA, TWO_PI) + abs(p.y - swarmY);
          fd *= swarmSize;
          colors[p.index] = LXColor.gray(max(0, 100 - fd - (100 + fd) * LXUtils.wrapdistf(f, pos, 1)));
        }
        ++ri;
      }
    }
  }
}

@LXCategory("MIDI")
public class ColumnNotes extends EnvelopPattern {
  
  private final ColumnLayer[] columns = new ColumnLayer[model.columns.size()]; 
  
  public ColumnNotes(LX lx) {
    super(lx);
    for (Column column : model.columns) {
      int c = column.index;
      addLayer(columns[c] = new ColumnLayer(lx, column));
      addParameter("attack-" + c, columns[c].attack);
      addParameter("decay-" + c, columns[c].decay);
    }
  }
  
  @Override
  public void noteOnReceived(MidiNoteOn note) {
    int channel = note.getChannel();
    if (channel < this.columns.length) {
      this.columns[channel].envelope.engage.setValue(true);
    }
  }
  
  @Override
  public void noteOffReceived(MidiNote note) {
    int channel = note.getChannel();
    if (channel < this.columns.length) {
      this.columns[channel].envelope.engage.setValue(false);
    }
  }
  
  private class ColumnLayer extends LXLayer {
    
    private final CompoundParameter attack;
    private final CompoundParameter decay;
    private final ADEnvelope envelope;
    
    private final Column column;
    
    private final LXModulator vibrato = startModulator(new SinLFO(.8, 1, 400));
    
    public ColumnLayer(LX lx, Column column) {
      super(lx);
      this.column = column;
      
      this.attack = (CompoundParameter)
        new CompoundParameter("Atk-" + column.index, 50, 25, 2000)
        .setExponent(4)
        .setUnits(LXParameter.Units.MILLISECONDS)
        .setDescription("Sets the attack time of the flash");
    
      this.decay = (CompoundParameter)
        new CompoundParameter("Dcy-" + column.index, 1000, 50, 2000)
        .setExponent(4)
        .setUnits(LXParameter.Units.MILLISECONDS)
        .setDescription("Sets the decay time of the flash");
    
      this.envelope = new ADEnvelope("Env", 0, new FixedParameter(100), attack, decay);

      addModulator(this.envelope);
    }
    
    public void run(double deltaMs) {
      float level = this.vibrato.getValuef() * this.envelope.getValuef();
      for (LXPoint p : column.points) {
        colors[p.index] = LXColor.gray(level);
      }
    }
  }
  
  public void run(double deltaMs) {
    setColors(#000000);
  }
}

@LXCategory(LXCategory.TEXTURE)
public class Sparkle extends LXPattern {
  
  public final SinLFO[] sparkles = new SinLFO[60]; 
  private final int[] map = new int[model.size];
  
  public Sparkle(LX lx) {
    super(lx);
    for (int i = 0; i < this.sparkles.length; ++i) {
      this.sparkles[i] = (SinLFO) startModulator(new SinLFO(0, random(50, 120), random(2000, 7000)));
    }
    for (int i = 0; i < model.size; ++i) {
      this.map[i] = (int) constrain(random(0, sparkles.length), 0, sparkles.length-1);
    }
  }
  
  public void run(double deltaMs) {
    for (LXPoint p : model.points) {
      colors[p.index] = LXColor.gray(constrain(this.sparkles[this.map[p.index]].getValuef(), 0, 100));
    }
  }
}

@LXCategory(LXCategory.TEXTURE)
public class Starlight extends LXPattern {
  
  public final CompoundParameter speed = new CompoundParameter("Speed", 1, 2, .5);
  public final CompoundParameter base = new CompoundParameter("Base", -10, -20, 100);
  
  public final LXModulator[] brt = new LXModulator[50];
  private final int[] map1 = new int[model.size];
  private final int[] map2 = new int[model.size];
  
  public Starlight(LX lx) {
    super(lx);
    for (int i = 0; i < this.brt.length; ++i) {
      this.brt[i] = startModulator(new SinLFO(this.base, random(50, 120), new FunctionalParameter() {
        private final float rand = random(1000, 5000);
        public double getValue() {
          return rand * speed.getValuef();
        }
      }).randomBasis());
    }
    for (int i = 0; i < model.size; ++i) {
      this.map1[i] = (int) constrain(random(0, this.brt.length), 0, this.brt.length-1);
      this.map2[i] = (int) constrain(random(0, this.brt.length), 0, this.brt.length-1);
    }
    addParameter("speed", this.speed);
    addParameter("base", this.base);
  }
  
  public void run(double deltaMs) {
    for (LXPoint p : model.points) {
      int i = p.index;
      float brt = this.brt[this.map1[i]].getValuef() + this.brt[this.map2[i]].getValuef(); 
      colors[i] = LXColor.gray(constrain(.5*brt, 0, 100));
    }
  }
}

@LXCategory(LXCategory.TEXTURE)
public class Jitters extends LXModelPattern<EnvelopModel> {
  
  public final CompoundParameter period = (CompoundParameter)
    new CompoundParameter("Period", 200, 2000, 50)
    .setExponent(.5)
    .setDescription("Speed of the motion");
    
  public final CompoundParameter size =
    new CompoundParameter("Size", 8, 3, 20)
    .setDescription("Size of the movers");
    
  public final CompoundParameter contrast =
    new CompoundParameter("Contrast", 100, 50, 300)
    .setDescription("Amount of contrast");    
  
  final LXModulator pos = startModulator(new SawLFO(0, 1, period));
  
  final LXModulator sizeDamped = startModulator(new DampedParameter(size, 30));
  
  public Jitters(LX lx) {
    super(lx);
    addParameter("period", this.period);
    addParameter("size", this.size);
    addParameter("contrast", this.contrast);
  }
  
  public void run(double deltaMs) {
    float size = this.sizeDamped.getValuef();
    float pos = this.pos.getValuef();
    float sizeInv = 1 / size;
    float contrast = this.contrast.getValuef();
    boolean inv = false;
    for (Rail rail : model.rails) {
      inv = !inv;
      float pv = inv ? pos : (1-pos);
      int i = 0;
      for (LXPoint p : rail.points) {
        float pd = (i % size) * sizeInv;
        colors[p.index] = LXColor.gray(max(0, 100 - contrast * LXUtils.wrapdistf(pd, pv, 1)));
        ++i;
      }
    }
  }
}

public class Bugs extends EnvelopPattern {
  
  public final CompoundParameter speed = (CompoundParameter)
    new CompoundParameter("Speed", 10, 20, 1)
    .setDescription("Speed of the bugs");
  
  public final CompoundParameter size =
    new CompoundParameter("Size", .1, .02, .4)
    .setDescription("Size of the bugs");
  
  public Bugs(LX lx) {
    super(lx);
    for (Rail rail : model.rails) {
      for (int i = 0; i < 10; ++i) {
        addLayer(new Layer(lx, rail));
      }
    }
    addParameter("speed", this.speed);
    addParameter("size", this.size);
  }
  
  class RandomSpeed extends FunctionalParameter {
    
    private final float rand;
    
    RandomSpeed(float low, float hi) {
      this.rand = random(low, hi);
    }
    
    public double getValue() {
      return this.rand * speed.getValue();
    }
  }
  
  class Layer extends LXModelLayer<EnvelopModel> {
    
    private final Rail rail;
    private final LXModulator pos = startModulator(new SinLFO(
      startModulator(new SinLFO(0, .5, new RandomSpeed(500, 1000)).randomBasis()),
      startModulator(new SinLFO(.5, 1, new RandomSpeed(500, 1000)).randomBasis()),
      new RandomSpeed(3000, 8000)
    ).randomBasis());
    
    private final LXModulator size = startModulator(new SinLFO(
      startModulator(new SinLFO(.1, .3, new RandomSpeed(500, 1000)).randomBasis()),
      startModulator(new SinLFO(.5, 1, new RandomSpeed(500, 1000)).randomBasis()),
      startModulator(new SinLFO(4000, 14000, random(3000, 18000)).randomBasis())
    ).randomBasis());
    
    Layer(LX lx, Rail rail) {
      super(lx);
      this.rail = rail;
    }
    
    public void run(double deltaMs) {
      float size = Bugs.this.size.getValuef() * this.size.getValuef();
      float falloff = 100 / max(size, (1.5*INCHES / model.yRange));
      float pos = this.pos.getValuef();
      for (LXPoint p : this.rail.points) {
        float b = 100 - falloff * abs(p.yn - pos);
        if (b > 0) {
          addColor(p.index, LXColor.gray(b));
        }
      }
    }
  }
  
  public void run(double deltaMs) {
    setColors(#000000);
  }
}