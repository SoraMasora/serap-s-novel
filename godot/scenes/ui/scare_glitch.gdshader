// 0.7.4 · Глитч скримера (GL Compatibility / WebGL2): разнос RGB, сдвиг полос, шум, негатив, красный тон.
// Все эффекты — через uniform'ы из loop_overlay.gd; в «мягком режиме» они остаются нулевыми.
shader_type canvas_item;

uniform float split : hint_range(0.0, 0.08) = 0.0;
uniform float slices : hint_range(0.0, 1.0) = 0.0;
uniform float noise : hint_range(0.0, 1.0) = 0.0;
uniform float invert : hint_range(0.0, 1.0) = 0.0;
uniform float redden : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

varying vec4 tint;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453);
}

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 uv = UV;
	float band = floor(uv.y * 28.0);
	float pick = hash(vec2(band, floor(seed * 7.0)));
	if (pick > 1.0 - slices * 0.55) {
		uv.x += (hash(vec2(band, seed + 3.1)) - 0.5) * 0.22 * slices;
	}
	float s = split * (0.65 + 0.35 * hash(vec2(seed, band)));
	vec4 c = texture(TEXTURE, uv);
	c.r = texture(TEXTURE, uv + vec2(s, s * 0.25)).r;
	c.b = texture(TEXTURE, uv - vec2(s, 0.0)).b;
	float n = hash(floor(uv * vec2(640.0, 360.0)) + vec2(seed * 13.0, seed * 7.0));
	c.rgb = mix(c.rgb, vec3(n), noise * 0.4);
	c.rgb = mix(c.rgb, vec3(1.0) - c.rgb, invert);
	c.rgb = mix(c.rgb, vec3(c.r * 1.3 + 0.08, c.g * 0.3, c.b * 0.34), redden);
	COLOR = c * tint;
}
