shader_type canvas_item;

// Paisaje procedural (cielo con degradado, sol y montañas), calculado por
// píxel en vez de por celda de una cuadrícula — por eso se ve nítido a
// cualquier resolución/tamaño de pantalla ("full HD" real, no un mosaico
// de cuadros de color) y sin bordes dentados en el sol o la silueta de
// las montañas (smoothstep en vez de un corte duro).

uniform float level = 1.0;

void fragment() {
	vec2 uv = UV;

	vec2 sun_center = vec2(0.72, 0.26);
	float sun_dist = distance(uv, sun_center);

	float mountain_height = 0.55 + 0.12 * sin(uv.x * 8.0 + level);

	vec3 sky_top = vec3(0.2, 0.25, 0.55);
	vec3 sky_bottom = vec3(0.95, 0.55, 0.35);
	vec3 sky = mix(sky_top, sky_bottom, uv.y);

	vec3 mountain_near = vec3(0.16, 0.19, 0.29);
	vec3 mountain_far = vec3(0.05, 0.07, 0.14);
	float shade = clamp((uv.y - mountain_height) * 2.0, 0.0, 1.0);
	vec3 mountain = mix(mountain_near, mountain_far, shade);

	float mountain_mask = smoothstep(mountain_height - 0.006, mountain_height + 0.006, uv.y);
	vec3 col = mix(sky, mountain, mountain_mask);

	float sun_mask = 1.0 - smoothstep(0.085, 0.098, sun_dist);
	col = mix(col, vec3(1.0, 0.9, 0.55), sun_mask);

	COLOR = vec4(col, 1.0);
}
