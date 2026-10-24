
extends Node2D


var chat_window: Window
var settings_window: Window

var context_menu: PopupMenu
var speed = 10
var direction = Vector2(1, 0)
var screen_size = Vector2()
var desktop_rect = Rect2i()
var precise_window_position = Vector2()
var window_size = Vector2(200, 200)

var idle_timer = 0.0
var is_idling = false

var is_dragging = false
var drag_offset = Vector2()

var is_stopped = false

var bubble_timer = 0.0
var bubble_duration = 2.0

var random_speech_timer = 0.0
var random_speech_interval = 15.0

var click_count = 0
var click_timer = 0.0
var double_click_delay = 0.3
var mouse_down = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var area = $AnimatedSprite2D/Area2D
@onready var stop_button = $StopButton
@onready var speech_label = $SpeechLabel
@onready var speech_panel = $SpeechPanel

@onready var tray_menu = $TrayMenu
@onready var tray_icon = $TrayIcon

var stop_button_active = false


func maybe_idle():
	if randf() < 0.3:
		is_idling = true
		idle_timer = randf_range(1.0, 3.0)
		animated_sprite.play("Idle")
		speed = 0



func _on_area_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		context_menu.position = DisplayServer.mouse_get_position()
		context_menu.reset_size()
		context_menu.popup()
		return
			
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			is_stopped = !is_stopped
			
			if is_stopped:
				speed = 0
				animated_sprite.stop()
			else:
				speed = 10
				animated_sprite.play("Walking")
			return

		if not is_stopped:
			speed = 10
			animated_sprite.play("Hurt")
			say("AAAH!")

		is_dragging = true

		var mouse_pos = Vector2(DisplayServer.mouse_get_position())
		var win_pos = Vector2(DisplayServer.window_get_position())
		drag_offset = mouse_pos - win_pos

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and is_dragging:
			is_dragging = false
			
			if not is_stopped:
				animated_sprite.play("Turn_around_poses")
				await animated_sprite.animation_finished
				
				if not is_stopped:
					animated_sprite.play("Walking")

func update_desktop_rect():
	var first_screen_pos = Vector2i(999999, 999999)
	var last_screen_end = Vector2i(-999999, -999999)
	
	for i in range(DisplayServer.get_screen_count()):
		var pos = DisplayServer.screen_get_position(i)
		var size = DisplayServer.screen_get_size(i)
		
		first_screen_pos.x = min(first_screen_pos.x, pos.x)
		first_screen_pos.y = min(first_screen_pos.y, pos.y)
		
		last_screen_end.x = max(last_screen_end.x, pos.x + size.x)
		last_screen_end.y = max(last_screen_end.y, pos.y + size.y)
	desktop_rect = Rect2i(
		first_screen_pos,
		last_screen_end - first_screen_pos
	)

func _ready():
	update_desktop_rect()
	precise_window_position = Vector2(DisplayServer.window_get_position())
	animated_sprite.play("Walking")
	var start_pos = DisplayServer.window_get_position()
	print("Window position: ", start_pos)
	print("Desktop bounds: ", start_pos)
	print("speed ", speed)
	area.input_event.connect(_on_area_input)

	stop_button.position = Vector2(86.5, 173)
	stop_button.size = Vector2(24, 24)
	stop_button.text = "⏻"
	stop_button.add_theme_font_size_override("font_size", 18)
	stop_button.pressed.connect(_on_stop_button_pressed)
	update_stop_button_color()
	speech_label.text = ""
	speech_label.position = Vector2(45, 20)
	speech_label.size = Vector2(120, 32)
	speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speech_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech_label.add_theme_color_override("font_color", Color.WHITE)
	speech_label.add_theme_font_size_override("font_size", 14)
	speech_label.z_index = 10
	speech_panel.position = Vector2(40, 15)
	speech_panel.size = Vector2(120, 32)
	speech_label.z_index = 10
	speech_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var pill = StyleBoxFlat.new()
	pill.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	pill.set_corner_radius_all(16)
	
	speech_panel.add_theme_stylebox_override("panel", pill)
	speech_label.hide()
	speech_panel.hide()
	
	context_menu = PopupMenu.new()
	context_menu.add_item("Chat", 2)
	context_menu.add_item("Settings", 3)
	context_menu.add_separator()
	context_menu.add_item("Reload", 0)
	context_menu.add_item("Exit", 1)
	add_child(context_menu)
	
	context_menu.id_pressed.connect(_on_context_menu_pressed)
	
	tray_menu = PopupMenu.new()
	tray_menu.name = "TrayMenu"
	add_child(tray_menu)
	
	tray_menu.add_item("Chat", 2)
	tray_menu.add_item("Settings", 3)
	tray_menu.add_separator()
	tray_menu.add_item("Reload", 0)
	tray_menu.add_item("Exit", 1)
	tray_icon.menu = tray_menu.get_path()
	tray_menu.id_pressed.connect(_on_context_menu_pressed)
	
func _on_stop_button_pressed():
	stop_button_active = !stop_button_active
	is_stopped = stop_button_active
	
	if stop_button_active:
		speed = 0
		is_dragging = false
		animated_sprite.play("Screen-off")
	else:
		speed = 10
		animated_sprite.play("Walking")
	
	update_stop_button_color()
	


func update_stop_button_color():
	var normal_style = StyleBoxFlat.new()
	var hover_style = StyleBoxFlat.new()
	var pressed_style = StyleBoxFlat.new()

	if stop_button_active:
		normal_style.bg_color = Color.RED
		hover_style.bg_color = Color(1, 0.3, 0.3)
		pressed_style.bg_color = Color(0.7, 0, 0)
	else:
		normal_style.bg_color = Color.BLACK
		hover_style.bg_color = Color(0.25, 0.25, 0.25)
		pressed_style.bg_color = Color(0.1, 0.1, 0.1)

	for style in [normal_style, hover_style, pressed_style]:
		style.set_corner_radius_all(12)

	stop_button.add_theme_stylebox_override("normal", normal_style)
	stop_button.add_theme_stylebox_override("hover", hover_style)
	stop_button.add_theme_stylebox_override("pressed", pressed_style)


func _physics_process(delta: float) -> void:
	
	random_speech_timer += delta
	
	if random_speech_timer >= random_speech_interval:
		random_speech_timer = 0.0
		random_speech_interval = randf_range(15.0, 35.0)
		if not is_stopped and not is_dragging:
			var messages = ["Hehe :3", "Hi", "I am a robot", "Beep boop!", "Leave me alone!", "I'm bored"]
			say(messages.pick_random())
	
	if bubble_timer > 0:
		bubble_timer -= delta
		if bubble_timer <= 0:
			speech_label.hide()
			speech_panel.hide()
	
	if is_dragging:
		var mouse_pos = Vector2(DisplayServer.mouse_get_position())
		var new_win_pos = mouse_pos - drag_offset
		precise_window_position = new_win_pos
		DisplayServer.window_set_position(Vector2i(new_win_pos))
		return

	if is_stopped:
		return

	if is_idling:
		idle_timer -= delta
		if idle_timer <= 0:
			is_idling = false
			speed = 10
			animated_sprite.play("Walking")
		return

	var window_position = precise_window_position
	print("Moving: ", window_position, " direction: ", direction, " speed ", speed )
	window_position += direction * speed * delta

	window_position.x = clamp(
		window_position.x,
		desktop_rect.position.x,
		desktop_rect.end.x - window_size.x
	)
	
	window_position.y = clamp(
		window_position.y,
		desktop_rect.position.y,
		desktop_rect.end.y - window_size.y
	)

	if window_position.x <= desktop_rect.position.x or window_position.x >= desktop_rect.end.x - window_size.x:
		direction.x *= -1
		animated_sprite.flip_h = !animated_sprite.flip_h
		maybe_idle()

	if window_position.y <= desktop_rect.position.y or window_position.y >= desktop_rect.end.y - window_size.y:
		direction.y *= -1
		maybe_idle()

	precise_window_position = window_position
	DisplayServer.window_set_position(Vector2i(window_position))

func say(message: String):
	speech_label.text = message
	speech_label.show()
	speech_panel.show()
	bubble_timer = bubble_duration

func _on_context_menu_pressed(id: int):
	match id:
		0:
			get_tree().reload_current_scene()
		1:
			get_tree().quit()
		2:
			open_chat()
		3:
			open_settings()

func open_chat():
	if is_instance_valid(chat_window):
		chat_window.popup_centered()
		return
	var packed_scene = load("res://chat.tscn") as PackedScene
	chat_window = packed_scene.instantiate() as Window
	get_tree().root.add_child(chat_window)
	chat_window.popup_centered()

func open_settings():
	if is_instance_valid(settings_window):
		settings_window.popup_centered()
		return
	var packed_scene = load("res://setup.tscn") as PackedScene
	settings_window = packed_scene.instantiate() as Window
	get_tree().root.add_child(settings_window)
	settings_window.popup_centered()
