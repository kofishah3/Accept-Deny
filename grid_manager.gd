extends Node2D

const GRID_SIZE = 16.0  # Size of each grid cell in pixels

var grid_width = 80  
var grid_height = 50 

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

func update_line_attack_range(unit_pos: Vector2, attack_range: int, diagonal_allowed: bool) -> Array:
	var valid_positions = []
	var directions = [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]
	if diagonal_allowed:
		directions.append_array([Vector2(1,1), Vector2(-1,1), Vector2(1,-1), Vector2(-1,-1)])
	
	for dir in directions:
		for i in range(1, attack_range + 1):
			var new_pos = unit_pos + (dir * i)
			if is_valid_grid_position(new_pos):
				valid_positions.append(new_pos)
			else:
				break  # Stop checking in this direction if we hit a wall
	return valid_positions

func update_aoe_attack_range(unit_pos: Vector2, attack_range: int, aoe_size: Vector2) -> Array:
	var valid_positions = []
	for x in range(-attack_range, attack_range + 1):
		for y in range(-attack_range, attack_range + 1):
			var new_pos = unit_pos + Vector2(x, y)
			if is_valid_grid_position(new_pos):
				# Manhattan distance for attack range
				if abs(x) + abs(y) <= attack_range:
					valid_positions.append(new_pos)
	return valid_positions

func update_piercing_attack_range(unit_pos: Vector2, diagonal_allowed: bool) -> Array:
	var valid_positions = []
	var directions = [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]
	if diagonal_allowed:
		directions.append_array([Vector2(1,1), Vector2(-1,1), Vector2(1,-1), Vector2(-1,-1)])
	
	for dir in directions:
		var current_pos = unit_pos
		while true:
			current_pos += dir
			if not is_valid_grid_position(current_pos):
				break
			valid_positions.append(current_pos)
	return valid_positions

func get_units_in_line(start_pos: Vector2, end_pos: Vector2) -> Array:
	var units = []
	var dir = (end_pos - start_pos).normalized()
	var current_pos = start_pos + dir
	
	while current_pos != end_pos:
		if is_valid_grid_position(current_pos):
			var unit = get_unit_at_position(current_pos)
			if unit:
				units.append(unit)
		current_pos += dir
	
	# Add the target unit at the end position
	var end_unit = get_unit_at_position(end_pos)
	if end_unit:
		units.append(end_unit)
	
	return units

func get_units_in_aoe(center_pos: Vector2, aoe_size: Vector2) -> Array:
	var units = []
	var half_size = aoe_size / 2
	
	for x in range(-half_size.x, half_size.x + 1):
		for y in range(-half_size.y, half_size.y + 1):
			var check_pos = center_pos + Vector2(x, y)
			if is_valid_grid_position(check_pos):
				var unit = get_unit_at_position(check_pos)
				if unit and not unit.is_in_group("player"):  # Exclude player from AOE
					units.append(unit)
	
	return units 
