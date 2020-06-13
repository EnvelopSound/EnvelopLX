#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

varying vec3 vPosition;
varying vec4 vertColor;

//input color
uniform float alpha;

void main() {

  //outputColor
  gl_FragColor = vertColor;
}