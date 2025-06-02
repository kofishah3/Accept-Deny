extends Node2D

const GRID_SIZE = 16.0  # Size of each grid cell in pixels
var grid_width = 60  
var grid_height = 43

var current_turn = "player"  # Can be "player" or "enemy"
var selected_unit = null
var valid_moves = []
var valid_attacks = []
var attack_color = Color(1, 0, 0, 0.3) # Semi-transparent red for all attacks
var occupied_tiles = {} # Dictionary to track occupied tiles
var move_ap_costs = {} # Dictionary to store AP cost for each valid move
var disabled_tiles = {}
var wall_global_positions: Array[Vector2i] = []

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
	
	# Draw disabled (unwalkable) tiles
	for tile in disabled_tiles.keys():
		var rect = Rect2(tile * GRID_SIZE, Vector2(GRID_SIZE, GRID_SIZE))
		draw_rect(rect, Color(1, 0, 0, 0.2))  # Semi-transparent red

func _process(_delta):
	queue_redraw()  # Redraw every frame to update highlights

func mark_unwalkable_tiles(tile_list: Array[Vector2i]) -> void:
	for pos in tile_list:
		disabled_tiles[pos] = true

func _is_walkable(grid_pos: Vector2) -> bool:
	var grid_pos_i = Vector2i(grid_pos)  # Convert to Vector2i for comparison
	return is_valid_grid_position(grid_pos) and not is_tile_occupied(grid_pos) and not disabled_tiles.has(grid_pos_i)

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
	return occupied_tiles.has(Vector2i(grid_pos))

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

# Allow diagonal movement, BFS for AP
func calculate_movement_range(unit_pos: Vector2, max_ap: int) -> Array:
	var valid_positions = []
	move_ap_costs.clear()
	var visited = {}
	var queue = [ {"pos": unit_pos, "cost": 0} ]
	visited[unit_pos] = true
	while queue.size() > 0:
		var current = queue.pop_front()
		var pos = current["pos"]
		var cost = current["cost"]
		if cost > 0:
			valid_positions.append(pos)
			move_ap_costs[pos] = cost
		if cost >= max_ap:
			continue
		for dir in [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]:
			var next = pos + dir
			if not _is_walkable(next):
				continue
			if visited.has(next):
				continue
			visited[next] = true
			queue.append({"pos": next, "cost": cost + 1})
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
	
func clear_disabled_tiles() -> void:
	disabled_tiles.clear()
