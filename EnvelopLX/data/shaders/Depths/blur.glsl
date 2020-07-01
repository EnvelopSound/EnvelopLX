//  Blur  effect
//  Edited  from  https://www.shadertoy.com/view/XdfGDH

uniform float iTime;
uniform float sigma;
uniform vec2 iResolution;
uniform sampler2D texture;

float  normpdf(in float  x,  in float  sigma)  {
    return  0.39894 * exp(-0.5 * x * x / (sigma * sigma)) / sigma;
}

void main() {
    
	vec2  uv = gl_FragCoord.xy / iResolution.xy;
    
    vec3  c = texture(texture, uv).rgb;
    
    vec2  center = vec2(0.5, 0.5);
    center = vec2(0.5, 0.5);

    float  d = smoothstep(0.3, 1.0, 0.1 + distance(center, uv));

    //  grain  effect
    float  strength = 2.0;
    float  x = (uv.x + 4.0) * (uv.y + 4.0) * (iTime * 10.0);
    vec3  grain = vec3(mod((mod(x, 13.0) + 1.0) * (mod(x, 123.0) + 1.0), 0.01) - 0.005) * strength;

    const int  mSize = 7;
    const int  kSize = (mSize - 1) / 2;
    float  kernel[mSize];
    vec3  final_colour = vec3(0.0);

    //create  the  1-D  kernel
    float  Z = 0.0;
    for (int  j = 0; j <= kSize; ++j) {
        kernel[kSize + j] = kernel[kSize - j] = normpdf(float(j), sigma);
    }

    //get  the  normalization  factor  (as  the  gaussian  has  been  clamped)
    for (int  j = 0; j < mSize; ++j) {
        Z += kernel[j];
    }

    //read  out  the  texels
    for (int  i = -kSize; i <= kSize; ++i) {
        for(int  j = -kSize; j <= kSize; ++j) {
            final_colour += kernel[kSize + j] * kernel[kSize + i] * texture(texture, (gl_FragCoord.xy + vec2(float(i), float(j))) / iResolution.xy).rgb;
                }
    }

    vec3  c_step_1 = final_colour / (Z * Z);

    float  nd = 1.0 - d;
    vec3 c_step_2 = clamp(c_step_1 * nd, 0.0, 1.0);

    // I don't like the image too clean
    c_step_2 += grain * 1.0;

    gl_FragColor = vec4(c_step_2, 1.0);
}