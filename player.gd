extends Area2D

@onready var anim = $AnimatedSprite2D
@export var movement_range = 3

# Combat stats
@export var strength = 8
@export var speed = 7
@export var defense = 5
@export var resistance = 3
@export var skill = 6
@export var luck = 4
@export var max_health = 20
@export var max_action_points = 6
var current_health
var current_action_points

# Mode
var current_mode = "move"  # Can be "move", "attack", "load_string", or "hack"
var is_interacting_with_ui = false
var current_hack_type = ""  # Store the current hack type when in hack mode

# Weapons
var weapons = {
	"baton": {
		"name": "Baton",
		"type": "melee",
		"loaded_string": "",
		"constraints": {
			"max_length": 3,
			"allowed_chars": ["1", "2", "3"],
			"pattern": "any"
		},
		"range": 1,
		"color": Color(1, 0, 0, 0.3),  # Transparent red
		"ap_cost": 1,
		"attack_type": "single"
	},
	"bow": {
		"name": "Bow",
		"type": "ranged",
		"loaded_string": "",
		"constraints": {
			"max_length": 3,
			"allowed_chars": ["1", "2", "3"],
			"pattern": "any"
		},
		"range": 6,
		"color": Color(1, 0, 0, 0.3),
		"ap_cost": 3,
		"attack_type": "line",
		"diagonal_allowed": false
	},
	"shotgun": {
		"name": "Shotgun",
		"type": "aoe",
		"loaded_string": "",
		"constraints": {
			"max_length": 3,
			"allowed_chars": ["1", "2", "3"],
			"pattern": "any"
		},
		"range": 1,
		"color": Color(1, 0, 0, 0.3),
		"ap_cost": 2,
		"attack_type": "aoe",
		"aoe_size": Vector2(0, 3),
		"diagonal_allowed": false
	},
	"sniper": {
		"name": "Sniper",
		"type": "piercing",
		"loaded_string": "",
		"constraints": {
			"max_length": 5,
			"allowed_chars": ["1", "2", "3"],
			"pattern": "any"
		},
		"range": -1,  # -1 indicates unlimited range
		"color": Color(1, 0, 0, 0.3),
		"ap_cost": 6,
		"attack_type": "piercing",
		"diagonal_allowed": false
	},
	"emp_grenade": {
		"name": "EMP Grenade",
		"type": "aoe",
		"loaded_string": "",
		"constraints": {
			"max_length": 2,
			"allowed_chars": ["1", "2", "3"],
			"pattern": "any"
		},
		"range": 5,
		"color": Color(1, 0, 0, 0.3),
		"ap_cost": 4,
		"attack_type": "aoe",
		"aoe_size": Vector2(3, 3),  # Increased AOE size
		"diagonal_allowed": true,  # Allow diagonal attacks
		"can_target_empty": true  # Allow targeting empty tiles
	}
}
var current_weapon = "baton"  # Changed default weapon to baton
var weapon_type = "energy"

var grid_manager
var grid_position = Vector2.ZERO
var has_moved = false
var has_attacked = false
var target_position = Vector2.ZERO
var previous_grid_position = Vector2.ZERO
var is_moving = false
var move_speed = 4.0  # Grid cells per second
var move_path = []

# Hack system
var hack_costs = {
	"stun": 5,
	"confuse": 2,
	"overwrite": 4
}

func _ready():
	add_to_group("player")
	grid_manager = get_node("/root/main/GridManager")
	grid_position = grid_manager.world_to_grid(position)
	# Snap to grid center on initialization
	position = grid_manager.grid_to_world(grid_position)
	current_health = max_health
	current_action_points = max_action_points
	
	# Connect to the battle UI
	var battle_ui = get_node("/root/main/CanvasLayer/BattleUI")
	if battle_ui:
		battle_ui.set_player(self)

func load_string_to_weapon(weapon_id: String, new_string: String) -> bool:
	if not weapons.has(weapon_id):
		return false
	
	var weapon = weapons[weapon_id]
	var constraints = weapon.constraints
	
	# Check string length
	if new_string.length() > constraints.max_length:
		return false
	
	# Check allowed characters
	for character in new_string:
		if not constraints.allowed_chars.has(character):
			return false
	
	# Check pattern if specified
	if constraints.pattern != "any":
		# Add pattern validation here if needed
		pass
	
	weapon.loaded_string = new_string
	return true

func _process(delta):
	if is_moving and move_path.size() > 0:
		var next_grid = move_path[0]
		var target_world_pos = grid_manager.grid_to_world(next_grid)
		position = position.move_toward(target_world_pos, move_speed * grid_manager.GRID_SIZE * delta)
		if position.distance_to(target_world_pos) < 1:
			# Ensure exact grid center position when movement completes
			position = target_world_pos
			grid_position = next_grid
			move_path.pop_front()
			if move_path.size() > 0:
				play_move_animation()
			else:
				is_moving = false
				grid_manager.update_occupied_tiles()
				update_movement_range()  # Update movement range after moving
	elif is_moving:
		# Fallback for non-path movement (shouldn't happen)
		is_moving = false
		# Ensure position is snapped to grid
		position = grid_manager.grid_to_world(grid_position)
		grid_manager.update_occupied_tiles()
		update_movement_range()

func _input(event):
	if grid_manager.current_turn != "player" or is_interacting_with_ui:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var target_grid_pos = grid_manager.world_to_grid(mouse_pos)
		
		# Handle unit selection (only if not in attack or hack mode)
		if current_mode != "attack" and current_mode != "hack" and grid_manager.world_to_grid(position).distance_to(target_grid_pos) < 1:
			if grid_manager.selected_unit == self:
				grid_manager.selected_unit = null
				grid_manager.valid_moves = []
				grid_manager.valid_attacks = []
			else:
				grid_manager.selected_unit = self
				if current_action_points > 0:
					current_mode = "move"
					update_movement_range()
			return
		
		# Handle hacks
		if current_mode == "hack":
			var target_unit = grid_manager.get_unit_at_position(target_grid_pos)
			if target_unit and target_unit.is_in_group("enemy"):
				var cost = hack_costs[current_hack_type]
				if current_action_points >= cost:
					hack_enemy(target_unit, current_hack_type)
					current_action_points -= cost
					update_ui()
					current_mode = "move"
					update_movement_range()
					if current_action_points <= 0:
						end_turn()
			return
		
		# Handle attacks first (allow even if not previously selected)
		if current_mode == "attack" and target_grid_pos in grid_manager.valid_attacks:
			var weapon = weapons[current_weapon]
			var ap_cost = get_attack_ap_cost()
			if current_action_points >= ap_cost:
				# For EMP grenade, we can target empty tiles
				if weapon.get("can_target_empty", false):
					attack(target_grid_pos)
					current_action_points -= ap_cost
					update_ui()
					current_mode = "move"
					update_movement_range()
					if current_action_points <= 0:
						end_turn()
				else:
					# For other weapons, require a target unit
					var target_unit = grid_manager.get_unit_at_position(target_grid_pos)
					if target_unit:
						attack(target_unit)
						current_action_points -= ap_cost
						update_ui()
						current_mode = "move"
						update_movement_range()
						if current_action_points <= 0:
							end_turn()
			return
		
		# Only handle movement if we're selected and in move mode
		if grid_manager.selected_unit == self and current_mode == "move":
			# Check if target position is walkable and not occupied
			if not grid_manager._is_walkable(target_grid_pos) or is_position_occupied(target_grid_pos):
				return
				
			previous_grid_position = grid_position
			# Build move_path using A* pathfinding to avoid non-walkable tiles
			move_path.clear()
			var path = find_path_to_target(target_grid_pos)
			if path.size() > 0:
				# Calculate movement cost based on actual path length
				var movement_cost = path.size() - 1  # Subtract 1 because path includes start position
				if movement_cost <= current_action_points:
					move_path = path
					is_moving = true
					grid_manager.valid_moves = []
					current_action_points -= movement_cost
					update_ui()
					play_move_animation() # Play the first animation immediately
					# Animation for subsequent steps is handled in _process

func find_path_to_target(target_pos: Vector2) -> Array:
	var open_set = []
	var closed_set = {}
	var came_from = {}
	var g_score = {}
	var f_score = {}
	
	# Initialize start node
	open_set.append(grid_position)
	g_score[grid_position] = 0
	f_score[grid_position] = heuristic(grid_position, target_pos)
	
	while open_set.size() > 0:
		# Find node with lowest f_score
		var current = open_set[0]
		var current_index = 0
		for i in range(open_set.size()):
			if f_score[open_set[i]] < f_score[current]:
				current = open_set[i]
				current_index = i
		
		# Remove current from open set and add to closed set
		open_set.remove_at(current_index)
		closed_set[current] = true
		
		# If we reached the target, reconstruct and return the path
		if current == target_pos:
			return reconstruct_path(came_from, current)
		
		# Check all neighbors
		for dir in [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]:
			var neighbor = current + dir
			
			# Skip if neighbor is not walkable, is occupied by an enemy, or in closed set
			if not grid_manager._is_walkable(neighbor) or is_position_occupied(neighbor) or closed_set.has(neighbor):
				continue
			
			var tentative_g_score = g_score[current] + 1
			
			# If neighbor is not in open set, add it
			if not open_set.has(neighbor):
				open_set.append(neighbor)
			# If this path to neighbor is worse than previous, skip
			elif tentative_g_score >= g_score.get(neighbor, INF):
				continue
			
			# This path is the best so far, record it
			came_from[neighbor] = current
			g_score[neighbor] = tentative_g_score
			f_score[neighbor] = g_score[neighbor] + heuristic(neighbor, target_pos)
	
	# If we get here, no path was found
	return []

func heuristic(a: Vector2, b: Vector2) -> float:
	# Manhattan distance
	return abs(a.x - b.x) + abs(a.y - b.y)

func reconstruct_path(came_from: Dictionary, current: Vector2) -> Array:
	var path = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path

func update_ui():
	var battle_ui = get_node("/root/main/CanvasLayer/BattleUI")
	if battle_ui:
		battle_ui.update_ui()

func update_movement_range():
	# Use current_action_points as the movement range
	var all_moves = grid_manager.calculate_movement_range(grid_position, current_action_points)
	
	# Filter moves based on available AP and path validity
	var valid_moves = []
	for move in all_moves:
		# Skip if position is occupied
		if is_position_occupied(move):
			continue
			
		# Find path to this position
		var path = find_path_to_target(move)
		if path.size() > 0:
			# Calculate movement cost based on actual path length
			var movement_cost = path.size() - 1  # Subtract 1 because path includes start position
			if movement_cost <= current_action_points:
				valid_moves.append(move)
	
	grid_manager.valid_moves = valid_moves
	grid_manager.valid_attacks = []
	print("Updated valid moves: ", grid_manager.valid_moves.size())

func update_attack_range():
	grid_manager.valid_moves = []
	
	if current_mode == "hack":
		# For hacking, show all enemies in the room
		var main = get_node("/root/main")
		var enemies = main.enemies.get_children()
		grid_manager.valid_attacks = []
		for enemy in enemies:
			if is_instance_valid(enemy):
				grid_manager.valid_attacks.append(enemy.grid_position)
		grid_manager.attack_color = Color(0, 1, 0, 0.3)  # Green for hack range
		return
		
	var weapon = weapons[current_weapon]
	var valid_attacks = []
	
	match weapon.attack_type:
		"single":
			var range_attacks = grid_manager.update_attack_range(grid_position, weapon.range)
			# Filter for line of sight
			for pos in range_attacks:
				if has_line_of_sight_to(pos):
					valid_attacks.append(pos)
		"line":
			var line_attacks = grid_manager.update_line_attack_range(grid_position, weapon.range, weapon.diagonal_allowed)
			# Filter for line of sight
			for pos in line_attacks:
				if has_line_of_sight_to(pos):
					valid_attacks.append(pos)
		"aoe":
			if current_weapon == "shotgun":
				# For shotgun, we need to check all four directions
				var directions = [
					Vector2(1, 0),  # Right
					Vector2(-1, 0), # Left
					Vector2(0, 1),  # Down
					Vector2(0, -1)  # Up
				]
				
				for dir in directions:
					var aoe_size = Vector2(3, 0) if abs(dir.x) > 0 else Vector2(0, 3)
					if dir.y < 0:  # If shooting up, invert the y component
						aoe_size.y = -3
					
					var aoe_attacks = grid_manager.update_aoe_attack_range(grid_position, weapon.range, aoe_size, weapon.diagonal_allowed)
					# Filter for line of sight
					for pos in aoe_attacks:
						if has_line_of_sight_to(pos):
							valid_attacks.append(pos)
			else:
				# For other AOE weapons (like EMP grenade)
				var aoe_attacks = grid_manager.update_aoe_attack_range(grid_position, weapon.range, weapon.aoe_size, weapon.diagonal_allowed)
				# Filter for line of sight
				for pos in aoe_attacks:
					if has_line_of_sight_to(pos):
						valid_attacks.append(pos)
		"piercing":
			var piercing_attacks = grid_manager.update_piercing_attack_range(grid_position, weapon.diagonal_allowed)
			# Filter for line of sight
			for pos in piercing_attacks:
				if has_line_of_sight_to(pos):
					valid_attacks.append(pos)
	
	grid_manager.valid_attacks = valid_attacks
	grid_manager.attack_color = weapon.color
	print("Updated valid attacks: ", grid_manager.valid_attacks.size())

func has_line_of_sight_to(target_pos: Vector2) -> bool:
	var current = grid_position
	var target = target_pos
	
	# Get the direction vector
	var dir = (target - current).normalized()
	
	# Check each tile along the line
	while current != target:
		# Move to next tile
		if abs(dir.x) > abs(dir.y):
			current.x += sign(dir.x)
		else:
			current.y += sign(dir.y)
		
		# If we hit the target, we have line of sight
		if current == target:
			return true
		
		# Check if next tile is unwalkable
		var next_tile = current + dir
		if not grid_manager._is_walkable(next_tile):
			return false
		
		# If current tile is unwalkable, no line of sight
		if not grid_manager._is_walkable(current):
			return false
	
	return true

func attack(target):
	var weapon = weapons[current_weapon]
	if weapon.loaded_string == "":
		print("No string loaded in ", weapon.name)
		return
	
	# Handle both unit targets and position targets
	var target_pos = target.grid_position if target is Node2D else target
	
	match weapon.attack_type:
		"single":
			if target is Node2D:
				target.take_damage(weapon.loaded_string)
		"line":
			# Attack all units in a line
			var line_targets = grid_manager.get_units_in_line(grid_position, target_pos)
			for line_target in line_targets:
				line_target.take_damage(weapon.loaded_string)
		"aoe":
			# For shotgun, calculate direction and rotate AOE accordingly
			if current_weapon == "shotgun":
				var direction = (target_pos - grid_position).normalized()
				var rotated_aoe_size = Vector2(0, 3)
				
				# Determine the direction and rotate AOE accordingly
				if abs(direction.x) > abs(direction.y):
					# Horizontal shot
					rotated_aoe_size = Vector2(3, 0)
				elif direction.y < 0:
					# Shooting up
					rotated_aoe_size = Vector2(0, -3)
				else:
					# Shooting down (default)
					rotated_aoe_size = Vector2(0, 3)
				
				# Attack all units in AOE
				var aoe_targets = grid_manager.get_units_in_aoe(target_pos, rotated_aoe_size)
				for aoe_target in aoe_targets:
					aoe_target.take_damage(weapon.loaded_string)
			else:
				# For other AOE weapons (like EMP grenade)
				var aoe_targets = grid_manager.get_units_in_aoe(target_pos, weapon.aoe_size)
				for aoe_target in aoe_targets:
					aoe_target.take_damage(weapon.loaded_string)
		"piercing":
			# Attack all units in line of sight
			var piercing_targets = grid_manager.get_units_in_line(grid_position, target_pos)
			for piercing_target in piercing_targets:
				piercing_target.take_damage(weapon.loaded_string)
	
	print("Attacked with ", weapon.name, " using string: ", weapon.loaded_string)
	# Clear the loaded string after use
	weapon.loaded_string = ""
	update_ui()

func take_damage(amount):
	current_health -= amount
	update_ui()
	if current_health <= 0:
		queue_free()

func end_turn():
	has_attacked = true
	grid_manager.selected_unit = null
	grid_manager.valid_moves = []
	grid_manager.valid_attacks = []
	get_node("/root/main").end_player_turn()

func reset_turn():
	has_attacked = false
	is_moving = false
	current_action_points = max_action_points
	current_mode = "move"
	# Don't auto-select the unit
	grid_manager.selected_unit = null
	grid_manager.valid_moves = []
	grid_manager.valid_attacks = []
	update_ui()

# Add a helper to get AP cost for attack
func get_attack_ap_cost():
	var weapon = weapons[current_weapon]
	return weapon.ap_cost

# When a weapon is selected, enter attack mode
func set_weapon_and_attack_mode(weapon_id):
	current_weapon = weapon_id
	weapon_type = weapons[weapon_id].type
	current_mode = "attack"
	update_attack_range()
	update_ui()
	# Always select this player for attack mode
	if grid_manager:
		grid_manager.selected_unit = self

func play_move_animation():
	if move_path.size() == 0:
		return
	var direction = move_path[0] - grid_position
	if direction.x > 0:
		anim.play("walk_right")
	elif direction.x < 0:
		anim.play("walk_left")
	elif direction.y > 0:
		anim.play("walk_down")
	elif direction.y < 0:
		anim.play("walk_up")

func hack_enemy(target_enemy, hack_type: String):
	if not hack_costs.has(hack_type):
		print("Invalid hack type")
		return
	var cost = hack_costs[hack_type]
	if current_action_points < cost:
		print("Not enough AP to hack.")
		return
	
	if is_instance_valid(target_enemy):
		match hack_type:
			"stun": target_enemy.apply_stun()
			"confuse": target_enemy.apply_confuse()
			"overwrite": target_enemy.apply_overwrite()
		print("Hacked enemy with ", hack_type)
		update_ui()

func enter_hack_mode(hack_type: String):
	current_hack_type = hack_type
	current_mode = "hack"
	update_attack_range()
	update_ui()
	# Always select this player for hack mode
	if grid_manager:
		grid_manager.selected_unit = self

func is_position_occupied(pos: Vector2) -> bool:
	# Check if position is occupied by any enemy
	var main = get_node("/root/main")
	for enemy in main.enemies.get_children():
		if enemy.grid_position == pos:
			return true
	return false
