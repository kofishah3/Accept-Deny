extends Node2D

@onready var grid_manager = $GridManager
@onready var player = $Player
@onready var enemies = $Enemies
@onready var dungeon_container = $DungeonContainer

var dungeon_scene = preload("res://Level/dungeon_level.tscn")
var dungeon_instance 

var current_turn = "player"
var processing_enemy_turns = false

var room_and_wall_data : Dictionary = {}

func _ready():
	# Initialize the game
	$GridManager.current_turn = current_turn
	dungeon_instance = dungeon_scene.instantiate()
	dungeon_container.add_child(dungeon_instance)
	
	#get the room world positions and their wall data
	if dungeon_instance.has_method("get_room_pos_data"):
		room_and_wall_data = dungeon_instance.get_room_pos_data()
			
	for room_pos in room_and_wall_data.keys():
		#print(str(room_pos) + " " + str(room_and_wall_data[room_pos])) #printing the rooms data
		var wall_local_positions = room_and_wall_data[room_pos] #the positiosn relative to the room itself
		var wall_global_positions: Array[Vector2i] = []
		
		var room_pos_vec2 = room_pos as Vector2i
		
		for local_pos in wall_local_positions: 
			wall_global_positions.append(room_pos_vec2 + local_pos) #overall positions

		if grid_manager.has_method("mark_unwalkable_tiles"):
			grid_manager.mark_unwalkable_tiles(wall_global_positions)
			
		#var wall_positions = room_and_wall_data
		pass

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
