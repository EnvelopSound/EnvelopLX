import java.net.InetAddress;
import java.util.Map;

static class OscListener implements LXOscListener {
  
  private final LX lx;
  
  private final Map<InetAddress, LXOscClient> clients =
    new HashMap<InetAddress, LXOscClient>();
  
  OscListener(LX lx) {
    this.lx = lx;
  }
  
  public void oscMessage(OscMessage message) {
    println("[" + message.getSource() + "] " + message);
    if (message.matches("/lx/register/envelop")) {
      LXOscClient client = clients.get(message.getSource()); 
      if (client == null) {
        try {
          clients.put(message.getSource(), new LXOscClient(lx, message.getSource()));
        } catch (SocketException sx) {
          sx.printStackTrace();
        }
      }
    }
  }
}

static class LXOscClient implements LXOscListener {
  private final LX lx;
  private final LXOscEngine.Transmitter transmitter;
  
  private final static int NUM_KNOBS = 12;
  private final KnobListener[] knobs = new KnobListener[NUM_KNOBS]; 

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
  
  LXOscClient(LX lx, InetAddress address) throws SocketException {
    this.lx = lx;
    this.transmitter = lx.engine.oscEngine.transmitter(address, 3434);
    
    lx.engine.oscEngine.addListener(this);
    
    setupListeners();
    
    // Register
    register();
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
    }
  }
  
  void register() {
    sendMessage("/lx/register");
    sendPatterns();
    registerKnobs(lx.getPattern());
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
    OscMessage message = new OscMessage("/lx/pattern/list");
    LXPattern activePattern = lx.getPattern();
    int active = 0, i = 0;
    for (LXPattern pattern : lx.getPatterns()) {
      message.add(pattern.getName());
      if (pattern == activePattern) {
        active = i;
      }
      ++i;
    }
    sendPacket(message);    
    sendMessage("/lx/pattern/active", active);
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