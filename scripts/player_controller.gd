class_name PlayerController
extends CharacterBody2D

## Temporary player controller. The visual is drawn by the Player scene so it
## can be replaced later without changing movement or collision behaviour.

@export_range(1.0, 500.0, 1.0, "suffix:px/s") var move_speed := 95.0


func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * move_speed
	move_and_slide()
