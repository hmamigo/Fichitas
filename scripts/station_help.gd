class_name StationHelp
extends Node3D
## Estación "¿Cómo jugar?": una mesa a la izquierda del álbum con la explicación en
## cuatro pasos. Es solo información, así que todo va pintado plano sobre la mesa
## (`FlatLabel`, como en el álbum): la única acción es el botón "Atrás" de la capa 2D.
## La cámara viaja hasta acá desde el menú y vuelve al tocar "Atrás".

const CARD_W := 3.5
const PPU := 128               # píxeles de diseño por unidad del mundo
const TITLE_H := 1.5           # cabecera (icono, título y una línea)
const ROW_H := 1.14            # alto de cada paso
const GAP := 0.16              # aire entre cabecera y pasos, y entre pasos
const TILT := 0.17             # igual que la cámara del tablero
const LOOK_Y := -0.5           # punto de mira bajo: la mesa alta queda centrada pese a la inclinación

# Encuadre: manda el ancho (como en la victoria); la mesa es alta, así que lleva más
# aire a los lados para que el borde cercano, agrandado por la inclinación, no toque el marco.
const FIT_PAD_W := 1.9
const FIT_PAD_H := 0.9

var labels: Array = []          # FlatLabel: cabecera y pasos (nada se toca)
var _table: Node3D
var _height: float = 0.0

func build() -> void:
	clear()
	var rows: Array = [
		{"name": "1 · Elegí qué practicar", "sub": "Materia, recorrido general o repaso.",
			"icon": "cuaderno", "color": Color("4a8ff5")},
		{"name": "2 · Elegí el modo", "sub": "Memoria boca abajo. Asociación a la vista.",
			"icon": "cerebro", "color": Color("a78bfa")},
		{"name": "3 · Tocá las parejas", "sub": "Tocá una ficha y después su pareja.",
			"icon": "juego", "color": Color("ffc93c")},
		{"name": "4 · Recorré la mesa", "sub": "Deslizá y pellizcá para acercar.",
			"icon": "mobile_phone", "color": Color("42cd84")},
	]
	_height = TITLE_H + float(rows.size()) * ROW_H + float(rows.size()) * GAP
	_table = TileLook.table(self, CARD_W + 0.5, _height + 0.5)
	var views: Array = []
	var w: int = int(CARD_W * PPU)
	var k: int = Cards.HELP_K
	var z: float = -_height * 0.5
	var title_px: int = int(TITLE_H * PPU)
	var head := FlatLabel.new()
	head.setup(Vector2(CARD_W, TITLE_H))
	head.position.z = z + TITLE_H * 0.5
	add_child(head)
	head.bake(Cards.help_header("¿Cómo se juega?", "Elegí materia y modo.", w, title_px), w * k, title_px * k)
	head.pop_in(0.0)
	views.append_array(head.views())
	labels.append(head)
	z += TITLE_H + GAP
	var row_px: int = int(ROW_H * PPU)
	for i in rows.size():
		var d: Dictionary = rows[i]
		var lb := FlatLabel.new()
		lb.setup(Vector2(CARD_W, ROW_H))
		lb.position.z = z + ROW_H * 0.5
		add_child(lb)
		lb.bake(Cards.help_row(str(d["name"]), str(d["sub"]), str(d["icon"]), d["color"], w, row_px),
			w * k, row_px * k)
		lb.pop_in(0.04 * float(i + 1))
		views.append_array(lb.views())
		labels.append(lb)
		z += ROW_H + GAP
	FaceTex.settle(views)

func clear() -> void:
	for l in labels:
		(l as Node).queue_free()
	labels.clear()
	if _table != null:
		_table.queue_free()
		_table = null
	_height = 0.0

## Distancia de cámara a la que cabe la mesa entera con aire alrededor.
func fit_distance() -> float:
	var need := Vector2(CARD_W + FIT_PAD_W, maxf(_height, 1.0) + FIT_PAD_H)
	return CamView.distance_for(get_viewport(), need)

## Zona libre del suelo bajo la mesa, en coordenadas del mundo (la mesa es el origen).
func clear_rect() -> Rect2:
	if labels.is_empty():
		return Rect2()
	var w: float = CARD_W + 0.7
	var h: float = _height + 0.7
	return Rect2(global_position.x - w * 0.5, global_position.z - h * 0.5, w, h)
