shader_type canvas_item;

// Muestra el paisaje ya horneado (ver landscape.gdshader) y le aplica el
// tinte de la barra chica/monstruo: 0 = normal, 1 = "modo monstruo" a full
// -- todo lo revelado se tiñe de rojo/oscuro como aviso, imitando el cambio
// de imagen a "monstruo" del arcade original.

uniform float panic = 0.0;

void fragment() {
	vec3 col = texture(TEXTURE, UV).rgb;
	vec3 monster_col = mix(col * 0.4, vec3(0.45, 0.03, 0.06), 0.6);
	COLOR = vec4(mix(col, monster_col, panic), 1.0);
}
