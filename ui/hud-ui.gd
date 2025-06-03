extends Control

var player: Node2D
var current_weapon: String = "baton"
var hint_label: Label  # Add hint display label
var weapons: Dictionary = {
	"baton": {
		"name": "Baton",
		"type": "Melee",
		"range": 1,
		"regex": "Strings of length 3 using numbers 1-3",
		"ap_cost": 1,
		"color": Color(1, 0, 0, 0.3),
		"description": "A close-range melee weapon ideal for quick, low-cost attacks."
	},
	"bow": {
		"name": "Bow",
		"type": "Ranged",
		"range": 6,
		"regex": "Strings of length 3 using numbers 1-3",
		"ap_cost": 3,
		"color": Color(1, 0, 0, 0.3),
		"description": "A ranged weapon effective for hitting targets from a distance with moderate action point cost."
	},
	"shotgun": {
		"name": "Shotgun",
		"type": "AoE",
		"range": 1,
		"regex": "Strings of length 3 using numbers 1-3",
		"ap_cost": 2,
		"color": Color(1, 0, 0, 0.3),
		"description": "A short-range area-of-effect weapon that can hit multiple enemies at once."
	},
	"sniper": {
		"name": "Sniper",
		"type": "Piercing",
		"range": -1,
		"regex": "Strings of length 5 using numbers 1-3",
		"ap_cost": 6,
		"color": Color(1, 0, 0, 0.3),
		"description": "A long-range piercing weapon designed for high-damage, precise shots but costs more action points."
	},
	"emp_grenade": {
		"name": "EMP Grenade",
		"type": "AoE",
		"range": 5,
		"regex": "Strings of length 2 using numbers 1-3",
		"ap_cost": 4,
		"color": Color(1, 0, 0, 0.3),
		"description": "An area-of-effect device that disables electronics and affects multiple targets within range."
	}
}

# Weapon texture mapping - single spritesheet
var weapon_spritesheet_path: String = "res://assets(weapons)/Weapon_Icons.png"

# UI Elements from on-game-screen scene
var health_bar: TextureProgressBar
var ap_bar: TextureProgressBar
var inventory_node: GridContainer
var phase_display_node: CanvasLayer
var accumulated_string_view_node: NinePatchRect
var attack_move_button_node: NinePatchRect
var end_turn_button_node: NinePatchRect
var player_display_node: NinePatchRect

# Additional UI elements we'll add
var weapon_container: VBoxContainer
var weapon_string_label: Label
var loaded_string_label: Label  # New label for loaded weapon string
var load_string_button: Button
var string_input: LineEdit
var ui_initialized: bool = false
var currently_selected_slot: Control = null  # Track the currently selected weapon slot
var weapon_tooltip: Control = null  # Tooltip for weapon information
var regex_load_panel: Control = null  # Regex load panel instance
var hacks_panel: Control = null  # Hacks panel instance
var hacks_button: Button = null  # Reference to the hacks button

@onready var on_game_screen_scene := preload("res://ui/on-game screen/on-game-screen.tscn")
@onready var regex_load_panel_scene := preload("res://ui/on-game screen/regex-load-panel.tscn")
@onready var hacks_panel_scene := preload("res://ui/on-game screen/hacks_panel.tscn")
var on_game_screen_instance: Control

func _ready():
	# Set the UI to block input events
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Make sure the UI is on top
	show_behind_parent = false
	top_level = true
	call_deferred("create_ui")

func create_ui():
	# Create the UI instance
	on_game_screen_instance = on_game_screen_scene.instantiate()
	# Make sure the UI instance blocks input
	on_game_screen_instance.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(on_game_screen_instance)
	
	# Create hint display at the top of the screen
	create_hint_display()
	
	#cache UI elements from the on-game-screen scene
	player_display_node = on_game_screen_instance.get_node("PlayerDisplay")
	inventory_node = on_game_screen_instance.get_node("Inventory")
	phase_display_node = on_game_screen_instance.get_node("Phase Display")
	accumulated_string_view_node = on_game_screen_instance.get_node("Accumulated String View")
	attack_move_button_node = on_game_screen_instance.get_node("Attack_Move Button")
	end_turn_button_node = on_game_screen_instance.get_node("End Turn Button")
	
	# Set all UI elements to block input
	for node in [player_display_node, inventory_node, phase_display_node, 
				accumulated_string_view_node, attack_move_button_node, end_turn_button_node]:
		if node and node is Control:
			node.mouse_filter = Control.MOUSE_FILTER_STOP
	
	#get health and ap progress bars from PlayerDisplay
	health_bar = player_display_node.get_node("HealthTextureProgressBar")
	ap_bar = player_display_node.get_node("ManaTextureProgressBar")
	
	# Set progress bars to block input
	if health_bar and health_bar is Control:
		health_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	if ap_bar and ap_bar is Control:
		ap_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	
	#connect existing button signals
	var attack_move_button = attack_move_button_node.get_node("TextureButton")
	var end_turn_button = end_turn_button_node.get_node("TextureButton")

	# Set buttons to block input
	if attack_move_button and attack_move_button is Control:
		attack_move_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if end_turn_button and end_turn_button is Control:
		end_turn_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	attack_move_button.pressed.connect(_on_move_mode_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	# Connect the hacks button from the scene
	hacks_button = player_display_node.get_node("Char/Hacks Button")
	if hacks_button:
		hacks_button.pressed.connect(_on_hacks_button_pressed)
		hacks_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	#create additional UI elements for weapon selection and hacking
	create_additional_ui_elements()
	
	# Load weapon textures into inventory slots
	load_weapon_textures_to_inventory()
	
	# Create weapon tooltip
	create_weapon_tooltip()
	
	# Create regex load panel
	create_regex_load_panel()
	
	# Create hacks panel
	create_hacks_panel()
	
	# Update hint display
	update_hint_display()
	
	ui_initialized = true
	
	# If we already have a player, update the UI
	if player and is_instance_valid(player):
		update_ui()

func create_hint_display():
	# Create a hint label at the top center of the screen
	hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "Dungeon Hint: Loading..."
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Set the font
	var font = load("res://themes/regex.ttf")
	if font:
		hint_label.add_theme_font_override("font", font)
	
	# Center the hint label on the screen
	hint_label.anchors_preset = Control.PRESET_CENTER
	hint_label.position = Vector2(225, 60)  # Move up from center
	hint_label.size = Vector2(800, 40)  # Make it wider to accommodate text
	
	# Style the hint label
	hint_label.add_theme_color_override("font_color", Color(1, 1, 0))  # Yellow text
	hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))  # Black shadow
	hint_label.add_theme_constant_override("shadow_offset_x", 2)
	hint_label.add_theme_constant_override("shadow_offset_y", 2)
	
	add_child(hint_label)

func update_hint_display():
	if not hint_label:
		return
		
	# Get the current hint from the dungeon level
	var dungeon_container = get_node("/root/main/DungeonContainer")
	if dungeon_container and dungeon_container.get_child_count() > 0:
		var dungeon_level = dungeon_container.get_child(0)
		var current_hint = dungeon_level.get_current_hint()
		if current_hint != "":
			hint_label.text = "Pattern Hint: " + current_hint
		else:
			hint_label.text = "No active pattern hint"
	else:
		hint_label.text = "Dungeon Hint: Loading..."

func create_additional_ui_elements():
	# Create container for additional UI elements	 positioned on the left side
	var additional_container = VBoxContainer.new()
	additional_container.name = "AdditionalUIContainer"
	additional_container.position = Vector2(20, 20)
	additional_container.size = Vector2(200, 600)
	additional_container.visible = false  # Hide the additional UI elements
	additional_container.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	add_child(additional_container)
	
	# Loaded string display
	loaded_string_label = Label.new()
	loaded_string_label.name = "LoadedStringLabel"
	loaded_string_label.text = ""
	loaded_string_label.add_theme_font_size_override("font_size", 16)
	loaded_string_label.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	additional_container.add_child(loaded_string_label)
	
	# Weapon selection section
	var weapon_label = Label.new()
	weapon_label.text = "Weapons:"
	weapon_label.add_theme_font_size_override("font_size", 16)
	weapon_label.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	additional_container.add_child(weapon_label)
	
	weapon_container = VBoxContainer.new()
	weapon_container.name = "WeaponButtons"
	weapon_container.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	additional_container.add_child(weapon_container)
	
	for weapon_id in weapons:
		var weapon = weapons[weapon_id]
		var button = Button.new()
		button.name = weapon_id
		button.text = weapon.name + " (" + str(weapon.ap_cost) + " AP)"
		button.size = Vector2(180, 30)
		button.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
		button.pressed.connect(_on_weapon_selected.bind(weapon_id))
		weapon_container.add_child(button)
	
	# Weapon string section
	var string_section_label = Label.new()
	string_section_label.text = "Weapon String:"
	string_section_label.add_theme_font_size_override("font_size", 16)
	string_section_label.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	additional_container.add_child(string_section_label)
	
	weapon_string_label = Label.new()
	weapon_string_label.name = "WeaponStringLabel"
	weapon_string_label.text = "String: "
	weapon_string_label.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	additional_container.add_child(weapon_string_label)
	
	string_input = LineEdit.new()
	string_input.name = "StringInput"
	string_input.placeholder_text = "Enter regex string..."
	string_input.size = Vector2(180, 30)
	string_input.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	additional_container.add_child(string_input)
	
	load_string_button = Button.new()
	load_string_button.name = "LoadStringButton"
	load_string_button.text = "Load String (1 AP)"
	load_string_button.size = Vector2(180, 30)
	load_string_button.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	load_string_button.pressed.connect(_on_load_string_pressed)
	additional_container.add_child(load_string_button)
	
	# Hacking section
	var hack_label = Label.new()
	hack_label.text = "Hacking:"
	hack_label.add_theme_font_size_override("font_size", 16)
	hack_label.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input
	additional_container.add_child(hack_label)

func set_player(new_player: Node2D):
	player = new_player
	if ui_initialized:
		update_ui()

func set_current_phase(is_player_turn: bool):
	update_phase_display(is_player_turn)

func update_ui():
	if not ui_initialized or not player or not is_instance_valid(player):
		return
	
	# Update health progress bar
	if health_bar:
		health_bar.max_value = player.max_health
		health_bar.value = player.current_health
	
	# Update AP progress bar (repurpose for action points)
	if ap_bar:
		ap_bar.max_value = player.max_action_points
		ap_bar.value = player.current_action_points
	
	# Update loaded string display
	if loaded_string_label and player.weapons.has(player.current_weapon):
		loaded_string_label.text = player.weapons[player.current_weapon].loaded_string
	
	# Update weapon button colors and states
	if weapon_container:
		for button in weapon_container.get_children():
			if button is Button:
				var weapon = weapons[button.name]
				if button.name == player.current_weapon:
					button.modulate = Color(1, 1, 0)  # Yellow for selected
				else:
					button.modulate = Color(1, 1, 1)  # White for unselected
				
				# Disable buttons if not enough AP
				button.disabled = player.current_action_points < weapon.ap_cost
	
	# Update weapon string UI
	if weapon_string_label and player.weapons.has(player.current_weapon):
		weapon_string_label.text = "String: " + player.weapons[player.current_weapon].loaded_string
	
	if load_string_button:
		load_string_button.disabled = player.current_action_points < 1
	
	# Update hacks button state
	if hacks_button:
		hacks_button.disabled = player.current_action_points < 2  # Minimum AP needed for confuse hack

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

func _on_hacks_button_pressed():
	if not ui_initialized or not player or not is_instance_valid(player):
		return
	
	show_hacks_panel()

func load_weapon_textures_to_inventory():
	if not inventory_node:
		return
	
	# Load the single 80x16 spritesheet
	var spritesheet_texture = load(weapon_spritesheet_path)
	if not spritesheet_texture:
		print("Failed to load weapon spritesheet")
		return
	
	var spritesheet_image = spritesheet_texture.get_image()
	
	# Get the weapon IDs in order to match with inventory slots
	var weapon_ids = ["baton", "bow", "shotgun", "sniper", "emp_grenade"]
	var slot_index = 0
	
	#loop through inventory slots and assign weapon textures
	for child in inventory_node.get_children():
		if child.name.begins_with("Slot") and slot_index < weapon_ids.size():
			var weapon_id = weapon_ids[slot_index]
			
			var icon_node = child.get_node("Icon")
			if icon_node:
				var weapon_x_offset = slot_index * 16 #get the 16x16 sprite
				var icon_image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
				
				#extract weapon icon from sheet
				icon_image.blit_rect(spritesheet_image, Rect2i(weapon_x_offset, 0, 16, 16), Vector2i(0, 0))
				
				# Create texture from the extracted image
				var icon_texture = ImageTexture.new()
				icon_texture.set_image(icon_image)
				
				#assign to the icon
				icon_node.texture = icon_texture
				icon_node.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# Make the entire slot clickable for weapon selection
			child.gui_input.connect(_on_inventory_slot_clicked.bind(weapon_id))
			child.mouse_filter = Control.MOUSE_FILTER_PASS
			
			# Add hover effects (pass both slot and icon for animation)
			child.mouse_entered.connect(_on_inventory_slot_hovered.bind(icon_node, weapon_id))
			child.mouse_exited.connect(_on_inventory_slot_unhovered.bind(icon_node))
			
			slot_index += 1

func _on_inventory_slot_clicked(event: InputEvent, weapon_id: String):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			hide_weapon_tooltip()
			# find the clicked slot
			var clicked_slot = null
			var weapon_ids = ["baton", "bow", "shotgun", "sniper", "emp_grenade"]
			var slot_index = weapon_ids.find(weapon_id)
			
			if slot_index != -1 and inventory_node:
				var slot_counter = 0
				for child in inventory_node.get_children():
					if child.name.begins_with("Slot"):
						if slot_counter == slot_index:
							clicked_slot = child
							break
						slot_counter += 1
			
			# Apply green glow to the selected slot
			if clicked_slot:
				apply_selected_glow(clicked_slot)
			
			_on_weapon_selected(weapon_id)
		
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click opens regex load panel
			hide_weapon_tooltip()
			show_regex_load_panel(weapon_id)

func apply_selected_glow(slot: Control):
	#remove glow from previously selected slot if any
	if currently_selected_slot and currently_selected_slot != slot:
		currently_selected_slot.modulate = Color(1.0, 1.0, 1.0, 1.0)  
	
	#apply green glow to the new selected slot
	slot.modulate = Color(0.5, 1.5, 0.5, 1.0)  
	currently_selected_slot = slot

func _on_inventory_slot_hovered(icon: Control, weapon_id: String):
	if not icon:
		return
		
	# wobble and grow effects for weapon icon
	var tween = create_tween()
	tween.set_parallel(true)  #allows multiple animations
	
	#growing effect (scale up the icon)
	tween.tween_property(icon, "scale", Vector2(1.2, 1.2), 0.2)
	
	#show weapon tooltip
	var mouse_pos = get_global_mouse_position()
	show_weapon_tooltip(weapon_id, mouse_pos)

func _on_inventory_slot_unhovered(icon: Control):
	if not icon:
		return
		
	#reset icon to normal size and rotation
	var tween = create_tween()
	tween.set_parallel(true)
	
	#return to normal scale
	tween.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.2)
	hide_weapon_tooltip()

func create_weapon_tooltip():
	weapon_tooltip = PanelContainer.new()
	weapon_tooltip.name = "WeaponTooltip"
	weapon_tooltip.visible = false
	weapon_tooltip.z_index = 100  
	
	# create tooltip background style
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.9)  
	style_box.border_color = Color(0.5, 1.0, 0.5, 1.0) 
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(5)
	style_box.set_expand_margin_all(5)
	weapon_tooltip.add_theme_stylebox_override("panel", style_box)
	
	var content = VBoxContainer.new()
	content.name = "Content"
	weapon_tooltip.add_child(content)
	
	# Add tooltip to main UI
	add_child(weapon_tooltip)

func show_weapon_tooltip(weapon_id: String, mouse_pos: Vector2):
	if not weapon_tooltip or not player:
		return
	
	var weapon = weapons[weapon_id]
	var content = weapon_tooltip.get_node("Content")
	
	#clear content
	for child in content.get_children():
		child.queue_free()
	
	var name_label = Label.new()
	name_label.text = weapon.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(name_label)
	
	# AP Cost
	var ap_label = Label.new()
	ap_label.text = "AP Cost: " + str(weapon.ap_cost)
	ap_label.add_theme_font_size_override("font_size", 12)
	ap_label.add_theme_color_override("font_color", Color.CYAN)
	content.add_child(ap_label)
	
	# Regex requirement
	var regex_label = Label.new()
	regex_label.text = "Regex: " + str(weapon.regex)
	regex_label.add_theme_font_size_override("font_size", 12)
	regex_label.add_theme_color_override("font_color", Color.YELLOW)
	content.add_child(regex_label)
	
	# Special type
	var special_label = Label.new()
	special_label.text = "Special: " + str(weapon.type)
	special_label.add_theme_font_size_override("font_size", 12)
	special_label.add_theme_color_override("font_color", Color.GOLD)
	content.add_child(special_label)
	
	var desc_label = Label.new()
	desc_label.text = weapon.description
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(200, 0)
	content.add_child(desc_label)
	
	#position tooltip near the mouse but ensure it stays on screen
	weapon_tooltip.position = mouse_pos + Vector2(10, -120)  # Position above the mouse
	weapon_tooltip.visible = true

func hide_weapon_tooltip():
	if weapon_tooltip:
		weapon_tooltip.visible = false

func create_regex_load_panel():
	regex_load_panel = regex_load_panel_scene.instantiate()
	regex_load_panel.scale = Vector2i(3,3) #to make bigger
	regex_load_panel.visible = false  #keep hidden until rght click
	add_child(regex_load_panel)
	
	var save_button = regex_load_panel.get_node("Button")
	if save_button:
		save_button.pressed.connect(_on_regex_save_pressed)
	
	# Make the panel consume input events so they don't propagate
	regex_load_panel.gui_input.connect(_on_regex_panel_input)
	
	regex_load_panel.position = Vector2(10, 10) #can be adjusted - pls make change

func _on_regex_panel_input(event: InputEvent):
	# Consume input events so they don't reach the main _input function
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

func show_regex_load_panel(weapon_id: String):
	if not regex_load_panel or not player:
		return
	
	# Update the weapon icon in the panel
	var weapon_icon = regex_load_panel.get_node("Weapon Icon")
	if weapon_icon:
		# Get weapon texture from the spritesheet
		var weapon_ids = ["baton", "bow", "shotgun", "sniper", "emp_grenade"]
		var weapon_index = weapon_ids.find(weapon_id)
		if weapon_index != -1:
			var spritesheet_texture = load(weapon_spritesheet_path)
			if spritesheet_texture:
				var spritesheet_image = spritesheet_texture.get_image()
				var weapon_x_offset = weapon_index * 16
				var icon_image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
				icon_image.blit_rect(spritesheet_image, Rect2i(weapon_x_offset, 0, 16, 16), Vector2i(0, 0))
				var icon_texture = ImageTexture.new()
				icon_texture.set_image(icon_image)
				weapon_icon.texture = icon_texture
	
	#load current weapon string into the LineEdit
	var line_edit = regex_load_panel.get_node("LineEdit")
	if line_edit and player.weapons.has(weapon_id):
		line_edit.text = player.weapons[weapon_id].loaded_string
	
	# store current weapon ID for saving
	regex_load_panel.set_meta("current_weapon", weapon_id)
	
	# Show the panel
	regex_load_panel.visible = true

func hide_regex_load_panel():
	if regex_load_panel:
		regex_load_panel.visible = false

func _on_regex_save_pressed():
	if not regex_load_panel or not player:
		return
	
	var weapon_id = regex_load_panel.get_meta("current_weapon", "")
	if weapon_id == "":
		return
	
	var line_edit = regex_load_panel.get_node("LineEdit")
	if line_edit and player.current_action_points >= 1:
		var new_string = line_edit.text
		if player.load_string_to_weapon(weapon_id, new_string):
			player.current_action_points -= 1
			update_ui()
			hide_regex_load_panel()
			print("Loaded regex string: ", new_string, " to weapon: ", weapon_id)

func _input(event):
	# Close regex panel with Escape key
	if event.is_action_pressed("ui_cancel"):
		if regex_load_panel and regex_load_panel.visible:
			hide_regex_load_panel()
		elif hacks_panel and hacks_panel.visible:
			hide_hacks_panel()
	
	# Close panels when clicking outside of them
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		
		# Check regex panel
		if regex_load_panel and regex_load_panel.visible:
			# Account for the panel's scale when calculating the rect
			var scaled_size = regex_load_panel.size * regex_load_panel.scale
			var panel_rect = Rect2(regex_load_panel.global_position, scaled_size)
			if not panel_rect.has_point(mouse_pos):
				hide_regex_load_panel()
		
		# Check hacks panel
		elif hacks_panel and hacks_panel.visible:
			# Account for the panel's scale when calculating the rect
			var scaled_size = hacks_panel.size * hacks_panel.scale
			var panel_rect = Rect2(hacks_panel.global_position, scaled_size)
			if not panel_rect.has_point(mouse_pos):
				hide_hacks_panel()

func update_phase_display(is_player_turn: bool):
	if not phase_display_node:
		return
	
	var player_panel = phase_display_node.get_node("Player-Green")
	var enemy_panel = phase_display_node.get_node("Enemy-Red") 
	var phase_label = phase_display_node.get_node("Who-Phase")
	
	if is_player_turn:
		# Player's turn - show green panel, hide red panel
		if player_panel:
			player_panel.visible = true
		if enemy_panel:
			enemy_panel.visible = false
		if phase_label:
			phase_label.text = "Player's Turn"
	else:
		# Enemy's turn - show red panel, hide green panel
		if player_panel:
			player_panel.visible = false
		if enemy_panel:
			enemy_panel.visible = true
		if phase_label:
			phase_label.text = "Enemy's Turn"

func create_hacks_panel():
	hacks_panel = hacks_panel_scene.instantiate()
	hacks_panel.scale = Vector2(4, 4)  # Make bigger
	hacks_panel.visible = false  # Keep hidden until opened
	add_child(hacks_panel)
	
	# Connect hack buttons to their respective functions
	var confuse_button = hacks_panel.get_node("VBoxContainer/Confuse")
	var stun_button = hacks_panel.get_node("VBoxContainer/Stun")
	var overwrite_button = hacks_panel.get_node("VBoxContainer/Overwrite")
	
	if confuse_button:
		confuse_button.pressed.connect(_on_hack_confuse_pressed)
	if stun_button:
		stun_button.pressed.connect(_on_hack_stun_pressed)
	if overwrite_button:
		overwrite_button.pressed.connect(_on_hack_overwrite_pressed)
	
	# Make the panel consume input events so they don't propagate
	hacks_panel.gui_input.connect(_on_hacks_panel_input)
	
	# Position the panel (can be adjusted)
	hacks_panel.position = Vector2(10, 10)

func _on_hacks_panel_input(event: InputEvent):
	# Consume input events so they don't reach the main _input function
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

func show_hacks_panel():
	if not hacks_panel or not player:
		return
	
	# Update button states based on available AP
	var confuse_button = hacks_panel.get_node("VBoxContainer/Confuse")
	var stun_button = hacks_panel.get_node("VBoxContainer/Stun")
	var overwrite_button = hacks_panel.get_node("VBoxContainer/Overwrite")
	
	if confuse_button:
		confuse_button.disabled = player.current_action_points < 2
	if stun_button:
		stun_button.disabled = player.current_action_points < 5
	if overwrite_button:
		overwrite_button.disabled = player.current_action_points < 4
	
	# Show the panel
	hacks_panel.visible = true

func hide_hacks_panel():
	if hacks_panel:
		hacks_panel.visible = false

func _on_hack_stun_pressed():
	if player and is_instance_valid(player):
		player.enter_hack_mode("stun")
		hide_hacks_panel()
		update_ui()

func _on_hack_confuse_pressed():
	if player and is_instance_valid(player):
		player.enter_hack_mode("confuse")
		hide_hacks_panel()
		update_ui()

func _on_hack_overwrite_pressed():
	if player and is_instance_valid(player):
		player.enter_hack_mode("overwrite")
		hide_hacks_panel()
		update_ui()
