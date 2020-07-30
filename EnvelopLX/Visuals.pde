import java.util.LinkedHashMap;

/**
 * Abstract class for a visual simulation effect in the preview rendering environment.
 * These effects can essentially render anything they like using a 3D PGraphics object,
 * but they specifically also have access to the colors of the LED effects as well as
 * the source and decoded Envelop audio levels
 *
 * The core drawing method is onDraw(UI ui, PGraphics pg) - note that all Processing
 * drawing calls must go through this explicitly passed pg object, rather than direct
 * top-level Processing API calls.
 */
public abstract class UIVisual extends UI3dComponent implements LXSerializable {

  private final Map<String, LXParameter> parameters = new LinkedHashMap<String, LXParameter>();

  /**
   * Default name of a visual is it's class name with UI stripped, but a subclass may
   * override to provide a prettier name if desired.
   */
  public String getName() {
    String className = getClass().getSimpleName();
    if (className.startsWith("UI")) {
      className = className.substring(2);
    }
    return className;
  }

  /**
   * Subclasses may override to do offscreen-rendering before the actual
   * composited draw pass. Note that access to the main pg object is not
   * allowed yet. A separate, explicit pg object should be managed and
   * used by the visual.
   */
  protected void beforeDraw(UI ui) {
  }

  /**
   * Adds a parameter to the visual device. A UI to control the parameter will be generated
   * and it will also be saved/restored with this visual component.
   */
  protected void addParameter(String path, LXParameter parameter) {
    if (this.parameters.containsKey(key)) {
      throw new IllegalArgumentException("Cannot add same parameter path: " + path);
    }
    this.parameters.put(path, parameter);
  }

  /**
   * Default implementation is provided and should work for the majority of devices, but
   * subclasses are free to override this to create their own custom UI if needed.
   */
  protected void buildControlUI(UI ui, UI2dContainer controls) {
    float yp = 0;
    float controlWidth = 80;
    float xp = controls.getContentWidth() - controlWidth;
    for (LXParameter p : this.parameters.values()) {
      UI2dComponent control = null;
      if (p instanceof BooleanParameter) {
        control = new UIButton(xp, yp, controlWidth, 16).setParameter((BooleanParameter) p).setActiveLabel("On").setInactiveLabel("Off");
      } else if (p instanceof BoundedParameter) {
        control = new UIDoubleBox(xp, yp, controlWidth, 16).setParameter((BoundedParameter) p);
      } else if (p instanceof DiscreteParameter) {
        control = new UIDropMenu(xp, yp, controlWidth, 16, (DiscreteParameter) p);
      } else if (p instanceof ColorParameter) {
        control = new UIColorPicker(xp, yp, controlWidth, 16, (ColorParameter) p);
      }
      if (control != null) {
        new UILabel(0, yp, controls.getContentWidth() - control.getWidth() - 4, 16)
          .setLabel(p.getLabel())
          .setPadding(0, 4)
          .setFont(ui.theme.getControlFont())
          .setTextAlignment(LEFT, CENTER)
          .addToContainer(controls);
        control.addToContainer(controls);
        yp += 20;
      }
    }
    controls.setContentHeight(max(0, yp - 4));
  }

  private static final String KEY_CLASS = "class";
  private static final String KEY_VISIBLE = "visible";

  @Override
    public void save(LX lx, JsonObject obj) {
    obj.addProperty(KEY_CLASS, getClass().getName());
    obj.addProperty(KEY_VISIBLE, this.isVisible());
    for (String path : parameters.keySet()) {
      LXParameter parameter = parameters.get(path);
      if (parameter instanceof BoundedParameter) {
        obj.addProperty(path, parameter.getValue());
      } else if (parameter instanceof BooleanParameter) {
        obj.addProperty(path, ((BooleanParameter) parameter).isOn());
      } else if (parameter instanceof DiscreteParameter) {
        obj.addProperty(path, ((DiscreteParameter) parameter).getValuei());
      } else {
        println("WARNING: UIVisual objects do not support saving this parameter type: " + parameter.getClass());
      }
    }
  }

  @Override
    public void load(LX lx, JsonObject obj) {
    LXSerializable.Utils.loadBoolean(this.visible, obj, KEY_VISIBLE);
    for (String path : parameters.keySet()) {
      if (obj.has(path)) {
        LXParameter parameter = parameters.get(path);
        JsonElement value = obj.get(path);
        if (parameter instanceof BoundedParameter) {
          parameter.setValue(value.getAsDouble());
        } else if (parameter instanceof BooleanParameter) {
          ((BooleanParameter) parameter).setValue(value.getAsBoolean());
        } else if (parameter instanceof DiscreteParameter) {
          parameter.setValue(value.getAsInt());
        }
      }
    }
  }
}

class UISoundObjects extends UIVisual {
  final PFont objectLabelFont; 

  public final BoundedParameter radius =
    new BoundedParameter("Radius", 6*INCHES, 2*INCHES, 12*INCHES)
    .setDescription("Radius of the sound object spheres");

  UISoundObjects() {
    this.objectLabelFont = loadFont("Arial-Black-24.vlw");
    addParameter("radius", this.radius);
  }

  public String getName() {
    return "Sound Objects";
  }

  public void onDraw(UI ui, PGraphics pg) {
    float radius = this.radius.getValuef();
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
        pg.sphere(radius);
        pg.noLights();
        pg.scale(1, -1);
        pg.textAlign(CENTER, CENTER);
        pg.textFont(objectLabelFont);
        pg.textSize(4);
        pg.fill(#00ddff);
        pg.text(Integer.toString(channel.index), 0, -1*INCHES, -radius - .1*INCHES);
        pg.scale(1, -1);
        pg.translate(-tx, -ty, -tz);
      }
    }
  }
}

class UIOrbs extends UIVisual {

  public final BoundedParameter radius =
    new BoundedParameter("Radius", 2*INCHES, 1*INCHES, 8*INCHES)
    .setDescription("Maximum radius of the orbs");

  public UIOrbs() {
    addParameter("radius", this.radius);
  }

  public void onDraw(UI ui, PGraphics pg) {
    int[] colors = ui.lx.getUIFrame().getColors(); 
    float radius = this.radius.getValuef();

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
        pg.sphere(a / 255. * radius);
        pg.translate(-p.x, -p.y, -p.z);
      }
    }
    pg.noLights();
  }
}

class UISkybox extends UIVisual {

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

    addParameter("skymap", this.skymap);
    addParameter("alpha", this.alpha);

    this.skymap.addListener(new LXParameterListener() {
      public void onParameterChanged(LXParameter p) {
        reload = true;
      }
    }
    );
  }

  private static final float SKYBOX_SIZE = 200*FEET;

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

      pg.tint(0xffffffff);
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

class UIFloatingDiscs extends UIVisual {

  public final BoundedParameter brightness =
    new BoundedParameter("Brightness", 150, 255)
    .setDescription("Brightness of the light source");

  public final BoundedParameter tiltRange =
    new BoundedParameter("Tilt Range", PI/8, 0, HALF_PI)
    .setDescription("Range of modulated tilting");

  public final BoundedParameter sizeRange =
    new BoundedParameter("Size Range", 6*INCHES, 0, 3*FEET) 
    .setDescription("Range of modulated size change");    

  class Disc {

    final float x;
    final float y;
    final float z;
    final float size;
    final float pitch;
    final float roll;

    final SinLFO pitchMod = new SinLFO(-1, 1, random(11000, 19000));
    final SinLFO rollMod = new SinLFO(-1, 1, random(11000, 21000));
    final SinLFO xMod = new SinLFO(0, random(1, 3)*FEET, random(9000, 23000));
    final SinLFO zMod = new SinLFO(0, random(1, 3)*FEET, random(9000, 23000));
    final SinLFO sizeMod = new SinLFO(0, 1, random(9000, 23000));

    Disc() {
      float r = venue.rMax + 5*FEET;
      float elev = random(0, HALF_PI);
      float theta = random(0, TWO_PI);
      this.x = r * cos(theta) * cos(elev);
      this.z = r * sin(theta) * cos(elev);
      this.y = 5*FEET + r * .75 * sin(elev);

      this.pitch = -QUARTER_PI * cos(elev) * cos(theta);
      this.roll = QUARTER_PI * cos(elev) * sin(theta);

      this.size = random(1*FEET, 3*FEET);
      addLoopTask(this.pitchMod.randomBasis().start());
      addLoopTask(this.rollMod.randomBasis().start());
      addLoopTask(this.xMod.randomBasis().start());
      addLoopTask(this.zMod.randomBasis().start());
      addLoopTask(this.sizeMod.randomBasis().start());
    }

    public void onDraw(UI ui, PGraphics pg) {
      float tiltRange = UIFloatingDiscs.this.tiltRange.getValuef(); 
      float pitch = this.pitch + tiltRange * this.pitchMod.getValuef();
      float roll = this.roll + tiltRange * this.rollMod.getValuef();

      float x = this.x + this.xMod.getValuef();
      float z = this.z + this.xMod.getValuef();

      float size = this.size + this.sizeMod.getValuef() * sizeRange.getValuef();

      pg.translate(x, y, z);
      pg.rotateX(HALF_PI);
      pg.rotateY(pitch);
      pg.rotateX(roll);
      pg.ellipseMode(CENTER);
      pg.ellipse(0, 0, size, size);
      pg.ellipseMode(CORNER);
      pg.rotateX(-roll);
      pg.rotateY(-pitch);
      pg.rotateX(-HALF_PI);
      pg.translate(-x, -y, -z);
    }
  }

  private static final int NUM_PLANES = 240; 
  private final Disc[] planes;

  public UIFloatingDiscs() {
    this.planes = new Disc[NUM_PLANES];
    for (int i = 0; i < this.planes.length; ++i) {
      this.planes[i] = new Disc();
    }
    addParameter("brightness", this.brightness);
    addParameter("tiltRange", this.tiltRange);
    addParameter("sizeRange", this.sizeRange);
  }

  public String getName() {
    return "Floating Discs";
  }

  public void onDraw(UI ui, PGraphics pg) {
    float brightness = this.brightness.getValuef();
    pg.pointLight(brightness, brightness, brightness, venue.cx, 0, venue.cz);
    pg.directionalLight(brightness/2, brightness/2, brightness/2, 1, -1, 1);
    pg.noStroke();
    pg.fill(#ffffff);
    for (Disc plane : this.planes) {
      plane.onDraw(ui, pg);
    }
    pg.noLights();
  }
}

/*
 * Marble Texture effect in GLSL
 * Copyright 2020 - Giovanni Muzio
 * https://kesson.io
 *
 * fBM thanks to:
 *
 * thebookofshaders.com, by Patricio Gonzalez Vivo
 * https://thebookofshaders.com/13/
 *
 * Domain Warping and fBM, by Inigo Quilez
 * https://www.iquilezles.org/www/articles/warp/warp.htm
 * https://www.iquilezles.org/www/articles/fbm/fbm.htm
 *
 */

import java.nio.*;

class UIMarbleTexture extends UIVisual {

  PShader shader;
  PGraphics offscreen, offscreen2;
  PShape globe;

  public final ColorParameter baseColor = 
    new ColorParameter("Base Color", rgbf(0.086f, 0.01f, 0.20f));

  public final ColorParameter finalColor = 
    new ColorParameter("Final Color", rgbf(0.90f, 0.06f, 0.096f));

  public final ColorParameter colorMixA = 
    new ColorParameter("Color Mix A", rgbf(0.06f, 0.96f, 0.99f));

  public final ColorParameter colorMixB = 
    new ColorParameter("Color Mix B", rgbf(0.00f, 0.00f, 0.90f));    

  public final BoundedParameter hurst_exponent =
    new BoundedParameter("Hurst Exp.", 0.5f, 0.25f, 0.75f)
    .setDescription("The parameter that controls the behavior of the self-similarity, its fractal dimension and its power spectrum.");

  public final BoundedParameter size =
    new BoundedParameter("Size", 4.0f, 1.0f, 16.0f)
    .setDescription("The size of the effect");

  public final BoundedParameter octaves =
    new BoundedParameter("Octaves", 8, 1, 16)
    .setDescription("Number of octaves, or depth of the effect");

  public final BoundedParameter warping_speed_1 =
    new BoundedParameter("Warping Speed 1", 0.05f, 0.0f, 1.0f) 
    .setDescription("Speed of the first warping domain effect");  

  public final BoundedParameter warping_speed_2 =
    new BoundedParameter("Warping Speed 2", 0.065f, 0.0f, 1.0f) 
    .setDescription("Second speed of the warping domain effect");

  public final BoundedParameter amount =
    new BoundedParameter("Amount", 4.0f, 0.0f, 32.0f) 
    .setDescription("Amount of the warping effect");

  public final BoundedParameter opacity =
    new BoundedParameter("Opacity", 1.0f, 0.0f, 1.0f) 
    .setDescription("Amount of the warping effect");

  public final BooleanParameter isEnvironmentalMap =
    new BooleanParameter("Environmental Map", true)
    .setDescription("Wheter the shader is applied as environmental map");

  public final BooleanParameter isMirrored =
    new BooleanParameter("Mirror", false)
    .setDescription("Mirror the shader and applies it to a square texture");

  public final BooleanParameter isTexture =
    new BooleanParameter("Texture", false)
    .setDescription("Wheter the shader is applied as texture on top on the render");

  public UIMarbleTexture() {

    int pgw = 1080, pgh = 1080;
    offscreen = createGraphics(pgw, pgh, P3D);
    offscreen2 = createGraphics(pgw, pgh, P3D);
    // UI controls
    addParameter("environmental Map", this.isEnvironmentalMap);
    addParameter("mirror", this.isMirrored);
    addParameter("texture", this.isTexture);
    addParameter("baseColor", this.baseColor);
    addParameter("finalColor", this.finalColor);
    addParameter("colorMixA", this.colorMixA);
    addParameter("colorMixB", this.colorMixB);

    addParameter("hurst_exponent", this.hurst_exponent);
    addParameter("size", this.size);
    addParameter("octaves", this.octaves);
    addParameter("warping speed 1", this.warping_speed_1);
    addParameter("warping speed 2", this.warping_speed_2);
    addParameter("amount", this.amount);
    addParameter("opacity", this.opacity);

    // Get the parameters to set the uniforms in the shader
    float size = this.size.getValuef();
    float hurst_exp = this.hurst_exponent.getValuef();
    int octaves = int(this.octaves.getValuef());
    float warp_speed_1 = this.warping_speed_1.getValuef();
    float warp_speed_2 = this.warping_speed_2.getValuef();
    float amount = this.amount.getValuef();
    float opacity = this.opacity.getValuef();

    // Load the shader and initialize the uniforms
    shader = loadShader("./data/Shaders/MarbleFrag.glsl");
    shader.set("iResolution", float(width), float(height));
    shader.set("iTime", 0.0f);
    shader.set("size", size);
    shader.set("hurst_exponent", hurst_exp);
    shader.set("amount", amount);
    shader.set("num_octaves", octaves);
    shader.set("warping_speed_1", warp_speed_1);
    shader.set("warping_speed_2", warp_speed_2);
    shader.set("opacity", opacity);

    // The colors of the shader
    setShaderColor("baseColor", this.baseColor);
    setShaderColor("finalColor", this.finalColor);
    setShaderColor("colorMixA", this.colorMixA);
    setShaderColor("colorMixB", this.colorMixB);

    noStroke();
    globe = createShape(SPHERE, 10000);

    setVisible(false);
  }

  private int rgbf(float r, float g, float b) {
    return LXColor.rgb((int) (r*255), (int) (g*255), (int) (b*255));
  }

  private void setShaderColor(String attribute, ColorParameter clr) {
    int c = clr.getColor();
    float r = ((c & 0xff0000) >> 16) / 255f;
    float g = ((c & 0xff00) >> 8) / 255f;
    float b = (c & 0xff) / 255f;
    shader.set(attribute, r, g, b);
  }

  public String getName() {
    return "Marble Texture";
  }

  // A method to show the offscreen shader
  // To fix the angles not mathing at the top and bottom corners
  private void TexturedCube(PGraphics pg, PGraphics tex, int p) {
    int s = p * 2;

    pg.blendMode(NORMAL);

    pg.push();
    pg.translate(0, 0, p);
    pg.imageMode(CENTER);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.push();
    pg.translate(-p, 0, 0);
    pg.rotateY(HALF_PI);
    pg.imageMode(CENTER);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.push();
    pg.translate(p, 0, 0);
    pg.rotateY(-HALF_PI);
    pg.imageMode(CENTER);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.push();
    pg.translate(0, 0, -p);
    pg.imageMode(CENTER);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.push();
    pg.translate(0, -p-1, 0);
    pg.imageMode(CENTER);
    pg.rotateX(HALF_PI);
    pg.rotateZ(HALF_PI);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.blendMode(LIGHTEST);
    pg.push();
    pg.translate(0, -p, 0);
    pg.imageMode(CENTER);
    pg.rotateX(HALF_PI);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.blendMode(NORMAL);

    pg.push();
    pg.translate(0, p+1, 0);
    pg.imageMode(CENTER);
    pg.rotateX(HALF_PI);
    pg.rotateZ(HALF_PI);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.blendMode(LIGHTEST);
    pg.push();
    pg.translate(0, p, 0);
    pg.imageMode(CENTER);
    pg.rotateX(HALF_PI);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.blendMode(NORMAL);
  }

  public void beforeDraw(UI ui) {
    // Get the parameters to set the uniforms in the shader
    float size = this.size.getValuef();
    float hurst_exp = this.hurst_exponent.getValuef();
    int octaves = int(this.octaves.getValuef());
    float warp_speed_1 = this.warping_speed_1.getValuef();
    float warp_speed_2 = this.warping_speed_2.getValuef();
    float amount = this.amount.getValuef();
    float opacity = this.opacity.getValuef();

    // Set the uniforms of the shader
    shader.set("iTime", millis() / 1000.0);
    shader.set("size", size);
    shader.set("hurst_exponent", hurst_exp);
    shader.set("amount", amount);
    shader.set("num_octaves", octaves);
    shader.set("warping_speed_1", warp_speed_1);
    shader.set("warping_speed_2", warp_speed_2);
    shader.set("opacity", opacity);

    // The colors of the shader
    setShaderColor("baseColor", this.baseColor);
    setShaderColor("finalColor", this.finalColor);
    setShaderColor("colorMixA", this.colorMixA);
    setShaderColor("colorMixB", this.colorMixB);

    offscreen.beginDraw();
    offscreen.background(0);
    offscreen.shader(shader);
    offscreen.noStroke();
    offscreen.rectMode(CORNER);
    offscreen.rect(0, 0, offscreen.width, offscreen.height);
    offscreen.endDraw();

    if (this.isMirrored.isOn()) {
      int w_ = offscreen2.width;
      int h_ = offscreen2.height;
      offscreen2.beginDraw();
      offscreen.background(0);
      offscreen.blendMode(LIGHTEST);

      offscreen2.image(offscreen, 0, 0, w_, h_);

      offscreen2.pushMatrix();
      offscreen2.translate(offscreen2.width, 0);
      offscreen2.scale(-1, 1);
      offscreen2.image(offscreen, 0, 0, w_, w_);
      offscreen2.popMatrix();

      offscreen2.pushMatrix();
      offscreen2.translate(offscreen2.width, offscreen2.height);
      offscreen2.scale(-1, -1);
      offscreen2.image(offscreen, 0, 0, w_, w_);
      offscreen2.popMatrix();

      offscreen2.pushMatrix();
      offscreen2.translate(0, offscreen2.height);
      offscreen2.scale(1, -1);
      offscreen2.image(offscreen, 0, 0, w_, w_);
      offscreen2.popMatrix();

      offscreen2.endDraw();
    }

    // Apply the texture to the globe only if the mirroring is deactivated
    if (!this.isMirrored.isOn()) globe.setTexture(offscreen);
  }

  public void onDraw(UI ui, PGraphics pg) {

    // Choose is using the shader as environmental map or as texture on top of enerything else
    // And if mirrored, show it on a cube rather than a globe
    if (this.isEnvironmentalMap.isOn()) {
      if (this.isMirrored.isOn()) {
        TexturedCube(pg, offscreen2, 10000);
      } else {
        pg.shape(globe);
      }
    }

    if (this.isTexture.isOn()) {
      pg.push();
      pg.camera(0, 0, (pg.height/1.25), 0, 0, 0, 0, 1, 0);
      pg.translate(0, 0, (pg.height/1.25)-10);
      pg.noStroke();
      pg.blendMode(ADD);
      pg.imageMode(CENTER);
      // If the mirror effect is ON, apply the second (mirrored) offscreen
      if (this.isMirrored.isOn()) pg.image(offscreen2, 0, 0, pg.width/48, pg.height/48);
      else pg.image(offscreen, 0, 0, pg.width/48, pg.height/48);

      pg.pop();
    }
  }
}

/*
 * Waves effect in GLSL
 * Copyright 2020 - Giovanni Muzio
 * https://kesson.io
 *
 */

class UIWaves extends UIVisual {

  PShader shader;
  PShader kaleida;
  PShape box;
  PShape globe;
  PGraphics offscreenShader;
  PGraphics offscreenTexture;
  float time = 0;

  public final ColorParameter c1color = 
    new ColorParameter("Channel 1", rgbf(0.9f, 0.2f, 0.2f));

  public final ColorParameter c2color = 
    new ColorParameter("Channel 2", rgbf(0.2f, 0.9f, 0.2f));

  public final ColorParameter c3color = 
    new ColorParameter("Channel 3", rgbf(0.2f, 0.2f, 0.9f));

  public final ColorParameter c4color = 
    new ColorParameter("Channel 4", rgbf(0.9f, 0.9f, 0.2f));

  public final BoundedParameter c1opacity =
    new BoundedParameter("C1 Opacity", 1.0f, 0.0f, 1.0f)
    .setDescription("The sections of the kaleidoscope");

  public final BoundedParameter c2opacity =
    new BoundedParameter("C2 Opacity", 1.0f, 0.0f, 1.0f)
    .setDescription("The sections of the kaleidoscope");

  public final BoundedParameter c3opacity =
    new BoundedParameter("C3 opacity", 1.0f, 0.0f, 1.0f)
    .setDescription("The sections of the kaleidoscope");

  public final BoundedParameter c4opacity =
    new BoundedParameter("C4 Opacity", 1.0f, 0.0f, 1.0f)
    .setDescription("The sections of the kaleidoscope");

  public final BooleanParameter isVertical =
    new BooleanParameter("Vertical", true)
    .setDescription("Wheter the waves are vertical or horizontal");

  public final BooleanParameter isElliptical =
    new BooleanParameter("Elliptical", true)
    .setDescription("Wheter the waves are elliptical");

  public final BooleanParameter isMirrored =
    new BooleanParameter("Mirroring", false)
    .setDescription("If mirrored, the visual is specular on both X and Y axes");

  public final BooleanParameter isKaleidoscope =
    new BooleanParameter("Kaleidoscope", true)
    .setDescription("The kaleidoscopic effect");

  public final BooleanParameter isSoundReactive =
    new BooleanParameter("Sound Reactive", true)
    .setDescription("Is it sound reactive?");

  public final BooleanParameter isEnvironmentalMap =
    new BooleanParameter("Environmental Map", true)
    .setDescription("Either it is as envmap (spherical) or as a cubemap (box)");

  public final BoundedParameter sections =
    new BoundedParameter("sections", 4.0f, 1.0f, 64.0f)
    .setDescription("The sections of the kaleidoscope");

  public UIWaves() {

    addParameter("isVertical", this.isVertical);
    addParameter("isElliptical", this.isElliptical);
    addParameter("isMirrored", this.isMirrored);
    addParameter("isKaleidoscope", this.isKaleidoscope);
    addParameter("isEnvMap", this.isEnvironmentalMap);

    addParameter("Sound Reactive", this.isSoundReactive);

    addParameter("sections", this.sections);

    addParameter("C1 Color", this.c1color);
    addParameter("C2 Color", this.c2color);
    addParameter("C3 Color", this.c3color);
    addParameter("C4 Color", this.c4color);

    addParameter("C1 Opacity", this.c1opacity);
    addParameter("C2 Opacity", this.c2opacity);
    addParameter("C3 Opacity", this.c3opacity);
    addParameter("C4 Opacity", this.c4opacity);

    offscreenShader = createGraphics(1000, 1000, P3D);
    offscreenTexture = createGraphics(1000, 1000, P3D);

    shader = loadShader("./data/shaders/WavesFrag.glsl");
    shader.set("iTime", 0.0f);
    shader.set("iResolution", float(width), float(height));

    shader.set("isElliptical", this.isElliptical.isOn());
    shader.set("isVertical", this.isVertical.isOn());

    shader.set("channel1Volume", 1.0);
    shader.set("channel2Volume", 1.0);
    shader.set("channel3Volume", 1.0);
    shader.set("channel4Volume", 1.0);

    setShaderColor("channel1Color", this.c1color);
    setShaderColor("channel2Color", this.c2color);
    setShaderColor("channel3Color", this.c3color);
    setShaderColor("channel4Color", this.c4color);

    shader.set("channel1Opacity", this.c1opacity.getValuef());
    shader.set("channel2Opacity", this.c2opacity.getValuef());
    shader.set("channel3Opacity", this.c3opacity.getValuef());
    shader.set("channel4Opacity", this.c4opacity.getValuef());

    kaleida = loadShader("./data/shaders/KaleidaFilter.glsl");
    kaleida.set("iResolution", float(width), float(height));
    kaleida.set("iTime", 0.0f);
    kaleida.set("sections", 4.0f);
    kaleida.set("txTime", 0.0);
    kaleida.set("offset", 0.5);

    noStroke();
    box = createShape(BOX, 10000);
    globe = createShape(SPHERE, 10000);

    setVisible(false);
  }

  private int rgbf(float r, float g, float b) {
    return LXColor.rgb((int) (r*255), (int) (g*255), (int) (b*255));
  }

  private void setShaderColor(String attribute, ColorParameter clr) {
    int c = clr.getColor();
    float r = ((c & 0xff0000) >> 16) / 255f;
    float g = ((c & 0xff00) >> 8) / 255f;
    float b = (c & 0xff) / 255f;
    shader.set(attribute, r, g, b);
  }

  public String getName() {
    return "Waves";
  }

  public void beforeDraw(UI ui) {

    kaleida.set("iTime", time);
    kaleida.set("iResolution", float(width), float(height));
    kaleida.set("sections", this.sections.getValuef());
    kaleida.set("txTime", 0.0);
    kaleida.set("offset", 0.5);

    shader.set("iTime", time);
    shader.set("iResolution", float(width), float(height));

    shader.set("isElliptical", this.isElliptical.isOn());
    shader.set("isVertical", this.isVertical.isOn());

    // Set the volumes
    // If it is sound reactive, set the values to the sound
    // Otherwise just put the values to 1.0, full opacity (or full volume for each channel)
    for (int i = 1; i < 5; i++) {
      String param = "channel" + i + "Volume";
      float value = this.isSoundReactive.isOn() ? envelop.decode.channels[i].getNormalizedf() : 0.6;
      shader.set(param, value);
    }

    setShaderColor("channel1Color", this.c1color);
    setShaderColor("channel2Color", this.c2color);
    setShaderColor("channel3Color", this.c3color);
    setShaderColor("channel4Color", this.c4color);

    shader.set("channel1Opacity", this.c1opacity.getValuef());
    shader.set("channel2Opacity", this.c2opacity.getValuef());
    shader.set("channel3Opacity", this.c3opacity.getValuef());
    shader.set("channel4Opacity", this.c4opacity.getValuef());

    time += 0.01;

    offscreenShader.beginDraw();
    offscreenShader.background(0);
    offscreenShader.noStroke();
    offscreenShader.shader(shader);
    offscreenShader.rect(0, 0, offscreenShader.width, offscreenShader.height);
    offscreenShader.endDraw();

    offscreenTexture.beginDraw();
    offscreenTexture.background(0);
    offscreenTexture.noStroke();

    if (this.isKaleidoscope.isOn()) {

      offscreenTexture.push();
      offscreenTexture.image(offscreenShader, 0, 0, offscreenTexture.width/1, offscreenTexture.height/1);
      offscreenTexture.pop();

      offscreenTexture.filter(kaleida);
    } else {

      if (!this.isMirrored.isOn()) {

        offscreenTexture.push();
        offscreenTexture.image(offscreenShader, 0, 0, offscreenTexture.width, offscreenTexture.height);
        offscreenTexture.pop();
      } else {

        int w_ = offscreenTexture.width/2;
        int h_ = offscreenTexture.height/2;

        offscreenTexture.push();
        offscreenTexture.image(offscreenShader, 0, 0, w_, h_);
        offscreenTexture.pop();

        offscreenTexture.push();
        offscreenTexture.translate(offscreenTexture.width, 0);
        offscreenTexture.scale(-1, 1);
        offscreenTexture.image(offscreenShader, 0, 0, w_, h_);
        offscreenTexture.pop();

        offscreenTexture.push();
        offscreenTexture.translate(offscreenTexture.width, offscreenTexture.height);
        offscreenTexture.scale(-1, -1);
        offscreenTexture.image(offscreenShader, 0, 0, w_, h_);
        offscreenTexture.pop();

        offscreenTexture.push();
        offscreenTexture.translate(0, offscreenTexture.height);
        offscreenTexture.scale(1, -1);
        offscreenTexture.image(offscreenShader, 0, 0, w_, h_);
        offscreenTexture.pop();
      }
    }

    offscreenTexture.endDraw();

    if (this.isEnvironmentalMap.isOn()) globe.setTexture(offscreenTexture);
    else box.setTexture(offscreenTexture);
  }

  public void onDraw(UI ui, PGraphics pg) {

    if (this.isEnvironmentalMap.isOn()) {
      pg.push();
      pg.shape(globe);
      pg.pop();
    } else {
      pg.push();
      pg.shape(globe);
      pg.pop();
    }
  }
}

/*
 * Moire cloud
 * Copyright 2020 - Giovanni Muzio
 * https://kesson.io
 *
 */

class UIMoire extends UIVisual {

  private class Geometry {
    float[] glVertex;
    float[] glExternal;
    float[] glNoise;

    int vertLoc;
    int externalLoc;
    int noiseLoc;

    PGL pgl;

    PShader sh;

    FloatBuffer pointBuffer;
    FloatBuffer externalBuffer;
    FloatBuffer noiseBuffer;

    int vertexVboId;
    int externalVboId;
    int noiseVboId;

    int totalloop;

    // Hue, saturation and brightness for HSB colorama effect
    // Color changing over a period of time
    float hue = 0, saturation = 277, brightness = 313;

    Geometry(PGraphics pg, int total) {      
      totalloop = (total * total) * 2;
      this.sh = pg.loadShader("./data/shaders/hyperkosmo/fragment.glsl", "./data/shaders/hyperkosmo/vertex.glsl");

      this.glVertex = new float[totalloop*3];
      this.glExternal = new float[totalloop];
      this.glNoise = new float[totalloop*2];

      PGL pgl = pg.beginPGL();
      this.sh.bind();
      this.sh.set("time", millis() / 1000.0);
      this.sh.set("radius", 0.0);
      this.sh.set("eRadius", 0.0);
      this.sh.set("color", 1.0f, 1.0f, 1.0f);

      this.vertLoc = pgl.getAttribLocation(sh.glProgram, "vertex");
      this.externalLoc = pgl.getAttribLocation(sh.glProgram, "isExternal");
      this.noiseLoc = pgl.getAttribLocation(sh.glProgram, "noise");

      IntBuffer intBuffer = IntBuffer.allocate(3);

      pgl.genBuffers(3, intBuffer);

      this.vertexVboId = intBuffer.get(0);
      this.externalVboId = intBuffer.get(1);
      this.noiseVboId = intBuffer.get(2);

      this.sh.unbind();
      pg.endPGL();

      float nx = 0;
      float ny = 0;

      int pIndex = 0;
      int rIndex = 0;
      int nIndex = 0;

      for (int i = 0; i < total; i++) {

        float lat = map(i, 0, total-1, 0, PI);

        nx = sin(lat);

        for (int j = 0; j < total; j++) {

          float lon = map(j, 0, total-1, 0, TWO_PI);

          ny = sin(lon);

          this.glVertex[pIndex + 0] = sin(lat) * cos(lon);
          this.glVertex[pIndex + 1] = sin(lat) * sin(lon);
          this.glVertex[pIndex + 2] = cos(lat);
          this.glVertex[pIndex + 3] = sin(lat) * cos(lon);
          this.glVertex[pIndex + 4] = sin(lat) * sin(lon);
          this.glVertex[pIndex + 5] = cos(lat);
          pIndex += 6;

          if (rIndex%2 == 0) this.glExternal[rIndex] = 0.0;
          else this.glExternal[rIndex] = 1.0;
          rIndex++;
          if (rIndex%2 == 0) this.glExternal[rIndex] = 0.0;
          else this.glExternal[rIndex] = 1.0;
          rIndex++;

          glNoise[nIndex + 0] = nx;
          glNoise[nIndex + 1] = ny;
          glNoise[nIndex + 2] = nx;
          glNoise[nIndex + 3] = ny;
          nIndex += 4;
        }
      }

      pointBuffer = this.allocateDirectFloatBuffer(glVertex.length*2);
      externalBuffer = this.allocateDirectFloatBuffer(glExternal.length);
      noiseBuffer = this.allocateDirectFloatBuffer(glNoise.length);

      pointBuffer.rewind();
      pointBuffer.put(glVertex);
      pointBuffer.rewind();

      externalBuffer.rewind();
      externalBuffer.put(glExternal);
      externalBuffer.rewind();

      noiseBuffer.rewind();
      noiseBuffer.put(glNoise);
      noiseBuffer.rewind();
    }

    public void setColor(ColorParameter clr) {
      int c = clr.getColor();
      float r = ((c & 0xff0000) >> 16) / 255f;
      float g = ((c & 0xff00) >> 8) / 255f;
      float b = (c & 0xff) / 255f;
      this.sh.set("color", r, g, b);
    }

    // c is color, t is time, or frequency
    public void setColorama(float t) {
      float frequencyMilliseconds = t * 1000.0;
      float currentTime = millis() % frequencyMilliseconds;
      hue = map(currentTime, 0, frequencyMilliseconds, 0, 360);
      colorMode(HSB, 360);
      color chue = color(hue, saturation, brightness);
      colorMode(RGB, 1);
      float r = red(chue);
      float g = green(chue);
      float b = blue(chue);
      this.sh.set("color", r, g, b);
      colorMode(RGB, 255);
    }

    public void setAlpha(float v) {
      this.sh.set("alpha", v);
    }

    public void setRadius(float v, float e) {
      this.sh.set("radius", v);
      this.sh.set("eRadius", v*e);
    }

    // Set the radius when oscillating, t is the frequency in seconds
    public void setOscillatingRadius(float min, float max, float e, float t) {
      float frequencyMilliseconds = t * 1000.0;
      float currentTime = millis() % frequencyMilliseconds;
      float newMax = max - min;
      float r = min + sin(max(0.0, map(currentTime, 0, frequencyMilliseconds, 0, PI))) * newMax;
      this.sh.set("radius", r);
      this.sh.set("eRadius", r * e);
    }
    
    public void setTime(float f) {
       float normalizedTime = millis() / 1000.0;  // Normalize time from millis to seconds
       this.sh.set("time", normalizedTime * f);
    }

    public void run(PGraphics pg) {

      pgl = pg.beginPGL();

      this.sh.bind();

      //
      /* VERTEX */
      pgl.enableVertexAttribArray(vertLoc);
      int vertData = glVertex.length;
      pgl.bindBuffer(PGL.ARRAY_BUFFER, vertexVboId);
      pgl.bufferData(PGL.ARRAY_BUFFER, Float.BYTES * vertData, pointBuffer, PGL.DYNAMIC_DRAW);
      pgl.vertexAttribPointer(vertLoc, 3, PGL.FLOAT, false, Float.BYTES * 3, 0 );

      //
      /* RADIUS */
      pgl.enableVertexAttribArray(externalLoc);
      int externalData = glExternal.length;
      pgl.bindBuffer(PGL.ARRAY_BUFFER, externalVboId);
      pgl.bufferData(PGL.ARRAY_BUFFER, Float.BYTES * externalData, externalBuffer, PGL.DYNAMIC_DRAW);
      pgl.vertexAttribPointer(externalLoc, 1, PGL.FLOAT, false, Float.BYTES, 0 );

      //
      /* NOISE */
      pgl.enableVertexAttribArray(noiseLoc);
      int noiseData = glNoise.length;
      pgl.bindBuffer(PGL.ARRAY_BUFFER, noiseVboId);
      pgl.bufferData(PGL.ARRAY_BUFFER, Float.BYTES * noiseData, noiseBuffer, PGL.DYNAMIC_DRAW);
      pgl.vertexAttribPointer(noiseLoc, 2, PGL.FLOAT, false, Float.BYTES * 2, 0 );

      //
      /* DRAW */
      pgl.bindBuffer(PGL.ARRAY_BUFFER, 0);
      pgl.drawArrays(PGL.LINES, 0, vertData);

      pgl.disableVertexAttribArray(vertLoc);
      pgl.disableVertexAttribArray(externalLoc);
      pgl.disableVertexAttribArray(noiseLoc);

      pgl.bindBuffer(PGL.ARRAY_BUFFER, 0);

      this.sh.unbind();
      pg.endPGL();
    }

    private FloatBuffer allocateDirectFloatBuffer(int n) {
      return ByteBuffer.allocateDirect(n * Float.BYTES).order(ByteOrder.nativeOrder()).asFloatBuffer();
    }
  }

  public final ColorParameter nColor = 
    new ColorParameter("Color", rgbf(0.9f, 0.2f, 0.2f));

  public final BoundedParameter alpha =
    new BoundedParameter("alpha", 0.25f, 0.0f, 1.0f)
    .setDescription("Alpha channel of the moire shape");

  public final BoundedParameter radius =
    new BoundedParameter("radius", 1000.0f, 250.0f, 10000.0f)
    .setDescription("The radius of the globe");

  public final BoundedParameter size =
    new BoundedParameter("Size", 5.0f, 0.0f, 20.0f)
    .setDescription("The size of the globe");

  public final BoundedParameter speed =
    new BoundedParameter("Speed", 0.25f, 0.1f, 2.0f)
    .setDescription("The speed of the globe");

  public final BooleanParameter isColorama =
    new BooleanParameter("Colorama", false)
    .setDescription("Change the color over time");

  public final BoundedParameter coloramaTime =
    new BoundedParameter("Colorama Time", 10.0f, 0.1f, 60.0f)
    .setDescription("Frequency of colorama, in seconds");

  public final BooleanParameter isOscillatingRadius =
    new BooleanParameter("Oscillating Radius", false)
    .setDescription("Oscillate the value of the radius over time");

  public final BoundedParameter oscillatingFrequency =
    new BoundedParameter("Radius frequency", 10.0f, 0.1f, 300.0f)
    .setDescription("Minimum value of radius when changing over time");

  public final BoundedParameter radiusMin =
    new BoundedParameter("RadiusMin", 1500.0f, 250.0f, 9750.0f)
    .setDescription("Minimum value of radius when changing over time");

  public final BoundedParameter radiusMax =
    new BoundedParameter("RadiusMax", 8500.0f, 250.0f, 10000.0f)
    .setDescription("Maximum value of radius when changing over time");

  public String getName() {
    return "Moire";
  }

  private int rgbf(float r, float g, float b) {
    return LXColor.rgb((int) (r*255), (int) (g*255), (int) (b*255));
  }

  Geometry geometry;
  PShape environment;

  public UIMoire() {
    addParameter("Color", this.nColor);
    addParameter("Alpha", this.alpha);
    addParameter("Radius", this.radius);
    addParameter("Size", this.size);
    addParameter("Speed", this.speed);
    addParameter("Colorama", this.isColorama);
    addParameter("Colorama Time", this.coloramaTime);
    addParameter("Oscillating Radius", this.isOscillatingRadius);
    addParameter("Oscillating Frequency", this.oscillatingFrequency);
    addParameter("RadiusMin", this.radiusMin);
    addParameter("RadiusMax", this.radiusMax);

    noStroke();
    fill(0);
    this.environment = createShape(SPHERE, 10000);

    setVisible(false);
  }

  public void beforeDraw(UI ui) {
    float alpha = this.alpha.getValuef();
    float radius = this.radius.getValuef();
    float size = this.size.getValuef();
    float speed = this.speed.getValuef();
    if (this.geometry != null) {
      this.geometry.setColor(this.nColor);
      this.geometry.setAlpha(alpha);
      this.geometry.setRadius(radius, size);
      this.geometry.setTime(speed);
      // If the colorama effect is on, change it over time
      if (this.isColorama.isOn()) {
        float f = this.coloramaTime.getValuef(); // Frequency in seconds
        this.geometry.setColorama(f);
      }

      // If the radius is oscillating
      if (this.isOscillatingRadius.isOn()) {
        float radiusMin = this.radiusMin.getValuef();
        float radiusMax = this.radiusMax.getValuef();
        float frequency = this.oscillatingFrequency.getValuef();
        this.geometry.setOscillatingRadius(radiusMin, radiusMax, size, frequency);
      }
    }
  }

  public void onDraw(UI ui, PGraphics pg) {

    if (this.geometry == null) this.geometry = new Geometry(pg, 500);

    pg.push();
    pg.shape(environment);
    pg.blendMode(ADD);
    this.geometry.run(pg);
    pg.pop();
  }
}



/*
 * Worley Texture effect in GLSL
 * Copyright 2020 - Giovanni Muzio
 * https://kesson.io
 *
 */

class UIWorleyBulb extends UIVisual {

  private PShader shader;
  private PShape globe;
  private float time;

  public final ColorParameter baseColor = 
    new ColorParameter("Color", rgbf(0.086f, 0.01f, 0.20f));  

  public final BoundedParameter mode =
    new BoundedParameter("Mode", 0.0f, 0.0f, 2.0f)
    .setDescription("Draw mode");

  public final BoundedParameter amount =
    new BoundedParameter("Amount", 1.0f, 1.0f, 16.0f)
    .setDescription("The size of the cells - bigger numbers -> smaller cells");

  public final BoundedParameter rainbowAmount =
    new BoundedParameter("colorAmount", 0.05, 0.0, 1.0)
    .setDescription("The saturation when in rainbow mode");

  public final BoundedParameter alpha =
    new BoundedParameter("Alpha", 1.0f, 0.0f, 1.0f) 
    .setDescription("Alpha of the object");  

  public final BooleanParameter isRainbow =
    new BooleanParameter("Rainbow mode", false)
    .setDescription("Wether the rainbow color is applied to the globe");

  public final BooleanParameter negative =
    new BooleanParameter("Negative", false)
    .setDescription("Is the shader in negative mode?");

  public final BoundedParameter speed =
    new BoundedParameter("Speed", 0.01f, 0.01f, 0.1f) 
    .setDescription("Alpha of the object");  

  public UIWorleyBulb() {
    addParameter("Speed", this.speed);
    addParameter("Color", this.baseColor);
    addParameter("Mode", this.mode);
    addParameter("Amount", this.amount);
    addParameter("Alpha", this.alpha);
    addParameter("Negative", this.negative);
    addParameter("isRainbow", this.isRainbow);
    addParameter("Rainbow Amount", this.rainbowAmount);

    this.shader = loadShader("./data/shaders/WorleyBulb/fragment.glsl", "./data/shaders/WorleyBulb/vertex.glsl");

    noStroke();
    this.globe = createShape(SPHERE, 1);

    this.time = 0.0;

    setVisible(false);
  }

  private int rgbf(float r, float g, float b) {
    return LXColor.rgb((int) (r*255), (int) (g*255), (int) (b*255));
  }

  private void setColor(ColorParameter clr) {
    int c = clr.getColor();
    float r = ((c & 0xff0000) >> 16) / 255f;
    float g = ((c & 0xff00) >> 8) / 255f;
    float b = (c & 0xff) / 255f;
    this.shader.set("inputColor", r, g, b);
  }

  public String getName() {
    return "Worley Bulb";
  }

  public void beforeDraw(UI ui) {
    this.shader.set("iTime", this.time);
    this.shader.set("iResolution", float(width), float(height));
    this.shader.set("mode", int(this.mode.getValuef()));
    this.shader.set("amount", this.amount.getValuef());
    this.shader.set("rainbowAmount", this.rainbowAmount.getValuef());
    this.shader.set("alpha", this.alpha.getValuef());
    this.shader.set("rainbow", this.isRainbow.isOn());
    this.shader.set("negative", this.negative.isOn());
    this.setColor(this.baseColor);

    this.time += this.speed.getValuef();
  }

  public void onDraw(UI ui, PGraphics pg) {
    pg.push();
    pg.shader(this.shader);
    pg.scale(1500);
    pg.shape(this.globe);
    pg.pop();
    pg.resetShader();
  }
}



/*
 * Seastorm - EnvelopLX edition
 * Copyright 2020 - Giovanni Muzio
 * https://kesson.io
 *
 */

class UISeastorm extends UIVisual {

  // The Nature of Code
  // Daniel Shiffman
  // http://natureofcode.com

  // Flow Field Following

  private class FlowField {

    // A flow field is a two dimensional array of PVectors
    PVector[][] field;
    int cols, rows; // Columns and Rows
    int resolution; // How large is each "cell" of the flow field

    float zoff = 0.0; // 3rd dimension of noise

    FlowField(int w, int h, int r) {
      resolution = r;
      // Determine the number of columns and rows based on sketch's width and height
      cols = w/resolution;
      rows = h/resolution;
      field = new PVector[cols][rows];
      init();
    }

    void init() {
      // Reseed noise so we get a new flow field every time
      noiseSeed((int)random(10000));
      float xoff = 0;
      for (int i = 0; i < cols; i++) {
        float yoff = 0;
        for (int j = 0; j < rows; j++) {
          float theta = map(noise(xoff, yoff), 0, 1, 0, TWO_PI);
          // Polar to cartesian coordinate transformation to get x and y components of the vector
          field[i][j] = new PVector(cos(theta), sin(theta));
          yoff += 0.1;
        }
        xoff += 0.1;
      }
    }

    void update() {
      float xoff = 0;
      for (int i = 0; i < cols; i++) {
        float yoff = 0;
        for (int j = 0; j < rows; j++) {
          float theta = map(noise(xoff, yoff, zoff), 0, 1, 0, TWO_PI);
          // Make a vector from an angle
          field[i][j] = PVector.fromAngle(theta);
          yoff += 0.1;
        }
        xoff += 0.1;
      }
      // Animate by changing 3rd dimension of noise every frame
      zoff += 0.01;
    }

    PVector lookup(PVector lookup) {
      int column = int(constrain(lookup.x/resolution, 0, cols-1));
      int row = int(constrain(lookup.y/resolution, 0, rows-1));
      return field[column][row].copy();
    }
  }

  // The Nature of Code
  // Daniel Shiffman
  // http://natureofcode.com

  // Flow Field Following

  private class Vehicle {

    // The usual stuff
    PVector position;
    PVector velocity;
    PVector acceleration;
    float r;
    float maxforce;    // Maximum steering force
    float maxspeed;    // Maximum speed
    float actualSpeed = 1;
    float multiplier = 1;

    Vehicle(PVector l, float ms, float mf) {
      position = l.copy();
      r = 3.0;
      maxspeed = ms;
      maxforce = mf;
      acceleration = new PVector(0, 0);
      velocity = new PVector(0, 0);
      actualSpeed = maxspeed;
    }

    public void run() {
      update();
      borders();
    }


    // Implementing Reynolds' flow field following algorithm
    // http://www.red3d.com/cwr/steer/FlowFollow.html
    void follow(FlowField flow) {
      // What is the vector at that spot in the flow field?
      PVector desired = flow.lookup(position);
      // Scale it up by maxspeed
      desired.mult(maxspeed);
      // Steering is desired minus velocity
      PVector steer = PVector.sub(desired, velocity);
      steer.limit(maxforce);  // Limit to maximum steering force
      applyForce(steer);
    }

    void applyForce(PVector force) {
      // We could add mass here if we want A = F / M
      acceleration.add(force);
    }

    // Method to update position
    void update() {
      actualSpeed = lerp(actualSpeed, maxspeed, 0.05);
      //multiplier = lerp(multiplier, .5, 0.1);
      multiplier = lerp(multiplier, 1, 0.1);
      // Update velocity
      velocity.sub(acceleration);
      // Limit speed
      velocity.limit(maxspeed);
      velocity.mult(multiplier);
      position.add(velocity);
      // Reset accelertion to 0 each cycle
      acceleration.mult(0);
    }

    // Wraparound
    void borders() {
      if (position.x < -r) position.x = width+r;
      if (position.y < -r) position.y = height+r;
      if (position.x > width+r) position.x = -r;
      if (position.y > height+r) position.y = -r;
    }
  }

  private class Geometry {

    // Flowfield object
    FlowField flowfield;
    // An ArrayList of vehicles
    ArrayList<Vehicle> vehicles;

    // Offscreen render
    PGraphics offscreen, offscreen2;

    // Environmental globe
    PShape globe;

    // OpenGL 
    float[] glVertex;

    int vertLoc;

    PGL pgl;

    PShader sh;

    FloatBuffer pointBuffer;

    int vertexVboId;

    Geometry(PGraphics pg, int total) { 

      offscreen = createGraphics(1000, 1000, P3D);
      offscreen.beginDraw();
      offscreen.background(0, 0, 0);
      offscreen.endDraw();

      offscreen2 = createGraphics(1000, 1000, P3D);
      offscreen2.beginDraw();
      offscreen2.background(0, 0, 0);
      offscreen2.endDraw();

      flowfield = new FlowField(offscreen.width, offscreen.height, 40);
      vehicles = new ArrayList<Vehicle>();

      // Make a whole bunch of vehicles with random maxspeed and maxforce values
      for (int i = 0; i < total; i++) {
        vehicles.add(new Vehicle(new PVector(random(offscreen.width), random(offscreen.height)), random(0.05, 0.5)*4, random(0.1, 0.5)*500));
      }

      noStroke();
      globe = createShape(SPHERE, 10000);

      this.sh = pg.loadShader("./data/shaders/seastorm/fragment.glsl", "./data/shaders/seastorm/vertex.glsl");

      this.glVertex = new float[total*3];

      PGL pgl = beginPGL();
      this.sh.bind();
      this.sh.set("color", 0.1960, 0.6235, 0.8823, 0.15);

      this.vertLoc = pgl.getAttribLocation(sh.glProgram, "vertex");

      IntBuffer intBuffer = IntBuffer.allocate(1);

      pgl.genBuffers(1, intBuffer);

      this.vertexVboId = intBuffer.get(0);

      this.sh.unbind();
      endPGL();

      int index = 0;

      for (Vehicle v : vehicles) {

        this.glVertex[index + 0] = v.position.x;
        this.glVertex[index + 1] = v.position.y;
        this.glVertex[index + 2] = v.position.z;

        index += 3;
      }

      pointBuffer = this.allocateDirectFloatBuffer(glVertex.length);

      pointBuffer.rewind();
      pointBuffer.put(glVertex);
      pointBuffer.rewind();
    }

    public void setColor(ColorParameter clr, float a) {
      int c = clr.getColor();
      float r = ((c & 0xff0000) >> 16) / 255f;
      float g = ((c & 0xff00) >> 8) / 255f;
      float b = (c & 0xff) / 255f;
      this.sh.set("color", r, g, b, a);
    }

    public void setColorama(float r, float g, float b, float a) {
      this.sh.set("color", r, g, b, a);
    }

    public void run(boolean mirror) {
      offscreen.beginDraw();
      offscreen.blendMode(NORMAL);
      offscreen.fill(0, 25);
      offscreen.noStroke();
      offscreen.rectMode(CORNER);
      offscreen.rect(0, 0, offscreen.width, offscreen.height);
      offscreen.blendMode(ADD);

      flowfield.update();

      for (Vehicle v : vehicles) {
        v.follow(flowfield);
        v.run();
      }

      int index = 0;

      for (Vehicle v : vehicles) {

        this.glVertex[index + 0] = v.position.x;
        this.glVertex[index + 1] = v.position.y;
        this.glVertex[index + 2] = v.position.z;

        index += 3;
      }

      pointBuffer = this.allocateDirectFloatBuffer(glVertex.length);

      pointBuffer.rewind();
      pointBuffer.put(glVertex);
      pointBuffer.rewind();

      pgl = offscreen.beginPGL();

      this.sh.bind();

      //
      /* VERTEX */
      pgl.enableVertexAttribArray(vertLoc);
      int vertData = glVertex.length;
      pgl.bindBuffer(PGL.ARRAY_BUFFER, vertexVboId);
      pgl.bufferData(PGL.ARRAY_BUFFER, Float.BYTES * vertData, pointBuffer, PGL.DYNAMIC_DRAW);
      pgl.vertexAttribPointer(vertLoc, 3, PGL.FLOAT, false, Float.BYTES * 3, 0 );

      //
      /* DRAW */
      pgl.bindBuffer(PGL.ARRAY_BUFFER, 0);
      pgl.drawArrays(PGL.POINTS, 0, vertData);

      pgl.disableVertexAttribArray(vertLoc);

      pgl.bindBuffer(PGL.ARRAY_BUFFER, 0);

      this.sh.unbind();
      offscreen.endPGL();

      offscreen.endDraw();

      // Mirror the shader on the second offscreen
      if (mirror) {
        int w_ = offscreen2.width/2;
        int h_ = offscreen2.height/2;
        offscreen2.beginDraw();

        offscreen2.image(offscreen, 0, 0, w_, h_);

        offscreen2.pushMatrix();
        offscreen2.translate(offscreen2.width, 0);
        offscreen2.scale(-1, 1);
        offscreen2.image(offscreen, 0, 0, w_, h_);
        offscreen2.popMatrix();

        offscreen2.pushMatrix();
        offscreen2.translate(offscreen2.width, offscreen2.height);
        offscreen2.scale(-1, -1);
        offscreen2.image(offscreen, 0, 0, w_, h_);
        offscreen2.popMatrix();

        offscreen2.pushMatrix();
        offscreen2.translate(0, offscreen2.height);
        offscreen2.scale(1, -1);
        offscreen2.image(offscreen, 0, 0, w_, h_);
        offscreen2.popMatrix();

        offscreen2.endDraw();
      }
    }

    // A method to show the offscreen shader
    // To fix the angles not mathing at the top and bottom corners
    private void TexturedCube(PGraphics pg, PGraphics tex, int p) {
      int s = p * 2;

      pg.blendMode(NORMAL);

      pg.push();
      pg.translate(0, 0, p);
      pg.imageMode(CENTER);
      pg.image(tex, 0, 0, s, s);
      pg.pop();

      pg.push();
      pg.translate(-p, 0, 0);
      pg.rotateY(HALF_PI);
      pg.imageMode(CENTER);
      pg.image(tex, 0, 0, s, s);
      pg.pop();

      pg.push();
      pg.translate(p, 0, 0);
      pg.rotateY(-HALF_PI);
      pg.imageMode(CENTER);
      pg.image(tex, 0, 0, s, s);
      pg.pop();

      pg.push();
      pg.translate(0, 0, -p);
      pg.imageMode(CENTER);
      pg.image(tex, 0, 0, s, s);
      pg.pop();

      pg.push();
      pg.translate(0, -p-1, 0);
      pg.imageMode(CENTER);
      pg.rotateX(HALF_PI);
      pg.rotateZ(HALF_PI);
      pg.image(tex, 0, 0, s, s);
      pg.pop();

      pg.blendMode(LIGHTEST);
      pg.push();
      pg.translate(0, -p, 0);
      pg.imageMode(CENTER);
      pg.rotateX(HALF_PI);
      pg.image(tex, 0, 0, s, s);
      pg.pop();

      pg.blendMode(NORMAL);

      pg.push();
      pg.translate(0, p+1, 0);
      pg.imageMode(CENTER);
      pg.rotateX(HALF_PI);
      pg.rotateZ(HALF_PI);
      pg.image(tex, 0, 0, s, s);
      pg.pop();

      pg.blendMode(LIGHTEST);
      pg.push();
      pg.translate(0, p, 0);
      pg.imageMode(CENTER);
      pg.rotateX(HALF_PI);
      pg.image(tex, 0, 0, s, s);
      pg.pop();

      pg.blendMode(NORMAL);
    }

    public void display(PGraphics pg, boolean mirror) {
      pg.push();
      if (mirror) {
        //globe.setTexture(offscreen2);
        TexturedCube(pg, offscreen2, 10000);
      } else {
        globe.setTexture(offscreen);
        pg.shape(globe);
      }
      pg.pop();
    }

    private FloatBuffer allocateDirectFloatBuffer(int n) {
      return ByteBuffer.allocateDirect(n * Float.BYTES).order(ByteOrder.nativeOrder()).asFloatBuffer();
    }
  }

  // Parameters
  public final ColorParameter nColor = 
    new ColorParameter("Color", rgbf(0.1960, 0.6235, 0.8823));

  public final BoundedParameter alpha =
    new BoundedParameter("Alpha", 0.05, 0.01f, 0.5f)
    .setDescription("The size of the rocks");

  public final BooleanParameter isColorama =
    new BooleanParameter("Colorama", false)
    .setDescription("Automatically changes color");

  public final BooleanParameter isMirror =
    new BooleanParameter("Mirror", false)
    .setDescription("Automatically changes color");

  public String getName() {
    return "Seastorm";
  }

  private int rgbf(float r, float g, float b) {
    return LXColor.rgb((int) (r*255), (int) (g*255), (int) (b*255));
  }

  Geometry geometry;

  public UISeastorm() {
    addParameter("Color", this.nColor);
    addParameter("Alpha", this.alpha);
    addParameter("Colorama", this.isColorama);
    addParameter("Mirror", this.isMirror);

    setVisible(false);
  }

  public void beforeDraw(UI ui) {
    if (this.geometry != null) {
      if (!this.isColorama.isOn()) {
        this.geometry.setColor(this.nColor, this.alpha.getValuef());
      } else {
        colorMode(HSB, 360);
        float h = ((cos(frameCount*0.005) * 0.5) + 0.5) * 360;
        float s = 270;
        float b = 310;
        color c = color(h, s, b);
        colorMode(RGB, 1);
        this.geometry.setColorama(red(c), green(c), blue(c), this.alpha.getValuef());
        colorMode(RGB, 255);
      }
      geometry.run(this.isMirror.isOn());
    }
  }

  public void onDraw(UI ui, PGraphics pg) {

    pg.push();

    if (this.geometry == null) this.geometry = new Geometry(pg, 100000);

    geometry.display(pg, this.isMirror.isOn());

    pg.pop();
  }
}



///*
// * AI Env
// * Copyright 2020 - Giovanni Muzio
// * https://kesson.io
// *
// */

import processing.video.*;

class UIArtificialEnvironment extends UIVisual {

  private class Geometry {

    Movie movie;

    float[] glVertex;
    float[] glUv;

    int vertLoc;
    int uvLoc;

    PGL pgl;

    PShader sh;

    FloatBuffer pointBuffer;
    FloatBuffer uvBuffer;

    int vertexVboId;
    int uvVboId;

    int totalloop;

    PGraphics offscreen, offscreen2;

    Geometry(PGraphics pg, int total) {      

      movie = new Movie(EnvelopLX.this, "ai_nebulas.mp4");
      movie.loop();
      movie.read();

      offscreen = createGraphics(movie.width, movie.height, P3D);
      offscreen2 = createGraphics(movie.width * 2, movie.height * 2, P3D);

      totalloop = total * total;

      this.sh = pg.loadShader("./data/shaders/aienv/fragment.glsl", "./data/shaders/aienv/vertex.glsl");

      this.glVertex = new float[totalloop*3];
      this.glUv = new float[totalloop * 2];

      //this.sh.set("txtIn", null);
      this.sh.set("radius", 2000.0);
      this.sh.set("noiseDepth", 1000.0);

      PGL pgl = pg.beginPGL();
      this.sh.bind();

      this.vertLoc = pgl.getAttribLocation(sh.glProgram, "vertex");
      this.uvLoc = pgl.getAttribLocation(sh.glProgram, "uv");

      IntBuffer intBuffer = IntBuffer.allocate(2);

      pgl.genBuffers(2, intBuffer);

      this.vertexVboId = intBuffer.get(0);
      this.uvVboId = intBuffer.get(1);

      this.sh.unbind();

      pg.endPGL();

      int vIndex = 0;
      int uvIndex = 0;

      for (int i = 0; i < total; i++) {

        float lat = map(i, 0, total-1, 0, PI);

        for (int j = 0; j < total; j++) {

          float lon = map(j, 0, total-1, 0, TWO_PI);

          this.glVertex[vIndex + 0] = sin(lat) * cos(lon);
          this.glVertex[vIndex + 1] = sin(lat) * sin(lon);
          this.glVertex[vIndex + 2] = cos(lat);

          vIndex += 3;

          glUv[uvIndex + 0] = map(i, 0, total-1, 0, 1);
          glUv[uvIndex + 1] = map(j, 0, total-1, 0, 1);

          uvIndex += 2;
        }
      }

      pointBuffer = this.allocateDirectFloatBuffer(glVertex.length);
      uvBuffer = this.allocateDirectFloatBuffer(glUv.length);

      pointBuffer.rewind();
      pointBuffer.put(glVertex);
      pointBuffer.rewind();

      uvBuffer.rewind();
      uvBuffer.put(glUv);
      uvBuffer.rewind();
    }

    public void setRadius(float v) {
      this.sh.set("radius", v);
    }

    public void setDepth(float v) {
      this.sh.set("noiseDepth", v);
    }

    public void setSound(String channel, float v) {
      this.sh.set(channel, v);
    }   

    public void run(PGraphics pg) {

      this.movie.read();

      offscreen.beginDraw();
      offscreen.background(0);
      offscreen.image(this.movie, 0, 0, offscreen.width, offscreen.height);
      offscreen.endDraw();

      boolean mirror = true;
      // Mirror the shader on the second offscreen
      if (mirror) {
        int w_ = offscreen2.width/2;
        int h_ = offscreen2.height/2;
        offscreen2.beginDraw();

        offscreen2.image(offscreen, 0, 0, w_, h_);

        offscreen2.pushMatrix();
        offscreen2.translate(offscreen2.width, 0);
        offscreen2.scale(-1, 1);
        offscreen2.image(offscreen, 0, 0, w_, h_);
        offscreen2.popMatrix();

        offscreen2.pushMatrix();
        offscreen2.translate(offscreen2.width, offscreen2.height);
        offscreen2.scale(-1, -1);
        offscreen2.image(offscreen, 0, 0, w_, h_);
        offscreen2.popMatrix();

        offscreen2.pushMatrix();
        offscreen2.translate(0, offscreen2.height);
        offscreen2.scale(1, -1);
        offscreen2.image(offscreen, 0, 0, w_, h_);
        offscreen2.popMatrix();

        offscreen2.endDraw();
      }

      if (mirror) this.sh.set("txtIn", offscreen2);
      else this.sh.set("txtIn", offscreen);

      pgl = pg.beginPGL();

      this.sh.bind();

      //
      /* VERTEX */
      pgl.enableVertexAttribArray(vertLoc);
      int vertData = glVertex.length;
      pgl.bindBuffer(PGL.ARRAY_BUFFER, vertexVboId);
      pgl.bufferData(PGL.ARRAY_BUFFER, Float.BYTES * vertData, pointBuffer, PGL.DYNAMIC_DRAW);
      pgl.vertexAttribPointer(vertLoc, 3, PGL.FLOAT, false, Float.BYTES * 3, 0 );

      //
      /* RADIUS */
      pgl.enableVertexAttribArray(uvLoc);
      int uvData = glUv.length;
      pgl.bindBuffer(PGL.ARRAY_BUFFER, uvVboId);
      pgl.bufferData(PGL.ARRAY_BUFFER, Float.BYTES * uvData, uvBuffer, PGL.DYNAMIC_DRAW);
      pgl.vertexAttribPointer(uvLoc, 2, PGL.FLOAT, false, Float.BYTES * 2, 0 );

      //
      /* DRAW */
      pgl.bindBuffer(PGL.ARRAY_BUFFER, 0);
      pgl.drawArrays(PGL.POINTS, 0, vertData);

      pgl.disableVertexAttribArray(vertLoc);
      pgl.disableVertexAttribArray(uvLoc);

      pgl.bindBuffer(PGL.ARRAY_BUFFER, 0);

      this.sh.unbind();
      pg.endPGL();
    }

    private FloatBuffer allocateDirectFloatBuffer(int n) {
      return ByteBuffer.allocateDirect(n * Float.BYTES).order(ByteOrder.nativeOrder()).asFloatBuffer();
    }
  }

  public final BooleanParameter soundReactive =
    new BooleanParameter("Sound Reactive", false)
    .setDescription("Is it sound reactive?");

  public final BoundedParameter noiseDepth =
    new BoundedParameter("Noise Depth", 1000.0f, 0.0f, 3000.0f)
    .setDescription("How much is the depth map on the sphere");

  public final BoundedParameter radius =
    new BoundedParameter("Radius", 2000.0f, 2.0f, 20000.0f)
    .setDescription("How much is the depth map on the sphere");

  public String getName() {
    return "AI Nebulas";
  }

  Geometry geometry;
  PApplet applet;

  public UIArtificialEnvironment() {

    addParameter("noiseDepth", this.noiseDepth);
    addParameter("Radius", this.radius);
    addParameter("Sound Reactive", this.soundReactive);

    setVisible(false);
  }

  public void beforeDraw(UI ui) {
    if (this.geometry != null) {
      this.geometry.setDepth(this.noiseDepth.getValuef());
      this.geometry.setRadius(this.radius.getValuef());
      for (int i = 0; i < 8; i++) {
        if (this.soundReactive.isOn()) {
          this.geometry.setSound("Channel" + i, envelop.decode.channels[i].getNormalizedf());
        } else {
          this.geometry.setSound("Channel" + i, 0.0);
        }
      }
    }
  }

  public void onDraw(UI ui, PGraphics pg) {

    if (this.geometry == null) this.geometry = new Geometry(pg, 500);

    pg.push();
    this.geometry.run(pg);
    pg.pop();
  }
}



/*
 * Depths effect in GLSL
 * Copyright 2020 - Giovanni Muzio
 * https://kesson.io
 *
 * Port from Timeless Depths
 * Copyright 2020 - Giovanni Muzio
 * https://www.shadertoy.com/view/ttlyWB
 *
 */

class UIDepths extends UIVisual {

  PShader shader, sblur;
  PGraphics offscreen_pass1, offscreen_pass2, offscreen_pass3;
  PShape globe;

  public final BoundedParameter size =
    new BoundedParameter("Size", 0.5, 0.1f, 2.0f)
    .setDescription("The size of the rocks");

  public final BoundedParameter speed1 =
    new BoundedParameter("Speed", 0.0576, 0.0f, 0.5f)
    .setDescription("Speed of evolution");

  public final BoundedParameter speed2 =
    new BoundedParameter("Speed", 0.0565, 0.0f, 0.5f)
    .setDescription("Speed of evolution");

  public final BoundedParameter DoF =
    new BoundedParameter("Depth of Field", 8.0, 5.0f, 32.0f)
    .setDescription("How 'far' we see the rocks");

  public final BoundedParameter blur =
    new BoundedParameter("Blur amount", 7.0, 0.01f, 10.0f)
    .setDescription("The blur amount");

  public final BooleanParameter isWideAngle =
    new BooleanParameter("Wide Angle", true)
    .setDescription("is the camera zoom or wide angle?");

  public final BooleanParameter isTexture =
    new BooleanParameter("Texture", false)
    .setDescription("Wheter the shader is applied as texture on top on the render");

  public final BooleanParameter isSoundReactive =
    new BooleanParameter("Sound Reactive", false)
    .setDescription("Is the shader sound reactive?");

  public final ColorParameter rocksColor = 
    new ColorParameter("Rocks Color", rgbf(0.1, 0.4, 1.0)); 

  public final ColorParameter waterColor = 
    new ColorParameter("Water Color", rgbf(0.05, 0.18, 0.38)); 

  public UIDepths() {

    // Offscreen PGraphics
    int pgw = 1080, pgh = 1080;
    offscreen_pass1 = createGraphics(pgw, pgh, P3D);
    offscreen_pass2 = createGraphics(pgw, pgh, P3D);
    offscreen_pass3 = createGraphics(pgw, pgh, P3D);

    // UI controls
    addParameter("Rocks Color", this.rocksColor);
    addParameter("Water Color", this.waterColor);
    addParameter("Size", this.size);
    addParameter("Speed 1", this.speed1);
    addParameter("Speed 2", this.speed2);
    addParameter("Depth of Field", this.DoF);
    addParameter("Blur", this.blur);
    addParameter("Wide Angle", this.isWideAngle);
    addParameter("Sound Reactive", this.isSoundReactive);
    addParameter("Texture", this.isTexture);

    // Get the parameters to set the uniforms in the shader
    float size = this.size.getValuef();
    float speed1 = this.speed1.getValuef();
    float speed2 = this.speed2.getValuef();
    float dof = this.DoF.getValuef();
    float blurAmount = this.blur.getValuef();
    boolean wideangle = this.isWideAngle.isOn();

    // Load the shader and initialize the uniforms
    shader = loadShader("./data/shaders/Depths/shader.glsl");
    shader.set("resolution", float(width), float(height));
    shader.set("time", 0.0f);
    shader.set("size", size);
    shader.set("speed1", speed1);
    shader.set("speed2", speed2);
    shader.set("maxDistance", dof);
    shader.set("wideangle", wideangle);
    setShaderColor("cracksColor", this.rocksColor);
    setShaderColor("waterColor", this.waterColor);

    // Post effect shader
    sblur = loadShader("./data/shaders/Depths/blur.glsl");
    sblur.set("iResolution", float(pgw), float(pgh));
    sblur.set("iTime", 0.0);
    sblur.set("sigma", blurAmount);

    noStroke();
    globe = createShape(BOX, 10000);

    setVisible(false);
  }

  private void TexturedCube(PGraphics pg, PGraphics tex, int p) {
    int s = p * 2;

    pg.blendMode(NORMAL);

    pg.push();
    pg.translate(0, 0, p);
    pg.imageMode(CENTER);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.push();
    pg.translate(-p, 0, 0);
    pg.rotateY(HALF_PI);
    pg.imageMode(CENTER);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.push();
    pg.translate(p, 0, 0);
    pg.rotateY(-HALF_PI);
    pg.imageMode(CENTER);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.push();
    pg.translate(0, 0, -p);
    pg.imageMode(CENTER);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.push();
    pg.translate(0, -p-1, 0);
    pg.imageMode(CENTER);
    pg.rotateX(HALF_PI);
    pg.rotateZ(HALF_PI);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.blendMode(LIGHTEST);
    pg.push();
    pg.translate(0, -p, 0);
    pg.imageMode(CENTER);
    pg.rotateX(HALF_PI);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.blendMode(NORMAL);

    pg.push();
    pg.translate(0, p+1, 0);
    pg.imageMode(CENTER);
    pg.rotateX(HALF_PI);
    pg.rotateZ(HALF_PI);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.blendMode(LIGHTEST);
    pg.push();
    pg.translate(0, p, 0);
    pg.imageMode(CENTER);
    pg.rotateX(HALF_PI);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.blendMode(NORMAL);
  }

  private int rgbf(float r, float g, float b) {
    return LXColor.rgb((int) (r*255), (int) (g*255), (int) (b*255));
  }

  private void setShaderColor(String attribute, ColorParameter clr) {
    int c = clr.getColor();
    float r = ((c & 0xff0000) >> 16) / 255f;
    float g = ((c & 0xff00) >> 8) / 255f;
    float b = (c & 0xff) / 255f;
    shader.set(attribute, r, g, b);
  }

  public String getName() {
    return "Depths";
  }

  public void beforeDraw(UI ui) {
    
    // Get the parameters to set the uniforms in the shader
    float size = this.size.getValuef();
    float speed1 = this.speed1.getValuef();
    float speed2 = this.speed1.getValuef();
    float dof = this.DoF.getValuef();
    float blurAmount = this.blur.getValuef();
    boolean wideangle = this.isWideAngle.isOn();

    if (this.isSoundReactive.isOn()) {
      size = this.size.getValuef() * envelop.decode.channels[0].getNormalizedf();
      speed1 = this.speed1.getValuef() * envelop.decode.channels[1].getNormalizedf();
      speed2 = this.speed1.getValuef() * envelop.decode.channels[2].getNormalizedf();
    }

    // Load the shader and initialize the uniforms
    shader.set("time", millis() / 1000.0);
    shader.set("size", size);
    shader.set("speed1", speed1);
    shader.set("speed2", speed2);
    shader.set("maxDistance", dof);
    shader.set("wideangle", wideangle);
    setShaderColor("cracksColor", this.rocksColor);
    setShaderColor("waterColor", this.waterColor);

    // Post effect shader
    sblur.set("iTime", millis() / 1000.0);
    sblur.set("sigma", blurAmount);

    // Render the shader
    offscreen_pass1.beginDraw();
    //offscreen_pass1.background(random(255));
    offscreen_pass1.shader(shader);
    offscreen_pass1.noStroke();
    offscreen_pass1.rect(0, 0, offscreen_pass1.width, offscreen_pass1.height);
    offscreen_pass1.endDraw();

    // Mirror the shader on the second offscreen
    offscreen_pass2.beginDraw();

    offscreen_pass2.image(offscreen_pass1, 0, 0, offscreen_pass2.width/2, offscreen_pass2.height/2);

    offscreen_pass2.pushMatrix();
    offscreen_pass2.translate(offscreen_pass2.width, 0);
    offscreen_pass2.scale(-1, 1);
    offscreen_pass2.image(offscreen_pass1, 0, 0, offscreen_pass2.width/2, offscreen_pass2.height/2);
    offscreen_pass2.popMatrix();

    offscreen_pass2.pushMatrix();
    offscreen_pass2.translate(offscreen_pass2.width, offscreen_pass2.height);
    offscreen_pass2.scale(-1, -1);
    offscreen_pass2.image(offscreen_pass1, 0, 0, offscreen_pass2.width/2, offscreen_pass2.height/2);
    offscreen_pass2.popMatrix();

    offscreen_pass2.pushMatrix();
    offscreen_pass2.translate(0, offscreen_pass2.height);
    offscreen_pass2.scale(1, -1);
    offscreen_pass2.image(offscreen_pass1, 0, 0, offscreen_pass2.width/2, offscreen_pass2.height/2);
    offscreen_pass2.popMatrix();

    offscreen_pass2.endDraw();

    // Due to how textures are handled between PGraphics ad shaders, apply the post effect on a third offscreen
    offscreen_pass3.beginDraw();
    offscreen_pass3.image(offscreen_pass2, 0, 0, offscreen_pass3.width, offscreen_pass3.height);
    if (blurAmount > 0.02) offscreen_pass3.filter(sblur);
    offscreen_pass3.endDraw();

    globe.setTexture(offscreen_pass3);
  }

  public void onDraw(UI ui, PGraphics pg) {

    // It this doesn't need to be as texture
    // Apply it as an env map
    if (!this.isTexture.isOn()) TexturedCube(pg, offscreen_pass3, 10000);

    // Otherwise use it as the only element on the screen
    if (this.isTexture.isOn()) {
      pg.push();
      pg.camera(0, 0, (pg.height/1.25), 0, 0, 0, 0, 1, 0);
      pg.translate(0, 0, (pg.height/1.25)-10);
      pg.noStroke();
      pg.blendMode(ADD);
      pg.imageMode(CENTER);
      pg.image(offscreen_pass3, 0, 0, pg.width/48, pg.height/48);
      pg.pop();
    }
  }
}



/*
 * Starfield GLSL effect
 * Copyright 2020 - Giovanni Muzio
 * https://kesson.io
 *
 * Thanks to:
 * https://www.youtube.com/watch?v=rvDo9LvfoVE
 *
 * Domain Warping and fBM, by Inigo Quilez
 * https://www.iquilezles.org/www/articles/warp/warp.htm
 * https://www.iquilezles.org/www/articles/fbm/fbm.htm
 *
 */

class UIStarfield extends UIVisual {

  PShader shader;
  PGraphics offscreen, offscreen2;
  PShape globe;
  float hue, saturation, brightness;

  public final ColorParameter colorMixA = 
    new ColorParameter("Color Mix A", rgbf(0.06f, 0.96f, 0.99f));

  public final BoundedParameter speed =
    new BoundedParameter("Speed", 0.01f, 0.0f, 0.5f)
    .setDescription("The speed of the Starfield");

  public final BoundedParameter density =
    new BoundedParameter("Density", 1.0f, 1.0f, 6.0f)
    .setDescription("The speed of the Starfield");

  public final BooleanParameter isColorama =
    new BooleanParameter("Colorama", true)
    .setDescription("Wheter the shader is applied as environmental map");

  public final BooleanParameter isSoundreactive =
    new BooleanParameter("Soundreactive", true)
    .setDescription("Wheter the shader is applied as environmental map");

  public final BooleanParameter isTexture =
    new BooleanParameter("Texture", false)
    .setDescription("Wheter the shader is applied as texture on top on the render");

  public UIStarfield() {
    // HSB colors to easily change them over time
    hue = random(TWO_PI);
    saturation = 118;
    brightness = 360;

    offscreen = createGraphics(1080, 1080, P3D);
    offscreen2 = createGraphics(1080, 1080, P3D);
    // UI controls
    addParameter("colorMixA", this.colorMixA);
    addParameter("speed", this.speed);
    addParameter("density", this.density);
    addParameter("automatic color", this.isColorama);
    addParameter("sound reactive", this.isSoundreactive);
    addParameter("texture", this.isTexture);

    // Get the parameters to set the uniforms in the shader
    float speed = this.speed.getValuef();

    // Load the shader and initialize the uniforms
    shader = loadShader("./data/Shaders/Starfield/starfield.glsl");
    shader.set("resolution", float(width), float(height));
    shader.set("time", 0.0f);
    shader.set("speed", speed);

    //General color of the starfield
    colorMode(HSB, 360);
    float h = (sin(hue) * 0.5 + 0.5) * 360;
    color c = color(h, saturation, brightness);
    colorMode(RGB, 1.0);
    shader.set("colorMixA", red(c), green(c), blue(c));

    setVisible(false);
  }

  // A method to show the offscreen shader
  // To fix the angles not mathing at the top and bottom corners
  private void TexturedCube(PGraphics pg, PGraphics tex, int p) {
    int s = p * 2;

    pg.blendMode(NORMAL);

    pg.push();
    pg.translate(0, 0, p);
    pg.imageMode(CENTER);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.push();
    pg.translate(-p, 0, 0);
    pg.rotateY(HALF_PI);
    pg.imageMode(CENTER);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.push();
    pg.translate(p, 0, 0);
    pg.rotateY(-HALF_PI);
    pg.imageMode(CENTER);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.push();
    pg.translate(0, 0, -p);
    pg.imageMode(CENTER);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.push();
    pg.translate(0, -p-1, 0);
    pg.imageMode(CENTER);
    pg.rotateX(HALF_PI);
    pg.rotateZ(HALF_PI);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.blendMode(LIGHTEST);
    pg.push();
    pg.translate(0, -p, 0);
    pg.imageMode(CENTER);
    pg.rotateX(HALF_PI);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.blendMode(NORMAL);

    pg.push();
    pg.translate(0, p+1, 0);
    pg.imageMode(CENTER);
    pg.rotateX(HALF_PI);
    pg.rotateZ(HALF_PI);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.blendMode(LIGHTEST);
    pg.push();
    pg.translate(0, p, 0);
    pg.imageMode(CENTER);
    pg.rotateX(HALF_PI);
    pg.image(tex, 0, 0, s, s);
    pg.pop();

    pg.blendMode(NORMAL);
  }

  private int rgbf(float r, float g, float b) {
    return LXColor.rgb((int) (r*255), (int) (g*255), (int) (b*255));
  }

  private void setShaderColor(String attribute, ColorParameter clr) {
    int c = clr.getColor();
    float r = ((c & 0xff0000) >> 16) / 255f;
    float g = ((c & 0xff00) >> 8) / 255f;
    float b = (c & 0xff) / 255f;
    shader.set(attribute, r, g, b);
  }

  public String getName() {
    return "Starfield";
  }

  public void beforeDraw(UI ui) {
    // Get the parameters to set the uniforms in the shader
    float speed = this.speed.getValuef();
    float density = this.density.getValuef();
    float ch1 = envelop.decode.channels[0].getNormalizedf();

    // Set the uniforms of the shader
    shader.set("time", millis() / 1000.0);
    shader.set("speed", speed);
    shader.set("density", density);
    // If Sound Reactive, the size of the stars is in sync with the first channel of the sound
    if (this.isSoundreactive.isOn()) {
      shader.set("starSize", constrain(map(ch1, 0, 0.3, 0.01, 0.06), 0.0025, 0.1));
    } else {
      shader.set("starSize", 0.05);
    }

    if (!this.isColorama.isOn()) {
      this.setShaderColor("colorMixA", this.colorMixA);
    } else {
      hue += 0.01;
      colorMode(HSB, 360);
      float h = (sin(hue) * 0.5 + 0.5) * 360;
      color c = color(h, saturation, brightness);
      colorMode(RGB, 1.0);
      shader.set("colorMixA", red(c), green(c), blue(c));
    }

    int w_ = offscreen2.width;
    int h_ = offscreen2.height;

    // Offscreen computation
    offscreen.beginDraw();
    offscreen.background(0);
    offscreen.shader(shader);
    offscreen.noStroke();
    offscreen.rectMode(CORNER);
    offscreen.rect(0, 0, offscreen.width, offscreen.height);
    offscreen.endDraw();

    offscreen2.beginDraw();
    offscreen.background(0);
    offscreen.blendMode(LIGHTEST);

    offscreen2.image(offscreen, 0, 0, w_, h_);

    offscreen2.pushMatrix();
    offscreen2.translate(offscreen2.width, 0);
    offscreen2.scale(-1, 1);
    offscreen2.image(offscreen, 0, 0, w_, w_);
    offscreen2.popMatrix();

    offscreen2.pushMatrix();
    offscreen2.translate(offscreen2.width, offscreen2.height);
    offscreen2.scale(-1, -1);
    offscreen2.image(offscreen, 0, 0, w_, w_);
    offscreen2.popMatrix();

    offscreen2.pushMatrix();
    offscreen2.translate(0, offscreen2.height);
    offscreen2.scale(1, -1);
    offscreen2.image(offscreen, 0, 0, w_, w_);
    offscreen2.popMatrix();

    offscreen2.endDraw();
  }

  public void onDraw(UI ui, PGraphics pg) {

    if (this.isTexture.isOn()) {
      pg.push();
      pg.camera(0, 0, (pg.height/1.25), 0, 0, 0, 0, 1, 0);
      pg.translate(0, 0, (pg.height/1.25)-10);
      pg.noStroke();
      pg.blendMode(ADD);
      pg.imageMode(CENTER);
      pg.image(offscreen, 0, 0, pg.width/48, pg.height/48);
      pg.pop();
    } else {
      TexturedCube(pg, offscreen2, 10000);
    }
  }
}
