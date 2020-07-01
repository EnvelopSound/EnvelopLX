// https://www.youtube.com/watch?v=rvDo9LvfoVE

precision mediump float;
uniform float time;
uniform float speed;
uniform float starSize;
uniform float density;
uniform vec2 mouse;
uniform vec2 resolution;
uniform vec3 colorMixA;

#define TWO_PI 6.2831
#define PI 3.1415
#define HALF_PI 1.5707
#define QUARTER_PI 0.7853
#define NUM_LAYERS 8.0
#define FBM_OCTAVES 5


mat2 rotate(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

float star(vec2 uv, float flare) {
  float d= length(uv);
  float m = starSize / d;
  float rays = max(0.0, 1.0 - abs(uv.x * uv.y * 1000.0));
  uv *= rotate(QUARTER_PI);
  rays += max(0.0, 1.0 - abs(uv.x * uv.y * 100.0)) * 0.3;
  rays *= flare;
  m += rays;
  m *= smoothstep(1.0, 0.2, d);
  return m;
}

// https://thebookofshaders.com/10/
float random (vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}

vec3 slayer(vec2 uv, vec3 cm) {
  vec3 col = vec3(0.0);

  vec2 gv = fract(uv) - 0.5;
  vec2 id = floor(uv);


  for (int y = -1; y <=1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 offs = vec2(x, y);
      float n = random(id + offs);
      vec2 sr = vec2(n - 0.5, fract(n * 3456.5678) - 0.5);
      float size = fract(n * 6789.3456);
      float s = star(gv - offs + sr, smoothstep(0.9, 1.0, size) * 0.8);
      vec3 color = sin(vec3(cm.x, cm.y * 0.66, cm.z*0.5) * fract(n * 6789.5432) * TWO_PI) * 0.5 + 0.5;
      color *= cm;//vec3(0.666667,1.0,1.0);
      s *= sin(time * 2.0 + n * TWO_PI) * 0.5 + 1.0;
      col += s * size * color;
    }
  }
  return col;
}

//	<https://www.shadertoy.com/view/4dS3Wd>
//	By Morgan McGuire @morgan3d, http://graphicscodex.com
//
float hash(float n) { return fract(sin(n) * 1e4); }
float hash(in vec2 _st) { return fract(sin(dot(_st.xy, vec2(12.9898,78.233)))* 43758.5453123); }

float noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);

	// Four corners in 2D of a tile
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	// Same code, with the clamps in smoothstep and common subexpressions
	// optimized away.
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm( in vec2 x) {
    float a = 0.3;
    float t = 0.0;
    for( int i=0; i < FBM_OCTAVES; i++ ) {
        t += a*noise(vec2(x));
        x = x * 2.0;
        a *= 0.5;
    }
    return t;
}

void main(void) {

  vec2 uv = (gl_FragCoord.xy - 0.5 * resolution.xy) / resolution.y;
  uv *= density;
  vec2 st = (gl_FragCoord.xy/resolution.xy)*6.0;

  float t = time * speed;

  vec3 col = vec3(0.0);

  //vec3 colorMixA = vec3(max(0.1, sin(time * 0.1) * 0.5 + 0.5), max(0.1, cos(time * 0.123) * 0.5 + 0.5), max(0.1, cos(time * 0.234)));
  vec3 colorMixB = pow(colorMixA, vec3(0.5876));

  // cosmic noise
  // First layer of warping
  vec2 q = vec2(fbm( st ),
                fbm( st + vec2(1.0) ) );

  // Second layer of warping
  vec2 r = vec2(fbm( st + q + vec2(1.7, 9.2) + 0.1 * time ),
                fbm( st + q + vec2(8.3, 2.8) + 0.125 * time ) );

  // float f = fbm(st + vec2(fbm(st + vec2(fbm(st + r)))));
  float f = fbm(st + r);

  col = mix(vec3(0.101961,0.619608,0.666667),
              vec3(colorMixB.x, colorMixB.y * 0.66, colorMixB.z*0.5),//vec3(0.666667,0.666667,0.5),
              clamp((f*f)*4.0,0.0,1.0));

  col = mix(col,
              colorMixB,//vec3(0.666667,1.0,1.0),
              clamp(length(r.x),0.0,1.0));

  col = vec3((f*f*f+0.6*f*f+0.5*f)*col);

  const float m = 1.0/NUM_LAYERS;
  for (float i = 0.0; i < 1.0; i += m) {
    float depth = fract(i+t);
    float scale = mix(20.0, 0.5, depth);
    float fade = depth * smoothstep(1.0, 0.9, depth);
    col += slayer(uv * scale + i * 7654.98, colorMixA) * fade;
  }

  gl_FragColor = vec4(col, 1.0);

}
