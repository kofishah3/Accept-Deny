extends "res://Level/rooms/base_room.gd"

var floor_tile_theme1: Array[Vector2i] = [Vector2i(15,6), Vector2i(15,7), Vector2i(16,6), Vector2i(16,7)]
var floor_tile_theme2: Array[Vector2i] = [Vector2i(17,6), Vector2i(17,7), Vector2i(17,6), Vector2i(18,7)]
var floor_tile_theme3: Array[Vector2i] = [Vector2i(15,8), Vector2i(15,9), Vector2i(16,8), Vector2i(16,9)]
var valid_floor_tiles : Array[Vector2i] = floor_tile_theme1 + floor_tile_theme2 + floor_tile_theme3 
var current_theme : int = 1

#load the room variants - using null initialization instead of @onready
var floor_sprite_0 = null
var floor_sprite_180 = null

func set_theme(theme_chosen : int) -> void:
	current_theme = theme_chosen
	
	# initalize the rooms
	floor_sprite_0 = get_node("RoomSprite0") if has_node("RoomSprite0") else null
	floor_sprite_180 = get_node("RoomSprite180") if has_node("RoomSprite180") else null
	
	var floor_rotation = randi_range(0, 1)
	var floor_sprite = _get_rotated_room(floor_rotation)
	if floor_sprite:
		set_floor_theme(floor_sprite, current_theme)
	
	# Update non-floor tile record when theme changes
	_collect_non_floor_tiles(floor_sprite)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func set_doors(neighbors: Dictionary) -> void:
	if has_node("north_door"):
		$north_door.visible = neighbors.get("up", false)
	if has_node("east_door"):
		$east_door.visible = neighbors.get("right", false)
	if has_node("south_door"):
		$south_door.visible = neighbors.get("down", false)
	if has_node("west_door"):
		$west_door.visible = neighbors.get("left", false)
	
func _is_floor_tile(atlas_coords : Vector2i) -> bool:
	return atlas_coords in valid_floor_tiles

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
					
func _get_rotated_room(rotation: int):
	match rotation:
		0:
			if floor_sprite_0:
				floor_sprite_0.visible = true
				return floor_sprite_0
			#no need to move the doors
		1:		
			if floor_sprite_180:
				floor_sprite_180.visible = true		
				
				#move the left and right doors down by 4 tiles
				if has_node("west_door"):
					$west_door.position.y += 16 * 4
				if has_node("east_door"):
					$east_door.position.y += 16 * 4			
				if has_node("north_door"):
					$north_door.position.x -= 16 * 3
				if has_node("south_door"):
					$south_door.position.x += 16 * 3

				return floor_sprite_180
		_:
			return floor_sprite_0 if floor_sprite_0 else null

func is_valid_spawn_position(x: int, y: int, floor_sprite: TileMapLayer, grid_manager: Node) -> bool:
	# First check if the position is valid according to base room rules
	if not super.is_valid_spawn_position(x, y, floor_sprite, grid_manager):
		return false
	
	# Get the current room rotation by checking which floor sprite is visible
	var is_rotated = floor_sprite_180 and floor_sprite_180.visible
	
	# Get the atlas coordinates at this position
	var cell_coords = Vector2i(x, y)
	var atlas_coords = floor_sprite.get_cell_atlas_coords(cell_coords)
	
	# Strictly check if this is a floor tile
	if not _is_floor_tile(atlas_coords):
		return false
	
	# Check surrounding tiles (3x3 area) to ensure we're not near any non-floor tiles
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check_coords = Vector2i(x + dx, y + dy)
			var check_atlas = floor_sprite.get_cell_atlas_coords(check_coords)
			if not _is_floor_tile(check_atlas):
				return false
	
	# Define the valid spawn areas for each rotation
	# These areas are now smaller and more strictly defined
	var valid_areas = []
	if is_rotated:
		# For 180° rotation
		valid_areas = [
			Rect2(4, 4, 2, 2),  # Top-left area (2 tiles away from walls)
			Rect2(4, 10, 2, 2)  # Bottom-left area (2 tiles away from walls)
		]
	else:
		# For 0° rotation
		valid_areas = [
			Rect2(4, 4, 2, 2),  # Top-left area (2 tiles away from walls)
			Rect2(10, 4, 2, 2)  # Top-right area (2 tiles away from walls)
		]
	
	# Check if the position is within any valid area
	var pos = Vector2(x, y)
	for area in valid_areas:
		if area.has_point(pos):
			# Final check - ensure we're not near any doors
			var door_positions = []
			if has_node("north_door") and $north_door.visible:
				door_positions.append(Vector2(8, 1))
			if has_node("south_door") and $south_door.visible:
				door_positions.append(Vector2(8, 14))
			if has_node("west_door") and $west_door.visible:
				door_positions.append(Vector2(1, 8))
			if has_node("east_door") and $east_door.visible:
				door_positions.append(Vector2(14, 8))
			
			# Check distance to all doors
			for door_pos in door_positions:
				if pos.distance_to(door_pos) < 3:  # Must be at least 3 tiles away from any door
					return false
			
			return true
	
	return false
