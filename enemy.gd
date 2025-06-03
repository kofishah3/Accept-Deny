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
@export var enemy_ui_offset := Vector2(-45, -50)  # Changed from (-65, -50) to move 20 pixels right
var current_string = ""
var current_action_points

# Mode
var current_mode = "move"  # Can be "move" or "attack"
var is_interacting_with_ui = false
var is_baton_target = false  # New variable to track if enemy is being targeted by baton

var previous_grid_position = Vector2.ZERO
var move_path = []

# Movement state
enum MovementState { IDLE, MOVING, ATTACKING }
var current_state = MovementState.IDLE
var move_speed = 4
var max_movement_range = 3

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

# Movement constants
const MOVEMENT_COST = 1  # Cost per tile moved
const DIAGONAL_COST = 1.4  # Cost for diagonal movement

func _ready():
	add_to_group("enemy")
	grid_manager = get_node("../../GridManager")
	grid_position = grid_manager.world_to_grid(position)
	position = grid_manager.grid_to_world(grid_position)
	
	$AnimatedSprite2D.position = Vector2.ZERO
	
	if string_length == null or string_length <= 0:
		string_length = 5
	
	if max_action_points == null or max_action_points <= 0:
		max_action_points = 4
	
	generate_new_string()
	current_action_points = max_action_points
	
	create_enemy_ui()
	update_enemy_ui()
	
	input_pickable = true
	connect("input_event", Callable(self, "_on_input_event"))

func _process(delta):
	match current_state:
		MovementState.MOVING:
			process_movement(delta)
		MovementState.IDLE:
			pass  # Removed position snapping
	
	update_enemy_ui_position()

func process_movement(delta):
	if move_path.size() == 0:
		current_state = MovementState.IDLE
		grid_manager.update_occupied_tiles()
		update_enemy_ui()
		check_and_attack()
		return
	
	var next_grid = move_path[0]
	var target_world_pos = grid_manager.grid_to_world(next_grid)
	var move_distance = move_speed * grid_manager.GRID_SIZE * delta
	
	var distance_to_target = position.distance_to(target_world_pos)
	if distance_to_target <= move_distance:
		position = target_world_pos
		grid_position = next_grid
		move_path.pop_front()
		if move_path.size() > 0:
			play_move_animation()
		else:
			current_state = MovementState.IDLE
			grid_manager.update_occupied_tiles()
			update_enemy_ui()
			check_and_attack()
	else:
		var direction = (target_world_pos - position).normalized()
		position += direction * move_distance

func take_turn():
	if not is_player_in_range() or is_stunned or current_action_points <= 0:
		return
	
	position = grid_manager.grid_to_world(grid_position)
	
	var player = get_node("/root/main/Player")
	if not player or not is_instance_valid(player):
		return
	
	# Try to attack first if in range
	if try_attack(player):
		has_attacked = true
		return
	
	# If we haven't moved and have enough AP, try to move
	if not has_moved and current_action_points >= MOVEMENT_COST:
		try_move_towards_player(player.grid_position)

func try_attack(player) -> bool:
	var attack_cost = get_attack_ap_cost()
	if current_action_points < attack_cost:
		return false
	
	var attack_range = weapons[current_weapon].range
	var distance = int(abs(grid_position.x - player.grid_position.x) + abs(grid_position.y - player.grid_position.y))
	
	if distance <= attack_range and has_line_of_sight_to(player.grid_position):
		attack(player)
		current_action_points -= attack_cost
		update_enemy_ui()
		return true
	
	return false

func try_move_towards_player(player_pos: Vector2):
	var best_move = evaluate_best_move_towards_player(player_pos)
	if best_move:
		# Calculate the path to the target position
		var path = []
		var current = grid_position
		var target = best_move
		
		# Calculate the number of steps needed in each direction
		var dx = target.x - current.x
		var dy = target.y - current.y
		
		# Check if we can move in a straight line
		var is_straight_line = false
		if dx == 0 or dy == 0:
			is_straight_line = true
		
		if is_straight_line:
			# For straight moves, add all steps up to the target
			var step = Vector2(sign(dx), sign(dy))
			for i in range(abs(dx) + abs(dy)):
				path.append(current + step)
				current += step
		else:
			# For diagonal moves, check which direction gets us closer to the player
			var horizontal_dist = abs((current.x + sign(dx)) - player_pos.x)
			var vertical_dist = abs((current.y + sign(dy)) - player_pos.y)
			
			# Calculate how many steps we can take in each direction
			var steps_x = min(abs(dx), max_movement_range)
			var steps_y = min(abs(dy), max_movement_range)
			
			# Move in the direction that gets us closer to the player first
			if horizontal_dist < vertical_dist:
				# Move horizontally first
				for i in range(steps_x):
					path.append(current + Vector2(sign(dx), 0))
					current += Vector2(sign(dx), 0)
				# Then move vertically
				for i in range(steps_y):
					path.append(current + Vector2(0, sign(dy)))
					current += Vector2(0, sign(dy))
			else:
				# Move vertically first
				for i in range(steps_y):
					path.append(current + Vector2(0, sign(dy)))
					current += Vector2(0, sign(dy))
				# Then move horizontally
				for i in range(steps_x):
					path.append(current + Vector2(sign(dx), 0))
					current += Vector2(sign(dx), 0)
		
		move_path = path
		current_state = MovementState.MOVING
		current_action_points -= MOVEMENT_COST
		has_moved = true
		update_enemy_ui()
		play_move_animation()

func evaluate_best_move_towards_player(player_pos: Vector2) -> Vector2:
	var valid_moves = get_valid_moves()
	var best_move = null
	var best_score = -INF
	
	for move in valid_moves:
		var score = evaluate_move(move, player_pos)
		if score > best_score:
			best_score = score
			best_move = move
	
	return best_move

func get_valid_moves() -> Array:
	var moves = []
	var max_range = min(max_movement_range, current_action_points)
	
	# Check all directions including diagonals
	var directions = [
		Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1),  # Cardinal
		Vector2(1,1), Vector2(-1,1), Vector2(1,-1), Vector2(-1,-1)  # Diagonal
	]
	
	for dir in directions:
		for i in range(1, max_range + 1):
			var pos = grid_position + (dir * i)
			if is_valid_move(pos):
				moves.append(pos)
	
	return moves

func is_valid_move(pos: Vector2) -> bool:
	if not grid_manager._is_walkable(pos) or is_position_occupied(pos):
		return false
	
	# Calculate Manhattan distance for movement range check
	var distance = int(abs(pos.x - grid_position.x) + abs(pos.y - grid_position.y))
	return distance <= max_movement_range

func evaluate_move(pos: Vector2, player_pos: Vector2) -> float:
	var distance_to_player = int(abs(pos.x - player_pos.x) + abs(pos.y - player_pos.y))
	var distance_from_start = int(abs(pos.x - grid_position.x) + abs(pos.y - grid_position.y))
	
	# Prefer moves that get closer to the player while staying within range
	var score = -distance_to_player
	
	# Penalize moves that are too far from our current position
	if distance_from_start > max_movement_range:
		score -= 1000
	
	# Bonus for positions that have line of sight to player
	if has_line_of_sight_to(player_pos):
		score += 50
	
	# Check if this move is in a straight line towards the player
	var is_straight_line = false
	if pos.x == grid_position.x and player_pos.x == grid_position.x:
		is_straight_line = true  # Vertical line
	elif pos.y == grid_position.y and player_pos.y == grid_position.y:
		is_straight_line = true  # Horizontal line
	
	# Strongly prefer straight line moves
	if is_straight_line:
		score += 100
	
	# Only use diagonal moves if they get us significantly closer
	if pos.x != grid_position.x and pos.y != grid_position.y:
		var straight_distance = int(abs(grid_position.x - player_pos.x) + abs(grid_position.y - player_pos.y))
		var diagonal_distance = int(abs(pos.x - player_pos.x) + abs(pos.y - player_pos.y))
		if diagonal_distance < straight_distance - 1:  # Only if diagonal saves at least 2 steps
			score += 25
		else:
			score -= 50  # Penalize unnecessary diagonal moves
	
	return score

func play_move_animation():
	if move_path.size() == 0:
		return
	
	var next_pos = move_path[0]
	var dx = next_pos.x - grid_position.x
	var dy = next_pos.y - grid_position.y
	
	# Play horizontal animation first if there's horizontal movement
	if dx != 0:
		if dx > 0:
			anim.play("walk_right")
		else:
			anim.play("walk_left")
	# Then play vertical animation if there's vertical movement
	elif dy != 0:
		if dy > 0:
			anim.play("walk_down")
		else:
			anim.play("walk_up")

func is_player_in_range() -> bool:
	var player = get_node("/root/main/Player")
	if not player or not is_instance_valid(player):
		return false
		
	# Calculate Manhattan distance to player
	var distance = int(abs(grid_position.x - player.grid_position.x) + abs(grid_position.y - player.grid_position.y))
	return distance <= ACTIVATION_RADIUS

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
	current_action_points = max_action_points
	update_enemy_ui()

# Hack effect methods
func apply_stun():
	is_stunned = true

func apply_confuse():
	is_confused = true

func apply_overwrite():
	var main = get_node("/root/main")
	var enemies = main.enemies.get_children()
	var active_enemies = []
	var inactive_enemies = []
	
	# Separate enemies into active and inactive
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy != self:
			if enemy.is_player_in_range():
				active_enemies.append(enemy)
		else:
				inactive_enemies.append(enemy)
	
	# Try to copy from active enemies first
	if active_enemies.size() > 0:
		var chosen = active_enemies[randi() % active_enemies.size()]
		current_string = chosen.current_string
		print("Enemy string overwritten with active enemy's string: ", current_string)
		update_enemy_ui()
	# Fall back to inactive enemies if no active ones are available
	elif inactive_enemies.size() > 0:
		var chosen = inactive_enemies[randi() % inactive_enemies.size()]
		current_string = chosen.current_string
		print("Enemy string overwritten with inactive enemy's string: ", current_string)
		update_enemy_ui()

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

func update_enemy_ui():
	if string_label:
		string_label.text = current_string
	
	# Update UI position relative to enemy
	update_enemy_ui_position()

func update_enemy_ui_position():
	if enemy_ui_instance and get_viewport():
		var screen_pos = get_global_transform_with_canvas().origin
		# Apply offset and set the UI position
		enemy_ui_instance.position = screen_pos + enemy_ui_offset

func check_and_attack():
	var player = get_node("/root/main/Player")
	if not player or not is_instance_valid(player):
		return
		
	# Check if player is in attack range
	var attack_range = weapons[current_weapon].range
	var distance = int(abs(grid_position.x - player.grid_position.x) + abs(grid_position.y - player.grid_position.y))
	if distance <= attack_range:
		# Check if there's line of sight to the player
		if has_line_of_sight_to(player.grid_position):
			var weapon = weapons[current_weapon]
			var ap_cost = ceil(weapon.might / 2)  # AP cost is half the weapon's might, rounded up
			if current_action_points >= ap_cost:
				print("Enemy attacking player")
				attack(player)
				current_action_points -= ap_cost
				update_enemy_ui()

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

func generate_new_string():
	var chars = ["1", "2", "3"]  # Changed from ["a", "b", "c"] to numbers
	current_string = ""
	for i in range(string_length):
		current_string += chars[randi() % chars.size()]

func create_enemy_ui():
	# Create new UI instance
	enemy_ui_instance = enemy_ui_scene.instantiate()
	
	# Add to canvas layer
	var canvas_layer = get_node("/root/main/CanvasLayer")
	if canvas_layer:
		canvas_layer.add_child(enemy_ui_instance)
		
		# Get UI elements
		string_label = enemy_ui_instance.get_node("StringLabel")
		
		print("Created new enemy UI instance")
		print("StringLabel found: ", string_label != null)
