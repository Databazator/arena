class_name Util

const POINT_DIST_THRESHOLD: int = 5
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
		
static func get_points_clusters_for_polygons(points: Array[Vector2], polygons: Array[PackedVector2Array]) -> Dictionary:
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
	
static func points_on_same_pos(p1: Vector2, p2: Vector2, threshold: int = POINT_DIST_THRESHOLD) -> bool:
	return p1.distance_to(p2) <= threshold

static func get_neigbouring_polygon_edge(poly1: PackedVector2Array, poly2: PackedVector2Array) -> Array[Vector2] :
	#assuming provided polygons are neighbours
	var res_edge: Array[Vector2] = []
	for i in range(poly1.size()):
		for j in range(poly2.size()):
			if points_on_same_pos(poly1[i], poly2[j]):
				res_edge.append(poly1[i])
	
	if res_edge.size() < 2:
		return [Vector2.ZERO, Vector2.ZERO]
	return res_edge

static func get_edge_centre(a: Vector2, b: Vector2) -> Vector2 :
	return Vector2((a.x + b.x)/2.0, (a.y + b.y)/2.0)

class PathNode:
	var Point: Vector2
	 # these two other properties are unneccesary, but I don't feel like calculatuing them again later so I just pass them along to speed things up a tad
	var IsEdge: bool               
	var Edge: PackedVector2Array
	
	func _init(point: Vector2, isEdge: bool = false, edge: PackedVector2Array = []):
		Point = point
		IsEdge = isEdge
		Edge = edge
	
class FringeNode:
	var Point: Vector2
	var Parent: FringeNode
	var PolygonIndex: Array[int]
	var IsPolyEdge: bool
	var PolyEdgePoints: PackedVector2Array
	var Cost: float
	var Depth: int
	
	func _init(point: Vector2, parent: FringeNode, polygonIndex: Array[int], isPolyEdge: bool, cost: float, depth: int, polyEdge: PackedVector2Array = []) -> void:
		Point = point
		Parent = parent
		PolygonIndex = polygonIndex
		IsPolyEdge = isPolyEdge
		Cost = cost
		Depth = depth
		PolyEdgePoints = polyEdge
	
class AStarGraph:
	var StartPos: Vector2
	var Polygons: Array[PackedVector2Array]
	var Gems: Array[Vector2]
	var Neighbours: Array[Array]
	var GemClusters: Dictionary
	
	var Fringe: Array[FringeNode]
	
	func Heuristic(position: Vector2) -> float:
		return position.distance_to(Gems[Util.get_closest_point(position, Gems)])
	
	func Cost(prev_position: Vector2, new_position: Vector2) -> float:
		return prev_position.distance_to(new_position)
	
	func IsGoal(new_position: Vector2) -> bool:
		for i in range(Gems.size()):
			if Util.points_on_same_pos(new_position, Gems[i]):
				return true
		return false
		
	func BestFringeNode() -> FringeNode:
		var min_cost: float = INF
		var min_i: int = 0
		for i in range(Fringe.size()):
			if Fringe[i].Cost < min_cost:
				min_cost = Fringe[i].Cost
				min_i = i
		return Fringe.pop_at(min_i)
	
	# get possible waypoints in navmesh, be it navmesh region edges or gems in current polygon
	# current poly is a 1-2 sized array of polygon vertices. When 
	func GetPossibleTargets(current_poly: Array[int]) -> Array:
		var res_targets: Array = []
		
		var target_gems = []
		var target_neighbours : Dictionary = {}
		
		for i in range(current_poly.size()):
			var curr = current_poly[i]
			var other = current_poly[1 - i] if current_poly.size() > 1 else -1
			
			if GemClusters.has(curr):
				target_gems.append_array(GemClusters[curr])
			
			var poly_neighbours = Neighbours[curr].duplicate()
			for j in range(poly_neighbours.size()):
				if poly_neighbours[j] == other:
					poly_neighbours.pop_at(j)
					break
			target_neighbours[curr] = poly_neighbours
		
		for i in range(target_gems.size()):
			var gem_pos = Gems[target_gems[i]]
			res_targets.append([gem_pos, false, [], []])
			
		for i in range(current_poly.size()):
			var neighbours = target_neighbours[current_poly[i]]
			for j in range(neighbours.size()):
				var poly_edge: Array[Vector2] = Util.get_neigbouring_polygon_edge(Polygons[current_poly[i]], Polygons[neighbours[j]])
				var edge_centre : Vector2 = Util.get_edge_centre(poly_edge[0], poly_edge[1])
				res_targets.append([edge_centre, true, [current_poly[i], neighbours[j]], poly_edge])
	
		return res_targets
	
	func Search(startPos: Vector2, startPolyIndex: Array[int], polygons: Array[PackedVector2Array], gems: Array[Vector2], neighbours: Array[Array]) -> Array[PathNode]: 
		StartPos = startPos
		Polygons = polygons
		Gems = gems
		Neighbours = neighbours
		GemClusters = Util.get_points_clusters_for_polygons(Gems, Polygons)
		
		var GoalNode: FringeNode = null
		var heur = Heuristic(startPos)
		var start_node = FringeNode.new(startPos, null, startPolyIndex, false, heur, 0)
		Fringe = [start_node]
		var visited : Dictionary = {}
		
		while Fringe.size() > 0:
			var current_node: FringeNode = BestFringeNode()
			var current_pos = current_node.Point
			var current_poly: Array[int] = current_node.PolygonIndex
			var current_is_edge = current_node.IsPolyEdge
			var current_cost = current_node.Cost
			var current_depth = current_node.Depth
			
			if IsGoal(current_pos):
				GoalNode = current_node
				break
				
			var possible_targets = GetPossibleTargets(current_poly)
			for i in range(possible_targets.size()):
				var new_target = possible_targets[i]
				var new_pos = new_target[0]
				var new_is_edge = new_target[1]
				var new_edge_polys: Array[int]
				new_edge_polys.assign(new_target[2])
				var edge_points: PackedVector2Array = PackedVector2Array(new_target[3])
				
				var new_cost = current_depth + Cost(current_pos, new_pos) + Heuristic(new_pos)
				if not visited.has(new_pos) or visited[new_pos] > new_cost:
					visited[new_pos] = new_cost
					var new_fringe_node_poly: Array[int]
					new_fringe_node_poly.assign([Util.get_closest_polygon(new_pos, Polygons)]) if not new_is_edge else new_fringe_node_poly.assign(new_edge_polys)
					var new_fringe_node = FringeNode.new(new_pos, current_node, 
					new_fringe_node_poly, new_is_edge, new_cost, current_depth + Cost(current_pos, new_pos), edge_points)
					Fringe.append(new_fringe_node)
		
		if GoalNode == null:
			return [PathNode.new(startPos)]
		else:
			var res_path: Array[PathNode] = []
			var curr_node = GoalNode
			
			while curr_node.Parent != null:
				res_path.append(PathNode.new(curr_node.Point, curr_node.IsPolyEdge, curr_node.PolyEdgePoints))
				curr_node = curr_node.Parent
				
			res_path.append(PathNode.new(curr_node.Point, curr_node.IsPolyEdge, curr_node.PolyEdgePoints))
			res_path.reverse()
			return res_path
