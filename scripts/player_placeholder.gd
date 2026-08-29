extends Node2D

## Deliberately simple stand-in for the future character art.

const RADIUS := 5.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color("e63946"))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color("7f1720"), 1.0, true)
