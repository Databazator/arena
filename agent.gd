extends Node2D
const Ship = preload("res://ship.gd")
@onready var ship : Ship = get_parent()
@onready var debug_path: Line2D = ship.get_node('../debug_path')

@onready var debug_vec: Line2D = ship.get_node('../debug_vec')
@onready var debug_vec2: Line2D = ship.get_node('../debug_vec2')

@onready var debug_objs: Node2D = ship.get_node('../debug_objs')
@onready var DebugRect = preload('res://debug_rect.tscn')
@onready var DebugLabel = preload('res://debug_label.tscn')

@onready var WAYPOINT_REACHED_DIST_MARGIN = 50

const THRUST_ANGLE_MARGIN = deg_to_rad(8)
const SPEED_STOP_MARGIN = 5
var ticks = 0
var spin:int = 0
var thrust:bool = false
var current_velocity

var corrected_rotation_vector:Vector2 = Vector2.ZERO

var astar_planner: Util.AStarGraph = Util.AStarGraph.new()

var current_ship_polygon: int

var waypoint_pos:Vector2
var waypoint_set:bool = false

#var velocity_target_angle: float
var angle_to_rot_target: float
var slowing_phase: bool = false

var stop: bool = false
var path_set: bool = false
var path: Array[Util.PathNode]
var path_target_index: int = 0

var replan: bool = false

var last_bounce_time: int = 0
const BOUNCE_REPLAN_THRESHOLD: int = 250

# This method is called on every tick to choose an action.  See README.md
# for a detailed description of its arguments and return value.
func action(_walls: Array[PackedVector2Array], _gems: Array[Vector2], 
			_polygons: Array[PackedVector2Array], _neighbors: Array[Array]):
	spin = 0
	thrust = false
	
	show_debug_path()
	show_debug_velocity_vectors()
	
	if replan or not path_set:
		replan = false
		current_ship_polygon = Util.get_closest_polygon(ship.position, _polygons)
		var path_plan: Array[Util.PathNode] = astar_planner.Search(ship.position, [current_ship_polygon], _polygons, _gems, _neighbors)
		print_rich("[rainbow freq=0.2 sat=0.8 val=0.8][wave amp=20.0 freq=-5.0 connected=0]" + str(path) + "[/wave][/rainbow]")
		if path_plan.size() == 1 and path_plan[0].Point == ship.position:
			print("No Goal Found")
		path_set = true
		path = path_plan
	
	temp_closest_nav(_polygons, _gems, _neighbors)
	
	ticks += 1 
	if ticks % 120 == 0:
		current_ship_polygon = Util.get_closest_polygon(ship.position, _polygons)
		var ship_neighbours = _neighbors[current_ship_polygon]
		
		var test_edges: Array[Vector2] = []
		for i in range(ship_neighbours.size()):
			var edge: Array[Vector2] = Util.get_neigbouring_polygon_edge(_polygons[current_ship_polygon], _polygons[ship_neighbours[i]])
			var edge_centre: Vector2 = Util.get_edge_centre(edge[0], edge[1])
			test_edges.append(edge_centre)
			
		clear_debug_objs()
		draw_debug_points(test_edges)
		draw_debug_poly_indices(_polygons)
		
	navigate_to_waypoint()
	
	return [spin, thrust, true]
	
func temp_closest_nav(_polygons, _gems, _neighbours):
	var current_ship_polygon = Util.get_closest_polygon(ship.position, _polygons)
	var gem_polygons = Util.get_points_clusters_for_polygons(_gems, _polygons)
	if !waypoint_set and !stop:
		waypoint_set = true
		if gem_polygons.has(current_ship_polygon):
			var close_gems_indices: Array = gem_polygons[current_ship_polygon]
			if close_gems_indices.size() > 1:
				var close_gems: Array[Vector2] = []
				for i in range(close_gems_indices.size()):
					close_gems.append(_gems[close_gems_indices[i]])
					
				var closest_gem_index = Util.get_closest_point(ship.position, close_gems)
				waypoint_pos = close_gems[closest_gem_index]
				print("waypoint: closest: " + str(closest_gem_index) + " from size: " + str(close_gems_indices))
			else:
				waypoint_pos = _gems[close_gems_indices[0]]
				print("waypoint: single gem: " + str(waypoint_pos))
		else:
			var ship_neighbours = _neighbours[current_ship_polygon]
			var next_polygon_index = randi_range(0, ship_neighbours.size() - 1)
			for i in range(ship_neighbours.size()):
				if gem_polygons.has(ship_neighbours[i]):
					next_polygon_index = i
			waypoint_pos = Util.get_polygon_centeroid(_polygons[ship_neighbours[next_polygon_index]])
			print("waypoint: new poly: " + str(next_polygon_index))
			
func show_debug_path():
	if path_set:
		debug_path.clear_points()
		debug_path.add_point(ship.position)
		for i in range(1, path.size()):
			debug_path.add_point(path[i].Point)

func show_debug_velocity_vectors():
	debug_vec.clear_points()
	debug_vec.add_point(ship.position)
	debug_vec.add_point(ship.position + ship.velocity)
	
	debug_vec2.clear_points()
	debug_vec2.add_point(ship.position)
	debug_vec2.add_point(ship.position + corrected_rotation_vector)
	
func clear_debug_objs():
	var children: Array[Node] = debug_objs.get_children()
	for i in range(children.size()):
		children[i].queue_free()
	
func draw_debug_points(points: Array[Vector2]):
	for i in range(points.size()):
		var point: ColorRect = DebugRect.instantiate()
		point.position = points[i] - point.size/2.0
		debug_objs.add_child(point)
	return
	
func draw_debug_poly_indices(polygons: Array[PackedVector2Array]):
	for i in range(polygons.size()):
		var centre = Util.get_polygon_centeroid(polygons[i])
		var label: Label = DebugLabel.instantiate()
		label.position = centre - label.size/2.0
		label.text = str(i)
		debug_objs.add_child(label)
# Called every time the agent has bounced off a wall.
func bounce():
	var curr_time = Time.get_ticks_msec()
	if last_bounce_time != 0 and curr_time - last_bounce_time > BOUNCE_REPLAN_THRESHOLD:
		replan = true
	last_bounce_time = curr_time

# Called every time a gem has been collected.
func gem_collected():
	replan = true
	
func waypoint_reached():
	if path_set:
		pass
	else:
		waypoint_set = false
	slowing_phase = false
	#stop = true

func navigate_to_waypoint():
	current_velocity = ship.velocity.length()
	var dist_to_waypoint = ship.position.distance_to(waypoint_pos)
	var time_to_reach_waypoint: float = dist_to_waypoint / current_velocity
	var time_to_rotate = PI / ship.ROTATE_SPEED
	var time_to_stop = current_velocity / (ship.ACCEL * 2)
	var slowing_time = time_to_rotate + time_to_stop
	
	if dist_to_waypoint <= WAYPOINT_REACHED_DIST_MARGIN and current_velocity <= SPEED_STOP_MARGIN:
		waypoint_reached()
	
	var vec_to_waypoint = ship.position.direction_to(waypoint_pos)
	var velocity_waypoint_angle = ship.velocity.angle_to(vec_to_waypoint)
	#print(rad_to_deg(velocity_waypoint_angle))
	
	if !slowing_phase and time_to_reach_waypoint <= slowing_time and abs(velocity_waypoint_angle) < deg_to_rad(22.5):
		if waypoint_set:
			slowing_phase = true
	
	if slowing_phase and abs(velocity_waypoint_angle) > deg_to_rad(45):
		slowing_phase = false
		
	do_rotate()
	do_thrust()

func do_rotate():
	if not waypoint_set:
		spin = 0
		return
	var velocity_vector = ship.velocity.normalized()
	var rotation_target = waypoint_pos
	if slowing_phase:
		rotation_target = ship.position + waypoint_pos.direction_to(ship.position) #slowing target, opposite of waypoint and ship
	
	var rotation_target_vector = ship.position.direction_to(rotation_target)
	var velocity_target_angle = velocity_vector.angle_to(rotation_target_vector) if velocity_vector != Vector2.ZERO and current_velocity > SPEED_STOP_MARGIN else 0
	#print("angle to target: " + str(rad_to_deg(velo_target_angle)))
	var correction_angle = 2 * velocity_target_angle if abs(velocity_target_angle) <= deg_to_rad(90.0) else deg_to_rad(180.0)
	#print("correction_angle: " + str(rad_to_deg(correction_angle)))
	if velocity_target_angle == 0:
		corrected_rotation_vector = rotation_target_vector
	else:
		corrected_rotation_vector = velocity_vector.rotated(correction_angle) * 100
		
	var corrected_rotation_target = ship.position + corrected_rotation_vector
	
	angle_to_rot_target = ship.get_angle_to(corrected_rotation_target)
	spin = 1 if angle_to_rot_target > 0 else -1
	if abs(angle_to_rot_target) <= ship.ROTATE_SPEED/60.0:
		spin = 0
		

func do_thrust():
	if abs(angle_to_rot_target) <= THRUST_ANGLE_MARGIN:
		if slowing_phase and current_velocity >= SPEED_STOP_MARGIN:
			thrust = true
			return
		elif not slowing_phase and waypoint_set:
			thrust = true
			return
	thrust = false
	return
	
