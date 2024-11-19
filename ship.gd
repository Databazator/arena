extends CharacterBody2D

const ROTATE_SPEED = 4
const ACCEL = 150

@onready var Laser = preload('res://laser.tscn')
@onready var use_agent = get_parent().use_agent
@onready var agent = get_node('agent')
@onready var RADIUS = get_node('CollisionShape2D').shape.radius

var lasers = 0

var mesh_version = -1
var wall_polygons: Array[PackedVector2Array]
var polygons: Array[PackedVector2Array]
var neighbors: Array[Array]

func convert_mesh(mesh):
	var vertices = mesh.get_vertices()
	var edge_map = {}

	wall_polygons = []
	for w in get_parent().walls:
		wall_polygons.append(w.transform * w.get_node('Polygon2D').polygon)

	polygons = []
	neighbors = []

	for i in range(mesh.get_polygon_count()):
		var pvertices = mesh.get_polygon(i)

		var polygon = PackedVector2Array()
		for k in pvertices:
			var p = Vector2(vertices[k].x, vertices[k].z)
			polygon.append(p)
		polygons.append(polygon)

		neighbors.append([])
		for j in range(-1, pvertices.size() - 1):
			var e = [pvertices[j], pvertices[j + 1]]
			e.sort()
			var k = edge_map.get(e)
			if k != null:
				neighbors[i].append(k)
				neighbors[k].append(i)
			else:
				edge_map[e] = i
	
func _physics_process(delta):
	var action
	if use_agent:
		if get_parent().building or get_parent().gems == []:
			action = [0, false, false]
		else:
			if get_parent().mesh_version > mesh_version:
				convert_mesh(%nav_region.navigation_polygon.get_navigation_mesh())
				mesh_version = get_parent().mesh_version

			var gems: Array[Vector2]
			gems.assign(get_parent().gems.map(func(g): return g.position))
			action = agent.action(wall_polygons, gems, polygons, neighbors)

	var turn = action[0] if use_agent else Input.get_axis('ui_left', 'ui_right')
	turn = clampi(turn, -1, 1)
	rotation += turn * ROTATE_SPEED * delta

	var thrust = action[1] if use_agent else Input.is_action_pressed('thrust')
	if thrust:
		velocity += Vector2.from_angle(rotation) * ACCEL * delta
		$particles.emitting = true
	else:
		$particles.emitting = false

	var collision = move_and_collide(velocity * delta)
	if collision:
		%bounce_sound.play()
		velocity = velocity.bounce(collision.get_normal()) * 0.7
		if use_agent:
			agent.bounce()

	var fire = action[2] if use_agent else Input.is_action_just_pressed('fire')
	if lasers > 0 and fire:
		get_parent().add_laser(-1)
		%fire_sound.play()
		var laser = Laser.instantiate()
		var point = Vector2.from_angle(rotation)
		laser.position = position + point * 20
		laser.rotation = rotation
		laser.velocity = velocity + point * laser.SPEED
		%lasers.add_child(laser)
