shader_type canvas_item;

// Capa de "opaco" sobre el paisaje: mask_tex trae un texel por celda
// lógica del tablero (blanco = ya capturada, negro = todavía sin
// revelar), muestreada con filtro bilineal (filter_linear) para que el
// borde de revelado salga suave en vez del escalón duro de un panel por
// celda, sin tener que subir la resolución de la cuadrícula del juego.
//
// OJO: smoothstep(0.42, 0.58, revealed) aquí sería un error -- el valor
// ya viene interpolado linealmente por el sampler a lo largo de todo el
// ancho de una celda (CELL px), y un smoothstep con bordes tan juntos
// COMPRIME ese degradado ya suave a una franja angosta (~16% del ancho),
// dejando un borde más duro/escalonado que si no se tocara -- eso es lo
// que se veía "cuadriculado". Se deja el valor bilineal tal cual, solo
// recortado a [0,1] por seguridad numérica.

uniform sampler2D mask_tex: filter_linear, repeat_disable;
uniform vec4 cover_color: source_color = vec4(0.145, 0.157, 0.204, 1.0);

void fragment() {
	float revealed = clamp(texture(mask_tex, UV).r, 0.0, 1.0);
	COLOR = vec4(cover_color.rgb, 1.0 - revealed);
}
