UIVenue getUIVenue() {
  switch (environment) {
  case SATELLITE: return new UISatellite();
  case MIDWAY: return new UIMidway();
  }
  return null;
}

public static enum LogoMode {
  GRAPHIC_TEXT("envelop-logo-graphic-text.png"),
  GRAPHIC("envelop-logo-graphic.png"),
  INVERSE_TEXT("envelop-logo-inverse-text.png"),
  INVERSE("envelop-logo-inverse.png"),
  NONE(null);
  
  private final String path;
  private PImage image;
  
  private LogoMode(String path) {
    this.path = path;
  }
    
  public PImage getImage(UI ui) {
    if (this == NONE) {
      return null;
    }
    if (this.image == null) {
      this.image = ui.applet.loadImage(this.path);
    }
    return this.image;
  }
  
  public String toString() {
    switch (this) {
    case GRAPHIC_TEXT: return "Full";
    case GRAPHIC: return "Logo";
    case INVERSE_TEXT: return "Inv";
    case INVERSE: return "Only";
    };
    return "None";
  }
}

abstract class UIVenue extends UIVisual {

  final static float BOOTH_SIZE_X = 6*FEET;
  final static float BOOTH_SIZE_Y = 40*INCHES;
  final static float BOOTH_SIZE_Z = 36*INCHES;

  final static float DEFAULT_LOGO_SIZE = 100*INCHES;
    
  final static float SPEAKER_SIZE_X = 21*INCHES;
  final static float SPEAKER_SIZE_Y = 16*INCHES;
  final static float SPEAKER_SIZE_Z = 15*INCHES;
  
  private PImage logoImage;
  
  public final BooleanParameter speakersVisible =
    new BooleanParameter("Speakers", true)
    .setDescription("Whether speakers are visible in the venue simulation");
    
  public final BooleanParameter floorVisible =
    new BooleanParameter("Floor", true)
    .setDescription("Whether floor is visible in the venue simulation");
    
  public final EnumParameter<LogoMode> logoMode =
    new EnumParameter<LogoMode>("Logo Mode", LogoMode.GRAPHIC_TEXT)
    .setDescription("Which version of the logo to render");
    
  public final BoundedParameter logoTint =
    new BoundedParameter("Logo Tint", 1)
    .setDescription("Brightness of the logo");
    
  public final BoundedParameter logoSize =
    new BoundedParameter("Logo Size", DEFAULT_LOGO_SIZE, 40*INCHES, 180*INCHES)
    .setDescription("Size of the logo");    
  
  public UIVenue() {
    addParameter("speakersVisible", this.speakersVisible);
    addParameter("floorVisible", this.floorVisible);
    addParameter("logoMode", this.logoMode);
    addParameter("logoTint", this.logoTint);
    addParameter("logoSize", this.logoSize);
  }
  
  @Override
  public void onDraw(UI ui, PGraphics pg) {
    pg.stroke(#000000);
    pg.fill(#202020);
    
    if (this.floorVisible.isOn()) {
      drawFloor(ui, pg);
    }
    
    // Logo
    PImage logo = this.logoMode.getEnum().getImage(ui);
    if (logo != null) {    
      pg.noFill();
      pg.noStroke();
      
      pg.beginShape();
      int tint = (int) (255 * this.logoTint.getValue());
      pg.tint(0xff000000 | (tint << 16) | (tint << 8) | (tint));
      pg.texture(logo);
      pg.textureMode(NORMAL);
      float logoSize = this.logoSize.getValuef();
      pg.vertex(-logoSize, .1, -logoSize, 0, 1);
      pg.vertex(logoSize, .1, -logoSize, 1, 1);
      pg.vertex(logoSize, .1, logoSize, 1, 0);
      pg.vertex(-logoSize, .1, logoSize, 0, 0);
      pg.endShape(CLOSE);
      pg.tint(0xffffffff);
    }
    
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
    if (this.speakersVisible.isOn()) {
      pg.fill(#000000);
      pg.stroke(#202020);
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

class UIVisuals extends UICollapsibleSection {
  
  private final Map<UIVisual, UI2dContainer> controls = new HashMap<UIVisual, UI2dContainer>(); 
  
  UIVisuals(final LXStudio.UI ui, float w) {
    super(ui, 0, 0, w, 124);
    setTitle("VISUALS");
    setLayout(UI2dContainer.Layout.VERTICAL);
    setChildMargin(4);

    embellishCameraControls(ui);
    
    new UIButton(0, 0, w - 8, 16) {
      public void onToggle(boolean on) {
        if (on) {
          getSurface().setSize(1732, 972);
        }
      }
    }
    .setMomentary(true)
    .setLabel("Set 720p resolution")
    .addToContainer(this);
    
    new UIButton(0, 0, w-8, 16)
    .setParameter(videoRecording)
    .setActiveColor(ui.theme.getAttentionColor())
    .setLabel("Export Video Frames")
    .addToContainer(this);

    for (UIVisual visual : envelop.ui.visuals) {
      UI2dContainer control = new UI2dContainer(0, 0, getContentWidth(), 0);
      control.setVisible(false);
      visual.buildControlUI(ui, control);
      this.controls.put(visual, control);      
    }

    UIVisualList visualList = new UIVisualList(ui, 0, 0, getContentWidth(), 20);
    visualList.addToContainer(this);
    
    for (UIVisual visual : envelop.ui.visuals) {
      this.controls.get(visual).addToContainer(this);
    }
    
  }
  
  private void embellishCameraControls(LXStudio.UI ui) {
     UI2dContainer row;
    
    UI2dContainer camera = ui.leftPane.camera;
    float yp = camera.getContentHeight() + 4;

    new UIButton(0, yp, getContentWidth(), 16)
    .setParameter(envelop.ui.camera.running)
    .setLabel("Animate Camera")
    .addToContainer(camera);
    
    yp += 20;
    row = row(camera, null);
    row.setY(yp);
        
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
    
    yp += 20;
    
    new UIButton(0, yp, getContentWidth(), 16)
    .setParameter(ui.preview.pointCloud.visible)
    .setLabel("Show LED Points")
    .addToContainer(camera);
    yp += 20;
    
    camera.setContentHeight(yp);
  }
  
  private UI2dContainer focusedControls = null;
  private void focusVisual(UIVisual visual) {
    if (this.focusedControls != null) {
      this.focusedControls.setVisible(false);
    }
    this.focusedControls = this.controls.get(visual);
    this.focusedControls.setVisible(true);
  }
 
  private UI2dContainer row(UI2dContainer container, String label) {
    
    if (label != null) {
      new UILabel(0, 0, getContentWidth(), 12)
      .setLabel(label)
      .setTextAlignment(LEFT, CENTER)
      .addToContainer(container);
    }
    
    return (UI2dContainer)
      new UI2dContainer(0, 0, getContentWidth(), 16)
      .setLayout(UI2dContainer.Layout.HORIZONTAL)
      .setChildMargin(4)
      .addToContainer(container);
  }
  
  class UIVisualList extends UIItemList.BasicList {
    public UIVisualList(UI ui, float x, float y, float w, float h) {
      super(ui, x, y, w, h);
      setShowCheckboxes(true);
      for (UIVisual visual : envelop.ui.visuals) {
        addItem(new Item(visual));
      }
    }
    
    class Item extends UIItemList.Item {
      
      public final UIVisual visual;
      
      public Item(UIVisual visual) {
        this.visual = visual;
      }
      
      public boolean isChecked() {
        return this.visual.isVisible();
      }
      
      public String getLabel() {
        return this.visual.getName();
      }
      
      public void onFocus() {
        focusVisual(this.visual);
      }
      
      public void onCheck(boolean checked) {
        this.visual.setVisible(checked);
      }
    }
  }
}

public class UIColorPicker extends UI2dComponent {
  
  private final ColorParameter clr;
  
  public UIColorPicker(float x, float y, float w, float h, ColorParameter clr) {
    super(x, y, w, h);
    setBorderColor(UI.get().theme.getControlBorderColor());
    this.clr = clr;
  }
  
  @Override
  public void onDraw(UI ui, PGraphics pg) {
    pg.fill(this.clr.getColor());
    pg.noStroke();
    pg.rect(0, 0, this.width, this.height);
  }
  
  @Override
  public void onMouseDragged(MouseEvent mouseEvent, float mx, float my, float dx, float dy) {
    this.clr.hue.setValue((360 + this.clr.hue.getValue() + 2*dx) % 360);
    if (mouseEvent.isShiftDown()) {
      this.clr.saturation.setValue(constrain(this.clr.saturation.getValuef() - dy, 0, 100));
    } else {
      this.clr.brightness.setValue(constrain(this.clr.brightness.getValuef() - dy, 0, 100));
    }
    redraw();
  }
  
}
  
