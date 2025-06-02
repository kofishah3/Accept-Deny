extends Node2D

@onready var floor_sprite = $RoomSprite

var floor_tile_theme1: Array[Vector2i] = [Vector2i(15,6), Vector2i(15,7), Vector2i(16,6), Vector2i(16,7)]
var floor_tile_theme2: Array[Vector2i] = [Vector2i(17,6), Vector2i(17,7), Vector2i(17,6), Vector2i(18,7)]
var floor_tile_theme3: Array[Vector2i] = [Vector2i(15,8), Vector2i(15,9), Vector2i(16,8), Vector2i(16,9)]
var valid_floor_tiles : Array[Vector2i] = floor_tile_theme1 + floor_tile_theme2 + floor_tile_theme3 
var current_theme : int = 1

# Store coordinates of non-floor tiles
var non_floor_tile_coords: Array[Vector2i] = []

# function for updating the themees of the room
func set_theme(theme_chosen : int) -> void:
	current_theme = theme_chosen
	set_floor_theme(floor_sprite, current_theme)
	# Update non-floor tile record when theme changes
	_collect_non_floor_tiles(floor_sprite)
	
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

# Collect all non-floor tile coordinates
func _collect_non_floor_tiles(room_layer: TileMapLayer) -> void:
	non_floor_tile_coords.clear()
	var used_cells = room_layer.get_used_cells()
	
	for cell_coords in used_cells:
		var atlas_coords = room_layer.get_cell_atlas_coords(cell_coords)
		
		if not _is_floor_tile(atlas_coords):
			non_floor_tile_coords.append(cell_coords)

# Getter method for non-floor tile coordinates
func get_non_floor_tiles() -> Array[Vector2i]:
	return non_floor_tile_coords.duplicate()

func set_floor_theme(room_layer: TileMapLayer, theme_id: int) -> void:
	var used_cells = room_layer.get_used_cells()
	
	for cell_coords in used_cells:
		var atlas_coords = room_layer.get_cell_atlas_coords(cell_coords)
		
		if _is_floor_tile(atlas_coords):
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
			
