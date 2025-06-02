extends Control

signal door_traversal_confirmed(door_name: String)
signal door_traversal_cancelled

var current_door_name: String = ""
var current_room: BaseRoom = null

@onready var yes_button = $CenterContainer/PanelContainer/VBoxContainer/HBoxContainer/YesButton
@onready var no_button = $CenterContainer/PanelContainer/VBoxContainer/HBoxContainer/NoButton

func _ready():
	# Connect button signals
	yes_button.pressed.connect(_on_yes_button_pressed)
	no_button.pressed.connect(_on_no_button_pressed)
	
	# Hide by default
	visible = false

func show_door_prompt(door_name: String, room: BaseRoom):
	current_door_name = door_name
	current_room = room
	visible = true
	
	# Pause the game while showing the popup
	var player = get_node("/root/main/Player")
	if player:
		player.is_interacting_with_ui = true

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
