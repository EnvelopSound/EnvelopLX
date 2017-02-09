import heronarts.lx.model.*;
import heronarts.lx.transform.*;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

static class Room extends LXModel {
  
  final static float WIDTH = 20*FEET + 10.25*INCHES;
  final static float DEPTH = 41*FEET + 6*INCHES;
  
  final static float INNER_OFFSET_X = WIDTH/2. - 1*FEET - 8.75*INCHES;
  final static float OUTER_OFFSET_X = WIDTH/2. - 5*FEET - 1.75*INCHES;
  final static float INNER_OFFSET_Z = -DEPTH/2. + 15*FEET + 10.75*INCHES;
  final static float OUTER_OFFSET_Z = -DEPTH/2. + 7*FEET + 8*INCHES;
  
  final static PVector[] COLUMN_POSITIONS = {
    new PVector(OUTER_OFFSET_X, OUTER_OFFSET_Z),
    new PVector(INNER_OFFSET_X, INNER_OFFSET_Z),
    new PVector(INNER_OFFSET_X, -INNER_OFFSET_Z),
    new PVector(OUTER_OFFSET_X, -OUTER_OFFSET_Z),
    new PVector(-OUTER_OFFSET_X, -OUTER_OFFSET_Z),
    new PVector(-INNER_OFFSET_X, -INNER_OFFSET_Z),
    new PVector(-INNER_OFFSET_X, INNER_OFFSET_Z),
    new PVector(-OUTER_OFFSET_X, OUTER_OFFSET_Z)
  };
  
  final static float SUB_OFFSET_X = 36*INCHES;
  final static float SUB_OFFSET_Z = 20*INCHES;
  
  final static PVector[] SUB_POSITIONS = {
    COLUMN_POSITIONS[0].copy().add(SUB_OFFSET_X, SUB_OFFSET_Z),
    COLUMN_POSITIONS[3].copy().add(SUB_OFFSET_X, -SUB_OFFSET_Z),
    COLUMN_POSITIONS[4].copy().add(-SUB_OFFSET_X, -SUB_OFFSET_Z),
    COLUMN_POSITIONS[7].copy().add(-SUB_OFFSET_X, SUB_OFFSET_Z),
  };
  
  final List<Column> columns;
  final List<Arc> arcs;
  final List<Rail> rails;
  
  Room() {
    super(new Fixture());
    Fixture f = (Fixture) fixtures.get(0);
    columns = Collections.unmodifiableList(Arrays.asList(f.columns));
    final Arc[] arcs = new Arc[columns.size() * 2];
    final Rail[] rails = new Rail[columns.size() * 2];
    int a = 0;
    int r = 0;
    for (Column column : columns) {
      for (Arc arc : column.arcs) {
        arcs[a++] = arc;
      }
      for (Rail rail : column.rails) {
        rails[r++] = rail;
      }
    }
    this.arcs = Collections.unmodifiableList(Arrays.asList(arcs));
    this.rails = Collections.unmodifiableList(Arrays.asList(rails));
  }
  
  private static class Fixture extends LXAbstractFixture {
    
    final Column[] columns = new Column[COLUMN_POSITIONS.length];
    
    Fixture() {
      LXTransform transform = new LXTransform();
      int ci = 0;
      for (PVector pv : COLUMN_POSITIONS) {
        transform.push();
        transform.translate(pv.x, 0, pv.y);
        float theta = atan2(pv.y, pv.x) - HALF_PI;
        transform.rotateY(theta);
        addPoints(columns[ci++] = new Column(transform, theta));
        transform.pop();
      }
    }
  }
}

static class Column extends LXModel {
  
  final static float SPEAKER_ANGLE = 22./180.*PI;
  
  final static float HEIGHT = Rail.HEIGHT;
  final static float RADIUS = 20*INCHES;
  
  final float theta;
  
  final List<Arc> arcs;
  final List<Rail> rails;
  
  Column(LXTransform transform, float theta) {
    super(new Fixture(transform));
    this.theta = theta;
    Fixture f = (Fixture) fixtures.get(0);
    arcs = Collections.unmodifiableList(Arrays.asList(f.arcs));
    rails = Collections.unmodifiableList(Arrays.asList(f.rails));
  }
  
  private static class Fixture extends LXAbstractFixture {
    final Arc[] arcs = new Arc[2];
    final Rail[] rails = new Rail[2];
    
    Fixture(LXTransform transform) {
      // Transform begins on the floor at center of column
      transform.push();
      transform.translate(-RADIUS, 0, 0);
      addPoints(rails[Rail.LEFT] = new Rail(transform));
      transform.translate(2*RADIUS, 0, 0);
      addPoints(rails[Rail.RIGHT] = new Rail(transform));
      transform.translate(-RADIUS, HEIGHT/3., 0);
      addPoints(arcs[Arc.BOTTOM] = new Arc(transform));
      transform.translate(0, HEIGHT/3., 0);
      addPoints(arcs[Arc.TOP] = new Arc(transform));
      transform.pop();
    }
  }
}

static class Rail extends LXModel {
  
  final static int LEFT = 0;
  final static int RIGHT = 1;
  
  final static int NUM_POINTS = 109;
  final static float POINT_SPACING = 1.31233596*INCHES;
  final static float HEIGHT = NUM_POINTS * POINT_SPACING;
  
  Rail(LXTransform transform) {
    super(new Fixture(transform));
  }
  
  private static class Fixture extends LXAbstractFixture {
    Fixture(LXTransform transform) {
      transform.push();
      transform.translate(0, POINT_SPACING / 2., 0);
      for (int i = 0; i < NUM_POINTS; ++i) {
        addPoint(new LXPoint(transform));
        transform.translate(0, POINT_SPACING, 0);
      }
      transform.pop();
    }
  }
}

static class Arc extends LXModel {
  
  final static float RADIUS = Column.RADIUS;
  
  final static int BOTTOM = 0;
  final static int TOP = 1;
  
  final static int NUM_POINTS = 34;
  final static float POINT_ANGLE = PI / NUM_POINTS;
  
  Arc(LXTransform transform) {
    super(new Fixture(transform));
  }
  
  private static class Fixture extends LXAbstractFixture {
    Fixture(LXTransform transform) {
      transform.push();
      transform.rotateY(POINT_ANGLE / 2.);
      for (int i = 0; i < NUM_POINTS; ++i) {
        transform.translate(-RADIUS, 0, 0);
        addPoint(new LXPoint(transform));
        transform.translate(RADIUS, 0, 0);
        transform.rotateY(POINT_ANGLE);
      }
      transform.pop();
    }
  }
}