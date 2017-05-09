/**
 * EnvelopLX
 *
 * An interactive, sound-reactive lighting control system for the
 * Envelop spatial audio platform.
 *
 *  https://github.com/EnvelopSound/EnvelopLX
 *  http://www.envelop.us/
 *
 * Copyright 2017- Mark C. Slee
 */

enum Environment {
  MIDWAY,
  SATELLITE
}

// Change this line if you want a different configuration!
Environment environment = Environment.MIDWAY;  
LXStudio lx;
Envelop envelop;
EnvelopModel venue;

void setup() {  
  long setupStart = System.nanoTime();
  // LX.logInitTiming();
  size(1280, 960, P3D);

  venue = getModel();
  lx = new LXStudio(this, venue) {
    @Override
    protected void initialize(LXStudio lx, LXStudio.UI ui) {
      envelop = new Envelop(lx);
      lx.engine.registerComponent("envelop", envelop);
      lx.engine.addLoopTask(envelop);
              
      // Output drivers
      try {
        lx.engine.output.gammaCorrection.setValue(1);
        lx.engine.output.enabled.setValue(false);
        lx.addOutput(getOutput(lx));
      } catch (Exception x) {
        throw new RuntimeException(x);
      }
        
      // OSC drivers
      try {
        lx.engine.osc.receiver(3344).addListener(new EnvelopOscControlListener(lx));
        lx.engine.osc.receiver(3355).addListener(new EnvelopOscSourceListener());
        lx.engine.osc.receiver(3366).addListener(new EnvelopOscMeterListener());
      } catch (SocketException sx) {
        throw new RuntimeException(sx);
      }
        
      lx.registerPatterns(new Class[]{
        JavascriptPattern.class,
        heronarts.p3lx.pattern.SolidColorPattern.class,
        IteratorTestPattern.class
      });
      lx.registerEffects(new Class[]{
        FlashEffect.class,
        BlurEffect.class,
        DesaturationEffect.class
      });
    
      ui.theme.setPrimaryColor(#008ba0);
      ui.theme.setSecondaryColor(#00a08b);
      ui.theme.setAttentionColor(#a00044);
      ui.theme.setFocusColor(#0094aa);
    }
    
    @Override
    protected void onUIReady(LXStudio lx, LXStudio.UI ui) {
      ui.leftPane.audio.setVisible(false);
      ui.preview.addComponent(getUIVenue());
      ui.preview.addComponent(new UISoundObjects());
      ui.preview.setPhi(PI/32).setMinRadius(2*FEET).setMaxRadius(48*FEET);
      new UIEnvelopSource(ui, 0, 0, ui.leftPane.global.getContentWidth()).addToContainer(ui.leftPane.global, 2);
      new UIEnvelopDecode(ui, 0, 0, ui.leftPane.global.getContentWidth()).addToContainer(ui.leftPane.global, 3);
    }
  };
  
  long setupFinish = System.nanoTime();
  println("Total initialization time: " + ((setupFinish - setupStart) / 1000000) + "ms"); 
}

void draw() {
}

static class Envelop extends LXRunnableComponent {
  
  public final Source source = new Source();
  public final Decode decode = new Decode();
  
  public Envelop(LX lx) {
    super(lx, "Envelop");
    addSubcomponent(source);
    addSubcomponent(decode);
    source.start();
    decode.start();
    start();
  }
  
  @Override
  public void run(double deltaMs) {
    source.loop(deltaMs);
    decode.loop(deltaMs);
  }
  
  private final static String KEY_SOURCE = "source";
  private final static String KEY_DECODE = "decode";
  
  @Override
  public void save(LX lx, JsonObject obj) {
    super.save(lx, obj);
    obj.add(KEY_SOURCE, LXSerializable.Utils.toObject(lx, this.source));
    obj.add(KEY_DECODE, LXSerializable.Utils.toObject(lx, this.decode));
  }
  
  @Override
  public void load(LX lx, JsonObject obj) {
    if (obj.has(KEY_SOURCE)) {
      this.source.load(lx, obj.getAsJsonObject(KEY_SOURCE));
    }
    if (obj.has(KEY_DECODE)) {
      this.decode.load(lx, obj.getAsJsonObject(KEY_DECODE));
    }
    super.load(lx, obj);
  }
  
  abstract class Meter extends LXRunnableComponent {

    private final double[] targets;
    
    public final BoundedParameter gain = (BoundedParameter)
      new BoundedParameter("Gain", 0, -24, 24)
      .setDescription("Sets the dB gain of the meter")
      .setUnits(LXParameter.Units.DECIBELS);
    
    public final BoundedParameter range = (BoundedParameter)
      new BoundedParameter("Range", 24, 6, 96)
      .setDescription("Sets the dB range of the meter")
      .setUnits(LXParameter.Units.DECIBELS);
      
    public final BoundedParameter attack = (BoundedParameter)
      new BoundedParameter("Attack", 25, 0, 50)
      .setDescription("Sets the attack time of the meter response")
      .setUnits(LXParameter.Units.MILLISECONDS);
      
    public final BoundedParameter release = (BoundedParameter)
      new BoundedParameter("Release", 50, 0, 500)
      .setDescription("Sets the release time of the meter response")
      .setUnits(LXParameter.Units.MILLISECONDS);
    
    protected Meter(String label, int numChannels) {
      super(label);
      targets = new double[numChannels];
      addParameter(gain);
      addParameter(range);
      addParameter(attack);
      addParameter(release);
    }
    
    public void run(double deltaMs) {
      NormalizedParameter[] channels = getChannels();
      for (int i = 0; i < channels.length; ++i) {
        double target = this.targets[i];
        double value = channels[i].getValue();
        double gain = (target >= value) ? Math.exp(-deltaMs / attack.getValue()) : Math.exp(-deltaMs / release.getValue());
        channels[i].setValue(target + gain * (value - target));
      }
    }
    
    public void setLevels(OscMessage message) {
      double gainValue = this.gain.getValue();
      double rangeValue = this.range.getValue();
      for (int i = 0; i < this.targets.length; ++i) {
        targets[i] = constrain((float) (1 + (message.getFloat() + gainValue) / rangeValue), 0, 1);
      }
    }
    
    protected abstract NormalizedParameter[] getChannels();
  }
  
  class Source extends Meter {
    public static final int NUM_CHANNELS = 16;
    
    class Channel extends NormalizedParameter {
      
      public final int index;
      public boolean active;
      public final PVector xyz = new PVector();
      
      float tx;
      float ty;
      float tz;
      
      Channel(int i) {
        super("Source-" + (i+1));
        this.index = i+1;
        this.active = false;
      }
    }
    
    public final Channel[] channels = new Channel[NUM_CHANNELS];
    
    Source() {
      super("Source", NUM_CHANNELS);
      for (int i = 0; i < channels.length; ++i) {
        addParameter(channels[i] = new Channel(i));
      }
    }
    
    public NormalizedParameter[] getChannels() {
      return this.channels;
    }
  }
  
  class Decode extends Meter {
    
    public static final int NUM_CHANNELS = 8;
    public final NormalizedParameter[] channels = new NormalizedParameter[NUM_CHANNELS];
    
    Decode() {
      super("Decode", NUM_CHANNELS);
      for (int i = 0; i < channels.length; ++i) {
        addParameter(channels[i] = new NormalizedParameter("Decode-" + (i+1)));
      }
    }
    
    public NormalizedParameter[] getChannels() {
      return this.channels;
    }
  }
}