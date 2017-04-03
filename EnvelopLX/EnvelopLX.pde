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
Environment environment = Environment.SATELLITE;  
LXStudio lx;
Envelop envelop;
EnvelopModel venue;

void setup() {
  long setupStart = System.nanoTime();
  // LX.logInitTiming();
  size(1280, 800, P3D);

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
      ui.theme.setControlBorderColor(#292929);
    }
    
    @Override
    protected void onUIReady(LXStudio lx, LXStudio.UI ui) {
      ui.leftPane.audio.setVisible(false);
      ui.main.addComponent(getUIVenue());
      ui.main.addComponent(new UISoundObjects());
      ui.main.setPhi(PI/32).setMinRadius(2*FEET).setMaxRadius(48*FEET);
      new UIEnvelopSource(ui, 0, 0, ui.leftPane.global.getContentWidth()).addToContainer(ui.leftPane.global, 2);
      new UIEnvelopDecode(ui, 0, 0, ui.leftPane.global.getContentWidth()).addToContainer(ui.leftPane.global, 3);
    }
  };
  long setupFinish = System.nanoTime();
  println("Initialization time: " + ((setupFinish - setupStart) / 1000000) + "ms"); 
}

void draw() {
  background(lx.ui.theme.getDarkBackgroundColor());
}

static class Envelop extends LXRunnable {
  
  public final Source source = new Source();
  public final Decode decode = new Decode();
  
  public Envelop(LX lx) {
    super(lx);
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
  
  abstract class Meter extends LXRunnable {

    private final double[] targets;
    
    public final BoundedParameter gain = (BoundedParameter)
      new BoundedParameter("Gain", 0, -24, 24).setUnits(LXParameter.Units.DECIBELS);
    
    public final BoundedParameter range = (BoundedParameter)
      new BoundedParameter("Range", 24, 6, 96).setUnits(LXParameter.Units.DECIBELS);
      
    public final BoundedParameter attack = (BoundedParameter)
      new BoundedParameter("Attack", 25, 0, 50).setUnits(LXParameter.Units.MILLISECONDS);
      
    public final BoundedParameter release = (BoundedParameter)
      new BoundedParameter("Release", 50, 0, 500).setUnits(LXParameter.Units.MILLISECONDS);
    
    protected Meter(int numChannels) {
      targets = new double[numChannels];
      addParameter(gain);
      addParameter(range);
      addParameter(attack);
      addParameter(release);
    }
    
    public void run(double deltaMs) {
      BoundedParameter[] channels = getChannels();
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
    
    protected abstract BoundedParameter[] getChannels();
  }
  
  class Source extends Meter {
    public static final int NUM_CHANNELS = 16;
    
    class Channel extends BoundedParameter {
      
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
      super(NUM_CHANNELS);
      for (int i = 0; i < channels.length; ++i) {
        channels[i] = new Channel(i);
        addParameter(channels[i]);
      }
    }
    
    public BoundedParameter[] getChannels() {
      return this.channels;
    }
  }
  
  class Decode extends Meter {
    
    public static final int NUM_CHANNELS = 8;
    public final BoundedParameter[] channels = new BoundedParameter[NUM_CHANNELS];
    
    Decode() {
      super(NUM_CHANNELS);
      for (int i = 0; i < channels.length; ++i) {
        channels[i] = new BoundedParameter("Source-" + (i+1));
        addParameter(channels[i]);
      }
    }
    
    public BoundedParameter[] getChannels() {
      return this.channels;
    }
  }
}