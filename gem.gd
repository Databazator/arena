class_name Gem
extends Area2D

func _on_body_entered(_body):
	get_parent().get_parent().collect_gem(self)
	queue_free()
