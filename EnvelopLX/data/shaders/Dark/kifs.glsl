#define PI 3.1415
#define NUM_ITERATIONS 5

uniform vec2 iResolution;
uniform float iTime;
uniform float fractalSize;
uniform float fractalSpeed;
uniform float evolutionSpeed;
uniform sampler2D iChannel0;

vec2 getPolar(float angle) {
    return vec2(sin(angle), cos(angle));
}

vec2 st(vec2 uv) {
    uv *= fractalSize;
    // uv *= 1.075;
    
    vec3 col = vec3(0.0);
    
    uv.x = abs(uv.x);
    uv.y += tan(0.833333* PI) * 0.5;
    
    vec2 n = getPolar(0.833333* PI);
    uv -= n * max(0.0, dot(uv-vec2(0.5, 0.0), n)) * 2.0;
    
    n = getPolar(0.666666 * ((sin(iTime*evolutionSpeed) * 0.5 + 0.5) * PI));
    float scale = 1.0;
    uv.x += 0.5;
    for (int i = 0; i < NUM_ITERATIONS; i++) {
        uv *= 3.0;
        scale *= 3.0;
       	uv.x -= 1.5;
        uv.x = abs(uv.x);
        uv.x -= 0.5;
        uv -= n * min(0.0, dot(uv, n)) * 2.0;
    }
    
    uv /= scale;
    return uv;
}

void main( ) {
    
    vec2 uv = (gl_FragCoord.xy - 0.5 * iResolution.xy) / iResolution.y;
    
    float t = sin(iTime * fractalSpeed) * 0.5 + 0.5;
    vec3 col = texture(iChannel0, st(uv) + t).rgb;

    gl_FragColor = vec4(col,1.0);

}