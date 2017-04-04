import java.net.SocketException;

LXOutput getOutput(LX lx) throws IOException {
  switch (environment) {
  case MIDWAY: 
    return new MidwayOutput(lx);
  case SATELLITE: 
    return new SatelliteOutput(lx);
  }
  return null;
}

class MidwayOutput extends LXDatagramOutput {
  MidwayOutput(LX lx) throws IOException {
    super(lx);
    int columnIp = 101;
    for (Column column : venue.columns) {
      addDatagram(new DDPDatagram(column).setAddress("10.0.0." + (columnIp++)));
    }
  }
}

class SatelliteOutput extends LXDatagramOutput {
  SatelliteOutput(LX lx) throws IOException {
    super(lx);
    int universe = 0;
    int columnIp = 1;
    for (Column column : venue.columns) {
      for (Rail rail : column.rails) {
        // Top to bottom
        int[] indices = new int[rail.size];
        for (int i = 0; i < indices.length; i++) {
          indices[indices.length-1-i] = rail.points.get(i).index;
        }
        addDatagram(new ArtNetDatagram(indices, 512, universe++).setAddress("192.168.0." + columnIp));
      }
      ++columnIp;
    }
  }
}