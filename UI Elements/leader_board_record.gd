extends Control

var district_number_field
var district_color_field
var district_size_field

func _ready():
	district_number_field = $DistrictNumber
	district_color_field = $DistrictColor
	district_size_field = $DistrictSize
	

	
func set_record(district_number, district_color, district_size):
	district_number_field.text = str(district_number)
	
	var district_image = Image.create_empty(1,1, true, Image.FORMAT_RGB8)
	district_image.fill(district_color)
	district_color_field.texture = ImageTexture.create_from_image(district_image)
	
	district_size_field.text = str(district_size)
	
func set_district_size(district_size):
	district_size_field.text = str(district_size)
