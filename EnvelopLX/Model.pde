import java.util.Arrays;
import java.util.Collections;
import java.util.List;

final static float INCHES = 1;
final static float FEET = 12*INCHES;

EnvelopModel getModel() {
  switch (environment) {
  case SATELLITE: return new Satellite();
  case MIDWAY: return new Midway();
  }
  return null;
}

static abstract class EnvelopModel extends LXModel {
    
  static abstract class Config {
    
    static class Rail {
      public final PVector position;
      public final int numPoints;
      public final float pointSpacing;
      
      Rail(PVector position, int numPoints, float pointSpacing) {
        this.position = position;
        this.numPoints = numPoints;
        this.pointSpacing = pointSpacing;
      }
    }
    
    public abstract PVector[] getColumns();
    public abstract float[] getArcs();
    public abstract Rail[] getRails();
  }
  
  public final List<Column> columns;
  public final List<Arc> arcs;
  public final List<Rail> rails;
  
  protected EnvelopModel(Config config) {
    super(new Fixture(config));
    Fixture f = (Fixture) fixtures.get(0);
    columns = Collections.unmodifiableList(Arrays.asList(f.columns));
    final Arc[] arcs = new Arc[columns.size() * config.getArcs().length];
    final Rail[] rails = new Rail[columns.size() * config.getRails().length];
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
    
    final Column[] columns;
    
    Fixture(Config config) {
      columns = new Column[config.getColumns().length];
      LXTransform transform = new LXTransform();
      int ci = 0;
      for (PVector pv : config.getColumns()) {
        transform.push();
        transform.translate(pv.x, 0, pv.y);
        float theta = atan2(pv.y, pv.x) - HALF_PI;
        transform.rotateY(-theta);
        addPoints(columns[ci] = new Column(config, ci, transform, theta));
        transform.pop();
        ++ci;
      }
    }
  }
}

static class Midway extends EnvelopModel {
  
  final static float WIDTH = 20*FEET + 10.25*INCHES;
  final static float DEPTH = 41*FEET + 6*INCHES;
  
  final static float INNER_OFFSET_X = WIDTH/2. - 1*FEET - 8.75*INCHES;
  final static float OUTER_OFFSET_X = WIDTH/2. - 5*FEET - 1.75*INCHES;
  final static float INNER_OFFSET_Z = -DEPTH/2. + 15*FEET + 10.75*INCHES;
  final static float OUTER_OFFSET_Z = -DEPTH/2. + 7*FEET + 8*INCHES;
  
  final static float SUB_OFFSET_X = 36*INCHES;
  final static float SUB_OFFSET_Z = 20*INCHES;
  
  final static EnvelopModel.Config CONFIG = new EnvelopModel.Config() {
    public PVector[] getColumns() {
      return COLUMN_POSITIONS;
    }
    
    public float[] getArcs() {
      return ARC_POSITIONS;
    }
    
    public EnvelopModel.Config.Rail[] getRails() {
      return RAILS;
    }
  };
  
  final static int NUM_POINTS = 109;
  final static float POINT_SPACING = 1.31233596*INCHES;
  
  final static EnvelopModel.Config.Rail[] RAILS = {
    new EnvelopModel.Config.Rail(new PVector(-1, 0, 0), NUM_POINTS, POINT_SPACING),
    new EnvelopModel.Config.Rail(new PVector(1, 0, 0), NUM_POINTS, POINT_SPACING)
  };
  
  final static float[] ARC_POSITIONS = { 1/3.f, 2/3.f };
  
  final static PVector[] COLUMN_POSITIONS = {
    new PVector(-OUTER_OFFSET_X, -OUTER_OFFSET_Z, 101),
    new PVector(-INNER_OFFSET_X, -INNER_OFFSET_Z, 102),
    new PVector(-INNER_OFFSET_X,  INNER_OFFSET_Z, 103),
    new PVector(-OUTER_OFFSET_X,  OUTER_OFFSET_Z, 104),
    new PVector( OUTER_OFFSET_X,  OUTER_OFFSET_Z, 105),
    new PVector( INNER_OFFSET_X,  INNER_OFFSET_Z, 106),
    new PVector( INNER_OFFSET_X, -INNER_OFFSET_Z, 107),
    new PVector( OUTER_OFFSET_X, -OUTER_OFFSET_Z, 108)
  };
    
  final static PVector[] SUB_POSITIONS = {
    COLUMN_POSITIONS[0].copy().add(-SUB_OFFSET_X, -SUB_OFFSET_Z),
    COLUMN_POSITIONS[3].copy().add(-SUB_OFFSET_X, SUB_OFFSET_Z),
    COLUMN_POSITIONS[4].copy().add(SUB_OFFSET_X, SUB_OFFSET_Z),
    COLUMN_POSITIONS[7].copy().add(SUB_OFFSET_X, -SUB_OFFSET_Z),
  };
  
  Midway() {
    super(CONFIG);
  }
}

static class Satellite extends EnvelopModel {
  
  final static float EDGE_LENGTH = 12*FEET;
  final static float HALF_EDGE_LENGTH = EDGE_LENGTH / 2;
  final static float INCIRCLE_RADIUS = HALF_EDGE_LENGTH + EDGE_LENGTH / sqrt(2);
  
  final static PVector[] PLATFORM_POSITIONS = {
    new PVector(-HALF_EDGE_LENGTH,  INCIRCLE_RADIUS, 101),
    new PVector(-INCIRCLE_RADIUS,  HALF_EDGE_LENGTH, 102),
    new PVector(-INCIRCLE_RADIUS, -HALF_EDGE_LENGTH, 103),
    new PVector(-HALF_EDGE_LENGTH, -INCIRCLE_RADIUS, 104),
    new PVector( HALF_EDGE_LENGTH, -INCIRCLE_RADIUS, 105),
    new PVector( INCIRCLE_RADIUS, -HALF_EDGE_LENGTH, 106),
    new PVector( INCIRCLE_RADIUS,  HALF_EDGE_LENGTH, 107),
    new PVector( HALF_EDGE_LENGTH,  INCIRCLE_RADIUS, 108)
  };
  
  final static PVector[] COLUMN_POSITIONS;
  static {
    float ratio = (INCIRCLE_RADIUS - Column.RADIUS - 6*INCHES) / INCIRCLE_RADIUS;
    COLUMN_POSITIONS = new PVector[PLATFORM_POSITIONS.length];
    for (int i = 0; i < PLATFORM_POSITIONS.length; ++i) {
      COLUMN_POSITIONS[i] = PLATFORM_POSITIONS[i].copy().mult(ratio);
    }
  };
  
  final static float POINT_SPACING = 1.31233596*INCHES;
  
  final static EnvelopModel.Config.Rail[] RAILS = {
    new EnvelopModel.Config.Rail(new PVector(-1, 0, 0), 108, POINT_SPACING),
    new EnvelopModel.Config.Rail(new PVector(0, 0, 1), 100, POINT_SPACING),
    new EnvelopModel.Config.Rail(new PVector(1, 0, 0), 108, POINT_SPACING)
  };
  
  final static float[] ARC_POSITIONS = { };
  
  final static EnvelopModel.Config CONFIG = new EnvelopModel.Config() {
    public PVector[] getColumns() {
      return COLUMN_POSITIONS;
    }
    
    public float[] getArcs() {
      return ARC_POSITIONS;
    }
    
    public EnvelopModel.Config.Rail[] getRails() {
      return RAILS;
    }
  };
  
  Satellite() {
    super(CONFIG);
  }
}


static class Column extends LXModel {
  
  final static float SPEAKER_ANGLE = 22./180.*PI;
  
  final static float HEIGHT = Rail.HEIGHT;
  final static float RADIUS = 20*INCHES;
  
  final int index;
  final float azimuth;
  
  final List<Arc> arcs;
  final List<Rail> rails;
  
  Column(EnvelopModel.Config config, int index, LXTransform transform, float azimuth) {
    super(new Fixture(config, transform));
    this.index = index;
    this.azimuth = azimuth;
    Fixture f = (Fixture) fixtures.get(0);
    arcs = Collections.unmodifiableList(Arrays.asList(f.arcs));
    rails = Collections.unmodifiableList(Arrays.asList(f.rails));
  }
  
  private static class Fixture extends LXAbstractFixture {
    final Arc[] arcs;
    final Rail[] rails;
    
    Fixture(EnvelopModel.Config config, LXTransform transform) {
      
      // Transform begins on the floor at center of column
      transform.push();
      
      // Rails
      this.rails = new Rail[config.getRails().length];
      for (int i = 0; i < config.getRails().length; ++i) {
        EnvelopModel.Config.Rail rail = config.getRails()[i]; 
        transform.translate(RADIUS * rail.position.x, 0, RADIUS * rail.position.z);
        addPoints(rails[i] = new Rail(rail, transform));
        transform.translate(-RADIUS * rail.position.x, 0, -RADIUS * rail.position.z);
      }
      
      // Arcs
      this.arcs = new Arc[config.getArcs().length];
      for (int i = 0; i < config.getArcs().length; ++i) {
        float y = config.getArcs()[i] * HEIGHT;
        transform.translate(0, y, 0);      
        addPoints(arcs[i] = new Arc(transform));
        transform.translate(0, -y, 0);
      }
      
      transform.pop();
    }
  }
}

static class Rail extends LXModel {
  
  final static int LEFT = 0;
  final static int RIGHT = 1;
  
  final static float HEIGHT = 12*FEET;
  
  public final float theta;
  
  Rail(EnvelopModel.Config.Rail rail, LXTransform transform) {
    super(new Fixture(rail, transform));
    this.theta = atan2(transform.z(), transform.x());
  }
  
  private static class Fixture extends LXAbstractFixture {
    Fixture(EnvelopModel.Config.Rail rail, LXTransform transform) {
      transform.push();
      transform.translate(0, rail.pointSpacing / 2., 0);
      for (int i = 0; i < rail.numPoints; ++i) {
        addPoint(new LXPoint(transform));
        transform.translate(0, rail.pointSpacing, 0);
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
      transform.rotateY(-POINT_ANGLE / 2.);
      for (int i = 0; i < NUM_POINTS; ++i) {
        transform.translate(-RADIUS, 0, 0);
        addPoint(new LXPoint(transform));
        transform.translate(RADIUS, 0, 0);
        transform.rotateY(-POINT_ANGLE);
      }
      transform.pop();
    }
  }
}