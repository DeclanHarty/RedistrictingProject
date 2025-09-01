extends Node2D

const COLORS = ['#e6194b', '#3cb44b', '#ffe119', '#4363d8', '#f58231', '#911eb4', '#46f0f0', '#f032e6', '#bcf60c', '#fabebe', '#008080', '#e6beff', '#9a6324', '#fffac8', '#800000', '#aaffc3', '#808000', '#ffd8b1', '#000075', '#808080']

@export var CANVAS_WIDTH = 64
var CANVAS_HEIGHT = CANVAS_WIDTH
const MOORES_NEIGHBORS = [Vector2i(0,1), Vector2i(1,1),  Vector2i(1,0), Vector2i(1,-1), Vector2i(0,-1), Vector2i(-1,-1), Vector2i(-1,0), Vector2i(-1,1)]
const CARDINAL_DIRECTIONS = [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]
@export var NUMBER_OF_DISTRICTS = 12

@export var SIZE_STD_DEV_WEIGHT = 100
@export var DISTANCE_FROM_CENTER_DEV_WEIGHT = 50
# Array of Vector2i's representing the tiles that are currently edges
var edges : Array[Vector2i] = []
var directions = CARDINAL_DIRECTIONS

@export var running : bool

#Working District State
var working_state : RedistrictingState = RedistrictingState.new()

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
var LEADERBOARD

func _ready() -> void:
	# Initialize the Working and Current Best Images and Textures
	working_image = Image.new()
	working_texture = ImageTexture.new()
	best_image = Image.new()
	best_texture = ImageTexture.new()
	
	CANVAS_HEIGHT = CANVAS_WIDTH
	
	
	# Get sprite references
	BEST_RESULT_SPRITE = $BestMap
	CURRENT_SPRITE = $CurrentMap
	
	#Get Leaderboard
	LEADERBOARD = $Leaderboard
	

	CURRENT_SPRITE.scale /= CANVAS_WIDTH
	BEST_RESULT_SPRITE.scale /= CANVAS_WIDTH
	# 2D Array of integers that represents the map where each integer 
	# indicates what district that tile belongs to
	var district_map  = []
	# Array of integers where each index indicates the district and the integer indicates the number of tiles a part of that district.
	var district_sizes = []
	# Current std dev among district size
	var current_size_std_dev
	# Array of vector2i's that represents the sum of the positions of each district
	var district_position_sums : Array[Vector2i]
	district_position_sums.resize(NUMBER_OF_DISTRICTS)
	# std dev of the average distance from district center for all districts
	var avg_distance_from_center_std_dev
	# Initialize district map and district map area
	init_district_map(district_map, district_sizes, CANVAS_WIDTH, CANVAS_HEIGHT)
	
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
			var closest_position_index = determine_nearest_position(Vector2(x,y), positions)
			working_image.set_pixel(x,y, Color(COLORS[closest_position_index]))
			best_image.set_pixel(x,y, Color(COLORS[closest_position_index]))
			district_map[x][y] = closest_position_index
			district_sizes[closest_position_index] += 1
			district_position_sums[closest_position_index] += Vector2i(x,y)
			
	var district_centers = []
	for i in range(len(district_position_sums)):
		var center : Vector2 = Vector2(district_position_sums[i]) / float(district_sizes[i])
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
		
	avg_distance_from_center_std_dev = calc_stand_dev(average_distances_from_district_center)
	
	print(avg_distance_from_center_std_dev)
				
	# Calculate the current standard deviation 
	current_size_std_dev = calc_stand_dev(district_sizes)
	
	#Set Working State
	working_state.intialize(district_map, district_sizes, current_size_std_dev, district_position_sums, avg_distance_from_center_std_dev, NUMBER_OF_DISTRICTS,CANVAS_WIDTH, CANVAS_HEIGHT)
	# Set Best from Working State
	best_state.copy_from(working_state)
			
	find_starting_edge_pixels(working_state, directions)
	
	# Set the working sprite
	working_texture = ImageTexture.create_from_image(working_image)
	CURRENT_SPRITE.texture = working_texture
	CURRENT_SPRITE.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Set the best solution sprite
	best_texture = ImageTexture.create_from_image(best_image)
	BEST_RESULT_SPRITE.texture = best_texture
	BEST_RESULT_SPRITE.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	#Get Info for Leaderboard
	var leaderboard_data = working_state.get_leaderboard_data()
	
	for i in range(NUMBER_OF_DISTRICTS):
		leaderboard_data[i].append(COLORS[i])
		
	LEADERBOARD.start_leaderboard(leaderboard_data)
	
func _process(delta: float) -> void:
	if (!running):
		return
	time_since_last_step -= delta
	if(time_since_last_step <= 0 and len(edges) > 0):
		time_since_last_step = time_between_steps
		var pos_and_new_district = flip_edge()
		
		if(pos_and_new_district[1] == -1):
			return
		if(working_state.get_score() < best_state.get_score()):
			print("Best Score : " + str(best_state.get_score()))
			print("Working Score : " + str(working_state.get_score()))
			var leaderboard_data = working_state.get_leaderboard_data()
			for i in range(NUMBER_OF_DISTRICTS):
				leaderboard_data[i].append(COLORS[i])
			LEADERBOARD.update_leaderboard(leaderboard_data)
			best_state.copy_from(working_state)
			
			
			for x in range(CANVAS_WIDTH):
				for y in range(CANVAS_HEIGHT):
					best_image.set_pixel(x,y, Color(COLORS[working_state.get_district_from_tile(x,y)]))
					
		if(number_of_bad_iterations >= MAX_NUMBER_OF_BAD_ITERATIONS):
			number_of_bad_iterations = 0
			working_state.copy_from(best_state)
			
			edges = find_starting_edge_pixels(working_state, directions)
			print("\nMoved Back\n")
			for x in CANVAS_WIDTH:
				for y in CANVAS_HEIGHT:
					working_image.set_pixel(x, y, Color(COLORS[working_state.get_district_from_tile(x,y)]))
		else:
			working_image.set_pixel(pos_and_new_district[0].x, pos_and_new_district[0].y, Color(COLORS[pos_and_new_district[1]]))

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

func find_starting_edge_pixels(redistricting_state : RedistrictingState, directions):
	edges = []
	for x in range(CANVAS_WIDTH):
		for y in range(CANVAS_HEIGHT):
			var pos = Vector2i(x,y)
			if redistricting_state.check_if_edge_pixel(pos, directions):
				edges.append(pos)
				
	return edges

func init_district_map(district_map, district_sizes, image_width, image_height):
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

func flip_edge():
	# Get a random edge tile to potentially flip
	var edge_index = randi_range(0, len(edges) - 1)
	var pos = edges[edge_index]
	# Get tile's original district
	var original_district = working_state.get_district_from_tile(pos.x, pos.y)
	
	# Get the neighboring district values of the chosen edge (not including original district value)
	var neighboring_districts = working_state.get_neighboring_districts_from_position(pos, directions)
			
	# Choose a random district that neighbors the chosen edge tile
	var neighbor_index = randi_range(0, len(neighboring_districts) - 1)
	var new_district = neighboring_districts[neighbor_index]
	
	#Check if move would create a split
	if(working_state.move_creates_split_check(pos)):
		return [Vector2i.ZERO, -1]

	var bad_move_value = randf()
	#Test Move
	var move = working_state.test_move(pos, new_district, SIZE_STD_DEV_WEIGHT, DISTANCE_FROM_CENTER_DEV_WEIGHT)
	var move_is_good = move[0]
	var move_state = move[1]
	
	# If move decreases area std deviation or passes the bad move check
	if(move_is_good or bad_move_value < initial_bad_move_chance):
		# Increase the number of bad iterations if a "bad" move
		if(!move_is_good and bad_move_value < initial_bad_move_chance):
			initial_bad_move_chance -= TEMP_CHANGE_RATE
			number_of_bad_iterations += 1
		
		# Call algorithm state to perform move
		working_state = move_state
		

		#Update edges to match new map
		working_state.determine_new_edges(pos, original_district, edges, directions)
		#find_edge_pixels(directions)
		return [pos, new_district]
	else:
		return [Vector2i.ZERO, -1]
		
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
	
