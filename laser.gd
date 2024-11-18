extends CharacterBody2D

const SPEED = 300

func _physics_process(delta):
	var c := move_and_collide(velocity * delta)
	if c:
		queue_free()
		get_parent().get_parent().laser_hit(c.get_collider())
