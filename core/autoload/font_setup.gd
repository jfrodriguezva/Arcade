extends Node
## Agrega fuentes de respaldo (emoji a color + símbolos monocromo) a la
## fuente por defecto del motor. Sin esto, cualquier ícono con emoji o
## símbolo que la fuente del motor no trae (corazones, dados, flechas
## ▲▼, piezas de ajedrez ♔♕, etc.) se ve en blanco en la build Web —
## a diferencia de nativo/editor, el navegador no le deja al motor usar
## las fuentes del sistema operativo como respaldo automático.
##
## Orden importa: el primero que tenga el glyph gana, así que la fuente
## de emoji a color va primero (para que 🎲 salga a color) y las de
## símbolos monocromo después, para lo que el emoji no cubre (flechas,
## piezas de ajedrez, fichas de dominó/mahjong).
const FALLBACK_PATHS := [
	"res://fonts/NotoColorEmoji.ttf",
	"res://fonts/NotoSansSymbols.ttf",
	"res://fonts/NotoSansSymbols2-Regular.ttf",
]


func _ready() -> void:
	var fallbacks: Array = ThemeDB.fallback_font.fallbacks
	for path: String in FALLBACK_PATHS:
		var font: FontFile = load(path)
		if font != null:
			fallbacks.append(font)
	ThemeDB.fallback_font.fallbacks = fallbacks
