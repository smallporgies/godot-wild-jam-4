tool
extends "res://actors/Health.gd"

var speed = 400
var time = 0.0

var start_position = Vector2()
var direction_scal = 1

export(float) var sine_amplitude = 80 setget _set_sine_amplitude
export(bool) var left_to_right = true setget _set_left_to_right 


func _ready():
	start_position = position


func _physics_process(delta):
	if Engine.editor_hint:
		return

	time += delta
	position.x += speed * delta * direction_scal
	position.y =  start_position.y + sin(time * 10) * sine_amplitude


func _set_sine_amplitude(value):
	sine_amplitude = value
	update()

func _set_left_to_right(value):
	left_to_right = value
	if (left_to_right == true):
		direction_scal = 1
	else:
		direction_scal = -1
	update()

func _draw():
	if not Engine.editor_hint:
		return

	var points_array = PoolVector2Array()
	var time_step = 0.02
	for i in range(128):
		var time = time_step * i
		var new_point = Vector2(time * speed * direction_scal, sin(time * 10) * sine_amplitude)
		points_array.append(new_point)
	draw_polyline(points_array, Color(1.0,1.0,1.0), 2.0, true)