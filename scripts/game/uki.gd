extends Node2D
## Temporary 32 × 32 owl placeholder; only flat shapes, no generated assets.
func _draw() -> void:
	draw_rect(Rect2(-16, -16, 32, 32), Color("e6dec2"))
	draw_circle(Vector2(-7, -4), 6, Color("303638"))
	draw_circle(Vector2(7, -4), 6, Color("303638"))
	draw_circle(Vector2(-6, -5), 2, Color.WHITE)
	draw_circle(Vector2(6, -5), 2, Color.WHITE)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 4), Vector2(4, 4), Vector2(0, 10)]), Color("8D8567"))
