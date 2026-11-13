extends SceneTree
## Capturas para ajustar el aspecto: godot --path . --script res://tests/_shot.gd
## Guarda en /tmp/opencode. No forma parte de las pruebas.

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
	await _shot("m_menu")
	main._go_subjects()
	await create_timer(1.4).timeout
	await _shot("m_subjects")
	main.board.cam_z = main.board.subject_station.pan_bounds(main.board.subject_station.fit_distance()).y
	await _shot("m_subjects_bottom")
	main._play("")
	await create_timer(2.2).timeout
	await _shot("m_game")
	main._on_won()
	await create_timer(0.8).timeout
	await _shot("m_win")
	main._go_menu()
	await create_timer(1.2).timeout
	Progress.data["level"] = 20
	main._play("")
	await create_timer(2.2).timeout
	await _shot("m_game24")
	main._on_won()
	await create_timer(0.8).timeout
	await _shot("m_win24")
	quit(0)