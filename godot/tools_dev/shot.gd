extends SceneTree
## Dev: скриншот главной сцены в нужной точке сюжета.
## godot --path . -s res://tools_dev/shot.gd -- --scene=c1_bug --i=0 --steps=3 --wait=2 --out=/tmp/a.png
func _init() -> void:
	call_deferred("_go")

func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + k + "="):
			return a.get_slice("=", 1)
	return d

func _go() -> void:
	var main: Control = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var sc := _arg("scene", "")
	if sc != "":
		main.runner.new_game("Кир")
		main.runner.st.scene = sc
		main.runner.st.i = int(_arg("i", "0"))
		var fl := _arg("flags", "")
		for f in fl.split(",", false):
			main.runner.st.flags[f] = true
		main.runner.st.feel = float(_arg("feel", "60"))
		main.title.visible = false
		var bgk := _arg("bg", "")
		if bgk != "":
			main.runner.st.bg = bgk
			main.set_bg(bgk, true)
		var sh := _arg("show", "")
		if sh != "":
			main.runner.show_char("sera", sh, "center") if main.runner.has_method("show_char") else null
			main._show_view("sera", sh, "center")
			main.runner.st.chars["sera"] = {"expr": sh, "pos": "center"}
		main.begin()
	var steps := int(_arg("steps", "0"))
	for k in steps:
		await create_timer(float(_arg("dt", "0.6"))).timeout
		var ev := _arg("ev", "adv")
		if ev == "adv":
			main.textbox.finish_typing() if main.textbox.typing else main.advance()
	var mx := _arg("mapx", "")
	if mx != "":
		await create_timer(0.5).timeout
		var w: PixelWorld = main.pixel_map.pworld
		w.hero.x = float(mx)
		w.hero.y = float(_arg("mapy", "120"))
		w.cam_x = clampf(w.hero.x - 160.0, 0, 240)
		var ac := _arg("act", "")
		if ac != "":
			await create_timer(0.3).timeout
			w.act(ac)
	var ex := _arg("expr", "")
	if ex != "":
		await create_timer(0.4).timeout
		var e := Expression.new()
		e.parse(ex.replace("~", ","), ["Game", "SaveSystem"])
		e.execute([root.get_node("Game"), root.get_node("SaveSystem")], main)
	var hv := int(_arg("hover", "-1"))
	if hv >= 0:
		await create_timer(0.6).timeout
		main.choice_list.get_child(hv).set_hover(true)
	var times := _arg("times", "")
	if times != "":
		var t0 := 0.0
		for ts in times.split(",", false):
			await create_timer(float(ts) - t0).timeout
			t0 = float(ts)
			var im := root.get_viewport().get_texture().get_image()
			im.save_png(_arg("out", "/tmp/shot.png").replace(".png", "_%s.png" % ts))
		quit(0)
		return
	await create_timer(float(_arg("wait", "1.5"))).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(_arg("out", "/tmp/shot.png"))
	print("SHOT ", _arg("out", "/tmp/shot.png"))
	quit(0)
