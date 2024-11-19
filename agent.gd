extends Node2D
const Ship = preload("res://ship.gd")
@onready var ship : Ship = get_parent()
@onready var debug_path: Line2D = ship.get_node('../debug_path')

@onready var debug_vec: Line2D = ship.get_node('../debug_vec')
@onready var debug_vec2: Line2D = ship.get_node('../debug_vec2')

@onready var WAYPOINT_REACHED_DIST_MARGIN = 50

var THRUST_ANGLE_MARGIN = deg_to_rad(8)
var SPEED_STOP_MARGIN = 5
var ticks = 0
var spin:int = 0
var thrust:bool = false
var current_velocity

var corrected_rotation_vector:Vector2 = Vector2.ZERO

var waypoint_pos:Vector2
var waypoint_set:bool = false

#var velocity_target_angle: float
var angle_to_rot_target: float
var slowing_phase: bool = false

var stop: bool = false

# This method is called on every tick to choose an action.  See README.md
# for a detailed description of its arguments and return value.
func action(_walls: Array[PackedVector2Array], _gems: Array[Vector2], 
			_polygons: Array[PackedVector2Array], _neighbors: Array[Array]):
	spin = 0
	thrust = false
	
	show_debug_path()
	
	var current_ship_polygon = Util.get_closest_polygon(ship.position, _polygons)
	var gem_polygons = Util.get_points_polygon_clusters(_gems, _polygons)
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
			var ship_neighbours = _neighbors[current_ship_polygon]
			var next_polygon_index = randi_range(0, ship_neighbours.size() - 1)
			for i in range(ship_neighbours.size()):
				if gem_polygons.has(ship_neighbours[i]):
					next_polygon_index = i
			waypoint_pos = Util.get_polygon_centeroid(_polygons[ship_neighbours[next_polygon_index]])
			print("waypoint: new poly: " + str(next_polygon_index))
	
	ticks += 1 
	if ticks % 180 == 0:
		#print_rich("[rainbow freq=0.2 sat=0.8 val=0.8][wave amp=20.0 freq=-5.0 connected=0]" + str("akjahkjhasjhfajsfjkasfjkahskfjhasjkfhasjkfhaksjakhfjk") + "[/wave][/rainbow]")

		pass
		#print(gem_polygons)
		#print("ship: " + str(current_ship_polygon))
		#spin = randi_range(-1, 1)
		#thrust = bool(randi_range(0, 1))
		
	navigate_to_waypoint()
	
	return [spin, thrust, false]

func show_debug_path():
	debug_path.clear_points()
	debug_path.add_point(ship.position)
	debug_path.add_point(waypoint_pos)
	
	debug_vec.clear_points()
	debug_vec.add_point(ship.position)
	debug_vec.add_point(ship.position + ship.velocity)
	
	debug_vec2.clear_points()
	debug_vec2.add_point(ship.position)
	debug_vec2.add_point(ship.position + corrected_rotation_vector)

# Called every time the agent has bounced off a wall.
func bounce():
	return

# Called every time a gem has been collected.
func gem_collected():
	return
	
func waypoint_reached():
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
	
