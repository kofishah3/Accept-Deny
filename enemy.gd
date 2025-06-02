extends Area2D

@onready var anim = $AnimatedSprite2D
@export var movement_range = 3

# Combat stats
@export var strength = 6
@export var speed = 5
@export var defense = 4
@export var resistance = 2
@export var skill = 4
@export var luck = 3
@export var string_length = 5  # Length of the enemy's string
@export var max_action_points = 6
@export var enemy_ui_offset := Vector2(10, -100)
var current_string = ""
var current_action_points

# Mode
var current_mode = "move"  # Can be "move" or "attack"
var is_interacting_with_ui = false
var is_baton_target = false  # New variable to track if enemy is being targeted by baton

var previous_grid_position = Vector2.ZERO
var move_path = []

# Weapons
var weapons = {
	"melee": {
		"name": "Melee Attack",
		"type": "physical",
		"might": 5,
		"hit": 90,
		"crit": 5,
		"range": 1,
		"color": Color(1, 0, 0, 0.3)  # Transparent red
	},
	"ranged": {
		"name": "Ranged Attack",
		"type": "energy",
		"might": 4,
		"hit": 80,
		"crit": 10,
		"range": 2,
		"color": Color(1, 0, 0, 0.3)  # Transparent red
	}
}
var current_weapon = "melee"
var weapon_type = "physical"

var grid_manager
var grid_position = Vector2.ZERO
var has_moved = false
var has_attacked = false
var target_position = Vector2.ZERO
var is_moving = false
var move_speed = 4.0  # Grid cells per second

# UI elements
var enemy_ui_scene = preload("res://ui/enemy_ui.tscn")
var enemy_ui_instance
var string_label
var action_points_bar
var action_points_label

# Hack effect state
var is_stunned = false
var is_confused = false
var is_overwrite = false

# Activation radius
const ACTIVATION_RADIUS = 8  # Manhattan distance for activation

func _ready():
	add_to_group("enemy")
	grid_manager = get_node("../../GridManager")
	grid_position = grid_manager.world_to_grid(position)
	position = grid_manager.grid_to_world(grid_position)
	
	# Ensure string_length has a valid value
	if string_length == null or string_length <= 0:
		string_length = 5  # Default value
	
	# Ensure max_action_points has a valid value
	if max_action_points == null or max_action_points <= 0:
		max_action_points = 4  # Default value
	
	generate_new_string()
	current_action_points = max_action_points
	
	# Create UI instance for this enemy
	create_enemy_ui()
	
	update_enemy_ui()
	
	# Connect input event
	input_pickable = true
	connect("input_event", Callable(self, "_on_input_event"))

func create_enemy_ui():
	# Create new UI instance
	enemy_ui_instance = enemy_ui_scene.instantiate()
	
	# Add to canvas layer
	var canvas_layer = get_node("/root/main/CanvasLayer")
	if canvas_layer:
		canvas_layer.add_child(enemy_ui_instance)
		
		# Get UI elements
		string_label = enemy_ui_instance.get_node("StringLabel")
		action_points_bar = enemy_ui_instance.get_node("ActionPointsBar")
		action_points_label = enemy_ui_instance.get_node("ActionPointsLabel")
		
		print("Created new enemy UI instance")
		print("StringLabel found: ", string_label != null)
		print("ActionPointsBar found: ", action_points_bar != null)
		print("ActionPointsLabel found: ", action_points_label != null)

func generate_new_string():
	var chars = ["a", "b", "c"]
	current_string = ""
	for i in range(string_length):
		current_string += chars[randi() % chars.size()]

func update_enemy_ui():
	if string_label:
		string_label.text = "String: " + current_string
	
	if action_points_bar:
		action_points_bar.max_value = max_action_points
		action_points_bar.value = current_action_points
	
	if action_points_label:
		action_points_label.text = "AP: " + str(current_action_points) + "/" + str(max_action_points)
	
	# Update UI position relative to enemy
	update_enemy_ui_position()

func update_enemy_ui_position():
	if enemy_ui_instance and get_viewport():
		var screen_pos = get_global_transform_with_canvas().origin
		# Apply offset and set the UI position
		enemy_ui_instance.position = screen_pos + enemy_ui_offset

func _process(delta):
	if is_moving and move_path.size() > 0:
		var next_grid = move_path[0]
		var target_world_pos = grid_manager.grid_to_world(next_grid)
		position = position.move_toward(target_world_pos, move_speed * grid_manager.GRID_SIZE * delta)
		if position.distance_to(target_world_pos) < 1:
			position = target_world_pos
			grid_position = next_grid
			move_path.pop_front()
			if move_path.size() > 0:
				play_move_animation()
			else:
				is_moving = false
				has_moved = true
				grid_manager.update_occupied_tiles()
				update_enemy_ui()  # Update UI after movement is complete
				check_and_attack()
	elif is_moving:
		# Fallback for non-path movement (shouldn't happen)
		is_moving = false
		grid_manager.update_occupied_tiles()
		update_enemy_ui()  # Update UI after movement is complete
	# Update enemy UI position to follow enemy
	update_enemy_ui_position()

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

func is_player_in_range() -> bool:
	var player = get_node("/root/main/Player")
	if not player or not is_instance_valid(player):
		return false
		
	# Calculate Manhattan distance to player
	var distance = int(abs(grid_position.x - player.grid_position.x) + abs(grid_position.y - player.grid_position.y))
	return distance <= ACTIVATION_RADIUS

func take_turn():
	print("Enemy taking turn")
	
	# Check if player is in range before taking any action
	if not is_player_in_range():
		print("Player not in range, skipping turn")
		return
		
	if is_stunned:
		print("Enemy is stunned and skips turn.")
		is_stunned = false
		return
	if is_overwrite:
		print("Enemy is overwriting its string with another enemy's string.")
		is_overwrite = false
		_overwrite_string_with_another_enemy()
	if current_action_points <= 0:
		return
	if is_confused:
		print("Enemy is confused and moves randomly.")
		is_confused = false
		var valid_moves = grid_manager.calculate_movement_range(grid_position, current_action_points)
		# Filter out occupied positions
		valid_moves = valid_moves.filter(func(pos): return not is_position_occupied(pos))
		if valid_moves.size() > 0:
			var random_move = valid_moves[randi() % valid_moves.size()]
			move_path.clear()
			var path = find_path_to_target(random_move)
			if path.size() > 0:
				var movement_cost = path.size() - 1  # Subtract 1 because path includes start position
				if movement_cost <= current_action_points:
					move_path = path
					move_path.pop_front()  # Remove starting position from path
					is_moving = true
					current_action_points -= movement_cost
					update_enemy_ui()  # Update UI after AP change
					play_move_animation()
		return
	
	var player = get_node("/root/main/Player")
	if not player or not is_instance_valid(player):
		return
	
	# Calculate if we can attack and still have enough AP to move
	var attack_cost = get_attack_ap_cost()
	var can_attack_and_move = current_action_points >= (attack_cost + 1)  # Need at least 1 AP to move
	
	# Try to attack first if in range and we have enough AP
	if current_action_points >= attack_cost:
		var attack_range = weapons[current_weapon].range
		var distance = int(abs(grid_position.x - player.grid_position.x) + abs(grid_position.y - player.grid_position.y))
		if distance <= attack_range:
			attack(player)
			current_action_points -= attack_cost
			update_enemy_ui()  # Update UI after AP change
	
	# If we haven't moved and have enough AP, try to move towards the player
	if not has_moved and current_action_points >= 1:
		# Get all valid moves within our AP range
		var valid_moves = grid_manager.calculate_movement_range(grid_position, current_action_points)
		# Filter out occupied positions
		valid_moves = valid_moves.filter(func(pos): return not is_position_occupied(pos))
		
		# Find the best move that gets us closest to the player
		var best_move = find_best_move_towards_player(valid_moves, player.grid_position)
		
		if best_move:
			print("Enemy moving to: ", best_move)
			# Use proper A* pathfinding to respect walls
			move_path.clear()
			var path = find_path_to_target(best_move)
			if path.size() > 0:
				# Calculate movement cost based on actual path length
				var movement_cost = path.size() - 1  # Subtract 1 because path includes start position
				if movement_cost <= current_action_points:
					move_path = path
					move_path.pop_front()  # Remove starting position from path
					is_moving = true
					current_action_points -= movement_cost
					update_enemy_ui()  # Update UI after AP change
					play_move_animation()
				else:
					# If we can't afford the full movement, move as far as we can
					var affordable_path = []
					var remaining_ap = current_action_points
					
					for i in range(1, path.size()):  # Start from 1 to skip starting position
						if remaining_ap > 0:
							affordable_path.append(path[i])
							remaining_ap -= 1
						else:
							break
					
					if affordable_path.size() > 0:
						move_path = affordable_path
						current_action_points -= affordable_path.size()
						update_enemy_ui()  # Update UI after AP change
						is_moving = true
						play_move_animation()
					else:
						has_moved = true
						check_and_attack()
			else:
				# No valid path found
				has_moved = true
				check_and_attack()
		else:
			has_moved = true
			check_and_attack()

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
			
			# Skip if neighbor is not walkable, is occupied, or in closed set
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

func check_and_attack():
	var player = get_node("/root/main/Player")
	if not player or not is_instance_valid(player):
		return
		
	# Check if player is in attack range
	var attack_range = weapons[current_weapon].range
	var distance = int(abs(grid_position.x - player.grid_position.x) + abs(grid_position.y - player.grid_position.y))
	if distance <= attack_range:
		var weapon = weapons[current_weapon]
		var ap_cost = ceil(weapon.might / 2)  # AP cost is half the weapon's might, rounded up
		if current_action_points >= ap_cost:
			print("Enemy attacking player")
			attack(player)
			current_action_points -= ap_cost
			update_enemy_ui()

func attack(target):
	var weapon = weapons[current_weapon]
	var hit_chance = calculate_hit_chance(target, weapon)
	var crit_chance = calculate_crit_chance(target, weapon)
	var damage = calculate_damage(target, weapon)
	
	# Always hit (remove hit chance check)
	# Roll for crit
	if randf() * 100 <= crit_chance:
		damage *= 3
		print("Critical hit with ", weapon.name, "!")
	
	target.take_damage(damage)
	print("Hit for ", damage, " damage with ", weapon.name, "!")

func calculate_hit_chance(target, weapon):
	var base_hit = weapon.hit + (skill * 2) + (luck / 2)
	var avoid = target.speed * 2 + target.luck
	return clamp(base_hit - avoid, 0, 100)

func calculate_crit_chance(target, weapon):
	var base_crit = weapon.crit + (skill / 2)
	var crit_avoid = target.luck
	return clamp(base_crit - crit_avoid, 0, 100)

func calculate_damage(target, weapon):
	var attack = strength + weapon.might
	var defense = target.defense if weapon.type != "energy" else target.resistance
	
	# Apply weapon type effectiveness
	var effectiveness = 1.0
	match [weapon.type, target.weapon_type]:
		["energy", "plasma"]: effectiveness = 1.5
		["plasma", "ion"]: effectiveness = 1.5
		["ion", "energy"]: effectiveness = 1.5
		["energy", "ion"]: effectiveness = 0.75
		["ion", "plasma"]: effectiveness = 0.75
		["plasma", "energy"]: effectiveness = 0.75
	
	return max(1, (attack - defense) * effectiveness)

func take_damage(attack_string):
	# For each character in the attack string, try to match and remove from current string
	var new_string = current_string
	var i = 0
	while i < attack_string.length() and new_string.length() > 0:
		var char_pos = new_string.find(attack_string[i])
		if char_pos != -1:
			# Remove the matched character
			new_string = new_string.substr(0, char_pos) + new_string.substr(char_pos + 1)
		i += 1
	
	current_string = new_string
	update_enemy_ui()
	
	if current_string.length() == 0:
		queue_free()

func reset_turn():
	has_moved = false
	has_attacked = false
	is_moving = false
	current_action_points = max_action_points
	update_enemy_ui()  # Update UI after resetting AP

# Hack effect methods
func apply_stun():
	is_stunned = true

func apply_confuse():
	is_confused = true

func apply_overwrite():
	is_overwrite = true

# Helper for overwrite effect
func _overwrite_string_with_another_enemy():
	var main = get_node("/root/main")
	var enemies = main.enemies.get_children()
	var other_enemies = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy != self:
			other_enemies.append(enemy)
	if other_enemies.size() > 0:
		var chosen = other_enemies[randi() % other_enemies.size()]
		current_string = chosen.current_string
		print("Enemy string overwritten with: ", current_string)
		update_enemy_ui()

# Helper to find best move away from player
func find_best_move_away_from_player(valid_moves, player_pos):
	var best_move = null
	var longest_distance = -INF
	for move in valid_moves:
		var distance = int(abs(move.x - player_pos.x) + abs(move.y - player_pos.y))
		if distance > longest_distance:
			longest_distance = distance
			best_move = move
	return best_move

# Helper to find best move towards player
func find_best_move_towards_player(valid_moves, player_pos):
	var best_move = null
	var shortest_distance = INF
	for move in valid_moves:
		var distance = int(abs(move.x - player_pos.x) + abs(move.y - player_pos.y))
		if distance < shortest_distance:
			shortest_distance = distance
			best_move = move
	return best_move

func is_position_occupied(pos: Vector2) -> bool:
	# Check if position is occupied by player
	var player = get_node("/root/main/Player")
	if player and player.grid_position == pos:
		return true
	
	# Check if position is occupied by other enemies
	var main = get_node("/root/main")
	for enemy in main.enemies.get_children():
		if enemy != self and enemy.grid_position == pos:
			return true
	
	return false

func get_attack_ap_cost() -> int:
	var weapon = weapons[current_weapon]
	return ceil(weapon.might / 2)  # AP cost is half the weapon's might, rounded up

func _exit_tree():
	# Clean up UI when enemy is removed
	if enemy_ui_instance and is_instance_valid(enemy_ui_instance):
		enemy_ui_instance.queue_free()

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var player = get_node("/root/main/Player")
		if player and player.current_mode == "baton":
			is_baton_target = true
			# Let the player handle the baton interaction
			player.handle_baton_target(self)
		elif player and player.current_mode == "move":
			# Only allow move mode interaction if not being targeted by baton
			if not is_baton_target:
				player.handle_move_target(self)

func reset_baton_state():
	is_baton_target = false
