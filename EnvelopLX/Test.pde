public class TestColumn extends EnvelopPattern {
  
  public final DiscreteParameter col = new DiscreteParameter("Col", 0, 8);
  public final DiscreteParameter rgb = new DiscreteParameter("Rgb", 0, 3);
  
  public TestColumn(LX lx) {
    super(lx);
    addParameter("col", this.col);
    addParameter("rgb", this.rgb);
  }
  
  public void run(double deltaMs) {
    setColors(0xff000000);
    setColor(model.columns.get(this.col.getValuei()), 0xff000000 | (0xff << (8 * this.rgb.getValuei()))); 
  }
}
