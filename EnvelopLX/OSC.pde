import java.net.InetAddress;
import java.util.Map;

class EnvelopOscListener implements LXOscListener {
  
  private int getIndex(OscMessage message) {
    String[] parts = message.getAddressPattern().toString().split("/");
    try {
      return Integer.valueOf(parts[parts.length - 1]);
    } catch (Exception x) {
      return -1;
    }
  }
  
  public void oscMessage(OscMessage message) {
    if (message.matches("/envelop/tempo/beat")) {
      lx.tempo.trigger(message.getInt()-1);
    } else if (message.matches("/envelop/tempo/bpm")) {
      lx.tempo.setBpm(message.getDouble());
    } else if (message.matches("/envelop/meter/decode")) {
      envelop.decode.setLevels(message);
    } else if (message.hasPrefix("/envelop/meter/source")) {
      int index = getIndex(message) - 1;
      if (index >= 0 && index < envelop.source.channels.length) {
        envelop.source.setLevel(index, message);
      }
    } else if (message.hasPrefix("/envelop/source")) {
      int index = getIndex(message) - 1;
      if (index >= 0 && index < envelop.source.channels.length) {
        Envelop.Source.Channel channel = envelop.source.channels[index];
        float rx = 0, ry = 0, rz = 0;
        String type = message.getString();
        if (type.equals("xyz")) {
          rx = message.getFloat();
          ry = message.getFloat();
          rz = message.getFloat();
        } else if (type.equals("aed")) {
          float azimuth = message.getFloat() / 180. * PI;
          float elevation = message.getFloat() / 180. * PI;
          float radius = message.getFloat();
          rx = radius * cos(-azimuth + HALF_PI) * cos(elevation);
          ry = radius * sin(-azimuth + HALF_PI) * cos(elevation);
          rz = radius * sin(elevation);
        }
        channel.xyz.set(rx, ry, rz);
        channel.active = true;
        channel.tx = venue.cx + rx * venue.xRange/2;
        channel.ty = venue.cy + rz * venue.yRange/2;
        channel.tz = venue.cz + ry * venue.zRange/2;
      }
    }
  }
}

class EnvelopOscMeterListener implements LXOscListener {
  public void oscMessage(OscMessage message) {
    if (message.matches("/server/dsp/meter/input")) {
      envelop.source.setLevels(message);
    } else if (message.matches("/server/dsp/meter/decoded")) {
      envelop.decode.setLevels(message);
    } else {
      println(message);
    }
  }
}

class EnvelopOscSourceListener implements LXOscListener {
    
  public void oscMessage(OscMessage message) {
    String[] parts = message.getAddressPattern().toString().split("/");
    if (parts.length == 4) {
      if (parts[1].equals("source")) {
        try {
          int index = Integer.parseInt(parts[2]) - 1;
          if (index >= 0 && index < envelop.source.channels.length) {
            Envelop.Source.Channel channel = envelop.source.channels[index];
            if (parts[3].equals("active")) {
              channel.active = message.getFloat() > 0;
            } else if (parts[3].equals("xyz")) {
              float rx = message.getFloat();
              float ry = message.getFloat();
              float rz = message.getFloat();
              channel.xyz.set(rx, ry, rz);
              channel.tx = venue.cx + rx * venue.xRange/2;
              channel.ty = venue.cy + rz * venue.yRange/2;
              channel.tz = venue.cz + ry * venue.zRange/2;
            }
          } else {
            println("Invalid source channel message: " + message);
          }
        } catch (NumberFormatException nfx) {}
      }
    }
  }
}

static class EnvelopOscControlListener implements LXOscListener {
  
  private final LX lx;
  
  private final Map<InetAddress, EnvelopOscClient> clients =
    new HashMap<InetAddress, EnvelopOscClient>();
  
  EnvelopOscControlListener(LX lx) {
    this.lx = lx;    
  }
  
  public void oscMessage(OscMessage message) {
    println("[" + message.getSource() + "] " + message);
    EnvelopOscClient client = clients.get(message.getSource());
    if (client == null) {
      if (message.matches("/lx/register/envelop")) {
        try {
          clients.put(message.getSource(), new EnvelopOscClient(lx, message.getSource()));
        } catch (SocketException sx) {
          sx.printStackTrace();
        }
      }
    } else {
      client.oscMessage(message);
    }
  }
}
  
static class EnvelopOscClient implements LXOscListener {
  
  private final static int NUM_KNOBS = 12;
  private final KnobListener[] knobs = new KnobListener[NUM_KNOBS]; 

  private final LX lx; 
  private final LXOscEngine.Transmitter transmitter;

  EnvelopOscClient(LX lx, InetAddress source) throws SocketException {
    this.lx = lx;
    this.transmitter = lx.engine.osc.transmitter(source, 3434);
    
    setupListeners();
    register();
  }

  private class KnobListener implements LXParameterListener {
    
    private final int index;
    private BoundedParameter parameter;
    
    private KnobListener(int index) {
      this.index = index;
    }
    
    void register(BoundedParameter parameter) {
      if (this.parameter != null) {
        this.parameter.removeListener(this);
      }
      this.parameter = parameter;
      if (this.parameter != null){
        this.parameter.addListener(this);
      }
    }
    
    void set(double value) {
      if (this.parameter != null) {
        this.parameter.setNormalized(value);
      }
    }
    
    public void onParameterChanged(LXParameter p) {
      sendKnobs(); 
    }
  }
  
  private void setupListeners() {
    // Build knob listener objects
    for (int i = 0; i < NUM_KNOBS; ++i) {
      this.knobs[i] = new KnobListener(i);
    }

    // Register to listen for pattern changes 
    lx.engine.getChannel(0).addListener(new LXChannel.AbstractListener() {
      public void patternDidChange(LXChannel channel, LXPattern pattern) {
        int i = 0;
        for (LXPattern p : channel.getPatterns()) {
          if (p == pattern) {
            sendMessage("/lx/pattern/active", i);
            break;
          }
          ++i;
        }
        registerKnobs(pattern);
        sendKnobs();
      }
    });
  }
  
  public void oscMessage(OscMessage message) {
    if (message.matches("/lx/register/envelop")) {
      register();
    } else if (message.matches("/lx/pattern/index")) {
      lx.goIndex(message.get().toInt());
    } else if (message.matches("/lx/pattern/parameter")) {
      // TODO(mcslee): sanitize input
      knobs[message.getInt()].set(message.getDouble());
    } else if (message.matches("/lx/tempo/bpm")) {
      lx.tempo.setBpm(message.getDouble());
      println("Set bpm to: " + lx.tempo.bpm());
    } else if (message.matches("/lx/tempo/tap")) {
      lx.tempo.trigger(false);
    }
  }
  
  void register() {
    sendMessage("/lx/register");
    sendPatterns();
    // registerKnobs(lx.engine.getActivePattern());
    sendKnobs();
  }
  
  void registerKnobs(LXPattern pattern) {
    int i = 0;
    for (LXParameter parameter : pattern.getParameters()) {
      if (i > NUM_KNOBS) {
        break;
      }
      if (parameter instanceof BoundedParameter) {
        knobs[i++].register((BoundedParameter) parameter);
      }
    }
    while (i < NUM_KNOBS) {
      knobs[i++].register(null);
    }
  }
  
  void sendKnobs() {
    OscMessage parameter = new OscMessage("/lx/pattern/parameter/values");
    for (KnobListener knob : this.knobs) {
      if (knob.parameter != null) {
        parameter.add(knob.parameter.getNormalizedf());
      } else {
        parameter.add(-1);
      }
    }
    sendPacket(parameter);
  }
  
  private void sendPatterns() {
    //OscMessage message = new OscMessage("/lx/pattern/list");
    //LXPattern activePattern = lx.engine.getPattern();
    //int active = 0, i = 0;
    //for (LXPattern pattern : lx.getPatterns()) {
    //  message.add(pattern.getName());
    //  if (pattern == activePattern) {
    //    active = i;
    //  }
    //  ++i;
    //}
    //sendPacket(message);    
    //sendMessage("/lx/pattern/active", active);
  }
  
  private void sendMessage(String addressPattern) {
    sendPacket(new OscMessage(addressPattern));
  }
  
  private void sendMessage(String addressPattern, int value) {
    sendPacket(new OscMessage(addressPattern).add(value));
  }
  
  private void sendPacket(OscPacket packet) {
    try {
      this.transmitter.send(packet);
    } catch (IOException iox) {
      iox.printStackTrace();
    }
  }
}
