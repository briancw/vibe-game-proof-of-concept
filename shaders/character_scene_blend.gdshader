shader_type canvas_item;

// A restrained ambient grade for procedural CanvasItem characters. Sampling
// the already-rendered room lets the character borrow a little of its warm,
// low-saturation palette without flattening its authored skin and clothing.
uniform sampler2D room_screen : hint_screen_texture, repeat_disable, filter_nearest;
uniform float environment_strength : hint_range(0.0, 0.35) = 0.14;
uniform float desaturation : hint_range(0.0, 0.2) = 0.04;

void fragment() {
	vec4 character = COLOR;
	vec3 room_color = texture(room_screen, SCREEN_UV).rgb;
	float room_light = dot(room_color, vec3(0.299, 0.587, 0.114));
	vec3 room_warmth = mix(vec3(0.78, 0.72, 0.64), room_color, 0.42);
	vec3 graded = character.rgb * mix(vec3(1.0), room_warmth * 1.18, environment_strength);
	graded *= mix(0.96, 1.04, room_light);
	float luminance = dot(graded, vec3(0.299, 0.587, 0.114));
	character.rgb = mix(graded, vec3(luminance), desaturation);
	COLOR = character;
}
