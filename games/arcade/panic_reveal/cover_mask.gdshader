shader_type canvas_item;

// Capa de "opaco" sobre el paisaje: mask_tex trae un texel por celda
// lógica del tablero (blanco = ya capturada, negro = todavía sin
// revelar), pero se muestrea con filtro bilineal (filter_linear) y se
// suaviza otra vez con smoothstep — el resultado es un borde de revelado
// suave entre celdas vecinas en vez del escalón duro de un panel por
// celda, sin tener que subir la resolución de la cuadrícula del juego.

uniform sampler2D mask_tex: filter_linear, repeat_disable;
uniform vec4 cover_color: source_color = vec4(0.145, 0.157, 0.204, 1.0);

void fragment() {
	float revealed = texture(mask_tex, UV).r;
	revealed = smoothstep(0.42, 0.58, revealed);
	COLOR = vec4(cover_color.rgb, 1.0 - revealed);
}
