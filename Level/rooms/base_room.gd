extends Node2D
class_name BaseRoom

signal player_entered(room_rect: Rect2)
signal player_exited
signal combat_triggered(room, enemies)

@export var has_combat := false
@export var enemy_data := []  # Array of enemy definitions for this room
@export var combat_positions := []  # Array of Vector2i positions for combatants
@export var room_width: int = 20  # Width in grid cells
@export var room_height: int = 15  # Height in grid cells

var player_in_room := false
var combat_completed := false
var room_rect: Rect2
var room_area: Area2D
var enemies: Array = []  # Array to store spawned enemies
var enemy_scene = preload("res://enemy.tscn")
var non_floor_tile_coords: Array[Vector2i] = []  # Store coordinates of non-floor tiles

# Door traversal popup
var door_popup_scene = preload("res://ui/door_traversal_popup.tscn")
var door_popup_instance = null

func _ready() -> void:	
	room_area = Area2D.new() #room area for player detection
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	var grid_manager = get_node("/root/main/GridManager")
	var cell_size = grid_manager.GRID_SIZE
	shape.size = Vector2(room_width * cell_size, room_height * cell_size)
	collision.shape = shape
	room_area.add_child(collision)
	add_child(room_area)
	
	# Connect area signals
	room_area.body_entered.connect(_on_room_area_entered)
	room_area.body_exited.connect(_on_room_area_exited)
	
	# Calculate room boundaries in world coordinates
	var top_left = grid_manager.grid_to_world(Vector2.ZERO)
	room_rect = Rect2(top_left, Vector2(room_width * cell_size, room_height * cell_size))
	
	# Spawn enemies if this room should have combat
	if has_combat:
		spawn_enemies()
	
	# Set up door interactions
	setup_door_interactions()
	
	# Create door popup instance
	create_door_popup()

func create_door_popup():
	if not door_popup_instance:
		door_popup_instance = door_popup_scene.instantiate()
		#add to canvas layer for proper UI display
		var canvas_layer = get_node("/root/main/CanvasLayer")
		if canvas_layer:
			canvas_layer.add_child(door_popup_instance)

func setup_door_interactions():
	# Add interaction areas to each door
	var doors = ["north_door", "south_door", "east_door", "west_door"]
	for door_name in doors:
		if has_node(door_name):
			var door = get_node(door_name)
			setup_door_interaction(door, door_name)

func setup_door_interaction(door: Node2D, door_name: String):
	# Create Area2D for door interaction
	var door_area = Area2D.new()
	door_area.name = door_name + "_area"
	
	# Create collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)  # 1x1 grid cell for precise interaction
	collision.shape = shape
	door_area.add_child(collision)
	
	# Add to door
	door.add_child(door_area)
	
	door_area.area_entered.connect(_on_door_entered.bind(door_name))
	door_area.area_exited.connect(_on_door_exited.bind(door_name))

func _on_door_entered(area: Area2D, door_name: String):
	if area.is_in_group("player"):
		var door = get_node(door_name)
		if door and door.visible:
			show_door_traversal_popup(door_name)

func _on_door_exited(area: Area2D, door_name: String):
	if area.is_in_group("player"):
		# Hide the popup when player moves away from door
		if door_popup_instance and door_popup_instance.visible:
			door_popup_instance.hide_popup()

func show_door_traversal_popup(door_name: String):
	# Make sure we have a popup instance
	if not door_popup_instance:
		create_door_popup()
	
	if door_popup_instance:
		door_popup_instance.show_door_prompt(door_name, self)

func teleport_player_through_door(door_name: String):
	var direction = get_door_direction(door_name)
	var target_room_pos = get_target_room_position(direction)
	
	if target_room_pos == Vector2i(-1, -1):
		print("no room found in direction: ", direction)
		return
	
	var target_room = find_room_at_position(target_room_pos)
	if not target_room:
		print("Target room not found at: ", target_room_pos)
		return
	
	var opposite_door = get_opposite_door_name(door_name)
	if not target_room.has_node(opposite_door):
		print("Target room doesn't have door: ", opposite_door)
		return
	
	# teleport the player
	var player = get_node("/root/main/Player")
	if player:
		var target_door = target_room.get_node(opposite_door)
		var teleport_pos = target_room.global_position + target_door.position
		
		# offset the player a little away from the door
		var offset = get_door_teleport_offset(opposite_door)
		teleport_pos += offset
		
		player.global_position = teleport_pos
		player.grid_position = get_node("/root/main/GridManager").world_to_grid(teleport_pos)
		
		# Update grid manager
		get_node("/root/main/GridManager").update_occupied_tiles()
		
		print("Player teleported from ", door_name, " to ", opposite_door, " at ", target_room_pos)

func get_door_direction(door_name: String) -> Vector2i:
	match door_name:
		"north_door": return Vector2i.UP
		"south_door": return Vector2i.DOWN
		"east_door": return Vector2i.RIGHT
		"west_door": return Vector2i.LEFT
		_: return Vector2i.ZERO

func get_opposite_door_name(door_name: String) -> String:
	match door_name:
		"north_door": return "south_door"
		"south_door": return "north_door"
		"east_door": return "west_door"
		"west_door": return "east_door"
		_: return ""

func get_door_teleport_offset(door_name: String) -> Vector2:
	# Offset player away from the door they're teleporting to
	match door_name:
		"north_door": return Vector2(0, 16)  # Place player below north door
		"south_door": return Vector2(0, -16)  # Place player above south door
		"east_door": return Vector2(-16, 0)   # Place player left of east door
		"west_door": return Vector2(16, 0)    # Place player right of west door
		_: return Vector2.ZERO

func get_target_room_position(direction: Vector2i) -> Vector2i:
	#get this room's position in the dungeon grid
	var dungeon_level = get_node("/root/main/DungeonContainer").get_child(0)
	var current_room_pos = get_room_grid_position()
	
	if current_room_pos == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	
	return current_room_pos + direction

func get_room_grid_position() -> Vector2i:
	# calculate this room's position in the dungeon grid
	var cell_size = 16 * 15  
	var room_grid_pos = Vector2i(global_position / cell_size)
	return room_grid_pos

func find_room_at_position(grid_pos: Vector2i) -> Node2D:
	# Find the room at the specified grid position
	var dungeon_container = get_node("/root/main/DungeonContainer")
	var cell_size = 16 * 15
	var target_world_pos = Vector2(grid_pos * cell_size)
	
	for room in dungeon_container.get_child(0).get_children():
		if room.is_in_group("rooms"):
			if room.global_position == target_world_pos:
				return room
	
	return null

func is_valid_spawn_position(x: int, y: int, floor_sprite: TileMapLayer, grid_manager: Node) -> bool:
	# Check if position is within room bounds
	if x <= 0 or x >= room_width - 1 or y <= 0 or y >= room_height - 1:
		return false
		
	# Get the tile's atlas coordinates
	var atlas_coords = floor_sprite.get_cell_atlas_coords(Vector2i(x, y))
	
	# Check if this is a valid floor tile
	if not _is_floor_tile(atlas_coords):
		return false
		
	# Calculate world and grid positions
	var world_pos = position + (Vector2(x, y) * grid_manager.GRID_SIZE)
	var grid_pos = grid_manager.world_to_grid(world_pos)
	
	# Check if position is walkable
	if not grid_manager._is_walkable(grid_pos):
		return false
		
	# Check surrounding tiles (3x3 area) to ensure it's not too close to walls
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var check_pos = Vector2i(x + dx, y + dy)
			var check_atlas = floor_sprite.get_cell_atlas_coords(check_pos)
			if not _is_floor_tile(check_atlas):
				return false
				
	return true

func spawn_enemies() -> void:
	var num_enemies = randi_range(1, 3)  # Random number of enemies between 1-3
	var grid_manager = get_node("/root/main/GridManager")
	var enemies_container = get_node("/root/main/Enemies")
	
	# Get valid spawn positions (avoid walls and doors)
	var valid_positions = []
	var floor_sprite = get_node("RoomSprite") if has_node("RoomSprite") else null
	if not floor_sprite:
		# Try to find any room sprite
		for child in get_children():
			if child is TileMapLayer:
				floor_sprite = child
				break
	
	if floor_sprite:
		# First pass: Find all valid floor tiles with strict validation
		for x in range(2, room_width - 2):  # Leave larger margin from walls
			for y in range(2, room_height - 2):
				if is_valid_spawn_position(x, y, floor_sprite, grid_manager):
					var world_pos = position + (Vector2(x, y) * grid_manager.GRID_SIZE)
					valid_positions.append(world_pos)
	
	# If we don't have enough valid positions, try a second pass with less strict requirements
	if valid_positions.size() < num_enemies:
		for x in range(1, room_width - 1):
			for y in range(1, room_height - 1):
				# Skip positions we already checked in the first pass
				if x >= 2 and x < room_width - 2 and y >= 2 and y < room_height - 2:
					continue
					
				if is_valid_spawn_position(x, y, floor_sprite, grid_manager):
					var world_pos = position + (Vector2(x, y) * grid_manager.GRID_SIZE)
					if not valid_positions.has(world_pos):  # Avoid duplicates
						valid_positions.append(world_pos)
	
	# Spawn enemies at random valid positions
	for i in range(num_enemies):
		if valid_positions.size() > 0:
			var spawn_pos = valid_positions[randi() % valid_positions.size()]
			var enemy = enemy_scene.instantiate()
			enemies_container.add_child(enemy)
			enemy.position = spawn_pos
			enemy.grid_position = grid_manager.world_to_grid(spawn_pos)
			enemies.append(enemy)
			
			# Remove used position to avoid enemies spawning on top of each other
			valid_positions.erase(spawn_pos)
	
	# Update occupied tiles after spawning all enemies
	grid_manager.update_occupied_tiles()

func _on_room_area_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not player_in_room:
		player_in_room = true
		player_entered.emit(room_rect)
		
		# Trigger combat if this room has combat and it hasn't been completed
		if has_combat and not combat_completed and enemies.size() > 0:
			emit_signal("combat_triggered", self, enemies)

func _on_room_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_room = false
		player_exited.emit()

func set_doors(neighbors: Dictionary) -> void:
	$north_door.visible = neighbors.get("up", false)
	$east_door.visible = neighbors.get("right", false)
	$south_door.visible = neighbors.get("down", false)
	$west_door.visible = neighbors.get("left", false)

func get_combat_position() -> Vector2i:
	# Return the player's combat position (usually center of room)
	return Vector2i(5, 5)  # Default to center, override in specific room types if needed

func get_enemy_position(enemy_data: Dictionary) -> Vector2i:
	# Return a position for the enemy based on available combat positions
	if combat_positions.size() > 0:
		return combat_positions[randi() % combat_positions.size()]
	return Vector2i(7, 5)  # Default position if no specific positions defined

func combat_finished() -> void:
	combat_completed = true
	# Add any room-specific logic for when combat is finished
	# For example, opening treasure chests, revealing secrets, etc.

# Virtual methods that should be implemented by room-specific scripts
func _is_floor_tile(atlas_coords: Vector2i) -> bool:
	return false  # Base implementation, should be overridden

func _collect_non_floor_tiles(room_layer: TileMapLayer) -> void:
	non_floor_tile_coords.clear()
	var used_cells = room_layer.get_used_cells()
	
	for cell_coords in used_cells:
		var atlas_coords = room_layer.get_cell_atlas_coords(cell_coords)
		
		if not _is_floor_tile(atlas_coords):
			non_floor_tile_coords.append(cell_coords)

func get_non_floor_tiles() -> Array[Vector2i]:
	return non_floor_tile_coords.duplicate() 
