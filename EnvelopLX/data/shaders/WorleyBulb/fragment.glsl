precision lowp int;
precision mediump float;

attribute vec2 texCoord;

uniform bool rainbow;
uniform bool negative;
uniform int mode;
uniform float iTime;
uniform float amount;
uniform float rainbowAmount;
uniform float alpha;
uniform vec2 iResolution;
uniform vec3 inputColor;

varying vec3 vPosition;
varying vec3 vColor;

// From https://www.youtube.com/watch?v=l-07BXzNdPw
vec3 randomVector(vec3 p) {
	vec3 a = fract(p.xyz*vec3(123.34, 234.34, 345.65));
    a += dot(a, a+34.45);
    vec3 v = fract(vec3(a.x*a.y, a.y*a.z, a.z*a.x));
    return v;
}

vec2 worley(in vec3 uv, in float t, in float factor, out vec3 cols) {
    vec3 st = uv * factor;
    vec2 minDist = vec2(1000.0);
 	vec3 gv = fract(st)-0.5;
    vec3 id = floor(st);
    vec3 cid = vec3(0.0);

    for (float z = -1.0; z <= 1.0; z++) {
        
        for (float y = -1.0; y <= 1.0; y++) {

            for (float x = -1.0; x <= 1.0; x++) {

                vec3 offs = vec3(x, y, z);

                vec3 n = randomVector(id + offs);
                vec3 p = offs + sin(n * t) * .5;
                p -= gv;

                float d = length(p);

                if (d < minDist.x) {
                    minDist.y = minDist.x;
                    minDist.x = d;
                    cid = id + offs;
                } else if (d < minDist.y) {
                    minDist.y = d;
                }

            }
        }
        
    }

    cols = cid * rainbowAmount;
    
    return minDist;
}

void main( void ) {
    
    vec2 uv = gl_FragCoord.xy / iResolution.xy;
    
    float t = iTime * 0.25;

    vec3 ccc = vec3(0.0);
        
    vec2 worleyValue = worley(vPosition, t, amount, ccc);

    float noise = 0.0;
    if (mode == 0) noise = worleyValue.x;
    else if (mode == 1) noise = worleyValue.y;
    else if (mode == 2) noise = worleyValue.y - worleyValue.x;
    
    vec3 baseCol = rainbow ? ccc : inputColor;
    
    vec3 finalColor = baseCol*noise;

    if (negative) finalColor = 1.0 - finalColor;
    
    gl_FragColor = vec4(finalColor, alpha);
}