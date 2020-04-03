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
  try {
    lx = new LXStudio(this, venue);
  } catch (Exception x) {
    x.printStackTrace();
    throw x;
  }
  
  long setupFinish = System.nanoTime();
  println("Total initialization time: " + ((setupFinish - setupStart) / 1000000) + "ms"); 

}

public void initialize(LXStudio lx, LXStudio.UI ui) {
  envelop = new Envelop(lx, ui);
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
    lx.engine.osc.receiver(3377).addListener(new EnvelopOscListener());
  } catch (SocketException sx) {
    throw new RuntimeException(sx);
  }

  ui.theme.setPrimaryColor(#008ba0);
  ui.theme.setSecondaryColor(#00a08b);
  ui.theme.setAttentionColor(#a00044);
  ui.theme.setFocusColor(#0094aa);
  ui.theme.setSurfaceColor(#cc3300);
  
}
    
public void onUIReady(LXStudio lx, LXStudio.UI ui) {
  envelop.ui.onReady(lx, ui);  
}

void draw() {
}

public class Envelop extends LXRunnableComponent {
  
  public final Source source;
  public final Decode decode;
  public final UI ui;
  
  public Envelop(LX lx, LXStudio.UI ui) {
    super(lx, "Envelop");
    addSubcomponent(this.source = new Source());
    addSubcomponent(this.decode = new Decode());
    source.start();
    decode.start();
    start();
    
    this.ui = new UI();    
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
  
  protected abstract class Meter extends LXRunnableComponent {

    private static final double TIMEOUT = 1000;
    
    private final double[] targets;
    private final double[] timeouts;
    
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
      this.targets = new double[numChannels];
      this.timeouts = new double[numChannels];
      addParameter(this.gain);
      addParameter(this.range);
      addParameter(this.attack);
      addParameter(this.release);
    }
    
    public void run(double deltaMs) {
      NormalizedParameter[] channels = getChannels();
      for (int i = 0; i < channels.length; ++i) {
        this.timeouts[i] += deltaMs;
        if (this.timeouts[i] > TIMEOUT) {
          this.targets[i] = 0;
        }
        double target = this.targets[i];
        double value = channels[i].getValue();
        double gain = (target >= value) ? Math.exp(-deltaMs / attack.getValue()) : Math.exp(-deltaMs / release.getValue());
        channels[i].setValue(target + gain * (value - target));
      }
    }
    
    public void setLevel(int index, OscMessage message) {
      double gainValue = this.gain.getValue();
      double rangeValue = this.range.getValue();
      this.targets[index] = constrain((float) (1 + (message.getFloat() + gainValue) / rangeValue), 0, 1);
      this.timeouts[index] = 0;
    }
    
    public void setLevels(OscMessage message) {
      double gainValue = this.gain.getValue();
      double rangeValue = this.range.getValue();
      for (int i = 0; i < this.targets.length; ++i) {
        this.targets[i] = constrain((float) (1 + (message.getFloat() + gainValue) / rangeValue), 0, 1);
        this.timeouts[i] = 0;
      }
    }
    
    protected abstract NormalizedParameter[] getChannels();
  }
  
  public class Source extends Meter {
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
  
  public class Decode extends Meter {
    
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
  
  public class UI {
    public final UIVenue venue;
    public final UISoundObjects soundObjects;
    public final Camera camera; 
    public final UIHalos halos;
    
    private UI() {
      this.venue = getUIVenue();
      this.soundObjects = new UISoundObjects();
      this.halos = new UIHalos();
      this.camera = new Camera();
    }
    
    public void onReady(LX lx, LXStudio.UI ui) {
      ui.leftPane.audio.setVisible(false);
      this.halos.setVisible(false);
      ui.preview.addComponent(this.venue);
      ui.preview.addComponent(this.soundObjects);
      ui.preview.addComponent(this.halos);
      ui.preview.setPhi(PI/32).setMinRadius(2*FEET).setMaxRadius(48*FEET);
      new UIEnvelopSource(ui, ui.leftPane.global.getContentWidth()).addToContainer(ui.leftPane.global, 2);
      new UIEnvelopDecode(ui, ui.leftPane.global.getContentWidth()).addToContainer(ui.leftPane.global, 3);
      new UIEnvelopStream(ui, ui.leftPane.global.getContentWidth()).addToContainer(ui.leftPane.global);
      ui.addLoopTask(this.camera);
    }
    
    public class Camera extends LXRunnableComponent {
      
      private SinLFO theta = new SinLFO(-TWO_PI, TWO_PI, 390000);
      private SinLFO phi = new SinLFO(0, 1, 99000);
      private SinLFO radius = new SinLFO(10*FEET, 30*FEET, 130000);
            
      public Camera() {
        this.theta.randomBasis().start();
        this.phi.randomBasis().start();
        this.radius.randomBasis().start();
        this.running.addListener(new LXParameterListener() {
          public void onParameterChanged(LXParameter p) {
            if (running.isOn()) {
              PVector eye = lx.ui.preview.getEye();
              theta.setValue(atan2(eye.x, -eye.z));
              phi.setValue(atan2(eye.y, dist(0, 0, eye.x, eye.z)));
              radius.setValue(eye.mag());
            }
          }
        });
      }
      
      @Override
      public void run(double deltaMs) {
        this.theta.loop(deltaMs);
        this.phi.loop(deltaMs);
        this.radius.loop(deltaMs);
        float phi = this.phi.getValuef();
        lx.ui.preview.setTheta(this.theta.getValue());
        lx.ui.preview.setPhi(phi * phi * PI / 2);
        lx.ui.preview.setRadius(this.radius.getValuef());
      }
    }
  }
  
}
