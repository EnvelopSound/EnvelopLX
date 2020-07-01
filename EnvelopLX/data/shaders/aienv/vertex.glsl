precision mediump float;

uniform mat4 transform;

uniform sampler2D txtIn;
uniform float radius;
uniform float noiseDepth;

uniform float Channel0;
uniform float Channel1;
uniform float Channel2;
uniform float Channel3;
uniform float Channel4;
uniform float Channel5;
uniform float Channel6;
uniform float Channel7;

attribute vec3 vertex;
attribute vec2 uv;

varying vec4 vertColor;

float brightness(vec3 c) {
  return 0.2126*c.r + 0.7152*c.g + 0.0722*c.b;
}

void main() {

  vec3 col = texture2D(txtIn, uv).rgb;

  float totalSound = 0.0;
  totalSound += Channel0;
  // totalSound += Channel1;
  // totalSound += Channel2;
  // totalSound += Channel3;
  // totalSound += Channel4;
  // totalSound += Channel5;
  // totalSound += Channel6;
  // totalSound += Channel7;
  //totalSound = clamp(totalSound/8.0, 0.0, 1.0);

  float n = totalSound > 0.0 ? totalSound * noiseDepth : noiseDepth;

  float b = brightness(col);
  float r = radius - (b * n);
  float x = r * vertex.x;
  float y = r * vertex.y;
  float z = r * vertex.z;

  vec4 pos = vec4(x, y, z, 1.0);

  float alpha = totalSound > 0.0 ? totalSound : 1.0;

  vertColor = vec4(col.xyz, alpha);

  gl_Position = transform * pos;
}
