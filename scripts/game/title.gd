extends Control
## Presentation only: the gameplay scene owns generation, rules, and state.
const GAME_SCENE := "res://scenes/main.tscn"
@onready var studio: Label = $Studio
@onready var menu: VBoxContainer = $Menu
@onready var play: Button = $Menu/Play
var starting := false

func _ready() -> void:
	studio.modulate.a = 0.0
	play.pressed.connect(_start_game)
	var intro := create_tween()
	intro.tween_property(studio, "modulate:a", 1.0, 0.4)
	intro.tween_interval(1.0)
	intro.tween_property(studio, "modulate:a", 0.0, 0.4)
	intro.tween_callback(_show_menu)

func _show_menu() -> void:
	studio.hide()
	menu.modulate.a = 0.0
	menu.show()
	var fade := create_tween()
	fade.tween_property(menu, "modulate:a", 1.0, 0.4)
	fade.tween_callback(_enable_play)

func _enable_play() -> void:
	play.disabled = false
	play.grab_focus()

func _start_game() -> void:
	if starting or play.disabled:
		return
	starting = true
	play.disabled = true
	var error := get_tree().change_scene_to_file(GAME_SCENE)
	if error != OK:
		starting = false
		play.disabled = false
		push_error("Could not open the gameplay scene: %s" % error_string(error))
