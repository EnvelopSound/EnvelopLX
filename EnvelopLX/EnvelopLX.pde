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

final BooleanParameter videoRecording = new BooleanParameter("Recording", false);
String videoRecordingFolder = null;
int videoFrame = 0;
float modifyFrameRate = -1;

void settings() {
  size(1280, 960, P3D);
}

void setup() {
  frameRate(30);
  long setupStart = System.nanoTime();
  // LX.logInitTiming();
  venue = getModel();
  try {
    lx = new LXStudio(this, venue);
  } catch (Exception x) {
    x.printStackTrace();
    throw x;
  }
  
  videoRecording.addListener(new LXParameterListener() {
    public void onParameterChanged(LXParameter p) {
      if (videoRecording.isOn()) {
        // Crank CPU try to get more frames out
        modifyFrameRate = 60.1;
        videoFrame = 0;
        videoRecordingFolder = "export/" + new java.text.SimpleDateFormat("yyyy-MM-dd-HH'h'mm'm'ss's'").format(java.util.Calendar.getInstance().getTime());
      } else {
        println("Video exported to " + videoRecordingFolder);
        modifyFrameRate = 30;
        videoRecordingFolder = null;
      }
    }
  });
  
  registerMethod("pre", this);
    
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

void pre() {
  envelop.ui.beforeDraw();
}

void draw() {
  if (this.modifyFrameRate > 0) {
    frameRate(this.modifyFrameRate);
    this.modifyFrameRate = -1;
  }
  
  lx.ui.preview.depth.setValue(2);
  if (videoRecordingFolder != null) {
    lx.ui.preview.getGraphics().hint(ENABLE_ASYNC_SAVEFRAME);
    lx.ui.preview.getGraphics().save(this.videoRecordingFolder + "/" + String.format("%05d", videoFrame++));
  }
}

public class Envelop extends LXRunnableComponent {
  
  // Envelop source sound object meters
  public final Source source;
  
  // Envelop decoded output meters for the columns
  public final Decode decode;
  
  // Envelop-specific UI customizations and objects
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
  private final static String KEY_UI = "ui";
  
  @Override
  public void save(LX lx, JsonObject obj) {
    super.save(lx, obj);
    obj.add(KEY_SOURCE, LXSerializable.Utils.toObject(lx, this.source));
    obj.add(KEY_DECODE, LXSerializable.Utils.toObject(lx, this.decode));
    obj.add(KEY_UI, LXSerializable.Utils.toObject(lx, this.ui));
  }
  
  @Override
  public void load(LX lx, JsonObject obj) {
    if (obj.has(KEY_SOURCE)) {
      this.source.load(lx, obj.getAsJsonObject(KEY_SOURCE));
    }
    if (obj.has(KEY_DECODE)) {
      this.decode.load(lx, obj.getAsJsonObject(KEY_DECODE));
    }
    if (obj.has(KEY_UI)) {
      this.ui.load(lx, obj.getAsJsonObject(KEY_UI));
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
  
  public class UI implements LXSerializable {
    public final Camera camera; 
    
    public final List<UIVisual> visuals = new ArrayList<UIVisual>();
    
    private UI() {
      this.camera = new Camera();
      addVisual(new UISkybox());
      addVisual(getUIVenue());
      addVisual(new UIOrbs());
      addVisual(new UISoundObjects());
      addVisual(new UIFloatingDiscs());
      
      // The marble texture visual
      addVisual(new UIMarbleTexture());
    }
    
    protected void beforeDraw() {
      for (UIVisual visual : this.visuals) {
        if (visual.isVisible()) {
          visual.beforeDraw(lx.ui);
        }
      }
    }
    
    protected void addVisual(UIVisual visual) {
      if (this.visuals.contains(visual)) {
        throw new IllegalStateException("Cannot add two copies of same visual object: " + visual);
      }
      this.visuals.add(visual);
    }
    
    public void onReady(LX lx, LXStudio.UI ui) {
      ui.leftPane.audio.setVisible(false);
      for (UIVisual visual : this.visuals) {
        ui.preview.addComponent(visual);
      }
      
      ui.preview.setPhi(PI/32).setMinRadius(2*FEET).setMaxRadius(48*FEET);
      new UIEnvelopSource(ui, ui.leftPane.global.getContentWidth()).addToContainer(ui.leftPane.global, 2);
      new UIEnvelopDecode(ui, ui.leftPane.global.getContentWidth()).addToContainer(ui.leftPane.global, 3);
      new UIVisuals(ui, ui.leftPane.global.getContentWidth()).addToContainer(ui.leftPane.global);
      ui.addLoopTask(this.camera);
    }
    
    private static final String KEY_POINTS = "points";
    private static final String KEY_VISUALS = "visuals";
    
    @Override
    public void save(LX lx, JsonObject obj) {
      obj.addProperty(KEY_POINTS, ((LXStudio) lx).ui.preview.pointCloud.isVisible());
      obj.add(KEY_VISUALS, LXSerializable.Utils.toArray(lx, this.visuals));
    }
  
    @Override
    public void load(LX lx, JsonObject obj) {
      LXSerializable.Utils.loadBoolean(((LXStudio) lx).ui.preview.pointCloud.visible, obj, KEY_POINTS);
      if (obj.has(KEY_VISUALS)) {
        JsonArray visualArr = obj.get(KEY_VISUALS).getAsJsonArray(); 
        for (JsonElement visualElement : visualArr) {
          JsonObject visualObj = (JsonObject) visualElement;
          String visualClass = visualObj.get(UIVisual.KEY_CLASS).getAsString();
          for (UIVisual visual : this.visuals) {
            if (visual.getClass().getName().equals(visualClass)) {
              visual.load(lx, visualObj);
            }
          }
        }
      }
    }
    
    public class Camera extends LXRunnableComponent {
      
      public final BoundedParameter phiRange =
        new BoundedParameter("Elevation Range", 15, 0, 90)
        .setDescription("Sets the maximum range of the camera's elevation rotation");
        
      public final BoundedParameter thetaPeriod =
        new BoundedParameter("Rotation Speed", .5)
        .setDescription("Sets the speed of the camera's horizontal rotation");
        
      public final BoundedParameter radiusDepth =
        new BoundedParameter("Radial Depth", 20, 0, 30)
        .setDescription("Sets the level of the camera radial distance animation");
        
      public final BoundedParameter radiusPeriod =
        new BoundedParameter("Depth Speed", .5)
        .setDescription("Sets the speed of the camera's distance animation");
      
      private final SinLFO theta = new SinLFO(-TWO_PI, TWO_PI, new FunctionalParameter() {
        public double getValue() {
          return lerp(5000000, 200000, thetaPeriod.getValuef());
        }
      });
      
      private final SinLFO phi = new SinLFO(0, 1, 99000);
      
      private static final float MIN_RADIUS = 10*FEET; 
      
      private final SinLFO radius = new SinLFO(MIN_RADIUS, new FunctionalParameter() {
        public double getValue() {
          return MIN_RADIUS + radiusDepth.getValue() * FEET;
        }
      }, new FunctionalParameter() {
        public double getValue() {
          return lerp(500000, 10000, radiusPeriod.getValuef());
        }
      });
            
            
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
        lx.ui.preview.setPhi(phi * phi * this.phiRange.getValuef() * PI / 180f);
        lx.ui.preview.setRadius(this.radius.getValuef());
      }
    }
  }
  
}
