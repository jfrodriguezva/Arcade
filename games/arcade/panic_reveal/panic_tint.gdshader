shader_type canvas_item;

// Muestra la foto del nivel con un poco más de saturación y contraste (más
// "de fondo de Windows") y le aplica el tinte de la barra chica/monstruo:
// panic 0 = normal, 1 = "modo monstruo" a full -- todo lo revelado se tiñe
// de rojo/oscuro como aviso, imitando el cambio de imagen a "monstruo" del
// arcade original.

uniform float panic = 0.0;
uniform float saturation = 1.18;
uniform float contrast = 1.06;

void fragment() {
	vec3 col = texture(TEXTURE, UV).rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	col = clamp((col - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec3 monster_col = mix(col * 0.4, vec3(0.45, 0.03, 0.06), 0.6);
	COLOR = vec4(mix(col, monster_col, panic), 1.0);
}
