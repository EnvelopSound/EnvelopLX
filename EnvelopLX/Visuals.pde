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
 * Running in real time
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
 * Code adapted, modified and merged by Giovanni Muzio - Kesson
 * https://kesson.io
 */

class UIMarbleTexture extends UIVisual {

  PShader marbleShader;
  PGraphics marbleGraphic;
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

  public final BooleanParameter isTexture =
    new BooleanParameter("Texture", false)
    .setDescription("Wheter the shader is applied as texture on top on the render");

  public UIMarbleTexture() {

    marbleGraphic = createGraphics(width, height, P3D);
    // UI controls
    addParameter("environmental Map", this.isEnvironmentalMap);
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
    marbleShader = loadShader("./data/Shaders/MarbleFrag.glsl");
    marbleShader.set("resolution", float(width), float(height));
    marbleShader.set("time", 0.0f);
    marbleShader.set("size", size);
    marbleShader.set("hurst_exponent", hurst_exp);
    marbleShader.set("amount", amount);
    marbleShader.set("num_octaves", octaves);
    marbleShader.set("warping_speed_1", warp_speed_1);
    marbleShader.set("warping_speed_2", warp_speed_2);
    marbleShader.set("opacity", opacity);

    // The colors of the shader
    setMarbleShaderColor("baseColor", this.baseColor);
    setMarbleShaderColor("finalColor", this.finalColor);
    setMarbleShaderColor("colorMixA", this.colorMixA);
    setMarbleShaderColor("colorMixB", this.colorMixB);
    
    noStroke();
    globe = createShape(SPHERE, 10000);
  }
  
  private int rgbf(float r, float g, float b) {
    return LXColor.rgb((int) (r*255), (int) (g*255), (int) (b*255));
  }
  
  private void setMarbleShaderColor(String attribute, ColorParameter clr) {
    int c = clr.getColor();
    float r = ((c & 0xff0000) >> 16) / 255f;
    float g = ((c & 0xff00) >> 8) / 255f;
    float b = (c & 0xff) / 255f;
    marbleShader.set(attribute, r, g, b);
  }
  
  public String getName() {
    return "Marble Texture";
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
    marbleShader.set("time", millis() / 1000.0);
    marbleShader.set("size", size);
    marbleShader.set("hurst_exponent", hurst_exp);
    marbleShader.set("amount", amount);
    marbleShader.set("num_octaves", octaves);
    marbleShader.set("warping_speed_1", warp_speed_1);
    marbleShader.set("warping_speed_2", warp_speed_2);
    marbleShader.set("opacity", opacity);

    // The colors of the shader
    setMarbleShaderColor("baseColor", this.baseColor);
    setMarbleShaderColor("finalColor", this.finalColor);
    setMarbleShaderColor("colorMixA", this.colorMixA);
    setMarbleShaderColor("colorMixB", this.colorMixB);

    marbleGraphic.beginDraw();
    marbleGraphic.background(0);
    marbleGraphic.shader(marbleShader);
    marbleGraphic.rectMode(CORNER);
    marbleGraphic.rect(0, 0, marbleGraphic.width, marbleGraphic.height);
    marbleGraphic.endDraw();

    globe.setTexture(marbleGraphic);
  }

  public void onDraw(UI ui, PGraphics pg) {

    if (this.isEnvironmentalMap.isOn()) pg.shape(globe);

    if (this.isTexture.isOn()) {
      pg.push();
      pg.camera(0, 0, (pg.height/1.25), 0, 0, 0, 0, 1, 0);
      pg.translate(0, 0, (pg.height/1.25)-10);
      pg.noStroke();
      pg.blendMode(ADD);
      pg.imageMode(CENTER);
      pg.image(marbleGraphic, 0, 0, pg.width/48, pg.height/48);
      pg.pop();
    }
  }
}
