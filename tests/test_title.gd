extends SceneTree
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _init() -> void:
	OS.set_environment("UKI_META_PROXY_URL", "")
	call_deferred("run")

func run() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/title.tscn", "project opens title scene")
	change_scene_to_file("res://scenes/title.tscn")
	await scene_changed
	var title := current_scene
	check(title != null and title.name == "TitleScreen", "title scene starts")
	check(title.studio.text == "DAIRN PRESENT" and title.studio.visible, "studio text appears first")
	check(not title.menu.visible and title.play.disabled, "menu waits for studio intro")
	check(title.get_node_or_null("GreatSteppe") == null, "no gameplay scene before PLAY")
	title._start_game()
	await process_frame
	check(current_scene == title, "cannot start while intro is active")
	await create_timer(0.7).timeout
	check(title.studio.modulate.a > 0.95 and not title.menu.visible, "studio title holds before transition")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("/tmp/uki-studio-screen.png") == OK, "studio viewport capture")
	await create_timer(1.8).timeout
	check(not title.studio.visible and title.menu.visible, "studio transitions to game title")
	var logo: TextureRect = title.get_node("Menu/LogoRow/Logo")
	check(logo.texture != null and logo.texture.resource_path == "res://assets/branding/uki-kirpi-logo.svg", "branding logo appears above PLAY")
	check(title.play.text == "PLAY" and not title.play.disabled, "PLAY enabled after fade")
	check(title.play.has_focus(), "keyboard focus on PLAY")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("/tmp/uki-title-screen.png") == OK, "title viewport capture")
	# Activate the actual focused button through the keyboard input path.
	var press := InputEventAction.new()
	press.action = "ui_accept"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = "ui_accept"
	release.pressed = false
	Input.parse_input_event(release)
	await create_timer(0.3).timeout
	check(current_scene != title and current_scene.name == "GreatSteppe", "PLAY opens gameplay")
	if current_scene.name == "GreatSteppe":
		check(current_scene.state != null, "gameplay initializes after PLAY")
		check(int(current_scene.state.world.seed) == 42, "command-line seed survives title transition")
		check(current_scene.state.discovered.size() == 7, "new game retains one-hex reveal rules")
	print("TITLE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
