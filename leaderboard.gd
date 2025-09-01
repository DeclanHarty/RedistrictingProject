extends Control

@export var start_leaderboard_records_position : Vector2
@export var distance_between_records : float
@export var number_of_records : int

@export var record_prefab : PackedScene

var records = []
	
func start_leaderboard(leaderboard_data):
	leaderboard_data.sort_custom(leaderboard_record_sort)
	
	for i in range(len(leaderboard_data)):
		var instance = record_prefab.instantiate()
		add_child(instance)
		instance.position = start_leaderboard_records_position + Vector2(0, distance_between_records) * i
		instance.set_record(leaderboard_data[i][0], leaderboard_data[i][2], leaderboard_data[i][1])
		records.append(instance)
		
func update_leaderboard(leaderboard_data):
	leaderboard_data.sort_custom(leaderboard_record_sort)
	for i in range(len(leaderboard_data)):
		records[i].set_record(leaderboard_data[i][0], leaderboard_data[i][2], leaderboard_data[i][1])


func leaderboard_record_sort(a, b):
	return a[1] > b[1]


	
	
	
