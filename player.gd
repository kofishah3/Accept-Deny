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
@export var max_action_points = 8
@export var weapon_ui_offset := Vector2(10, -100)
var current_health
var current_action_points

# Mode
var current_mode = "move"  # Can be "move", "attack", or "load_string"
var is_interacting_with_ui = false

# Weapons
var weapons = {
	"laser_rifle": {
		"name": "Laser Rifle",
		"type": "energy",
		"loaded_string": "",
		"constraints": {
			"max_length": 3,
			"allowed_chars": ["a", "b", "c"],
			"pattern": "any"  # any, alternating, or repeating
		},
		"range": 3,
		"color": Color(1, 0, 0, 0.3)  # Transparent red
	},
	"plasma_cannon": {
		"name": "Plasma Cannon",
		"type": "plasma",
		"loaded_string": "",
		"constraints": {
			"max_length": 4,
			"allowed_chars": ["a", "b"],
			"pattern": "alternating"  # Must alternate between a and b
		},
		"range": 2,
		"color": Color(1, 0, 0, 0.3)  # Transparent red
	},
	"ion_blaster": {
		"name": "Ion Blaster",
		"type": "ion",
		"loaded_string": "",
		"constraints": {
			"max_length": 6,
			"allowed_chars": ["a", "b", "c"],
			"pattern": "repeating"  # Must have repeating patterns
		},
		"range": 1,
		"color": Color(1, 0, 0, 0.3)  # Transparent red
	}
}
var current_weapon = "laser_rifle"
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

# UI elements
var player_weapon_ui_container
var weapon_string_label
var string_input
var load_string_button

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
	
	# COnnect to the Player Weapon UI
	var player_weapon_ui = get_node("/root/main/CanvasLayer/BattleUI/PlayerWeaponUI")
	print("PlayerWeaponUI found: ", player_weapon_ui != null)

	if player_weapon_ui:
		player_weapon_ui_container = player_weapon_ui
		weapon_string_label = player_weapon_ui.get_node("WeaponStringLabel")
		load_string_button = player_weapon_ui.get_node("LoadStringButton")
		string_input = player_weapon_ui.get_node("StringInput")
		
		print("WeaponStringLabel found: ", weapon_string_label != null)
		print("LoadStringButton found: ", load_string_button != null)
		print("StringInput found: ", string_input != null)
		
		if load_string_button:
			var connection_result = load_string_button.connect("pressed", Callable(self, "_on_load_string_pressed"))
			print("Button connection result: ", connection_result)
	
	update_weapon_ui()
	
	#create_weapon_ui()

#DEPRACATED -- moved to canvas layer and made automatically 
#func create_weapon_ui():
	## Create weapon string display
	#weapon_string_label = Label.new()
	#weapon_string_label.name = "WeaponStringLabel"
	#weapon_string_label.position = Vector2(-40, -130)
	#weapon_string_label.text = "Weapon String: " + weapons[current_weapon].loaded_string
	#add_child(weapon_string_label)
	#
	## Create load string button
	#load_string_button = Button.new()
	#load_string_button.name = "LoadStringButton"
	#load_string_button.position = Vector2(-40, -100)
	#load_string_button.text = "Load String (1 AP)"
	#load_string_button.connect("pressed", Callable(self, "_on_load_string_pressed"))
	#add_child(load_string_button)
	#
	## Create string input
	#string_input = LineEdit.new()
	#string_input.name = "StringInput"
	#string_input.position = Vector2(-40, -70)
	#string_input.placeholder_text = "Enter string..."
	#string_input.max_length = 6  # Maximum length of any weapon's string
	#add_child(string_input)

func _on_load_string_pressed():
	print("Load string button was pressed!")
	if current_action_points < 1:
		print("Not enough action points to load string")
		return
	
	var new_string = string_input.text
	if load_string_to_weapon(current_weapon, new_string):
		current_action_points -= 1
		string_input.text = ""  # Clear input after successful load
	update_ui() # Always update UI after loading

func update_weapon_ui():
	if weapon_string_label:
		weapon_string_label.text = "Weapon String: " + weapons[current_weapon].loaded_string
	
	if load_string_button:
		load_string_button.text = "Load String (1 AP)"
		load_string_button.disabled	= current_action_points < 1 
	
	# Update UI position relative to player
	update_weapon_ui_position()

func update_weapon_ui_position():
	if player_weapon_ui_container and get_viewport():
		# Get the player's position in screen coordinates
		var screen_pos = get_global_transform_with_canvas().origin
		# Apply the offset and set the UI position
		player_weapon_ui_container.position = screen_pos + weapon_ui_offset

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
				# Optionally, play idle animation here
	elif is_moving:
		# Fallback for non-path movement (shouldn't happen)
		is_moving = false
		grid_manager.update_occupied_tiles()
		update_movement_range()
	# Update weapon UI position to follow player
	update_weapon_ui_position()

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
		
		# Handle attacks (allow even if not previously selected)
		elif current_mode == "attack" and target_grid_pos in grid_manager.valid_attacks:
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

func update_ui():
	var battle_ui = get_node("/root/main/CanvasLayer/BattleUI")
	if battle_ui:
		battle_ui.update_ui()
	
	update_weapon_ui()

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
	grid_manager.valid_attacks = grid_manager.update_attack_range(grid_position, weapon.range)
	grid_manager.attack_color = weapon.color
	print("Updated valid attacks: ", grid_manager.valid_attacks.size())

func load_string_to_weapon(weapon_name, new_string):
	var weapon = weapons[weapon_name]
	var constraints = weapon.constraints
	
	# Check length constraint
	if new_string.length() > constraints.max_length:
		print("String too long for ", weapon.name)
		return false
	
	# Check allowed characters
	for char in new_string:
		if not char in constraints.allowed_chars:
			print("Invalid character '", char, "' for ", weapon.name)
			return false
	
	# Check pattern constraints
	match constraints.pattern:
		"alternating":
			for i in range(1, new_string.length()):
				if new_string[i] == new_string[i-1]:
					print("String must alternate characters for ", weapon.name)
					return false
		"repeating":
			var has_pattern = false
			for pattern_length in range(1, new_string.length() / 2 + 1):
				var pattern = new_string.substr(0, pattern_length)
				var is_repeating = true
				for i in range(pattern_length, new_string.length(), pattern_length):
					if new_string.substr(i, pattern_length) != pattern:
						is_repeating = false
						break
				if is_repeating:
					has_pattern = true
					break
			if not has_pattern:
				print("String must have a repeating pattern for ", weapon.name)
				return false
	
	# If all constraints are met, load the string
	weapon.loaded_string = new_string
	print("Successfully loaded string '", new_string, "' into ", weapon.name)
	update_ui() # Always update UI after loading
	return true

func attack(target):
	var weapon = weapons[current_weapon]
	if weapon.loaded_string == "":
		print("No string loaded in ", weapon.name)
		return
	
	target.take_damage(weapon.loaded_string)
	print("Attacked with ", weapon.name, " using string: ", weapon.loaded_string)
	# Clear the loaded string after use
	weapon.loaded_string = ""
	update_ui() # Always update UI after attacking

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
	return ceil(weapon.range / 2)

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
