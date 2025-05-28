extends Area2D

@onready var anim = $AnimatedSprite2D
@export var movement_range = 2

# Combat stats
@export var strength = 6
@export var speed = 5
@export var defense = 4
@export var resistance = 2
@export var skill = 4
@export var luck = 3
@export var max_health = 15
var current_health

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
var current_weapon = "plasma_cannon"
var weapon_type = "plasma"

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

func take_turn():
	print("Enemy taking turn")
	if has_moved and has_attacked:
		return
		
	var player = get_node("/root/main/Player")
	if not player or not is_instance_valid(player):
		return
		
	# If we haven't moved, try to move towards the player
	if not has_moved:
		var valid_moves = grid_manager.calculate_movement_range(grid_position, movement_range)
		var best_move = find_best_move_towards_player(valid_moves, player.grid_position)
		
		if best_move:
			print("Enemy moving to: ", best_move)
			target_position = best_move
			is_moving = true
		else:
			has_moved = true
			check_and_attack()

func check_and_attack():
	var player = get_node("/root/main/Player")
	if not player or not is_instance_valid(player):
		return
		
	# Check if player is in attack range
	var attack_range = weapons[current_weapon].range
	if grid_position.distance_to(player.grid_position) <= attack_range:
		print("Enemy attacking player")
		attack(player)
	else:
		has_attacked = true

func find_best_move_towards_player(valid_moves, player_pos):
	var best_move = null
	var shortest_distance = INF
	
	for move in valid_moves:
		var distance = move.distance_to(player_pos)
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
	
	has_attacked = true

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

func reset_turn():
	has_moved = false
	has_attacked = false
	is_moving = false
