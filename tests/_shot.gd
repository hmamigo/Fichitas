extends SceneTree
## Captura temporal: iconos del tema.

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("/tmp/opencode/%s.png" % name)
	print("guardado ", name)

func _doms(main: Node, n: int) -> Array:
	var all: Array = []
	for p in main.packs:
		for pr in p["pairs"]:
			all.append(pr)
	var out: Array = []
	for i in mini(n, all.size()):
		out.append({"tex": all[i]["a"], "stage": i % 3, "up": i % 3 == 1})
	return out

func _init() -> void:
	_run()

func _run() -> void:
	Progress.path = "user://test_shot.json"
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame
	main._on_dark(false)
	await create_timer(0.7).timeout
	await _shot("f_menu_light")
	main._go_subjects()
	await create_timer(0.7).timeout
	await _shot("f_subjects_light")
	main._play("")
	await create_timer(1.2).timeout
	await _shot("f_hud_light")
	main._on_won()
	await create_timer(0.7).timeout
	await _shot("f_win_light")
	main._on_dark(true)
	await create_timer(0.7).timeout
	await _shot("f_menu_dark")
	main._go_subjects()
	await create_timer(0.7).timeout
	await _shot("f_subjects_dark")
	main._play("")
	await create_timer(1.2).timeout
	await _shot("f_hud_dark")
	main._on_won()
	await create_timer(0.7).timeout
	await _shot("f_win_dark")
	quit(0)
