class UIRoomArchitecture extends UI3dComponent {
  
  final static float LOGO_SIZE = 100*INCHES;
  final PImage LOGO = loadImage("envelop-logo-clear.png");
  
  public void onDraw(UI ui, PGraphics pg) {
    // Floor
    pg.stroke(#000000);
    pg.fill(#202020);
    pg.translate(0, -4*INCHES, 0);
    pg.box(Room.WIDTH, 8*INCHES, Room.DEPTH);
    pg.translate(0, +4*INCHES, 0);
    
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
    
    // Subwoofers
    pg.fill(#000000);
    pg.stroke(#202020);
    for (PVector pv : Room.SUB_POSITIONS) {
      pg.translate(pv.x, 10*INCHES, pv.y);
      pg.rotateY(-QUARTER_PI);
      pg.box(29*INCHES, 20*INCHES, 29*INCHES);
      pg.rotateY(QUARTER_PI);
      pg.translate(-pv.x, -10*INCHES, -pv.y);
    }
    
    // Speakers
    for (Column column : room.columns) {
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
}

static class UIOutputControl extends UIWindow {
  public UIOutputControl(UI ui, LXOutput output, float x, float y) {
    super(ui, "OUTPUT", x, y, UIChannelControl.WIDTH, 48);
    float yp = UIWindow.TITLE_LABEL_HEIGHT;
    new UIButton(4, yp, width-8, 20).setParameter(output.enabled).setLabel("Live Output").addToContainer(this);
  }
}