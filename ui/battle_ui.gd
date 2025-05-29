extends Control

var player: Node2D
var current_weapon: String = "laser_rifle"
var weapons: Dictionary = {
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

# UI Elements
var health_bar: ProgressBar
var health_label: Label
var ap_bar: ProgressBar
var ap_label: Label
var weapon_container: VBoxContainer
var end_turn_button: Button
var mode_button: Button
var ui_initialized: bool = false

func _ready():
	call_deferred("create_ui")

func create_ui():
	# Create the UI container
	var container = VBoxContainer.new()
	container.name = "UIContainer"
	container.position = Vector2(20, 20)  # Fixed position at top-left
	container.size = Vector2(200, 400)
	add_child(container)
	
	# Create health bar
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.size = Vector2(180, 20)
	health_bar.max_value = 20  # Will be updated when player is set
	health_bar.value = 20
	container.add_child(health_bar)
	
	# Create health label
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.text = "HP: 20/20"  # Will be updated when player is set
	container.add_child(health_label)
	
	# Create action points bar
	ap_bar = ProgressBar.new()
	ap_bar.name = "ActionPointsBar"
	ap_bar.size = Vector2(180, 20)
	ap_bar.max_value = 5  # Will be updated when player is set
	ap_bar.value = 5
	container.add_child(ap_bar)
	
	# Create action points label
	ap_label = Label.new()
	ap_label.name = "ActionPointsLabel"
	ap_label.text = "AP: 5/5"  # Will be updated when player is set
	container.add_child(ap_label)
	
	# Create weapon selection buttons
	weapon_container = VBoxContainer.new()
	weapon_container.name = "WeaponButtons"
	weapon_container.size = Vector2(180, 120)
	container.add_child(weapon_container)
	
	for weapon_id in weapons:
		var weapon = weapons[weapon_id]
		var button = Button.new()
		button.name = weapon_id
		button.text = weapon.name
		button.size = Vector2(180, 30)
		button.pressed.connect(_on_weapon_selected.bind(weapon_id))
		weapon_container.add_child(button)
	
	# Create End Turn button
	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.text = "End Turn"
	end_turn_button.size = Vector2(180, 30)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	container.add_child(end_turn_button)
	
	# Create Mode Switch button
	mode_button = Button.new()
	mode_button.name = "ModeButton"
	mode_button.text = "Switch to Attack"
	mode_button.size = Vector2(180, 30)
	mode_button.pressed.connect(_on_mode_switch_pressed)
	container.add_child(mode_button)
	
	ui_initialized = true
	
	# If we already have a player, update the UI
	if player and is_instance_valid(player):
		update_ui()

func set_player(new_player: Node2D):
	player = new_player
	if ui_initialized:
		update_ui()

func update_ui():
	if not ui_initialized or not player or not is_instance_valid(player):
		return
	
	health_bar.max_value = player.max_health
	health_bar.value = player.current_health
	health_label.text = "HP: " + str(player.current_health) + "/" + str(player.max_health)
	
	ap_bar.max_value = player.max_action_points
	ap_bar.value = player.current_action_points
	ap_label.text = "AP: " + str(player.current_action_points) + "/" + str(player.max_action_points)
	
	# Update weapon button colors
	for button in weapon_container.get_children():
		if button.name == player.current_weapon:
			button.modulate = Color(1, 1, 0)  # Yellow for selected
		else:
			button.modulate = Color(1, 1, 1)  # White for unselected
	
	# Update mode button text
	update_mode_button()

	# Show AP cost for attack in attack mode
	if player.current_mode == "attack":
		var weapon = weapons[player.current_weapon]
		var ap_cost = ceil(weapon.might / 2)
		mode_button.text = "Attack (AP: " + str(ap_cost) + ")"
	else:
		mode_button.text = "Switch to Attack"

func update_mode_button():
	if not ui_initialized or not player or not is_instance_valid(player):
		return
		
	if player.current_mode == "move":
		mode_button.text = "Switch to Attack"
	else:
		mode_button.text = "Switch to Move"

func _on_weapon_selected(weapon_id: String):
	if not ui_initialized or not player or not is_instance_valid(player):
		return
		
	player.current_weapon = weapon_id
	player.weapon_type = weapons[weapon_id].type
	player.update_attack_range()
	update_ui()

func _on_end_turn_pressed():
	if not ui_initialized or not player or not is_instance_valid(player):
		return
		
	player.end_turn()

func _on_mode_switch_pressed():
	if not ui_initialized or not player or not is_instance_valid(player):
		return
		
	if player.current_mode == "move":
		player.current_mode = "attack"
		player.update_attack_range()
	else:
		player.current_mode = "move"
		player.update_movement_range()
	
	update_mode_button() 
