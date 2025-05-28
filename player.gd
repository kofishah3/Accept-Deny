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
var current_health

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
		"color": Color(0, 1, 0)  # Green
	},
	"plasma_cannon": {
		"name": "Plasma Cannon",
		"type": "plasma",
		"might": 8,
		"hit": 70,
		"crit": 15,
		"range": 2,
		"color": Color(1, 0.5, 0)  # Orange
	},
	"ion_blaster": {
		"name": "Ion Blaster",
		"type": "ion",
		"might": 5,
		"hit": 90,
		"crit": 5,
		"range": 1,
		"color": Color(0, 0.5, 1)  # Blue
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
	create_ui()

func create_ui():
	# Create health bar
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector2(-30, -50)
	health_bar.size = Vector2(60, 10)
	health_bar.max_value = max_health
	health_bar.value = current_health
	add_child(health_bar)
	
	# Create weapon selection buttons
	var button_container = VBoxContainer.new()
	button_container.name = "WeaponButtons"
	button_container.position = Vector2(-40, -80)
	button_container.size = Vector2(80, 100)
	add_child(button_container)
	
	for weapon_id in weapons:
		var weapon = weapons[weapon_id]
		var button = Button.new()
		button.name = weapon_id
		button.text = weapon.name
		button.size = Vector2(80, 20)
		button.mouse_entered.connect(_on_button_mouse_entered)
		button.mouse_exited.connect(_on_button_mouse_exited)
		button.pressed.connect(_on_weapon_selected.bind(weapon_id))
		button_container.add_child(button)
	
	# Create End Turn button
	var end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.text = "End Turn"
	end_turn_button.size = Vector2(80, 20)
	end_turn_button.position = Vector2(-40, 20)
	end_turn_button.mouse_entered.connect(_on_button_mouse_entered)
	end_turn_button.mouse_exited.connect(_on_button_mouse_exited)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	add_child(end_turn_button)
	
	# Create Mode Switch button
	var mode_button = Button.new()
	mode_button.name = "ModeButton"
	mode_button.text = "Switch to Attack"
	mode_button.size = Vector2(80, 20)
	mode_button.position = Vector2(-40, 50)
	mode_button.mouse_entered.connect(_on_button_mouse_entered)
	mode_button.mouse_exited.connect(_on_button_mouse_exited)
	mode_button.pressed.connect(_on_mode_switch_pressed)
	add_child(mode_button)
	
	# Hide UI elements initially
	$WeaponButtons.visible = false
	$EndTurnButton.visible = false
	$ModeButton.visible = false

func _on_button_mouse_entered():
	is_interacting_with_ui = true

func _on_button_mouse_exited():
	is_interacting_with_ui = false

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
			# After moving, switch to attack mode
			current_mode = "attack"
			$ModeButton.text = "Switch to Move"
			update_attack_range()

func _on_mode_switch_pressed():
	if current_mode == "move":
		current_mode = "attack"
		$ModeButton.text = "Switch to Move"
		update_attack_range()
		grid_manager.valid_moves = []
	else:
		current_mode = "move"
		$ModeButton.text = "Switch to Attack"
		update_movement_range()
		grid_manager.valid_attacks = []

func _input(event):
	if grid_manager.current_turn != "player" or has_attacked or is_interacting_with_ui:
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
				$WeaponButtons.visible = false
				$EndTurnButton.visible = false
				$ModeButton.visible = false
			else:
				grid_manager.selected_unit = self
				if not has_moved:
					current_mode = "move"
					$ModeButton.text = "Switch to Attack"
					update_movement_range()
					$EndTurnButton.visible = true
					$ModeButton.visible = true
				else:
					current_mode = "attack"
					$ModeButton.text = "Switch to Move"
					update_attack_range()
				$WeaponButtons.visible = true
			return
		
		# Only handle movement and attacks if we're selected
		if grid_manager.selected_unit != self:
			return
		
		# Handle movement
		if current_mode == "move" and not has_moved and target_grid_pos in grid_manager.valid_moves:
			target_position = target_grid_pos
			is_moving = true
			grid_manager.valid_moves = []
		
		# Handle attacks
		elif current_mode == "attack" and target_grid_pos in grid_manager.valid_attacks:
			var target_unit = grid_manager.get_unit_at_position(target_grid_pos)
			if target_unit:
				attack(target_unit)

func _on_weapon_selected(weapon_id):
	current_weapon = weapon_id
	weapon_type = weapons[weapon_id].type
	update_attack_range()
	# Update button colors to show selection
	for button in $WeaponButtons.get_children():
		if button.name == weapon_id:
			button.modulate = Color(1, 1, 0)  # Yellow for selected
		else:
			button.modulate = Color(1, 1, 1)  # White for unselected

func update_movement_range():
	grid_manager.valid_moves = grid_manager.calculate_movement_range(grid_position, movement_range)
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
	
	# End turn after attack is complete
	has_attacked = true
	grid_manager.selected_unit = null
	grid_manager.valid_moves = []
	grid_manager.valid_attacks = []
	$WeaponButtons.visible = false
	$EndTurnButton.visible = false
	$ModeButton.visible = false
	get_node("/root/main").end_player_turn()

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
	$HealthBar.value = current_health
	if current_health <= 0:
		queue_free()

func _on_end_turn_pressed():
	has_attacked = true  # Mark as having attacked to prevent further actions
	grid_manager.selected_unit = null
	grid_manager.valid_moves = []
	grid_manager.valid_attacks = []
	$WeaponButtons.visible = false
	$EndTurnButton.visible = false
	$ModeButton.visible = false
	get_node("/root/main").end_player_turn()

func reset_turn():
	has_moved = false
	has_attacked = false
	is_moving = false
	current_mode = "move"
	$ModeButton.text = "Switch to Attack"
	$WeaponButtons.visible = false
	$EndTurnButton.visible = false
	$ModeButton.visible = false
