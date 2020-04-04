UIVenue getUIVenue() {
  switch (environment) {
  case SATELLITE: return new UISatellite();
  case MIDWAY: return new UIMidway();
  }
  return null;
}

abstract class UIVenue extends UI3dComponent {

  final static float BOOTH_SIZE_X = 6*FEET;
  final static float BOOTH_SIZE_Y = 40*INCHES;
  final static float BOOTH_SIZE_Z = 36*INCHES;

  final static float LOGO_SIZE = 100*INCHES;
  final PImage LOGO = loadImage("envelop-logo-clear.png");
  final static float SPEAKER_SIZE_X = 21*INCHES;
  final static float SPEAKER_SIZE_Y = 16*INCHES;
  final static float SPEAKER_SIZE_Z = 15*INCHES;
  
  public final BooleanParameter speakersVisible =
    new BooleanParameter("speakersVisible", true)
    .setDescription("Whether speakers are visible in the venue simulation");  
  
  @Override
  public void onDraw(UI ui, PGraphics pg) {
    pg.stroke(#000000);
    pg.fill(#202020);
    drawFloor(ui, pg);
    
    // Logo
    pg.noFill();
    pg.noStroke();
    pg.beginShape();
    pg.texture(LOGO);
    pg.textureMode(NORMAL);
    pg.vertex(-LOGO_SIZE, .1, -LOGO_SIZE, 0, 1);
    pg.vertex(LOGO_SIZE, .1, -LOGO_SIZE, 1, 1);
    pg.vertex(LOGO_SIZE, .1, LOGO_SIZE, 1, 0);
    pg.vertex(-LOGO_SIZE, .1, LOGO_SIZE, 0, 0);
    pg.endShape(CLOSE);
    
    // Speakers
    if (this.speakersVisible.isOn()) {    
      pg.fill(#000000);
      pg.stroke(#202020);
      for (Column column : venue.columns) {
        pg.translate(column.cx, 0, column.cz);
        pg.rotateY(-column.azimuth);
        pg.translate(0, 9*INCHES, 0);
        pg.rotateX(Column.SPEAKER_ANGLE);
        pg.box(SPEAKER_SIZE_X, SPEAKER_SIZE_Y, SPEAKER_SIZE_Z);
        pg.rotateX(-Column.SPEAKER_ANGLE);
        pg.translate(0, 6*FEET-9*INCHES, 0);
        pg.box(SPEAKER_SIZE_X, SPEAKER_SIZE_Y, SPEAKER_SIZE_Z);
        pg.translate(0, 11*FEET + 3*INCHES - 6*FEET, 0);
        pg.rotateX(-Column.SPEAKER_ANGLE);
        pg.box(SPEAKER_SIZE_X, SPEAKER_SIZE_Y, SPEAKER_SIZE_Z);
        pg.rotateX(Column.SPEAKER_ANGLE);
        pg.rotateY(column.azimuth);
        pg.translate(-column.cx, -11*FEET - 3*INCHES, -column.cz);
      }
    }
  }
  
  protected abstract void drawFloor(UI ui, PGraphics pg);
}

class UISatellite extends UIVenue {
  public void drawFloor(UI ui, PGraphics pg) {
    
    // Desk
    pg.translate(0, BOOTH_SIZE_Y/2, Satellite.INCIRCLE_RADIUS + BOOTH_SIZE_Z/2);
    pg.box(BOOTH_SIZE_X, BOOTH_SIZE_Y, BOOTH_SIZE_Z);
    pg.translate(0, -BOOTH_SIZE_Y/2, -Satellite.INCIRCLE_RADIUS - BOOTH_SIZE_Z/2);
    
    pg.beginShape();
    for (PVector v : Satellite.PLATFORM_POSITIONS) {
      pg.vertex(v.x, 0, v.y);
    }
    pg.endShape(CLOSE);
    pg.beginShape(QUAD_STRIP);
    for (int vi = 0; vi <= Satellite.PLATFORM_POSITIONS.length; ++vi) {
      PVector v = Satellite.PLATFORM_POSITIONS[vi % Satellite.PLATFORM_POSITIONS.length];
      pg.vertex(v.x, 0, v.y);
      pg.vertex(v.x, -8*INCHES, v.y);
    }
    pg.endShape();
  }
}
  
class UIMidway extends UIVenue {
      
  @Override
  public void onDraw(UI ui, PGraphics pg) {
    super.onDraw(ui, pg);
    
    // Desk
    pg.translate(0, BOOTH_SIZE_Y/2, Midway.DEPTH/2 - BOOTH_SIZE_Z/2);
    pg.box(BOOTH_SIZE_X, BOOTH_SIZE_Y, BOOTH_SIZE_Z);
    pg.translate(0, -BOOTH_SIZE_Y/2, -Midway.DEPTH/2 + BOOTH_SIZE_Z/2);
    
    // Subwoofers
    for (PVector pv : Midway.SUB_POSITIONS) {
      pg.translate(pv.x, 10*INCHES, pv.y);
      pg.rotateY(-QUARTER_PI);
      pg.box(29*INCHES, 20*INCHES, 29*INCHES);
      pg.rotateY(QUARTER_PI);
      pg.translate(-pv.x, -10*INCHES, -pv.y);
    }
  }
  
  @Override
  protected void drawFloor(UI ui, PGraphics pg) {
    // Floor
    pg.translate(0, -4*INCHES, 0);
    pg.box(Midway.WIDTH, 8*INCHES, Midway.DEPTH);
    pg.translate(0, 4*INCHES, 0);
  }        
}

class UIEnvelopSource extends UICollapsibleSection {
  UIEnvelopSource(UI ui, float w) {
    super(ui, 0, 0, w, 124);
    setTitle("ENVELOP SOURCE");
    new UIEnvelopMeter(ui, envelop.source, 0, 0, getContentWidth(), 60).addToContainer(this);    
    UIAudio.addGainAndRange(this, 64, envelop.source.gain, envelop.source.range);
    UIAudio.addAttackAndRelease(this, 84, envelop.source.attack, envelop.source.release);
  }
}

class UIEnvelopDecode extends UICollapsibleSection {
  UIEnvelopDecode(UI ui, float w) {
    super(ui, 0, 0, w, 124);
    setTitle("ENVELOP DECODE");
    new UIEnvelopMeter(ui, envelop.decode, 0, 0, getContentWidth(), 60).addToContainer(this);
    UIAudio.addGainAndRange(this, 64, envelop.decode.gain, envelop.decode.range);
    UIAudio.addAttackAndRelease(this, 84, envelop.decode.attack, envelop.decode.release);
  }
}

class UIEnvelopMeter extends UI2dContainer {
      
  public UIEnvelopMeter(UI ui, Envelop.Meter meter, float x, float y, float w, float h) {
    super(x, y, w, h);
    setBackgroundColor(ui.theme.getDarkBackgroundColor());
    setBorderColor(ui.theme.getControlBorderColor());
    
    NormalizedParameter[] channels = meter.getChannels();
    float bandWidth = ((width-2) - (channels.length-1)) / channels.length;
    int xp = 1;
    for (int i = 0; i < channels.length; ++i) {
      int nextX = Math.round(1 + (bandWidth+1) * (i+1));
      new UIEnvelopChannel(channels[i], xp, 1, nextX-xp-1, this.height-2).addToContainer(this);
      xp = nextX;
    }
  }
  
  class UIEnvelopChannel extends UI2dComponent implements UIModulationSource {
    
    private final NormalizedParameter channel;
    private float lev = 0;
    
    UIEnvelopChannel(final NormalizedParameter channel, float x, float y, float w, float h) {
      super(x, y, w, h);
      this.channel = channel;
      addLoopTask(new LXLoopTask() {
        public void loop(double deltaMs) {
          float l2 = UIEnvelopChannel.this.height * channel.getNormalizedf();
          if (l2 != lev) {
            lev = l2;
            redraw();
          }
        }
      });
    }
    
    public void onDraw(UI ui, PGraphics pg) {
      if (lev > 0) {
        pg.noStroke();
        pg.fill(ui.theme.getPrimaryColor());
        pg.rect(0, this.height-lev, this.width, lev);
      }
    }
    
    public LXNormalizedParameter getModulationSource() {
      return this.channel;
    }
  }
}

class UIEnvelopStream extends UICollapsibleSection {
  UIEnvelopStream(LXStudio.UI ui, float w) {
    super(ui, 0, 0, w, 124);
    setTitle("ENVELOP STREAM");
    setLayout(UI2dContainer.Layout.VERTICAL);
    setChildMargin(4);
    
    UI2dContainer row;

    new UIButton(0, 0, getContentWidth()  , 16)
    .setParameter(envelop.ui.camera.running)
    .setLabel("Animate Camera")
    .addToContainer(this);
    
    row = row(null);
    
    new UIDoubleBox(0, 0, 40, 16)
    .setParameter(envelop.ui.camera.thetaPeriod)
    .addToContainer(row);
    
    new UIDoubleBox(0, 0, 40, 16)
    .setParameter(envelop.ui.camera.phiRange)
    .addToContainer(row);
    
    new UIDoubleBox(0, 0, 40, 16)
    .setParameter(envelop.ui.camera.radiusDepth)
    .addToContainer(row);
    
    new UIDoubleBox(0, 0, 40, 16)
    .setParameter(envelop.ui.camera.radiusPeriod)
    .addToContainer(row);
            
    row = row("Elements");
    
    new UIButton(0, 0, 40, 16)
    .setParameter(envelop.ui.venue.speakersVisible)
    .setLabel("Boxes")
    .addToContainer(row);
    
    new UIButton(0, 0, 40, 16)
    .setParameter(envelop.ui.soundObjects.visible)
    .setLabel("Orbs")
    .addToContainer(row);
        
    new UIButton(0, 0, 40, 16)
    .setParameter(ui.preview.pointCloud.visible)
    .setLabel("Points")
    .addToContainer(row);
    
    new UIButton(0, 0, 40, 16)
    .setParameter(envelop.ui.halos.visible)
    .setLabel("Halos")
    .addToContainer(row);
    
    row = row("Skybox");    
    new UIDropMenu(0, 0, getContentWidth() - 44, 16, envelop.ui.skybox.skymap).addToContainer(row);
    new UIDoubleBox(0, 0, 40, 16).setParameter(envelop.ui.skybox.alpha).addToContainer(row);
    
  }
  
  private UI2dContainer row(String label) {
    if (label != null) {
      new UILabel(0, 0, getContentWidth(), 12)
      .setLabel(label)
      .setTextAlignment(LEFT, CENTER)
      .addToContainer(this);
    }
    
    return (UI2dContainer)
      new UI2dContainer(0, 0, getContentWidth(), 16)
      .setLayout(UI2dContainer.Layout.HORIZONTAL)
      .setChildMargin(4)
      .addToContainer(this);
  }
}
  

class UISoundObjects extends UI3dComponent {
  final PFont objectLabelFont; 

  UISoundObjects() {
    this.objectLabelFont = loadFont("Arial-Black-24.vlw");
  }
  
  public void onDraw(UI ui, PGraphics pg) {
    for (Envelop.Source.Channel channel : envelop.source.channels) {
      if (channel.active) {
        float tx = channel.tx;
        float ty = channel.ty;
        float tz = channel.tz;
        pg.directionalLight(40, 40, 40, .5, -.4, 1);
        pg.ambientLight(40, 40, 40);
        pg.translate(tx, ty, tz);
        pg.noStroke();
        pg.fill(0xff00ddff);
        pg.sphere(6*INCHES);
        pg.noLights();
        pg.scale(1, -1);
        pg.textAlign(CENTER, CENTER);
        pg.textFont(objectLabelFont);
        pg.textSize(4);
        pg.fill(#00ddff);
        pg.text(Integer.toString(channel.index), 0, -1*INCHES, -6.1*INCHES);
        pg.scale(1, -1);
        pg.translate(-tx, -ty, -tz);
      }
    }    
  }
}

class UIHalos extends UI3dComponent {
  public void onDraw(UI ui, PGraphics pg) {
    int[] colors = lx.getColors(); 
    
    pg.noStroke();
    pg.sphereDetail(12);
    pg.pointLight(255, 255, 255, 0, 0, 0);
    pg.ambientLight(64, 64, 64);
    pg.directionalLight(128, 128, 128, 1, -1, 1);
    for (LXPoint p : venue.railPoints) {
      int c = colors[p.index];
      int a = max(0xff & c, 0xff & (c >> 8), 0xff & (c >> 16)); 
      if (a > 0) {      
        pg.fill((a << 24) | (c & 0x00ffffff));
        pg.translate(p.x, p.y, p.z);
        pg.sphere(a / 255. * 2*INCHES);
        pg.translate(-p.x, -p.y, -p.z);
      }
    }
    pg.noLights();
      
  }
}

class UISkybox extends UI3dComponent {
  
  private PImage frontZ;
  private PImage backZ;
  private PImage leftX;
  private PImage rightX;
  private PImage downY;
  private PImage upY;
    
  public final ObjectParameter<Skymap> skymap; 
  
  public final BoundedParameter alpha =
    new BoundedParameter("Alpha", 1)
    .setDescription("The alpha blending level of the skybox, lower to darken");
  
  public class Skymap {
    
    private final String name;
    private final File folder;
    
    Skymap(String name, File folder) {
      this.name = name;
      this.folder = folder;
    }
    
    public String toString() {
      return this.name;
    }
  }
  
  private boolean reload = false;
  private Skymap currentSkymap;
  
  public UISkybox() {
    File skyboxFolder = saveFile("data/skymaps");
    List<Skymap> skymaps = new ArrayList<Skymap>();
    skymaps.add(new Skymap("None", null));
    if (skyboxFolder.isDirectory()) {
      for (File f : skyboxFolder.listFiles()) {
        if (f.isDirectory()) {
          skymaps.add(new Skymap(f.getName(), f));
        }
      }
    }
    
    this.skymap =
      new ObjectParameter<Skymap>("Skymap", skymaps.toArray(new Skymap[]{}))
      .setDescription("Which skymap should be displayed around the Envelop environment"); 
      
    this.skymap.addListener(new LXParameterListener() {
      public void onParameterChanged(LXParameter p) {
        reload = true;
      }
    });
  }
  
  private static final float SKYBOX_SIZE = 100*FEET;
  
  public void onDraw(UI ui, PGraphics pg) {
    if (reload) {
      this.currentSkymap = this.skymap.getObject();
      if (this.currentSkymap.folder != null) {
        String path = "data/skymaps/" + this.currentSkymap.folder.getName(); 
        println("Loading skymap from " + path); 
        this.frontZ = loadImage(path + "/0_Front+Z.png");
        this.backZ = loadImage(path + "/1_Back-Z.png");
        this.leftX = loadImage(path + "/2_Left+X.png");
        this.rightX = loadImage(path + "/3_Right-X.png");
        this.upY = loadImage(path + "/4_Up+Y.png");
        this.downY = loadImage(path + "/5_Down-Y.png");
      }
      reload = false;
    }
    
    if ((this.currentSkymap != null) && (this.currentSkymap.folder != null)) {
      int alpha = 0xff & (int) (this.alpha.getValuef() * 255);
      pg.pushMatrix();
      pg.noStroke();
      pg.tint(0xff000000 | (alpha << 16) | (alpha << 8) | (alpha));
      pg.textureMode(NORMAL);
      drawBoxFace(pg, this.frontZ);
      pg.rotateY(-HALF_PI);
      drawBoxFace(pg, this.rightX);
      pg.rotateY(-HALF_PI);
      drawBoxFace(pg, this.backZ);
      pg.rotateY(-HALF_PI);
      drawBoxFace(pg, this.leftX);
      pg.rotateY(-HALF_PI);
      pg.rotateX(-HALF_PI);
      drawBoxFace(pg, this.upY);
      pg.rotateX(PI);
      drawBoxFace(pg, this.downY);
      pg.popMatrix();
    }
  }
  
  private void drawBoxFace(PGraphics pg, PImage texture) {
    pg.beginShape();
    pg.texture(texture);
    pg.vertex(-SKYBOX_SIZE, -SKYBOX_SIZE, SKYBOX_SIZE, 0, 1);
    pg.vertex(-SKYBOX_SIZE, SKYBOX_SIZE, SKYBOX_SIZE, 0, 0);
    pg.vertex(SKYBOX_SIZE, SKYBOX_SIZE, SKYBOX_SIZE, 1, 0);
    pg.vertex(SKYBOX_SIZE, -SKYBOX_SIZE, SKYBOX_SIZE, 1, 1);
    pg.endShape();
  }
    
   
}
