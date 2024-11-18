class_name Util

# Given a point p and a polygon, return the point on the polygon that is closest to p.
static func get_closest_point_on_polygon(p: Vector2, polygon: PackedVector2Array):
	var min_dist = INF
	var closest_point = null

	for i in range(-1, polygon.size() - 1):
		var q = Geometry2D.get_closest_point_to_segment(p, polygon[i], polygon[i + 1])
		var d = p.distance_to(q)
		if d < min_dist:
			min_dist = d
			closest_point = q

	return closest_point

# Given a line segment represented by points p and q, plus a polygon, return the
# shortest distance from the line segment to the polygon.  This will be 0 if the line
# segment intersects the polygon.
static func distance_segment_to_polygon(p: Vector2, q: Vector2, polygon: PackedVector2Array):
	var d = INF
	for i in range(-1, polygon.size() - 1):
		var a = Geometry2D.get_closest_points_between_segments(p, q, polygon[i], polygon[i + 1])
		d = minf(d, a[0].distance_to(a[1]))
	return d
	
static func get_random_point(r: Rect2):
	return

static func get_polygon_centeroid(polygon:PackedVector2Array):
	var gx = 0
	var gy = 0
	var len = polygon.size()
	for i in range(len):
		gx += polygon[i].x
		gy += polygon[i].y
	return Vector2(gx/len, gy/len)
	
