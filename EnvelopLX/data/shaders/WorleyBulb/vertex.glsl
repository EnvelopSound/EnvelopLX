precision mediump float;

uniform mat4 transform;

uniform float iTime;
uniform float amount;
uniform int mode;

attribute vec3 position;
attribute vec4 color;
attribute vec3 normal;

varying vec3 vPosition;
varying vec3 vColor;

// From https://www.youtube.com/watch?v=l-07BXzNdPw
vec3 randomVector(vec3 p) {
	vec3 a = fract(p.xyz*vec3(123.34, 234.34, 345.65));
    a += dot(a, a+34.45);
    vec3 v = fract(vec3(a.x*a.y, a.y*a.z, a.z*a.x));
    return v;
}

vec2 worley(vec3 uv, float t, float factor) {
    vec3 st = uv * factor;
    vec2 minDist = vec2(1000.0);
 	vec3 gv = fract(st)-0.5;
    vec3 id = floor(st);

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
                } else if (d < minDist.y) {
                    minDist.y = d;
                }

            }
        }
        
    }
    
    return minDist;
}

void main(void) {

    float t = iTime * 0.25;
        
    vec2 worleyValue = worley(position, t, amount);

    float noise = 0.0;
    if (mode == 0) noise = worleyValue.x;
    else if (mode == 1) noise = worleyValue.y;
    else if (mode == 2) noise = worleyValue.y - worleyValue.x;

    vec3 np = position + normal * (noise * 0.2);

    vPosition = np;

    vec4 fp = vec4(transform * vec4(np, 1.0));

    vColor = vec3(noise);

    gl_Position = vec4(fp);

}