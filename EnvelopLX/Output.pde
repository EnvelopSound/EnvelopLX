import heronarts.lx.output.DDPDatagram;
import heronarts.lx.output.LXDatagramOutput;
import java.net.SocketException;

static class Output extends LXDatagramOutput {
  Output(LX lx, Room room) throws IOException {
    super(lx);
    
    int columnIp = 101;
    for (Column column : room.columns) {
      int[] indices = new int[column.points.size()];
      int pi = 0;
      for (LXPoint p : column.points) {
        indices[pi++] = p.index;
      }
      addDatagram(new DDPDatagram(indices).setAddress("10.0.0." + (columnIp++)));
    }
    
    gammaCorrection.setValue(1);
    enabled.setValue(false);
  }
}