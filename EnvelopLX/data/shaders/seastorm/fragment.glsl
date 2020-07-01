precision mediump float;

varying vec4 vertColor;

//input color
uniform vec4 color;

void main() {

  //outputColor
  gl_FragColor = vec4(color.xyzw);
}
