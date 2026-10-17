
extends Node2D

var speed = 300
var direction = Vector2(1, 0)
var screen_size = Vector2()
var window_size = Vector2(200, 200)

var idle_timer = 0.0
var is_idling = false

var is_dragging = false
var drag_offset = Vector2()

var is_stopped = false

var click_count = 0
var click_timer = 0.0
var double_click_delay = 0.3
var mouse_down = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var area = $AnimatedSprite2D/Area2D


func maybe_idle():
	if randf() < 0.3:
		is_idling = true
		idle_timer = randf_range(1.0, 3.0)
		var r = randi() % 3
		if r == 0:
			animated_sprite.play("Idle")
			speed = 0



func _on_area_input(_viewport, event, _shape_idx):
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

func _ready():
	screen_size = Vector2(DisplayServer.screen_get_size())
	animated_sprite.play("Walking")
	area.input_event.connect(_on_area_input)


func _physics_process(delta: float) -> void:
	
	if is_dragging:
		var mouse_pos = Vector2(DisplayServer.mouse_get_position())
		var new_win_pos = mouse_pos - drag_offset
		DisplayServer.window_set_position(Vector2i(new_win_pos))
		return

	if is_stopped:
		return

	if is_idling:
		idle_timer -= delta
		if idle_timer <= 0:
			is_idling = false
			speed = 300
			animated_sprite.play("Walking")
		return

	var window_position = Vector2(DisplayServer.window_get_position())
	window_position += direction * speed * delta

	window_position.x = clamp(window_position.x, 0, screen_size.x - window_size.x)
	window_position.y = clamp(window_position.y, 0, screen_size.y - window_size.y)

	if window_position.x <= 0 or window_position.x >= screen_size.x - window_size.x:
		direction.x *= -1
		animated_sprite.flip_h = !animated_sprite.flip_h
		maybe_idle()

	if window_position.y <= 0 or window_position.y >= screen_size.y - window_size.y:
		direction.y *= -1
		maybe_idle()

	DisplayServer.window_set_position(Vector2i(window_position))
