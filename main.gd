extends Node2D

@onready var grid_manager = $GridManager
@onready var player = $Player
@onready var enemies = $Enemies
@onready var dungeon_container = $DungeonContainer

var dungeon_scene = preload("res://Level/dungeon_level.tscn")
var dungeon_instance 

var current_turn = "player"
var processing_enemy_turns = false

func _ready():
	# Initialize the game
	$GridManager.current_turn = current_turn
	dungeon_instance = dungeon_scene.instantiate()
	dungeon_container.add_child(dungeon_instance)

func _process(_delta):
	# Handle turn management
	if grid_manager.current_turn == "enemy" and not processing_enemy_turns:
		processing_enemy_turns = true
		process_enemy_turns()

func process_enemy_turns():
	print("Processing enemy turns")
	for enemy in enemies.get_children():
		if enemy and is_instance_valid(enemy):
			print("Processing enemy: ", enemy.name)
			enemy.take_turn()
			# Wait for enemy to complete their turn
			await get_tree().create_timer(1.0).timeout
			enemy.reset_turn()
	print("All enemies processed")
	end_enemy_turn()

func end_player_turn():
	print("Ending player turn")
	current_turn = "enemy"
	$GridManager.current_turn = current_turn
	processing_enemy_turns = false

func end_enemy_turn():
	print("Ending enemy turn")
	current_turn = "player"
	$GridManager.current_turn = current_turn
	reset_player_turn()
	processing_enemy_turns = false

func reset_player_turn():
	var player = $Player
	if player:
		player.reset_turn()

func grid_manager_update_occupied_tiles():
	grid_manager.update_occupied_tiles() 
