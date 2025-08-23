class_name RedistrictingState

@export var CANVAS_WIDTH : int
@export var CANVAS_HEIGHT : int
@export var district_map : Array
@export var district_sizes : Array[int]
@export var size_std_dev : float
@export var position_sums : Array[Vector2i]


func intialize(district_map, district_sizes, size_std_dev, position_sums, canvas_width, canvas_height):
	self.district_map = district_map
	self.district_sizes = district_sizes
	self.size_std_dev = size_std_dev
	self.position_sums = position_sums
	self.CANVAS_WIDTH = canvas_width
	self.CANVAS_HEIGHT = canvas_height
	

func copy_from(redistricting_state : RedistrictingState):
	self.district_map = redistricting_state.distract_map.duplicate(true)
	self.district_sizes = redistricting_state.district_sizes.duplicate(false)
	self.size_std_dev = redistricting_state.size_std_dev
	self.position_sums = redistricting_state.position_sums.duplicate(false)
	
func test_move(tile_pos : Vector2i, new_district : int, area_std_dev_weight, distance_from_center_std_dev_weight):
	pass
	
func make_move():
	pass
	
func get_neighboring_districts_from_position(position : Vector2i, directions) -> Array[int]:
	var current_district = district_map[position.x][position.y]
	var neighboring_districts = []
	for direction in directions:
		var check_pos = position + direction
		if (check_pos.x < 0 or check_pos.x >= CANVAS_WIDTH or check_pos.y < 0 or check_pos.y >= CANVAS_HEIGHT):
			continue
		var neighbor_district = district_map[check_pos.x][check_pos.y]
		if neighbor_district != current_district and neighbor_district not in neighboring_districts:
			neighboring_districts.append(neighbor_district)
			
	return neighboring_districts
	
	
