extends Sprite2D
class_name ImageLevel

func _ready() -> void:
	var pos : Vector2 = Vector2.ZERO
	
	if centered:
		pos = -texture.get_size() / 2
	
	var bitmap : BitMap = BitMap.new()
	
	bitmap.create_from_image_alpha(texture.get_image())
	
	var polygons : Array[PackedVector2Array] = bitmap.opaque_to_polygons(
		Rect2(Vector2.ZERO,texture.get_size())
	)
	
	for polygon in polygons:
		var body : StaticBody2D = StaticBody2D.new()
		add_child(body)
		body.position += pos
		var col : CollisionPolygon2D = CollisionPolygon2D.new()
		col.polygon = polygon
		body.add_child(col)
