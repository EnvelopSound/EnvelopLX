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
Output output;

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
    lx.addOutput(output = new Output(lx, room));
  } catch (Exception x) {
    throw new RuntimeException(x);
  }
      
  lx.ui.addLayer(new UI3dContext(lx.ui)
    .addComponent(new UIRoomArchitecture())
    .addComponent(new UIPointCloud(lx).setPointSize(3))
    .setCenter(0, 6*FEET, 0)
    .setRadius(36*FEET)
    .setMinRadius(2*FEET)
    .setMaxRadius(48*FEET)
  );
  
  lx.ui.addLayer(new UIChannelControl(lx.ui, lx, 4, 4));
  lx.ui.addLayer(new UIOutputControl(lx.ui, output, 4, 324));
}

void draw() {
  background(#191919);
}