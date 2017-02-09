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

import heronarts.lx.*;
import heronarts.lx.pattern.*;
import heronarts.p3lx.*;
import heronarts.p3lx.ui.*;
import heronarts.p3lx.ui.component.*;
import ddf.minim.*;

final static float INCHES = 1;
final static float FEET = 12*INCHES;

Room room; 
P3LX lx;

void setup() {
  size(1280, 720, P3D);
  lx = new P3LX(this, room = new Room());
  
  lx.setPatterns(new LXPattern[] {
    new Movers(lx),
    new SolidColorPattern(lx, #ffffff),
    new SolidColorPattern(lx, #ff0000),
    new SolidColorPattern(lx, #00ff00),
    new SolidColorPattern(lx, #0000ff)
  });
    
  try {
    lx.addOutput(new Output(lx, room));
  } catch (Exception x) {
    throw new RuntimeException(x);
  }
  
  final PImage LOGO = loadImage("envelop-logo-clear.png");
  final float LOGO_SIZE = 100*INCHES;
  
  lx.ui.addLayer(new UI3dContext(lx.ui)
    .addComponent(new UI3dComponent() {
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
    })
    .addComponent(new UIPointCloud(lx).setPointSize(3))
    .setCenter(0, 6*FEET, 0)
    .setRadius(36*FEET)
    .setMinRadius(2*FEET)
    .setMaxRadius(48*FEET)
  );
}

void draw() {
  background(#191919);
}