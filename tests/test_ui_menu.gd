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
	print("Resultado: %s" % ("TODO OK" if fails == 0 else "%d fallos" % fails))
	quit(0 if fails == 0 else 1)
