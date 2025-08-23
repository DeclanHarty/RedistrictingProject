extends Node2D

const COLORS = ['#e6194b', '#3cb44b', '#ffe119', '#4363d8', '#f58231', '#911eb4', '#46f0f0', '#f032e6', '#bcf60c', '#fabebe', '#008080', '#e6beff', '#9a6324', '#fffac8', '#800000', '#aaffc3', '#808000', '#ffd8b1', '#000075', '#808080']
const CANVAS_WIDTH = 32
const CANVAS_HEIGHT = 32
const MOORES_NEIGHBORS = [Vector2i(0,1), Vector2i(1,1),  Vector2i(1,0), Vector2i(1,-1), Vector2i(0,-1), Vector2i(-1,-1), Vector2i(-1,0), Vector2i(-1,1)]
const CARDINAL_DIRECTIONS = [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]
const NUMBER_OF_DISTRICTS = 12
# Array of Vector2i's representing the tiles that are currently edges
var edges : Array[Vector2i] = []
var directions = CARDINAL_DIRECTIONS

# 2D Array of integers that represents the map where each integer 
# indicates what district that tile belongs to
var district_map  = []

# Array of integers where each index indicates the district and the integer indicates the number of tiles a part of that district.
var district_sizes = []
# Current std dev among district size
var current_size_std_dev
# Array of vector2i's that represents the sum of the positions of each district
var district_position_sums : Array[Vector2i]

#Working District State
var working_state : RedistrictingState = RedistrictingState.new()

# Best result variables
var best_district_map
var best_district_sizes
var best_size_std_dev
var best_district_position_sums

#Best Districting State
var best_state : RedistrictingState = RedistrictingState.new()

var working_image
var best_image
var working_texture
var best_texture

var time_since_last_step = 1.0
var time_between_steps = .01

var initial_bad_move_chance = .20
var TEMP_CHANGE_RATE = 0
const MAX_NUMBER_OF_BAD_ITERATIONS = 50
var number_of_bad_iterations = 0

var BEST_RESULT_SPRITE
var CURRENT_SPRITE

func _ready() -> void:
	# Initialize the Working and Current Best Images and Textures
	working_image = Image.new()
	working_texture = ImageTexture.new()
	best_image = Image.new()
	best_texture = ImageTexture.new()
	
	# Get sprite references
	BEST_RESULT_SPRITE = $BestMap
	CURRENT_SPRITE = $CurrentMap
	
	# Initialize district map and district map area
	init_district_map(CANVAS_WIDTH, CANVAS_HEIGHT)
	
	# Create and initialize both best and 
	
	#Set Images to white initially
	working_image = Image.create_empty(CANVAS_WIDTH, CANVAS_HEIGHT, false, Image.FORMAT_RGBA8)
	working_image.fill(Color.WHITE)
	best_image = Image.create_empty(CANVAS_WIDTH, CANVAS_HEIGHT, false, Image.FORMAT_RGBA8)
	best_image.fill(Color.WHITE)
	
	# Get the positions for creating the initial random voronoi diagram
	var positions = create_random_positions(NUMBER_OF_DISTRICTS, CANVAS_WIDTH, CANVAS_HEIGHT)
	
	# Determine for each tile on the grid which is the closest district
	# Add up the total number of tiles per district
	for x in range(CANVAS_WIDTH):
		for y in range(CANVAS_HEIGHT):
			var closest_position_index = determine_nearest_position(Vector2i(x,y), positions)
			working_image.set_pixel(x,y, Color(COLORS[closest_position_index]))
			best_image.set_pixel(x,y, Color(COLORS[closest_position_index]))
			district_map[x][y] = closest_position_index
			district_sizes[closest_position_index] += 1
				
	# Calculate the current standard deviation 
	current_size_std_dev = calc_stand_dev(district_sizes)
	# Set initial best values
	best_district_map = district_map.duplicate(true)
	best_size_std_dev = current_size_std_dev
	best_district_sizes = district_sizes.duplicate(true)
	
	
	print(district_sizes)
	print(current_size_std_dev)
			
	find_edge_pixels(directions)
	
	# Set the working sprite
	working_texture = ImageTexture.create_from_image(working_image)
	CURRENT_SPRITE.texture = working_texture
	CURRENT_SPRITE.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Set the best solution sprite
	best_texture = ImageTexture.create_from_image(best_image)
	BEST_RESULT_SPRITE.texture = best_texture
	BEST_RESULT_SPRITE.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
func _process(delta: float) -> void:
	time_since_last_step -= delta
	if(time_since_last_step <= 0 and len(edges) > 0):
		time_since_last_step = time_between_steps
		var pos_and_new_district = flip_edge()
		
		if(pos_and_new_district[1] == -1):
			return
		if(current_size_std_dev < best_size_std_dev):
			best_size_std_dev = current_size_std_dev
			best_district_map = district_map.duplicate(true)
			best_district_sizes = district_sizes.duplicate(true)
			
			for x in range(CANVAS_WIDTH):
				for y in range(CANVAS_HEIGHT):
					best_image.set_pixel(x,y, Color(COLORS[district_map[x][y]]))
					
		if(number_of_bad_iterations >= MAX_NUMBER_OF_BAD_ITERATIONS):
			number_of_bad_iterations = 0
			district_map = best_district_map.duplicate(true)
			district_sizes = best_district_sizes.duplicate(true)
			current_size_std_dev = best_size_std_dev
			
			edges = find_edge_pixels(directions)
			print("\nMoved Back\n")
			for x in CANVAS_WIDTH:
				for y in CANVAS_HEIGHT:
					working_image.set_pixel(x, y, Color(COLORS[best_district_map[x][y]]))
		else:
			working_image.set_pixel(pos_and_new_district[0].x, pos_and_new_district[0].y, Color(COLORS[pos_and_new_district[1]]))

		print(str(current_size_std_dev) + " : " + str(initial_bad_move_chance))
		working_texture = ImageTexture.create_from_image(working_image)
		CURRENT_SPRITE.texture = working_texture
		
		best_texture = ImageTexture.create_from_image(best_image)
		BEST_RESULT_SPRITE.texture = best_texture
	pass
	
func create_random_positions(number_of_positions, image_width, image_height):
	var positions = []
	for i in range(number_of_positions):
		while(true):
			var pos_x = randi_range(0, image_width - 1)
			var pos_y = randi_range(0, image_height - 1)
			var pos = Vector2i(pos_x, pos_y)
			if pos not in positions:
				positions.append(pos)
				break
		
	return positions
	
func determine_nearest_position(test_pos : Vector2i, positions):
	var current_closest = null
	var closest_distance = 1.79769e308
	for i in range(len(positions)):
		var test_distance = test_pos.distance_to(positions[i])
		if test_distance < closest_distance:
			closest_distance = test_distance
			current_closest = i
			
	return current_closest

func find_edge_pixels(directions):
	edges = []
	for x in range(CANVAS_WIDTH):
		for y in range(CANVAS_HEIGHT):
			var pos = Vector2i(x,y)
			if check_if_edge_pixel(pos):
				edges.append(pos)
				
	return edges
					
func check_if_edge_pixel(pos):
	for direction in directions:
		var check_pos = pos + direction
		if (check_pos.x < 0 or check_pos.x >= CANVAS_WIDTH or check_pos.y < 0 or check_pos.y >= CANVAS_HEIGHT):
			continue
		if(district_map[pos.x][pos.y] != district_map[check_pos.x][check_pos.y]):
			return true
	return false
					

func init_district_map(image_width, image_height):
	""" Initializes the district map as a 2d array with each cell set to -1 and sets the district area map"""
	district_sizes.resize(NUMBER_OF_DISTRICTS)
	for i in range(len(district_sizes)):
		district_sizes[i] = 0
	for x in range(image_width):
		var y_col = []
		for y in range(image_height):
			y_col.append(-1)
		district_map.append(y_col)
		
func get_neighboring_districts(pos : Vector2i, district_map):
	""" Returns an array of the unique districts niehgboring a position"""
	var current_district = district_map[pos.x][pos.y]
	var neighboring_districts = []
	for direction in directions:
		var check_pos = pos + direction
		if (check_pos.x < 0 or check_pos.x >= CANVAS_WIDTH or check_pos.y < 0 or check_pos.y >= CANVAS_HEIGHT):
			continue
		var neighbor_district = district_map[check_pos.x][check_pos.y]
		if neighbor_district != current_district and neighbor_district not in neighboring_districts:
			neighboring_districts.append(neighbor_district)
			
	return neighboring_districts
	
func determine_new_edges(pos, original_district, new_district, district_map, edges):
	""" Determines if given tile and its neighbors are now edge tiles and updates the
	edges array to match"""
	#for direction in directions:
		#var check_pos = pos + direction
		#if (check_pos.x < 0 or check_pos.x >= CANVAS_WIDTH or check_pos.y < 0 or check_pos.y >= CANVAS_HEIGHT):
			#continue
		#var check_district = district_map[check_pos.x][check_pos.y]
		#if check_district == original_district && check_pos not in edges:
			#edges.append(check_pos)
		#if check_district == new_district:
			#var is_now_edge = check_if_edge_pixel(check_pos)
			#if(is_now_edge and check_pos not in edges):
				#edges.append(check_pos)
			#elif(!is_now_edge and check_pos in edges):
				#edges.erase(check_pos)
				
	for direction in directions:
		var check_pos = pos + direction
		#Check if cell is in the bounds of the map
		if (check_pos.x < 0 or check_pos.x >= CANVAS_WIDTH or check_pos.y < 0 or check_pos.y >= CANVAS_HEIGHT):
			continue
		
		#Add or remove tile from edge list
		var is_now_edge = check_if_edge_pixel(check_pos)
		if(is_now_edge and check_pos not in edges):
			edges.append(check_pos)
		elif(!is_now_edge and check_pos in edges):
			edges.erase(check_pos)
			
	#Check if the flipped pixel is still an edge
	var pixel_is_still_edge = check_if_edge_pixel(pos)
	if !pixel_is_still_edge:
		edges.erase(pos)
					
func flip_edge():
	# Get a random edge tile to potentially flip
	var edge_index = randi_range(0, len(edges) - 1)
	var pos = edges[edge_index]
	# Get tile's original district
	var original_district = district_map[pos.x][pos.y]
	
	# Get the neighboring district values of the chosen edge (not including original district value)
	var neighboring_districts = get_neighboring_districts(pos, district_map)
			
	# Choose a random district that neighbors the chosen edge tile
	var neighbor_index = randi_range(0, len(neighboring_districts) - 1)
	var new_district = neighboring_districts[neighbor_index]
	
	# Make a deep copy of the current district map and update it to match the potential move
	var new_dict = district_sizes.duplicate(true)
	new_dict[original_district] -= 1
	new_dict[new_district] += 1
	
	if(move_creates_split_check(pos, district_map)):
		return [Vector2i.ZERO, -1]
	# Calculate the std_deviation of the new move and roll a value between 0 and 1
	var test_std_deviation = calc_stand_dev(new_dict)
	var bad_move_value = randf()
	
	# If move decreases area std deviation or passes the bad move check
	if(test_std_deviation <= current_size_std_dev or bad_move_value < initial_bad_move_chance):
		# Increase the number of bad iterations if a "bad" move
		if(test_std_deviation > current_size_std_dev and bad_move_value < initial_bad_move_chance):
			initial_bad_move_chance -= TEMP_CHANGE_RATE
			number_of_bad_iterations += 1
		
		#Update the district area map and district map to the new district
		district_sizes = new_dict
		district_map[pos.x][pos.y] = new_district
		
		#Update standard deviation to match new standard deviation
		current_size_std_dev = test_std_deviation
		#Update edges to match new map
		determine_new_edges(pos, original_district, new_district, district_map, edges)
		#find_edge_pixels(directions)
		return [pos, new_district]
	else:
		return [Vector2i.ZERO, -1]

	
func calc_stand_dev(values):
	var average_value
	var average_4th_distance
	
	var distance_sum = 0
	var sum = 0
	
	for value in values:
		sum += value
	average_value = sum / len(values)
	
	for value in values:
		distance_sum += pow((value - average_value),2)
	
	average_4th_distance = distance_sum / len(values)
	return sqrt(average_4th_distance)
	
func move_creates_split_check(pos, current_district_map):
	var start_district
	var current_district
	
	# Flags
	var loop_flag = false
	var should_match_beginning = false
	
	var districts_that_should_not_appear_again = []
	
	var neighbors = []
	for direction in MOORES_NEIGHBORS:
		var check_pos = pos + direction
		#Check if cell is in the bounds of the map
		if (check_pos.x < 0 or check_pos.x >= CANVAS_WIDTH or check_pos.y < 0 or check_pos.y >= CANVAS_HEIGHT):
			neighbors.append(-1)
			
		else:
			var checked_cell_district = current_district_map[check_pos.x][check_pos.y]
			neighbors.append(checked_cell_district)
	
	#print(str(pos) + " : " + str(neighbors))
			
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
			var checked_cell_district = current_district_map[check_pos.x][check_pos.y]
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
					
				
			
	
	
	
	
	
