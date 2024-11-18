extends Node2D

@onready var ship: Ship = get_parent()
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

	# This is a dummy agent that just moves around randomly.
	# Replace this code with your actual implementation.
	if !waypoint_set and !stop:
		waypoint_set = true
		waypoint_pos = Util.get_polygon_centeroid(_polygons[randi_range(0, _polygons.size() - 1)])
	
	debug_path.clear_points()
	debug_path.add_point(ship.position)
	debug_path.add_point(waypoint_pos)
	
	debug_vec.clear_points()
	debug_vec.add_point(ship.position)
	debug_vec.add_point(ship.position + ship.velocity)
	
	debug_vec2.clear_points()
	debug_vec2.add_point(ship.position)
	debug_vec2.add_point(ship.position + corrected_rotation_vector)
	
	current_velocity = ship.velocity.length()
	var dist_to_waypoint = ship.position.distance_to(waypoint_pos)
	var time_to_reach_waypoint: float = dist_to_waypoint / current_velocity
	var time_to_rotate = PI / ship.ROTATE_SPEED
	var time_to_stop = current_velocity / (ship.ACCEL * 2)
	var slowing_time = time_to_rotate + time_to_stop
	
	if dist_to_waypoint <= WAYPOINT_REACHED_DIST_MARGIN and current_velocity <= SPEED_STOP_MARGIN:
		waypoint_set = false
		slowing_phase = false
		#stop = true	
		
	var vec_to_waypoint = ship.position.direction_to(waypoint_pos)
	var velocity_waypoint_angle = ship.velocity.angle_to(vec_to_waypoint)
	#print(rad_to_deg(velocity_waypoint_angle))
	
	if !slowing_phase and time_to_reach_waypoint <= slowing_time and abs(velocity_waypoint_angle) < deg_to_rad(22.5):
		if waypoint_set:
			slowing_phase = true
	
	if slowing_phase and abs(velocity_waypoint_angle) > deg_to_rad(45):
		slowing_phase = false
		
	ticks += 1 
	#if ticks % 30 == 0:
		#spin = randi_range(-1, 1)
		#thrust = bool(randi_range(0, 1))
		
	do_rotate()
	do_thrust()
	
	return [spin, thrust, false]

# Called every time the agent has bounced off a wall.
func bounce():
	return

# Called every time a gem has been collected.
func gem_collected():
	return
	
func waypoint_reached():
	return
	
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
		
	#print_rich("[rainbow freq=1.0 sat=0.8 val=0.8][wave amp=1.0 freq=-5.0 connected=0]" + str("%0.2f" % angle_to_target) + "[/wave][/rainbow]")

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
