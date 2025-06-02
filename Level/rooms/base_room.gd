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

func _ready() -> void:
	# Create room area for player detection
	room_area = Area2D.new()
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
