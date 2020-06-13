precision mediump float;

uniform float iTime;
uniform vec2 iResolution;

uniform vec3 channel1Color;
uniform vec3 channel2Color;
uniform vec3 channel3Color;
uniform vec3 channel4Color;

uniform float channel1Opacity;
uniform float channel2Opacity;
uniform float channel3Opacity;
uniform float channel4Opacity;

uniform float channel1Volume;
uniform float channel2Volume;
uniform float channel3Volume;
uniform float channel4Volume;

uniform bool isElliptical;
uniform bool isVertical;

#define PI 3.14159265359

void main() {

    vec2 uv = gl_FragCoord.xy / iResolution.xy;
    vec2 uvp  = -1.0 + 2.0 * uv;
    
    if (isElliptical) uvp *= vec2(sin(uvp.x) * PI, sin(uvp.y) * PI);

    vec4 a = vec4(0.0);
    vec4 b = vec4(0.0);
    float factor = 0.025;

    if (isVertical) {
        a = vec4(sin(uvp.y * 1.0 - iTime * 0.1),
                cos(uvp.y * 1.0 - iTime * 0.2),
                sin(uvp.y * 1.0 - iTime * 0.3),
                cos(uvp.y * 1.0 - iTime * 0.5));

        b = vec4(factor / abs(uvp.x + a.x),
                factor / abs(uvp.x + a.y),
                factor / abs(uvp.x + a.z),
                factor / abs(uvp.x + a.w));
    } else {
        a = vec4(sin(uvp.x * 1.0 - iTime * 0.1),
                cos(uvp.x * 1.0 - iTime * 0.2),
                sin(uvp.x * 1.0 - iTime * 0.3),
                cos(uvp.x * 1.0 - iTime * 0.5));
    
        b = vec4(factor / abs(uvp.y + a.x),
                factor / abs(uvp.y + a.y),
                factor / abs(uvp.y + a.z),
                factor / abs(uvp.y + a.w));
    }
    
    vec3 finalColor = vec3(0.0);
    finalColor = mix(finalColor, channel1Color * b.x * channel1Opacity, channel1Volume);
    finalColor = mix(finalColor, channel2Color * b.y * channel2Opacity, channel2Volume);
    finalColor = mix(finalColor, channel3Color * b.z * channel3Opacity, channel3Volume);
    finalColor = mix(finalColor, channel4Color * b.w * channel4Opacity, channel4Volume);
    
    gl_FragColor = vec4(finalColor, 1.0);
}