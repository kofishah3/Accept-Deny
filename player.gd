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
var current_mode = "move"  # Can be "move", "attack", or "load_string"
var is_interacting_with_ui = false

# Weapons
var weapons = {
	"baton": {
		"name": "Baton",
		"type": "melee",
		"loaded_string": "",
		"constraints": {
			"max_length": 3,
			"allowed_chars": ["a", "b", "c"],
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
			"allowed_chars": ["a", "b", "c"],
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
			"allowed_chars": ["a", "b", "c"],
			"pattern": "any"
		},
		"range": 1,
		"color": Color(1, 0, 0, 0.3),
		"ap_cost": 2,
		"attack_type": "aoe",
		"aoe_size": Vector2(2, 3)
	},
	"sniper": {
		"name": "Sniper",
		"type": "piercing",
		"loaded_string": "",
		"constraints": {
			"max_length": 5,
			"allowed_chars": ["a", "b", "c"],
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
			"allowed_chars": ["a", "b", "c"],
			"pattern": "any"
		},
		"range": 5,
		"color": Color(1, 0, 0, 0.3),
		"ap_cost": 4,
		"attack_type": "aoe",
		"aoe_size": Vector2(2, 2)
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

func _ready():
	add_to_group("player")
	grid_manager = get_node("/root/main/GridManager")
	grid_position = grid_manager.world_to_grid(position)
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
	for char in new_string:
		if not constraints.allowed_chars.has(char):
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
		grid_manager.update_occupied_tiles()
		update_movement_range()

func _input(event):
	if grid_manager.current_turn != "player" or is_interacting_with_ui:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var target_grid_pos = grid_manager.world_to_grid(mouse_pos)
		
		# Handle unit selection (only if not in attack mode)
		if current_mode != "attack" and grid_manager.world_to_grid(position).distance_to(target_grid_pos) < 1:
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
		
		# Handle attacks first (allow even if not previously selected)
		if current_mode == "attack" and target_grid_pos in grid_manager.valid_attacks:
			var target_unit = grid_manager.get_unit_at_position(target_grid_pos)
			if target_unit:
				var weapon = weapons[current_weapon]
				var ap_cost = get_attack_ap_cost()
				if current_action_points >= ap_cost:
					attack(target_unit)
					current_action_points -= ap_cost
					update_ui()
					current_mode = "move"
					update_movement_range()
					if current_action_points <= 0:
						end_turn()
			return
		
		# Only handle movement if we're selected and in move mode
		if current_mode == "move" and grid_manager.selected_unit == self and target_grid_pos in grid_manager.valid_moves:
			var distance = int(abs(grid_position.x - target_grid_pos.x) + abs(grid_position.y - target_grid_pos.y))
			if current_action_points >= distance and distance > 0:
				previous_grid_position = grid_position
				# Build move_path: vertical then horizontal
				move_path.clear()
				var cur = grid_position
				var vert_dir = sign(target_grid_pos.y - cur.y)
				for i in range(abs(target_grid_pos.y - cur.y)):
					cur = Vector2(cur.x, cur.y + vert_dir)
					move_path.append(cur)
				var horiz_dir = sign(target_grid_pos.x - cur.x)
				for i in range(abs(target_grid_pos.x - cur.x)):
					cur = Vector2(cur.x + horiz_dir, cur.y)
					move_path.append(cur)
				is_moving = true
				grid_manager.valid_moves = []
				current_action_points -= distance
				update_ui()
				play_move_animation() # Play the first animation immediately
				# Animation for subsequent steps is handled in _process

func update_ui():
	var battle_ui = get_node("/root/main/CanvasLayer/BattleUI")
	if battle_ui:
		battle_ui.update_ui()

func update_movement_range():
	# Use current_action_points as the movement range
	var all_moves = grid_manager.calculate_movement_range(grid_position, current_action_points)
	
	# Filter moves based on available AP (Manhattan distance)
	var valid_moves = []
	for move in all_moves:
		var dx = abs(grid_position.x - move.x)
		var dy = abs(grid_position.y - move.y)
		var distance = int(dx + dy)
		if distance <= current_action_points and distance > 0:
			valid_moves.append(move)
	
	grid_manager.valid_moves = valid_moves
	grid_manager.valid_attacks = []
	print("Updated valid moves: ", grid_manager.valid_moves.size())

func update_attack_range():
	grid_manager.valid_moves = []
	var weapon = weapons[current_weapon]
	
	match weapon.attack_type:
		"single":
			grid_manager.valid_attacks = grid_manager.update_attack_range(grid_position, weapon.range)
		"line":
			grid_manager.valid_attacks = grid_manager.update_line_attack_range(grid_position, weapon.range, weapon.diagonal_allowed)
		"aoe":
			grid_manager.valid_attacks = grid_manager.update_aoe_attack_range(grid_position, weapon.range, weapon.aoe_size)
		"piercing":
			grid_manager.valid_attacks = grid_manager.update_piercing_attack_range(grid_position, weapon.diagonal_allowed)
	
	grid_manager.attack_color = weapon.color
	print("Updated valid attacks: ", grid_manager.valid_attacks.size())

func attack(target):
	var weapon = weapons[current_weapon]
	if weapon.loaded_string == "":
		print("No string loaded in ", weapon.name)
		return
	
	match weapon.attack_type:
		"single":
			target.take_damage(weapon.loaded_string)
		"line":
			# Attack all units in a line
			var line_targets = grid_manager.get_units_in_line(grid_position, target.grid_position)
			for line_target in line_targets:
				line_target.take_damage(weapon.loaded_string)
		"aoe":
			# Attack all units in AOE
			var aoe_targets = grid_manager.get_units_in_aoe(target.grid_position, weapon.aoe_size)
			for aoe_target in aoe_targets:
				aoe_target.take_damage(weapon.loaded_string)
		"piercing":
			# Attack all units in line of sight
			var piercing_targets = grid_manager.get_units_in_line(grid_position, target.grid_position)
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
