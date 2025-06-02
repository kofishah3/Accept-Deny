extends Node2D

var floor_tile_theme1: Array[Vector2i] = [Vector2i(15,6), Vector2i(15,7), Vector2i(16,6), Vector2i(16,7)]
var floor_tile_theme2: Array[Vector2i] = [Vector2i(17,6), Vector2i(17,7), Vector2i(17,6), Vector2i(18,7)]
var floor_tile_theme3: Array[Vector2i] = [Vector2i(15,8), Vector2i(15,9), Vector2i(16,8), Vector2i(16,9)]
var valid_floor_tiles : Array[Vector2i] = floor_tile_theme1 + floor_tile_theme2 + floor_tile_theme3 
var current_theme : int = 1

#load the room variants - using null initialization instead of @onready
var floor_sprite_0 = null
var floor_sprite_90 = null
var floor_sprite_180 = null
var floor_sprite_270 = null

func set_theme(theme_chosen : int) -> void:
	current_theme = theme_chosen
	
	# initalize the rooms
	floor_sprite_0 = get_node("RoomSprite0") if has_node("RoomSprite0") else null
	floor_sprite_90 = get_node("RoomSprite90") if has_node("RoomSprite90") else null
	floor_sprite_180 = get_node("RoomSprite180") if has_node("RoomSprite180") else null
	floor_sprite_270 = get_node("RoomSprite270") if has_node("RoomSprite270") else null
	
	var floor_rotation = randi_range(0, 3)
	var current_room_rotationVar = _get_rotated_room(floor_rotation)
	if current_room_rotationVar:
		set_floor_theme(current_room_rotationVar, current_theme)
		
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

func set_floor_theme(tile_layer: TileMapLayer, theme_id: int) -> void:
	var used_cells = tile_layer.get_used_cells()
	
	for cell_coords in used_cells:
		var atlas_coords = tile_layer.get_cell_atlas_coords(cell_coords)

		if _is_floor_tile(atlas_coords):
			var new_atlas_coords = _get_random_floor_variant(theme_id)
			var source_id = tile_layer.get_cell_source_id(cell_coords)
			tile_layer.set_cell(cell_coords, source_id, new_atlas_coords)
			
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
						
				return floor_sprite_180
		2:		
			if floor_sprite_90:
				floor_sprite_90.visible = true		
				
				#move all the doors
				if has_node("north_door"):
					$north_door.position.x -= 16 * 3
				if has_node("south_door"):
					$south_door.position.y += 16 * 2	
					$south_door.position.x -= 16 * 3	
				if has_node("west_door"):
					$west_door.position.y += 16 * 3		
				if has_node("east_door"):
					$east_door.position.y += 16 * 3	
					$east_door.position.x -= 16 * 2		

				return floor_sprite_90
		3:
			if floor_sprite_270:
				floor_sprite_270.visible = true
				
				#move all the doors
				if has_node("south_door"):
					$south_door.position.y += 16 * 2		
				if has_node("west_door"):
					$west_door.position.y += 16 * 3		
				if has_node("east_door"):
					$east_door.position.y += 16 * 3	
					$east_door.position.x -= 16 * 3		
				
				return floor_sprite_270
		_:
			return floor_sprite_0 if floor_sprite_0 else null
