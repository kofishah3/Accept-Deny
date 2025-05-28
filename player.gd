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
@export var max_action_points = 5
var current_health
var current_action_points

# Mode
var current_mode = "move"  # Can be "move" or "attack"
var is_interacting_with_ui = false

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

func _ready():
	grid_manager = get_node("/root/main/GridManager")
	grid_position = grid_manager.world_to_grid(position)
	position = grid_manager.grid_to_world(grid_position)
	current_health = max_health
	current_action_points = max_action_points
	
	# Connect to the battle UI
	var battle_ui = get_node("/root/main/BattleUI")
	if battle_ui:
		battle_ui.set_player(self)

func _process(delta):
	if is_moving:
		var target_world_pos = grid_manager.grid_to_world(target_position)
		position = position.move_toward(target_world_pos, move_speed * grid_manager.GRID_SIZE * delta)
		
		if position.distance_to(target_world_pos) < 1:
			position = target_world_pos
			grid_position = target_position
			is_moving = false
			grid_manager.update_occupied_tiles()
			update_movement_range()  # Update movement range after moving

func _input(event):
	if grid_manager.current_turn != "player" or is_interacting_with_ui:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var target_grid_pos = grid_manager.world_to_grid(mouse_pos)
		
		# Handle unit selection
		if grid_manager.world_to_grid(position).distance_to(target_grid_pos) < 1:
			if grid_manager.selected_unit == self:
				grid_manager.selected_unit = null
				grid_manager.valid_moves = []
				grid_manager.valid_attacks = []
			else:
				grid_manager.selected_unit = self
				if current_action_points > 0:
					current_mode = "move"
					update_movement_range()
					# Update UI mode button
					var battle_ui = get_node("/root/main/BattleUI")
					if battle_ui:
						battle_ui.update_mode_button()
			return
		
		# Only handle movement and attacks if we're selected
		if grid_manager.selected_unit != self:
			return
		
		# Handle movement
		if current_mode == "move" and target_grid_pos in grid_manager.valid_moves:
			# Use Manhattan distance for AP cost
			var distance = int(abs(grid_position.x - target_grid_pos.x) + abs(grid_position.y - target_grid_pos.y))
			if current_action_points >= distance and distance > 0:
				target_position = target_grid_pos
				is_moving = true
				grid_manager.valid_moves = []
				current_action_points -= distance
				update_ui()
		
		# Handle attacks
		elif current_mode == "attack" and target_grid_pos in grid_manager.valid_attacks:
			var target_unit = grid_manager.get_unit_at_position(target_grid_pos)
			if target_unit:
				var weapon = weapons[current_weapon]
				var ap_cost = ceil(weapon.might / 2)  # AP cost is half the weapon's might, rounded up
				if current_action_points >= ap_cost:
					attack(target_unit)
					current_action_points -= ap_cost
					update_ui()
					
					# If we're out of AP, end turn
					if current_action_points <= 0:
						end_turn()

func update_ui():
	var battle_ui = get_node("/root/main/BattleUI")
	if battle_ui:
		battle_ui.update_ui()

func update_movement_range():
	# Calculate all possible moves within movement range (orthogonal only)
	var all_moves = grid_manager.calculate_movement_range(grid_position, movement_range)
	
	# Filter moves based on available AP
	var valid_moves = []
	for move in all_moves:
		var distance = int(abs(grid_position.x - move.x) + abs(grid_position.y - move.y))
		if distance <= current_action_points and distance > 0:  # Only show moves we can afford
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
