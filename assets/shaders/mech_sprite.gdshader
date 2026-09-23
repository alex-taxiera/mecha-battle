shader_type canvas_item;
// Battle sprite looks: a hit flash, and the greyed, dimmed look of a mech that's shut down or
// destroyed.

// Mixes the sprite toward white.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// Mixes the sprite toward its own grey.
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
// Scales the sprite's brightness: 1 leaves it as it is.
uniform float brightness : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(grey), desaturate) * brightness;
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c;
}
