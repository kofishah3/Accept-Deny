extends Control

var player: Node2D
var current_weapon: String = "baton"
var weapons: Dictionary = {
	"baton": {
		"name": "Baton",
		"type": "melee",
		"range": 1,
		"ap_cost": 1,
		"color": Color(1, 0, 0, 0.3)
	},
	"bow": {
		"name": "Bow",
		"type": "ranged",
		"range": 6,
		"ap_cost": 3,
		"color": Color(1, 0, 0, 0.3)
	},
	"shotgun": {
		"name": "Shotgun",
		"type": "aoe",
		"range": 1,
		"ap_cost": 2,
		"color": Color(1, 0, 0, 0.3)
	},
	"sniper": {
		"name": "Sniper",
		"type": "piercing",
		"range": -1,
		"ap_cost": 6,
		"color": Color(1, 0, 0, 0.3)
	},
	"emp_grenade": {
		"name": "EMP Grenade",
		"type": "aoe",
		"range": 5,
		"ap_cost": 4,
		"color": Color(1, 0, 0, 0.3)
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
var weapon_string_label: Label
var load_string_button: Button
var string_input: LineEdit
var ui_initialized: bool = false
var hack_stun_button: Button
var hack_confuse_button: Button
var hack_overwrite_button: Button

func _ready():
	# Set the UI to block input events
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Make sure the UI is on top
	show_behind_parent = false
	top_level = true
	
	call_deferred("create_ui")

func create_ui():
	# Create the UI container
	var container = VBoxContainer.new()
	container.name = "UIContainer"
	container.position = Vector2(20, 20)  # Fixed position at top-left
	container.size = Vector2(200, 400)
	container.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	add_child(container)
	
	# Create health bar
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.size = Vector2(180, 20)
	health_bar.max_value = 20  # Will be updated when player is set
	health_bar.value = 20
	health_bar.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	container.add_child(health_bar)
	
	# Create health label
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.text = "HP: 20/20"  # Will be updated when player is set
	health_label.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	container.add_child(health_label)
	
	# Create action points bar
	ap_bar = ProgressBar.new()
	ap_bar.name = "ActionPointsBar"
	ap_bar.size = Vector2(180, 20)
	ap_bar.max_value = 6  # Updated to match new max AP
	ap_bar.value = 6
	ap_bar.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	container.add_child(ap_bar)
	
	# Create action points label
	ap_label = Label.new()
	ap_label.name = "ActionPointsLabel"
	ap_label.text = "AP: 6/6"  # Updated to match new max AP
	ap_label.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	container.add_child(ap_label)
	
	# Create weapon selection buttons
	weapon_container = VBoxContainer.new()
	weapon_container.name = "WeaponButtons"
	weapon_container.size = Vector2(180, 200)  # Increased size for more weapons
	weapon_container.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	container.add_child(weapon_container)
	
	for weapon_id in weapons:
		var weapon = weapons[weapon_id]
		var button = Button.new()
		button.name = weapon_id
		button.text = weapon.name + " (" + str(weapon.ap_cost) + " AP)"
		button.size = Vector2(180, 30)
		button.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
		button.pressed.connect(_on_weapon_selected.bind(weapon_id))
		weapon_container.add_child(button)
	
	# Create weapon string UI elements
	weapon_string_label = Label.new()
	weapon_string_label.name = "WeaponStringLabel"
	weapon_string_label.size = Vector2(180, 20)
	weapon_string_label.text = "Weapon String: "
	weapon_string_label.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	container.add_child(weapon_string_label)
	
	load_string_button = Button.new()
	load_string_button.name = "LoadStringButton"
	load_string_button.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	load_string_button.size = Vector2(180, 30)
	load_string_button.text = "Load String (1 AP)"
	load_string_button.pressed.connect(_on_load_string_pressed)
	container.add_child(load_string_button)
	
	string_input = LineEdit.new()
	string_input.name = "StringInput"
	string_input.size = Vector2(180, 30)
	string_input.placeholder_text = "Enter string..."
	string_input.max_length = 6  # Maximum length of any weapon's string
	string_input.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	container.add_child(string_input)
	
	# Create End Turn button
	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.text = "End Turn"
	end_turn_button.size = Vector2(180, 30)
	end_turn_button.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	container.add_child(end_turn_button)
	
	# Create Move Mode button
	mode_button = Button.new()
	mode_button.name = "ModeButton"
	mode_button.text = "Move Mode"
	mode_button.size = Vector2(180, 30)
	mode_button.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	mode_button.pressed.connect(_on_move_mode_pressed)
	container.add_child(mode_button)
	
	# Create Hacking section
	var hack_label = Label.new()
	hack_label.text = "Hacking:"
	hack_label.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	container.add_child(hack_label)

	hack_stun_button = Button.new()
	hack_stun_button.name = "HackStunButton"
	hack_stun_button.text = "Stun Target (5 AP)"
	hack_stun_button.size = Vector2(180, 30)
	hack_stun_button.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	hack_stun_button.pressed.connect(_on_hack_stun_pressed)
	container.add_child(hack_stun_button)

	hack_confuse_button = Button.new()
	hack_confuse_button.name = "HackConfuseButton"
	hack_confuse_button.text = "Confuse Target (2 AP)"
	hack_confuse_button.size = Vector2(180, 30)
	hack_confuse_button.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	hack_confuse_button.pressed.connect(_on_hack_confuse_pressed)
	container.add_child(hack_confuse_button)

	hack_overwrite_button = Button.new()
	hack_overwrite_button.name = "HackOverwriteButton"
	hack_overwrite_button.text = "Overwrite Target (4 AP)"
	hack_overwrite_button.size = Vector2(180, 30)
	hack_overwrite_button.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	hack_overwrite_button.pressed.connect(_on_hack_overwrite_pressed)
	container.add_child(hack_overwrite_button)
	
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
	
	# Update weapon button colors and states
	for button in weapon_container.get_children():
		var weapon = weapons[button.name]
		if button.name == player.current_weapon:
			button.modulate = Color(1, 1, 0)  # Yellow for selected
		else:
			button.modulate = Color(1, 1, 1)  # White for unselected
		
		# Disable buttons if not enough AP
		button.disabled = player.current_action_points < weapon.ap_cost
	
	# Update weapon string UI
	weapon_string_label.text = "Weapon String: " + player.weapons[player.current_weapon].loaded_string
	load_string_button.disabled = player.current_action_points < 1
	
	# Update mode button text
	mode_button.text = "Move Mode"
	
	# Update hack button states
	if hack_stun_button:
		hack_stun_button.disabled = player.current_action_points < 5
	if hack_confuse_button:
		hack_confuse_button.disabled = player.current_action_points < 2
	if hack_overwrite_button:
		hack_overwrite_button.disabled = player.current_action_points < 4

func _on_weapon_selected(weapon_id: String):
	if not ui_initialized or not player or not is_instance_valid(player):
		return
	player.set_weapon_and_attack_mode(weapon_id)
	update_ui()

func _on_load_string_pressed():
	if not ui_initialized or not player or not is_instance_valid(player):
		return
	
	if player.current_action_points < 1:
		return
	
	var new_string = string_input.text
	if player.load_string_to_weapon(player.current_weapon, new_string):
		player.current_action_points -= 1
		string_input.text = ""  # Clear input after successful load
		update_ui()

func _on_end_turn_pressed():
	if not ui_initialized or not player or not is_instance_valid(player):
		return
	player.end_turn()

func _on_move_mode_pressed():
	if not ui_initialized or not player or not is_instance_valid(player):
		return
	player.current_mode = "move"
	player.update_movement_range()
	update_ui()

func _on_hack_stun_pressed():
	if player and is_instance_valid(player):
		player.enter_hack_mode("stun")
		update_ui()

func _on_hack_confuse_pressed():
	if player and is_instance_valid(player):
		player.enter_hack_mode("confuse")
		update_ui()

func _on_hack_overwrite_pressed():
	if player and is_instance_valid(player):
		player.enter_hack_mode("overwrite")
		update_ui() 
