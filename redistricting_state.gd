class_name RedistrictingState

var CANVAS_WIDTH : int = 0
var CANVAS_HEIGHT : int = 0
var NUMBER_OF_DISTRICTS : int = 0
# 2D Array of integers that represents the map where each integer 
# indicates what district that tile belongs to
var district_map : Array
# Array of integers where each index indicates the district and the integer indicates the number of tiles a part of that district.
var district_sizes : Array
# Current std dev among district size
var size_std_dev : float = 0
# Array of vector2i's that represents the sum of the positions of each district
var position_sums : Array[Vector2i]
var distance_from_center_std_dev : float = 0
var score : int = 100000000000000000

const MOORES_NEIGHBORS = [Vector2i(0,1), Vector2i(1,1),  Vector2i(1,0), Vector2i(1,-1), Vector2i(0,-1), Vector2i(-1,-1), Vector2i(-1,0), Vector2i(-1,1)]


func intialize(district_map, district_sizes, size_std_dev, position_sums, distance_from_center_std_dev, number_of_districts,canvas_width, canvas_height):
	self.district_map = district_map
	self.district_sizes = district_sizes
	self.size_std_dev = size_std_dev
	self.position_sums = position_sums
	self.distance_from_center_std_dev = distance_from_center_std_dev
	self.NUMBER_OF_DISTRICTS = number_of_districts
	self.CANVAS_WIDTH = canvas_width
	self.CANVAS_HEIGHT = canvas_height
	

func copy_from(redistricting_state : RedistrictingState):
	self.district_map = redistricting_state.district_map.duplicate(true)
	self.district_sizes = redistricting_state.district_sizes.duplicate(false)
	self.size_std_dev = redistricting_state.size_std_dev
	self.position_sums = redistricting_state.position_sums.duplicate(false)
	self.distance_from_center_std_dev = redistricting_state.distance_from_center_std_dev
	self.score = redistricting_state.get_score()
	self.NUMBER_OF_DISTRICTS = redistricting_state.NUMBER_OF_DISTRICTS
	self.CANVAS_WIDTH = redistricting_state.CANVAS_WIDTH
	self.CANVAS_HEIGHT = redistricting_state.CANVAS_HEIGHT
	
func test_move(tile_pos : Vector2i, new_district : int, size_std_dev_weight, distance_from_center_std_dev_weight):
	var district_sizes_copy = district_sizes.duplicate()
	var original_district = get_district_from_vector2(tile_pos)
	var new_distance_from_center_std_dev = 0
	
	district_sizes_copy[original_district] -= 1
	district_sizes_copy[new_district] += 1
	
	var new_size_std_dev = calc_stand_dev(district_sizes_copy)
	
	var new_score = new_size_std_dev * size_std_dev_weight + new_distance_from_center_std_dev * distance_from_center_std_dev_weight
	
	return new_score < score
		
	
func make_move(tile_pos : Vector2i, new_district : int, size_std_dev_weight, distance_from_center_std_dev_weight):
	var orignial_district = get_district_from_vector2(tile_pos)
	district_map[tile_pos.x][tile_pos.y] = new_district
	
	district_sizes[orignial_district] -= 1
	district_sizes[new_district] += 1
	
	size_std_dev = calc_stand_dev(district_sizes)
	print(size_std_dev)
	
	score = calculate_score(size_std_dev_weight, distance_from_center_std_dev_weight)
	
func get_neighboring_districts_from_position(position : Vector2i, directions) -> Array[int]:
	var current_district = district_map[position.x][position.y]
	var neighboring_districts : Array[int] = []
	for direction in directions:
		var check_pos = position + direction
		if (check_pos.x < 0 or check_pos.x >= CANVAS_WIDTH or check_pos.y < 0 or check_pos.y >= CANVAS_HEIGHT):
			continue
		var neighbor_district = district_map[check_pos.x][check_pos.y]
		if neighbor_district != current_district and neighbor_district not in neighboring_districts:
			neighboring_districts.append(neighbor_district)
			
	return neighboring_districts
	
func determine_new_edges(pos, original_district, edges, directions):
	""" Determines if given tile and its neighbors are now edge tiles and updates the
	edges array to match"""
	for direction in directions:
		var check_pos = pos + direction
		#Check if cell is in the bounds of the map
		if (check_pos.x < 0 or check_pos.x >= CANVAS_WIDTH or check_pos.y < 0 or check_pos.y >= CANVAS_HEIGHT):
			continue
		
		#Add or remove tile from edge list
		var is_now_edge = check_if_edge_pixel(check_pos, directions)
		if(is_now_edge and check_pos not in edges):
			edges.append(check_pos)
		elif(!is_now_edge and check_pos in edges):
			edges.erase(check_pos)
			
	#Check if the flipped pixel is still an edge
	var pixel_is_still_edge = check_if_edge_pixel(pos, directions)
	if !pixel_is_still_edge:
		edges.erase(pos)
		
func check_if_edge_pixel(pos, directions):
	for direction in directions:
		var check_pos = pos + direction
		if (check_pos.x < 0 or check_pos.x >= CANVAS_WIDTH or check_pos.y < 0 or check_pos.y >= CANVAS_HEIGHT):
			continue
		# If there is an adjacent district the tile must be on an edge
		if(district_map[pos.x][pos.y] != district_map[check_pos.x][check_pos.y]):
			return true
	return false
	
func get_district_from_tile(position_x, position_y):
	return self.district_map[position_x][position_y]
	
func get_district_from_vector2(position : Vector2i):
	return self.district_map[position.x][position.y]
	
func move_creates_split_check(pos):
	var start_district
	var current_district
	
	# Flags
	var loop_flag = false
	var should_match_beginning = false
	
	var districts_that_should_not_appear_again = []
			
	for direction in MOORES_NEIGHBORS:
		var check_pos = pos + direction
		
		#Check if cell is in the bounds of the map
		if (check_pos.x < 0 or check_pos.x >= CANVAS_WIDTH or check_pos.y < 0 or check_pos.y >= CANVAS_HEIGHT):
			# If start_district has not been set yet initialize it to -1
			if(should_match_beginning):
				#print("District Came Up Again")
				return true
			if(start_district == null):
				start_district = -1
				current_district = -1
			# If current_district is different from the checked cell's district
			elif(current_district != -1):
				districts_that_should_not_appear_again.append(current_district)
				current_district = -1
			#print(-1)
		else:
			var checked_cell_district = district_map[check_pos.x][check_pos.y]
			if(start_district == null):
				# Set start and current district to the district of the checked cell
				start_district = checked_cell_district
				current_district = checked_cell_district
			
			# If a district that should not have appeared again comes up return true
			elif(checked_cell_district in districts_that_should_not_appear_again):
				#print("District Came Up Again")
				return true
			# If encountering a new district
			elif(current_district != checked_cell_district):
				if(should_match_beginning):
					#print("Did Not Properly Loop")
					return true
				
				if(current_district != start_district):
					districts_that_should_not_appear_again.append(current_district)
					if(loop_flag and checked_cell_district == start_district):
						should_match_beginning = true
						#print("Should match")
				else:
					
					loop_flag = true
					#print("set loop flag")
					
				current_district = checked_cell_district
		#print(current_district)
	#print("Went through")
	return false
	
func calculate_score(size_dev_weight, center_dev_weight):
	return size_std_dev * size_dev_weight + distance_from_center_std_dev * center_dev_weight

func calc_stand_dev(values):
	var average_value
	var average_squared_distance
	
	var distance_sum = 0
	var sum = 0
	
	for value in values:
		sum += value
	average_value = sum / len(values)
	
	for value in values:
		distance_sum += pow((value - average_value),2)
	
	average_squared_distance = distance_sum / len(values)
	return sqrt(average_squared_distance)

func recalculate_center_deviation():
	var district_centers = []
	for i in range(len(position_sums)):
		var center : Vector2 = Vector2(position_sums[i]) / float(district_sizes[i])
		district_centers.append(center)
	
	# An array where the index represents the district and the value represents the total distance from center
	# for every tile in that district
	var distance_from_center_sums = []
	distance_from_center_sums.resize(NUMBER_OF_DISTRICTS)
	distance_from_center_sums.fill(0)
	
	for x in CANVAS_WIDTH:
		for y in CANVAS_HEIGHT:
			var district = district_map[x][y]
			var distance_from_center = Vector2(x,y).distance_to(district_centers[district])
			distance_from_center_sums[district] += distance_from_center
			
	var average_distances_from_district_center = []
	for i in range(len(distance_from_center_sums)):
		average_distances_from_district_center.append(distance_from_center_sums[i] / float(district_sizes[i]))
		
	distance_from_center_std_dev = calc_stand_dev(average_distances_from_district_center)
	
	return
	
func get_score():
	return score
	
func get_size_std_dev():
	return size_std_dev
