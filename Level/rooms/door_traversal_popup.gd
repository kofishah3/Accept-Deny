extends Control

signal door_traversal_confirmed(door_name: String)
signal door_traversal_cancelled

var current_door_name: String = ""
var current_room: BaseRoom = null

@onready var yes_button = $CenterContainer/PanelContainer/VBoxContainer/HBoxContainer/YesButton
@onready var no_button = $CenterContainer/PanelContainer/VBoxContainer/HBoxContainer/NoButton
@onready var label = $CenterContainer/PanelContainer/VBoxContainer/Label

func _ready():
	# Connect button signals
	yes_button.pressed.connect(_on_yes_button_pressed)
	no_button.pressed.connect(_on_no_button_pressed)
	
	# Hide by default
	visible = false

func show_door_prompt(door_name: String, room: BaseRoom):
	current_door_name = door_name
	current_room = room
	
	# Get the character assigned to this door's destination
	var door_text = get_door_display_text_for_destination(room, door_name)
	label.text = door_text
	
	visible = true
	
	# Pause the game while showing the popup
	var player = get_node("/root/main/Player")
	if player:
		player.is_interacting_with_ui = true

func get_door_display_text_for_destination(room: BaseRoom, door_name: String) -> String:
	# Get the dungeon level to check for character assignments
	var dungeon_container = get_node("/root/main/DungeonContainer")
	
	if dungeon_container and dungeon_container.get_child_count() > 0:
		var dungeon_level = dungeon_container.get_child(0)
		
		# Get this room's grid position
		var current_room_pos = room.get_room_grid_position()
		
		# Calculate the destination room position based on door direction
		var door_direction = get_door_direction_vector(door_name)
		var destination_room_pos = current_room_pos + door_direction
		
		# Check if the destination room has an assigned character
		var assigned_character = dungeon_level.get_door_character_for_room(destination_room_pos)
		
		if assigned_character != "":
			return "  " + assigned_character.to_upper() + "  "
		else:
			return "  Traverse?  "
	
	return "  Traverse?  "

func get_door_direction_vector(door_name: String) -> Vector2i:
	match door_name:
		"north_door": return Vector2i(0, -1)  # Going up decreases Y
		"south_door": return Vector2i(0, 1)   # Going down increases Y
		"east_door": return Vector2i(1, 0)    # Going right increases X
		"west_door": return Vector2i(-1, 0)   # Going left decreases X
		_: return Vector2i(0, 0)

func _on_yes_button_pressed():
	# Confirm traversal
	if current_room:
		current_room.teleport_player_through_door(current_door_name)
	hide_popup()

func _on_no_button_pressed():
	# Cancel traversal
	hide_popup()

func hide_popup():
	visible = false
	current_door_name = ""
	current_room = null
	
	# Resume the game
	var player = get_node("/root/main/Player")
	if player:
		player.is_interacting_with_ui = false 
