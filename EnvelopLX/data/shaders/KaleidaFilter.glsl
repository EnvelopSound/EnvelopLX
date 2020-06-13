// from shadertoy https://www.shadertoy.com/view/4ss3WX

uniform vec2 iResolution;
uniform sampler2D texture;
uniform float iTime;

uniform float sections;
uniform float txTime;
uniform float offset;

#define iChannel0 texture

const float PI = 3.141592658;
const float TAU = 2.0 * PI;

float Tile1D(float p, float a){
  p -= 4.0 * a * floor(p/4.0 * a);
  p -= 2.* max(p - 2.0 * a , 0.0);
  return p;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord );

void main() {
    mainImage(gl_FragColor,gl_FragCoord.xy);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 pos = vec2(fragCoord.xy - offset * iResolution.xy) / iResolution.y;

	float rad = length(pos);
	float angle = atan(pos.y, pos.x);

	angle += iTime*0.1;

	float ma = mod(angle, TAU/sections);
	ma = abs(ma - PI/sections);
  
	float x = cos(ma) * rad;
	float y = sin(ma) * rad;

	fragColor = texture(iChannel0, vec2(x - txTime, y - txTime));

}