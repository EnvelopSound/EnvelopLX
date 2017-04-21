UI3dComponent getUIVenue() {
  switch (environment) {
  case SATELLITE: return new UISatellite();
  case MIDWAY: return new UIMidway();
  }
  return null;
}

abstract class UIVenue extends UI3dComponent {

  final static float LOGO_SIZE = 100*INCHES;
  final PImage LOGO = loadImage("envelop-logo-clear.png");

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
    pg.fill(#000000);
    pg.stroke(#202020);
    for (Column column : venue.columns) {
      pg.translate(column.cx, 0, column.cz);
      pg.rotateY(-column.theta);
      pg.translate(0, 9*INCHES, 0);
      pg.rotateX(Column.SPEAKER_ANGLE);
      pg.box(21*INCHES, 16*INCHES, 15*INCHES);
      pg.rotateX(-Column.SPEAKER_ANGLE);
      pg.translate(0, 6*FEET-9*INCHES, 0);
      pg.box(21*INCHES, 16*INCHES, 15*INCHES);
      pg.translate(0, 11*FEET + 3*INCHES - 6*FEET, 0);
      pg.rotateX(-Column.SPEAKER_ANGLE);
      pg.box(21*INCHES, 16*INCHES, 15*INCHES);
      pg.rotateX(Column.SPEAKER_ANGLE);
      pg.rotateY(+column.theta);
      pg.translate(-column.cx, -11*FEET - 3*INCHES, -column.cz);
    }
  }
  
  protected abstract void drawFloor(UI ui, PGraphics pg);
}

class UISatellite extends UIVenue {
  public void drawFloor(UI ui, PGraphics pg) {
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
    pg.translate(0, 20*INCHES, -Midway.DEPTH/2 + 18*INCHES);
    pg.box(6*FEET, 40*INCHES, 36*INCHES);
    pg.translate(0, -20*INCHES, Midway.DEPTH/2 - 18*INCHES);
    
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
  UIEnvelopSource(UI ui, float x, float y, float w) {
    super(ui, x, y, w, 124);
    setTitle("ENVELOP SOURCE");
    new UIEnvelopMeter(ui, envelop.source, 0, 0, getContentWidth(), 60).addToContainer(this);    
    UIAudio.addGainAndRange(this, 64, envelop.source.gain, envelop.source.range);
    UIAudio.addAttackAndRelease(this, 84, envelop.source.attack, envelop.source.release);
  }
}

class UIEnvelopDecode extends UICollapsibleSection {
  UIEnvelopDecode(UI ui, float x, float y, float w) {
    super(ui, x, y, w, 124);
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