extends SceneTree
## UX del menú: godot --headless --path . --script res://tests/test_ui_menu.gd

var fails: int = 0

func check(ok: bool, msg: String) -> void:
	print(("  OK   " if ok else "  FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui := GameUI.new()
	root.add_child(ui)
	await process_frame
	ui.show_menu({"sound": true, "vib": false, "vib_visible": true})
	check(ui.sound_btn.text == "Sonido: sí", "el control anuncia que el sonido está activado")
	check(ui.vib_btn.text == "Vibración: no", "el control anuncia que la vibración está desactivada")
	ui.sound_btn.button_pressed = false
	check(ui.sound_btn.text == "Sonido: no", "la etiqueta de sonido se actualiza al desactivarlo")
	ui.vib_btn.button_pressed = true
	check(ui.vib_btn.text == "Vibración: sí", "la etiqueta de vibración se actualiza al activarla")
	# Calidad táctil: tamaño cómodo, relieve al pulsar y estado deshabilitado definido.
	check(ui.hud_back_button.get_parent().custom_minimum_size.y >= 104,
		"el botón de volver tiene un objetivo táctil cómodo")
	check(ui.sound_btn.custom_minimum_size.y >= 92,
		"los ajustes tienen un objetivo táctil cómodo")
	var back_tile: Control = ui.hud_back_button.get_parent()
	var up_box := back_tile.get_theme_stylebox("panel") as StyleBoxFlat
	ui.hud_back_button.button_down.emit()
	await process_frame
	var down_box := back_tile.get_theme_stylebox("panel") as StyleBoxFlat
	check(up_box != null and down_box != null and down_box.border_width_bottom < up_box.border_width_bottom,
		"el botón de volver se hunde al pulsar")
	ui.hud_back_button.button_up.emit()
	await process_frame
	check(back_tile.get_theme_stylebox("panel") == up_box, "el botón de volver recupera el relieve al soltar")
	var pill_disabled := ui.sound_btn.get_theme_stylebox("disabled")
	check(pill_disabled != null and not (pill_disabled is StyleBoxEmpty),
		"los ajustes tienen un estado deshabilitado definido")
	print("Resultado: %s" % ("TODO OK" if fails == 0 else "%d fallos" % fails))
	quit(0 if fails == 0 else 1)
