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
	
	# Wait for dungeon to be ready
	await get_tree().create_timer(0.1).timeout
	
	# Spawn player and enemy in starting room
	spawn_player_and_enemy()

func spawn_player_and_enemy():
	# Find the starting room
	var start_room = null
	for room in dungeon_container.get_children():
		if room.is_in_group("rooms") and room.name.begins_with("startroom"):
			start_room = room
			break
	
	if start_room:
		# Get the room's position and dimensions
		var room_pos = start_room.position
		var room_rect = Rect2(room_pos, Vector2(start_room.room_width * grid_manager.GRID_SIZE, start_room.room_height * grid_manager.GRID_SIZE))
		
		# Spawn player in front of the door (assuming south door)
		var door_pos = start_room.get_node("south_door").position
		# Offset player position: 16 pixels right and 32 pixels down from the door
		player.position = room_pos + door_pos + Vector2(16, 32)
		player.grid_position = grid_manager.world_to_grid(player.position)
		
		# Spawn enemy in a random position away from player
		var enemy = enemies.get_node("Enemy1")
		var valid_positions = []
		
		# Generate valid positions within the room
		for x in range(1, start_room.room_width - 1):
			for y in range(1, start_room.room_height - 1):
				var pos = Vector2(x, y)
				var world_pos = room_pos + pos * grid_manager.GRID_SIZE
				var grid_pos = grid_manager.world_to_grid(world_pos)
				
				# Check if position is at least 2 tiles away from player
				if grid_pos.distance_to(player.grid_position) >= 2:
					valid_positions.append(world_pos)
		
		if valid_positions.size() > 0:
			var spawn_pos = valid_positions[randi() % valid_positions.size()]
			enemy.position = spawn_pos
			enemy.grid_position = grid_manager.world_to_grid(spawn_pos)
		
		# Update occupied tiles
		grid_manager.update_occupied_tiles()

func _process(_delta):
	# Handle turn management
	if grid_manager.current_turn == "enemy" and not processing_enemy_turns:
		processing_enemy_turns = true
		process_enemy_turns()

func process_enemy_turns():
	print("Processing enemy turns")
	var active_enemies = []
	
	# First, collect all active enemies
	for enemy in enemies.get_children():
		if enemy and is_instance_valid(enemy) and enemy.is_player_in_range():
			active_enemies.append(enemy)
	
	# Process only active enemies
	for enemy in active_enemies:
		print("Processing enemy: ", enemy.name)
		enemy.take_turn()
		# Wait a shorter time for active enemies
		await get_tree().create_timer(0.3).timeout
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
