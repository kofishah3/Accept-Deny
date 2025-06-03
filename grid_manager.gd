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
var aoe_impact_tiles = []
var aoe_impact_timer = 0.0
const AOE_IMPACT_DURATION = 0.5  # Duration of the impact effect in seconds
var hovered_tile = null  # Track the currently hovered tile
var hover_aoe_tiles = []  # Store the AOE tiles for the hovered position

func _ready():
	# Initialize the grid
	update_occupied_tiles()

func _input(event):
	if event is InputEventMouseMotion:
		var mouse_pos = get_global_mouse_position()
		var new_hovered_tile = world_to_grid(mouse_pos)
		if new_hovered_tile != hovered_tile:
			hovered_tile = new_hovered_tile
			# Update hover AOE tiles if we're in attack mode and the tile is valid
			if selected_unit and selected_unit.current_mode == "attack":
				update_hover_aoe_tiles()
			queue_redraw()

func _draw():
	# Draw grid lines
	for x in range(grid_width + 1):
		draw_line(Vector2(x * GRID_SIZE, 0), Vector2(x * GRID_SIZE, grid_height * GRID_SIZE), Color.TRANSPARENT, 1.0)
	for y in range(grid_height + 1):
		draw_line(Vector2(0, y * GRID_SIZE), Vector2(grid_width * GRID_SIZE, y * GRID_SIZE), Color.TRANSPARENT, 1.0)
	
	# Draw valid moves
	for move in valid_moves:
		var rect = Rect2(move * GRID_SIZE, Vector2(GRID_SIZE, GRID_SIZE))
		draw_rect(rect, Color(0, 1, 0, 0.3))  # Semi-transparent green
	
	# Draw valid attacks
	for attack in valid_attacks:
		var rect = Rect2(attack * GRID_SIZE, Vector2(GRID_SIZE, GRID_SIZE))
		draw_rect(rect, attack_color)  # Use consistent semi-transparent red
	
	# Draw hover AOE preview
	for tile in hover_aoe_tiles:
		var rect = Rect2(tile * GRID_SIZE, Vector2(GRID_SIZE, GRID_SIZE))
		draw_rect(rect, Color(1, 0, 0, 0.2))  # Lighter red for hover preview
	
	# Draw AOE impact effect
	for tile in aoe_impact_tiles:
		var rect = Rect2(tile * GRID_SIZE, Vector2(GRID_SIZE, GRID_SIZE))
		# Use a brighter red for the impact effect
		var impact_color = Color(1, 0, 0, 0.6)
		draw_rect(rect, impact_color)
	
	# Draw disabled (unwalkable) tiles
	for tile in disabled_tiles.keys():
		var rect = Rect2(tile * GRID_SIZE, Vector2(GRID_SIZE, GRID_SIZE))
		draw_rect(rect, Color(1, 0, 0, 0.0))  # Semi-transparent red -- set to 0.0 for transparent

func _process(delta):
	queue_redraw()  # Redraw every frame to update highlights
	
	# Update AOE impact effect
	if aoe_impact_tiles.size() > 0:
		aoe_impact_timer -= delta
		if aoe_impact_timer <= 0:
			aoe_impact_tiles.clear()

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
		grid_pos.x * GRID_SIZE + 8.0,  # Half of 16 (GRID_SIZE) to center on 1x1 tile
		grid_pos.y * GRID_SIZE + 8.0   # Half of 16 (GRID_SIZE) to center on 1x1 tile
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
		
		# Add position to valid moves if it's not the starting position
		if cost > 0:
			valid_positions.append(pos)
			move_ap_costs[pos] = cost
		
		# Stop if we've reached max AP
		if cost >= max_ap:
			continue
		
		# Check all adjacent tiles
		for dir in [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]:
			var next = pos + dir
			
			# Skip if not walkable or already visited
			if not _is_walkable(next) or visited.has(next):
				continue
			
			# Calculate cost to move to this tile
			var next_cost = cost + 1
			
			# Add to queue if within AP range
			if next_cost <= max_ap:
				visited[next] = true
				queue.append({"pos": next, "cost": next_cost})
	
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
						# Only add if the tile is walkable
						if _is_walkable(new_pos):
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
				# Only add if the tile is walkable
				if _is_walkable(new_pos):
					valid_positions.append(new_pos)
				else:
					break  # Stop checking in this direction if we hit an unwalkable tile
			else:
				break  # Stop checking in this direction if we hit a wall
	return valid_positions

func update_aoe_attack_range(unit_pos: Vector2, attack_range: int, aoe_size: Vector2, diagonal_allowed: bool) -> Array:
	var valid_positions = []
	var player = get_node("/root/main/Player")
	var player_pos = player.grid_position if player else null
	
	# Calculate all possible positions within range
	for x in range(-attack_range, attack_range + 1):
		for y in range(-attack_range, attack_range + 1):
			var new_pos = unit_pos + Vector2(x, y)
			
			# Skip if not a valid grid position
			if not is_valid_grid_position(new_pos):
				continue
				
			# Skip if it's the unit's own position
			if new_pos == unit_pos:
				continue
				
			# Skip if it's the player's position
			if new_pos == player_pos:
				continue
				
			# Skip if not walkable
			if not _is_walkable(new_pos):
				continue
			
			# For diagonal movement, use max distance
			if diagonal_allowed:
				if max(abs(x), abs(y)) <= attack_range:
					valid_positions.append(new_pos)
			# For non-diagonal movement, use Manhattan distance
			else:
				if abs(x) + abs(y) <= attack_range:
					valid_positions.append(new_pos)
	
	# Calculate AOE tiles for visualization
	var aoe_tiles = []
	for target_pos in valid_positions:
		var half_size = aoe_size / 2
		for x in range(-half_size.x, half_size.x + 1):
			for y in range(-half_size.y, half_size.y + 1):
				var aoe_pos = target_pos + Vector2(x, y)
				# Only add AOE tiles that are valid grid positions and walkable
				if is_valid_grid_position(aoe_pos) and _is_walkable(aoe_pos) and not aoe_tiles.has(aoe_pos):
					aoe_tiles.append(aoe_pos)
	
	# Update the attack color to show AOE outline
	attack_color = Color(1, 0, 0, 0.3)  # Red tint for AOE
	
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
			# Only add positions that are walkable
			if _is_walkable(current_pos):
				valid_positions.append(current_pos)
			else:
				break  # Stop checking in this direction if we hit an unwalkable tile
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

func show_aoe_impact(center_pos: Vector2, aoe_size: Vector2):
	aoe_impact_tiles.clear()
	var half_size = aoe_size / 2
	
	# Calculate the AOE area
	for x in range(-half_size.x, half_size.x + 1):
		for y in range(-half_size.y, half_size.y + 1):
			var check_pos = center_pos + Vector2(x, y)
			# Only show impact on valid grid positions and walkable tiles
			if is_valid_grid_position(check_pos) and _is_walkable(check_pos):
				aoe_impact_tiles.append(check_pos)
	
	# Start the impact effect timer
	aoe_impact_timer = AOE_IMPACT_DURATION

func get_units_in_aoe(center_pos: Vector2, aoe_size: Vector2) -> Array:
	var units = []
	var half_size = aoe_size / 2
	
	# Calculate the AOE area
	for x in range(-half_size.x, half_size.x + 1):
		for y in range(-half_size.y, half_size.y + 1):
			var check_pos = center_pos + Vector2(x, y)
			# Only check valid grid positions and walkable tiles
			if is_valid_grid_position(check_pos) and _is_walkable(check_pos):
				var unit = get_unit_at_position(check_pos)
				if unit and not unit.is_in_group("player"):  # Exclude player from AOE
					units.append(unit)
	
	# Show the AOE impact effect
	show_aoe_impact(center_pos, aoe_size)
	
	return units

func update_hover_aoe_tiles():
	hover_aoe_tiles.clear()
	if not hovered_tile or not selected_unit or selected_unit.current_mode != "attack":
		return
		
	var weapon = selected_unit.weapons[selected_unit.current_weapon]
	if weapon.attack_type != "aoe":
		return
		
	# Only show preview if the hovered tile is a valid attack position
	if not valid_attacks.has(hovered_tile):
		return
		
	var half_size = weapon.aoe_size / 2
	for x in range(-half_size.x, half_size.x + 1):
		for y in range(-half_size.y, half_size.y + 1):
			var aoe_pos = hovered_tile + Vector2(x, y)
			# Only show AOE preview on valid grid positions and walkable tiles
			if is_valid_grid_position(aoe_pos) and _is_walkable(aoe_pos):
				hover_aoe_tiles.append(aoe_pos)
