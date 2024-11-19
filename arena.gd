extends Node2D

@export var use_agent = false
@export var random_seed = -1
@export var starting_level = 1
@export var show_navmesh = false
@export var show_path = false

@onready var Explosion = preload('res://explosion.tscn')
@onready var GemClass = preload('res://gem.tscn')
@onready var LaserIcon = preload('res://laser_icon.tscn')
@onready var Wall = preload('res://wall.tscn')

var level = 0
var mesh_version = 0
var score = 0

var building = true
var walls = []

# We can't remove gems instantly from the tree when they are collected, so we
# keep track of the existing gems here.
var gems: Array[Gem] = []

var time_left = 0

const TIME_LIMIT = 60

func _ready():
	if show_navmesh:
		NavigationServer2D.set_debug_enabled(true)

	if show_path:
		get_node('debug_path').show()

	level = starting_level - 1

	if random_seed != -1:
		seed(random_seed)

	var args = OS.get_cmdline_user_args()
	for arg in args:
		match arg:
			'-agent':
				use_agent = true
			_:
				print('unknown argument: ' + arg)
				get_tree().quit()

	next_level.call_deferred()

func random_point(rect):
	return Vector2(randf_range(rect.position.x, rect.end.x),
				   randf_range(rect.position.y, rect.end.y))

func collides(a, b):
	var s = a.get_node('CollisionShape2D')
	var t = b.get_node('CollisionShape2D')
	return s.shape.collide(s.global_transform, t.shape, t.global_transform)

func is_reachable(pos, epsilon):
	var map = get_world_2d().navigation_map
	var path = NavigationServer2D.map_get_path(map, $ship.position, pos, true)
	assert (path.size() > 0, 'navigation server is not ready')
	return path[path.size() - 1].distance_to(pos) <= epsilon

func build_level():
	get_tree().paused = true
	building = true
	
	var extent = Rect2(
		%left_wall.position.x + 5, %top_wall.position.y + 5,
		%right_wall.position.x - %left_wall.position.x - 10,
		%bottom_wall.position.y - %top_wall.position.y - 10)

	for w in walls:
		w.queue_free()
	walls = []

	var count = 4 + level
	##########################################
	#count = 1
	##########################################
	var extent1 = extent.grow(-100)
	var key_points = [extent1.position, Vector2(extent1.position.x, extent1.end.y),
					  extent1.end, Vector2(extent1.end.x, extent1.position.y)]

	for i in range(count):
		var w

		while true:
			w = Wall.instantiate()
			w.scale.x = randf_range(20, 50)
			w.rotation = randf_range(0, PI)
			w.position = random_point(extent1)
			%walls.add_child(w)

			$nav_region.rebake()
			await get_tree().physics_frame

			if key_points.all(func(a): return is_reachable(a, 10)):
				break

			$walls.remove_child(w)
			w.queue_free()

		walls.append(w)

	var avoid = walls.duplicate()
	avoid.append($ship)

	await get_tree().physics_frame
	
	#######################################
	#count = 10
	#######################################
	for i in range(count):
		var gem = null
		while true:
			gem = GemClass.instantiate()
			gem.position = random_point(extent.grow(-50))
			if avoid.any(func(a): return collides(a, gem)):
				continue

			if is_reachable(gem.position, 0):
				break

		$gems.add_child(gem)
		gems.append(gem)
		avoid.append(gem)

	mesh_version += 1
	building = false
	get_tree().paused = false

func show_time():
	var t = ceili(time_left)
	var frac = t - floori(time_left)
	$time_label.text = '%d:%02d' % [t / 60, t % 60]
	if time_left <= 5 and frac >= 0.5:
		$time_label.hide()
	else:
		$time_label.show()

func add_score(n):
	score += n
	$score_label.text = 'Score: ' + str(score)

func add_laser(n):
	$ship.lasers += n
	while $laser_icons.get_child_count() > $ship.lasers:
		var l = $laser_icons.get_child(-1)
		l.queue_free()
		$laser_icons.remove_child(l)
	while $laser_icons.get_child_count() < $ship.lasers:
		var l = LaserIcon.instantiate()
		l.position.x = $laser_icons.get_child_count() * 30
		$laser_icons.add_child(l)

func next_level():
	level += 1
	print('level %d' % level)
	$level_label.text = 'Level ' + str(level)
	time_left = TIME_LIMIT
	show_time()
	if level % 2 == 1:
		add_laser(1)
	build_level()

func collect_gem(gem):
	$pickup_sound.play()
	add_score(10)
	gems.erase(gem)
	if $ship.use_agent:
		$ship.agent.gem_collected()

	if gems == []:
		add_score(ceili(time_left))
		$next_level_sound.play()
		next_level.call_deferred()

func update_mesh():
	# Wait for the destroyed wall to actually be gone.
	await get_tree().physics_frame

	$nav_region.rebake()

	await get_tree().physics_frame
	mesh_version += 1

func laser_hit(obj):
	if obj in walls:
		$hit_wall_sound.play()

		var e = Explosion.instantiate()
		e.position = obj.position
		e.emitting = true
		add_child(e)

		obj.queue_free()
		walls.erase(obj)

		update_mesh.call_deferred()

func _on_timer_timeout():
	time_left -= 0.5
	show_time()
	if time_left <= 0:
		$game_over.show()
		print('final score: %d' % score)
		get_tree().paused = true
