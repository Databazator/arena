extends Node2D
const Ship = preload("res://ship.gd")
@onready var ship : Ship = get_parent()
@onready var debug_path: Line2D = ship.get_node('../debug_path')

@export var show_debug_vectors = true
@export var show_debug_navmesh = false

var velocity_vector_debug: Line2D
var rotation_target_debug: Line2D
var debug_objs: Node2D

const WAYPOINT_NODE_REACHED_DIST_MARGIN = 60
const WAYPOINT_GEM_REACHED_DIST_MARGIN = 30
const WAYPOINT_PASSTHROUGH_ANGLE_MARGIN = deg_to_rad(30)
const WAYPOINT_SKIP_PASS_NODE_ANGLE_MARGIN = deg_to_rad(5)
const WAYPOINTS_AHEAD_TO_FIRE = 3

const THRUST_ANGLE_MARGIN = deg_to_rad(8)
const SPEED_STOP_MARGIN = 5

var ticks = 0
var spin:int = 0
var thrust:bool = false
var fire_missile: bool = false
var current_velocity

var corrected_rotation_vector:Vector2 = Vector2.ZERO

var astar_planner: Util.AStarGraph = Util.AStarGraph.new()

var current_ship_polygon: int

var waypoint_pos:Vector2
var waypoint_set:bool = false

var angle_to_rot_target: float
var slowing_phase: bool = false

var waypoints: Array[Waypoint]
var current_waypoint: Waypoint
var current_waypoint_index: int = 0

var replan: bool = false

var last_bounce_time: int = 0
const BOUNCE_REPLAN_THRESHOLD: int = 500
var win_printed: bool = false

enum WaypointType {PASSTHROUGH, ARRIVE}

class Waypoint:
	var Position: Vector2
	var Type: WaypointType
	
	func _init(position, waypointType: WaypointType = WaypointType.ARRIVE) -> void:
		Position = position
		Type = waypointType
		
func _ready() -> void:
	init_debug_objs()
# This method is called on every tick to choose an action.  See README.md
# for a detailed description of its arguments and return value.
func action(_walls: Array[PackedVector2Array], _gems: Array[Vector2], 
			_polygons: Array[PackedVector2Array], _neighbors: Array[Array]):
	spin = 0
	thrust = false
	
	show_debug_path()
	if show_debug_vectors:
		show_debug_velocity_vectors()
	
	if ticks % 30 == 0: # ef it, just replan every now and then, seems to work way better
		replan = true
		win_debug()
	
	if replan or not waypoint_set:
		do_plan(_polygons, _gems, _neighbors)
	
	ticks += 1 
	if  ticks % 120 == 0 and show_debug_navmesh:
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
	
	return [spin, thrust, fire_missile]
	
func construct_waypoints(path: Array[Util.PathNode]) -> Array[Waypoint]:
	var res_waypoints: Array[Waypoint] = []
	var last_unskipped_node = 0
	for i in range(1, path.size() - 1):
		var segment_start = path[last_unskipped_node].Point
		var segment_last = path[i + 1].Point
		var curr_node = path[i]
		var curr_pos = curr_node.Point
		
		var vec_to_start = curr_pos.direction_to(segment_start)
		var vec_to_end = curr_pos.direction_to(segment_last)
		
		var angle_between_segments = abs(vec_to_start.angle_to(vec_to_end))
		if angle_between_segments != 0:
			angle_between_segments -= deg_to_rad(180)
	
		#print("angle:" + str(rad_to_deg(angle_between_segments)))
		var new_waypoint: Waypoint
		if abs(angle_between_segments) <= WAYPOINT_SKIP_PASS_NODE_ANGLE_MARGIN: # node in line with next node - can be skipped
			pass
		elif abs(angle_between_segments) <= WAYPOINT_PASSTHROUGH_ANGLE_MARGIN: # node reasonably straight in path- is a passthrough
			new_waypoint = Waypoint.new(curr_pos, WaypointType.PASSTHROUGH)
			res_waypoints.append(new_waypoint)
			last_unskipped_node = i
		else:
			new_waypoint = Waypoint.new(curr_pos, WaypointType.ARRIVE)
			res_waypoints.append(new_waypoint)
			last_unskipped_node = i
	
	var last_waypoint = Waypoint.new(path[-1].Point)
	res_waypoints.append(last_waypoint)
	return res_waypoints
	
func do_plan(polygons, gems, neighbours):
	slowing_phase = false
	
	replan = false
	current_ship_polygon = Util.get_closest_polygon(ship.position, polygons)
	var path_plan: Array[Util.PathNode] = astar_planner.Search(ship.position, [current_ship_polygon], polygons, gems, neighbours)
	
	# funnel path, iterative
	for i in range(path_plan.size() - 1):
		path_plan = Util.funnel_iter(path_plan)
	
	if path_plan.size() == 1 and path_plan[0].Point == ship.position:
		print("No Goal Found")
	else:
		# create waypoints from path plan
		waypoints = construct_waypoints(path_plan)
		current_waypoint_index = 0
		current_waypoint = waypoints[current_waypoint_index]
		waypoint_pos = current_waypoint.Position
		waypoint_set = true
	
# Called every time the agent has bounced off a wall.
func bounce():
	# replan if we bounced too many times in a short span of time
	var curr_time = Time.get_ticks_msec()
	if last_bounce_time != 0 and curr_time - last_bounce_time < BOUNCE_REPLAN_THRESHOLD:
		replan = true
	last_bounce_time = curr_time

# Called every time a gem has been collected.
func gem_collected():
	replan = true
	
func waypoint_reached():
	if waypoint_set:
		current_waypoint_index += 1
		if waypoints.size() <= current_waypoint_index:
			replan = true
			waypoint_set = false
		else:
			current_waypoint = waypoints[current_waypoint_index]
			waypoint_pos = current_waypoint.Position
	slowing_phase = false
	#stop = true

func navigate_to_waypoint():
	current_velocity = ship.velocity.length()
	var dist_to_waypoint = ship.position.distance_to(waypoint_pos)
	var time_to_reach_waypoint: float = dist_to_waypoint / current_velocity
	var time_to_rotate = PI / ship.ROTATE_SPEED
	var time_to_stop = current_velocity / (ship.ACCEL * 2) # it doesn't make sense, I shouldn¨t have to double the accel, but without it, the ship decclerates way too fast
	var slowing_time = time_to_rotate + time_to_stop
	
	if current_waypoint.Type == WaypointType.ARRIVE:
		var isLastWaypoint: bool = true if current_waypoint_index == waypoints.size() - 1 else false
		if (isLastWaypoint and dist_to_waypoint <= WAYPOINT_GEM_REACHED_DIST_MARGIN) or (not isLastWaypoint and dist_to_waypoint <= WAYPOINT_NODE_REACHED_DIST_MARGIN) and current_velocity <= SPEED_STOP_MARGIN:
			waypoint_reached()
	elif current_waypoint.Type == WaypointType.PASSTHROUGH:
		if dist_to_waypoint <= WAYPOINT_NODE_REACHED_DIST_MARGIN:
			waypoint_reached()
			
	var vec_to_waypoint = ship.position.direction_to(waypoint_pos)
	var velocity_waypoint_angle = ship.velocity.angle_to(vec_to_waypoint)
	
	if current_waypoint.Type == WaypointType.ARRIVE:
		if !slowing_phase and time_to_reach_waypoint <= slowing_time and abs(velocity_waypoint_angle) < deg_to_rad(22.5):
			if waypoint_set:
				slowing_phase = true
		if slowing_phase and (abs(velocity_waypoint_angle) > deg_to_rad(45) or current_velocity <= 0.5 * dist_to_waypoint):
			slowing_phase = false
		
	do_rotate()
	do_thrust()
	do_fire_missile()

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
	var correction_angle = 2 * velocity_target_angle if abs(velocity_target_angle) <= deg_to_rad(90.0) else deg_to_rad(180.0)
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
	thrust = false
	if abs(angle_to_rot_target) <= THRUST_ANGLE_MARGIN:
		if current_waypoint.Type == WaypointType.ARRIVE:
			if slowing_phase and current_velocity >= SPEED_STOP_MARGIN:
				thrust = true
			elif not slowing_phase and waypoint_set:
				thrust = true
		elif current_waypoint.Type == WaypointType.PASSTHROUGH:
			var next_nonpass_waypoint: Waypoint = get_next_nonpass_waypoint()
			var dist_to_waypoint = ship.position.distance_to(next_nonpass_waypoint.Position)
			var angle_tgt_vel_vec = abs(corrected_rotation_vector.angle_to(ship.velocity))
			if waypoint_set and ((dist_to_waypoint > current_velocity and angle_tgt_vel_vec < deg_to_rad(7)) or angle_tgt_vel_vec >= deg_to_rad(7)):
				thrust = true
	return
	
func do_fire_missile():
	fire_missile = false
	if ship.lasers == 0:
		return
	
	if waypoints.size() - current_waypoint_index >= WAYPOINTS_AHEAD_TO_FIRE:
		var angle_to_final = ship.get_angle_to(waypoints[-1].Position)
		if abs(angle_to_final) <= THRUST_ANGLE_MARGIN:
			fire_missile = true
	
func get_next_nonpass_waypoint() -> Waypoint:
	if current_waypoint_index >= waypoints.size() - 1:
		return waypoints[-1]
	for i in range(current_waypoint_index +1, waypoints.size()):
		if waypoints[i].Type == WaypointType.ARRIVE:
			return waypoints[i]
	return waypoints[-1]
	
func show_debug_path():
	if waypoint_set:
		debug_path.clear_points()
		debug_path.add_point(ship.position)
		for i in range(current_waypoint_index, waypoints.size()):
			debug_path.add_point(waypoints[i].Position)

func show_debug_velocity_vectors():
	velocity_vector_debug.clear_points()
	velocity_vector_debug.add_point(ship.position)
	velocity_vector_debug.add_point(ship.position + ship.velocity)
	
	rotation_target_debug.clear_points()
	rotation_target_debug.add_point(ship.position)
	rotation_target_debug.add_point(ship.position + corrected_rotation_vector)

func draw_debug_poly_indices(polygons: Array[PackedVector2Array]):
	for i in range(polygons.size()):
		var centre = Util.get_polygon_centeroid(polygons[i])
		var label: Label = Label.new()
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.pivot_offset = label.size/2.0
		label.position = centre - label.size/2.0
		label.text = str(i)
		debug_objs.add_child(label)
		
func clear_debug_objs():
	var children: Array[Node] = debug_objs.get_children()
	for i in range(children.size()):
		children[i].queue_free()
	
func draw_debug_points(points: Array[Vector2]):
	for i in range(points.size()):
		var point: ColorRect = ColorRect.new()
		point.color = Color.AQUA
		point.size = Vector2(20,20)
		point.pivot_offset = point.size/2.0
		point.position = points[i] - point.size/2.0
		debug_objs.add_child(point)
	return
	
func init_debug_objs():
	var arena_node: Node2D = ship.get_parent()
	
	velocity_vector_debug = Line2D.new()
	velocity_vector_debug.default_color = Color.RED
	velocity_vector_debug.width = 3
	velocity_vector_debug.z_index = 2
	arena_node.add_child.call_deferred(velocity_vector_debug)
	rotation_target_debug = Line2D.new()
	rotation_target_debug.default_color = Color.WEB_GREEN
	rotation_target_debug.width = 3
	rotation_target_debug.z_index = 1
	arena_node.add_child.call_deferred(rotation_target_debug)
	
	debug_objs = Node2D.new()
	arena_node.add_child.call_deferred(debug_objs)

func win_debug():
	if(ship.get_parent().score >= 300 and not win_printed):
		print_victory_debug()
		
func print_victory_debug():
	print_rich("[font_size=15][color=CRIMSON][shake rate=20.0 level=5 connected=1]" + "300!" + "[/shake][/color][/font_size][rainbow freq=0.2 sat=0.8 val=0.8][wave amp=20.0 freq=-5.0 connected=0]" + " YAAY! " + "[/wave][/rainbow] ")
	win_printed = true
	
func temp_closest_nav(_polygons, _gems, _neighbours):
	var current_ship_polygon = Util.get_closest_polygon(ship.position, _polygons)
	var gem_polygons = Util.get_points_clusters_for_polygons(_gems, _polygons)
	if !waypoint_set:
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
			
	
