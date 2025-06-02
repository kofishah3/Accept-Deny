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
@export var max_action_points = 4
@export var enemy_ui_offset := Vector2(10, -100)
var current_string = ""
var current_action_points

# Mode
var current_mode = "move"  # Can be "move" or "attack"
var is_interacting_with_ui = false

var previous_grid_position = Vector2.ZERO

# Weapons
var weapons = {
	"laser_rifle": {
		"name": "Laser Rifle",
		"type": "energy",
		"might": 6,
		"hit": 85,
		"crit": 10,
		"range": 3,
		"color": Color(1, 0, 0, 0.3)  # Transparent red
	},
	"plasma_cannon": {
		"name": "Plasma Cannon",
		"type": "plasma",
		"might": 8,
		"hit": 70,
		"crit": 15,
		"range": 2,
		"color": Color(1, 0, 0, 0.3)  # Transparent red
	},
	"ion_blaster": {
		"name": "Ion Blaster",
		"type": "ion",
		"might": 5,
		"hit": 90,
		"crit": 5,
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
var is_moving = false
var move_speed = 4.0  # Grid cells per second

# UI elements
var enemy_ui_container
var string_label
var action_points_bar
var action_points_label

func _ready():
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
	
	# Connect to the Enemy UI (now called VBoxContainer)
	var enemy_ui = get_node("/root/main/CanvasLayer/BattleUI/VBoxContainer")
	print("EnemyUI found: ", enemy_ui != null)

	if enemy_ui:
		enemy_ui_container = enemy_ui
		string_label = enemy_ui.get_node("StringLabel")
		action_points_bar = enemy_ui.get_node("ActionPointsBar")
		action_points_label = enemy_ui.get_node("ActionPointsLabel")
		
		print("StringLabel found: ", string_label != null)
		print("ActionPointsBar found: ", action_points_bar != null)
		print("ActionPointsLabel found: ", action_points_label != null)
	
	update_enemy_ui()

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
	if enemy_ui_container and get_viewport():
		var screen_pos = get_global_transform_with_canvas().origin
		#apply offset and set the UI position
		enemy_ui_container.position = screen_pos + enemy_ui_offset

func _process(delta):
	if is_moving:
		var target_world_pos = grid_manager.grid_to_world(target_position)
		position = position.move_toward(target_world_pos, move_speed * grid_manager.GRID_SIZE * delta)
		
		if position.distance_to(target_world_pos) < 1:
			position = target_world_pos
			grid_position = target_position
			is_moving = false
			has_moved = true
			grid_manager.update_occupied_tiles()
			# After moving, check if we can attack
			check_and_attack()
	
	# Update enemy UI position to follow enemy
	update_enemy_ui_position()

func play_move_animation():
	var direction = target_position - previous_grid_position
	
	if direction.x > 0:
		anim.play("walk_right")
	elif direction.x < 0:
		anim.play("walk_left")
	elif direction.y > 0:
		anim.play("walk_down")
	elif direction.y < 0: 
		anim.play("walk_up")

func take_turn():
	print("Enemy taking turn")
	if current_action_points <= 0:
		return
		
	var player = get_node("/root/main/Player")
	if not player or not is_instance_valid(player):
		return
		
	# If we haven't moved and have enough AP, try to move towards the player
	if not has_moved and current_action_points >= 1:
		var valid_moves = grid_manager.calculate_movement_range(grid_position, movement_range)
		var best_move = find_best_move_towards_player(valid_moves, player.grid_position)
		
		if best_move:
			print("Enemy moving to: ", best_move)
			
			#get position before moving
			previous_grid_position = grid_position
			
			target_position = best_move
			
			play_move_animation()
			
			is_moving = true
			current_action_points -= 1
			update_enemy_ui()
		else:
			has_moved = true
			check_and_attack()

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

func find_best_move_towards_player(valid_moves, player_pos):
	var best_move = null
	var shortest_distance = INF
	
	for move in valid_moves:
		var distance = int(abs(move.x - player_pos.x) + abs(move.y - player_pos.y))
		if distance < shortest_distance:
			shortest_distance = distance
			best_move = move
	
	return best_move

func attack(target):
	var weapon = weapons[current_weapon]
	var hit_chance = calculate_hit_chance(target, weapon)
	var crit_chance = calculate_crit_chance(target, weapon)
	var damage = calculate_damage(target, weapon)
	
	# Roll for hit
	if randf() * 100 <= hit_chance:
		# Roll for crit
		if randf() * 100 <= crit_chance:
			damage *= 3
			print("Critical hit with ", weapon.name, "!")
		
		target.take_damage(damage)
		print("Hit for ", damage, " damage with ", weapon.name, "!")
	else:
		print("Attack missed with ", weapon.name, "!")

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
	update_enemy_ui()
