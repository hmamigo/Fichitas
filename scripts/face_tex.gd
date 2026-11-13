class_name FaceTex
extends RefCounted
## Dibuja una pantalla 2D (los controles del tema) dentro de un SubViewport y
## devuelve su textura, para usarla como cara de una loseta 3D. Se pinta durante
## dos frames y luego el viewport queda dormido: no cuesta nada en cada frame.

## En headless (pruebas) no hay render: se devuelve null y la loseta queda lisa.
static func available() -> bool:
	return DisplayServer.get_name() != "headless"

## Crea el viewport con `content` dentro. Quien llama es dueño de liberarlo.
static func render(host: Node, content: Control, w: int, h: int) -> SubViewport:
	if not available():
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(content)
	content.position = Vector2.ZERO
	content.size = Vector2(w, h)
	return vp

## Deja de repintar los viewports cuando ya se han visto unos frames.
static func settle(views: Array) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for i in 3:
		await tree.process_frame
	for v in views:
		if is_instance_valid(v):
			(v as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED