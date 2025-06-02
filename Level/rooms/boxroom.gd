extends "res://Level/rooms/base_room.gd"

@onready var floor_sprite = $RoomSprite
@onready var details_layer = $DetailsLayer

var floor_tile_theme1: Array[Vector2i] = [Vector2i(15,6), Vector2i(15,7), Vector2i(16,6), Vector2i(16,7)]
var floor_tile_theme2: Array[Vector2i] = [Vector2i(17,6), Vector2i(17,7), Vector2i(17,6), Vector2i(18,7)]
var floor_tile_theme3: Array[Vector2i] = [Vector2i(15,8), Vector2i(15,9), Vector2i(16,8), Vector2i(16,9)]
var valid_floor_tiles : Array[Vector2i] = floor_tile_theme1 + floor_tile_theme2 + floor_tile_theme3 
var current_theme : int = 1

# Store coordinates of non-floor tiles

var floor_tile_coords: Array[Vector2i] = []
#load the tilset list script
var DecorTileData := preload("res://Level/DecorTileData.gd").new()

# function for updating the themees of the room
func set_theme(theme_chosen : int) -> void:
	current_theme = theme_chosen
	set_floor_theme(floor_sprite, current_theme)
	# Update non-floor tile record when theme changes
	# Add random decorations
	#_add_random_decor(details_layer, 3) #looks ugly, will add last
			
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func set_doors(neighbors: Dictionary) -> void:
	$north_door.visible = neighbors.get("up", false)
	$east_door.visible = neighbors.get("right", false)
	$south_door.visible = neighbors.get("down", false)
	$west_door.visible = neighbors.get("left", false)
	
func _is_floor_tile(atlas_coords : Vector2i) -> bool:
	return atlas_coords in valid_floor_tiles

func set_floor_theme(room_layer: TileMapLayer, theme_id: int) -> void:
	var used_cells = room_layer.get_used_cells()
	
	for cell_coords in used_cells:
		var atlas_coords = room_layer.get_cell_atlas_coords(cell_coords)
		
		if _is_floor_tile(atlas_coords):
			floor_tile_coords.append(cell_coords)
			var new_atlas_coords = _get_random_floor_variant(theme_id)
			var source_id = room_layer.get_cell_source_id(cell_coords)
			room_layer.set_cell(cell_coords, source_id, new_atlas_coords)		
			
func _get_random_floor_variant(theme_id: int) -> Vector2i:
	match theme_id:
		1:
			return floor_tile_theme1[randi_range(0, floor_tile_theme1.size() - 1)]
		2:
			return floor_tile_theme2[randi_range(0, floor_tile_theme2.size() - 1)]
		3:
			return floor_tile_theme3[randi_range(0, floor_tile_theme3.size() - 1)]
		_:
			return floor_tile_theme1[0]

func _add_random_decor(tile_layer: TileMapLayer, count: int) -> void:
	var chosen_floor_tiles: Array[Vector2i] = []
	#choose random floor locations based on count
	for i in range(0, count):
		chosen_floor_tiles.append(floor_tile_coords[randi_range(0, floor_tile_coords.size() - 1)])	
	
	# Add the decors at each coord location
	for coord in chosen_floor_tiles:
		var random_tile_atlas_coords: Vector2i = Vector2i(0,0)
		 
		#choose a random floor tile from the list from the DecorTileData-script
		if DecorTileData.has_method("get_random_floor_decor"):
			random_tile_atlas_coords = DecorTileData.get_random_floor_decor()
				
		tile_layer.set_cell(coord, 0, random_tile_atlas_coords)		
		
