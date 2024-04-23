@tool
extends Node2D
class_name ShapeDrawer

@export var shape : Shape2D : set = set_shape

func set_shape(value : Shape2D) -> void:
	if shape:
		shape.changed.disconnect(queue_redraw)
	shape = value
	if shape:
		shape.changed.connect(queue_redraw)
	queue_redraw()

@export var color : Color = Color(0,0,0) : set = set_color

func set_color(value : Color) -> void:
	color = value
	queue_redraw()

func _draw() -> void:
	if shape is CircleShape2D:
		draw_circle(Vector2.ZERO,shape.radius,color)
	elif shape is RectangleShape2D:
		draw_rect(shape.get_rect(),color)

