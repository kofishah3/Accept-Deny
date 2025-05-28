extends Node2D

const GRID_SIZE = 64.0  # Size of each grid cell in pixels
var grid_width = 18   # Number of cells horizontally
var grid_height = 12  # Number of cells vertically

var current_turn = "player"  # Can be "player" or "enemy"
var selected_unit = null
var valid_moves = []
var valid_attacks = []
var attack_color = Color(1, 0, 0, 0.3)  # Semi-transparent red for all attacks
var occupied_tiles = {}  # Dictionary to track occupied tiles

func _ready():
	# Initialize the grid
	update_occupied_tiles()

func _draw():
	# Draw grid lines
	for x in range(grid_width + 1):
		draw_line(Vector2(x * GRID_SIZE, 0), Vector2(x * GRID_SIZE, grid_height * GRID_SIZE), Color.WHITE, 1.0)
	for y in range(grid_height + 1):
		draw_line(Vector2(0, y * GRID_SIZE), Vector2(grid_width * GRID_SIZE, y * GRID_SIZE), Color.WHITE, 1.0)
	
	# Draw valid moves
	for move in valid_moves:
		var rect = Rect2(move * GRID_SIZE, Vector2(GRID_SIZE, GRID_SIZE))
		draw_rect(rect, Color(0, 1, 0, 0.3))  # Semi-transparent green
	
	# Draw valid attacks
	for attack in valid_attacks:
		var rect = Rect2(attack * GRID_SIZE, Vector2(GRID_SIZE, GRID_SIZE))
		draw_rect(rect, attack_color)  # Use consistent semi-transparent red

func _process(_delta):
	queue_redraw()  # Redraw every frame to update highlights

func update_occupied_tiles():
	occupied_tiles.clear()
	
	# Add player position
	var player = get_node("/root/main/Player")
	if player:
		occupied_tiles[player.grid_position] = player
	
	# Add enemy positions
	for enemy in get_node("/root/main/Enemies").get_children():
		occupied_tiles[enemy.grid_position] = enemy

func is_tile_occupied(grid_pos: Vector2) -> bool:
	return occupied_tiles.has(grid_pos)

func world_to_grid(world_pos: Vector2) -> Vector2:
	return Vector2(
		floor(world_pos.x / GRID_SIZE),
		floor(world_pos.y / GRID_SIZE)
	)

func grid_to_world(grid_pos: Vector2) -> Vector2:
	return Vector2(
		grid_pos.x * GRID_SIZE + GRID_SIZE/2.0,
		grid_pos.y * GRID_SIZE + GRID_SIZE/2.0
	)

func is_valid_grid_position(pos: Vector2) -> bool:
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

func calculate_movement_range(unit_pos: Vector2, movement_range: int) -> Array:
	var valid_positions = []
	for x in range(-movement_range, movement_range + 1):
		for y in range(-movement_range, movement_range + 1):
			var new_pos = unit_pos + Vector2(x, y)
			if is_valid_grid_position(new_pos) and not is_tile_occupied(new_pos):
				# Manhattan distance for grid-based movement
				if abs(x) + abs(y) <= movement_range:
					valid_positions.append(new_pos)
	return valid_positions

func update_attack_range(unit_pos: Vector2, attack_range: int) -> Array:
	var valid_positions = []
	for x in range(-attack_range, attack_range + 1):
		for y in range(-attack_range, attack_range + 1):
			var new_pos = unit_pos + Vector2(x, y)
			if is_valid_grid_position(new_pos):
				# Manhattan distance for attack range
				if abs(x) + abs(y) <= attack_range:
					# Don't add the unit's own position
					if new_pos != unit_pos:
						valid_positions.append(new_pos)
	return valid_positions

func get_unit_at_position(grid_pos: Vector2) -> Node:
	return occupied_tiles.get(grid_pos) 
