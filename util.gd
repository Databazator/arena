class_name Util

# Given a point p and a polygon, return the point on the polygon that is closest to p.
static func get_closest_point_on_polygon(p: Vector2, polygon: PackedVector2Array) -> Vector2:
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
static func distance_segment_to_polygon(p: Vector2, q: Vector2, polygon: PackedVector2Array) -> float:
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
	
# returns index of a polygon that contains the point or is closest to it
static func get_closest_polygon(point: Vector2, polygons: Array[PackedVector2Array]) -> int:
	var closest_point_dist = INF
	var closest_point_index = -1
	for i in range(polygons.size()):
		if Geometry2D.is_point_in_polygon(point, polygons[i]):
			return i
		else:
			var poly_closest_point: Vector2 = get_closest_point_on_polygon(point, polygons[i])
			var poly_closest_point_dist = poly_closest_point.distance_to(point)
			if poly_closest_point_dist < closest_point_dist:
				closest_point_dist = poly_closest_point_dist
				closest_point_index = i
	return closest_point_index
		
static func get_points_polygon_clusters(points: Array[Vector2], polygons: Array[PackedVector2Array]) -> Dictionary:
	var dict = {}
	for i in range(points.size()):
		var closest_poly = get_closest_polygon(points[i], polygons)
		if dict.has(closest_poly):
			dict[closest_poly].append(i)
		else:
			dict[closest_poly] = [i]
	return dict
	
static func get_closest_point(x:Vector2, points:Array[Vector2]) -> int:
	var closest_distance: float = INF
	var closest_point: int = 0
	for i in range(points.size()):
		var dist = x.distance_to(points[i])
		if dist < closest_distance:
			closest_distance = dist
			closest_point = i
	return closest_point
	
