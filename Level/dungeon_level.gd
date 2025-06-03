extends Node2D

@export var _dimensions : Vector2i = Vector2i(10,3) #max number of dungeon rooms
@export var _start : Vector2i = Vector2i(0,0) #Starting room is always at (0,0)
@export var _critical_path_length : int = 5 #number of rooms to get to final room (will be overridden by pattern)
@export var _branches : int = 2 #number of extra rooms 
@export var _branch_length : Vector2i = Vector2i(1,1) 
@export var floor_theme : int = 1

@onready var t_room = preload("res://Level/rooms/troom.tscn")
@onready var l_room = preload("res://Level/rooms/lroom.tscn")
@onready var box_room = preload("res://Level/rooms/boxroom.tscn" )
@onready var start_room = preload("res://Level/rooms/startroom.tscn")
@onready var boss_room = preload("res://Level/rooms/bossroom.tscn")

var _branch_candidates : Array[Vector2i] #list of rooms that can have branches
var dungeon : Array #the array should be a dictionary of the level data

var room_pos_data: Dictionary = {} #Position (Vector2) => Array[Vector2] of non-floor tiles

# Door puzzle system
var selected_pattern: Dictionary = {} # The randomly chosen pattern for this dungeon
var door_character_assignments: Dictionary = {} # Maps door positions to characters
var current_hint: String = "" # The hint to display

# Door puzzle patterns - accessible by dungeon rooms
var door_patterns: Dictionary = {
	"12123": {
		"pattern": "12123",
		"hint": "has 121 as substring"
	},
	"33212": {
		"pattern": "33212", 
		"hint": "has 33 as substring"
	},
	"11322": {
		"pattern": "11322",
		"hint": "has 11 as substring"
	},
	"23213": {
		"pattern": "23213",
		"hint": "has 23 as substring"
	},
	"31231": {
		"pattern": "31231",
		"hint": "even 31's"
	},
	"12312": {
		"pattern": "12312", 
		"hint": "even 12's"
	},
	"22223": {
		"pattern": "22223",
		"hint": "has 222 as substring"
	},
	"13131": {
		"pattern": "13131",
		"hint": "has 13 as substring"
	},
	"32213": {
		"pattern": "32213",
		"hint": "has 32 as substring and ends with 3"
	},
	"11122": {
		"pattern": "11122",
		"hint": "has two consecutive 2's and starts with 1"
	}
}

func _ready() -> void:
	# Select random pattern and adjust critical path length
	selected_pattern = get_random_door_pattern()
	_critical_path_length = selected_pattern.pattern.length()
	current_hint = selected_pattern.hint
	
	print("Selected pattern: ", selected_pattern.pattern)
	print("Critical path length: ", _critical_path_length)
	print("Hint: ", current_hint)
	
	#initialize random floor theme
	floor_theme = randi_range(1,3)
	
	_initalize_dungeon()
	_place_entrance()
	_generate_critical_path(_start, _critical_path_length, "C", Vector2i.ZERO)
	_generate_branches()
	_assign_door_characters()
	_print_dungeon()
	_spawn_rooms()
	
func _initalize_dungeon() -> void:
	for x in _dimensions.x:
		dungeon.append([])
		for y in _dimensions.y:
			dungeon[x].append(0)
			
func _place_entrance() -> void:
	dungeon[_start.x][_start.y] = {
		"type": "S",
		"connections": []
	}

func _generate_branches() -> void:
	var branches_created : int = 0
	var candidate : Vector2i
	while branches_created < _branches and _branch_candidates.size():
		candidate = _branch_candidates[randi_range(0, _branch_candidates.size() - 1)]
		if _generate_critical_path(candidate, randi_range(_branch_length.x, _branch_length.y), str(branches_created + 1), Vector2i.ZERO):
			branches_created += 1
		else:
			_branch_candidates.erase(candidate)
	
func _generate_critical_path(from: Vector2i, length: int, marker: String, prev_direction := Vector2i.ZERO) -> bool:
	if length == 0:
		return true

	var current = from
	var directions = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

	#avoid immediately going back the way we came
	if prev_direction != Vector2i.ZERO:
		directions.erase(-prev_direction)  

	directions.shuffle()  #randomize order while keeping bias

	for direction in directions:
		var next = current + direction

		if next.x >= 0 and next.x < _dimensions.x and next.y >= 0 and next.y < _dimensions.y and not dungeon[next.x][next.y]:
			current = next

			#checks if this is the last room (the exit room)
			if length == 1 and marker == "C": 
				dungeon[current.x][current.y] =	{
						"type" : "L",
						"connections" : []			
				}
			else:
				if typeof(dungeon[current.x][current.y]) != TYPE_DICTIONARY: 
					dungeon[current.x][current.y] =	{
						"type" : marker,
						"connections" : []			
					}
			dungeon[current.x][current.y]["connections"].append(-direction) 

			if length > 1:
				_branch_candidates.append(current)

			if _generate_critical_path(current, length - 1, marker, direction):
				return true
			else:
				_branch_candidates.erase(current)
				dungeon[current.x][current.y] = 0
				current -= direction

	return false

#console only
func _print_dungeon() -> void:
	var dungeon_as_string : String = ""
	for y in _dimensions.y:
		for x in _dimensions.x:
			var cell = dungeon[x][y]
			if cell:
				if typeof(cell) == TYPE_DICTIONARY:
					dungeon_as_string += "[" + str(cell["type"]) + "]"
				else:
					dungeon_as_string += "[" + str(cell) + "]"
			else:
				dungeon_as_string += "   "
		dungeon_as_string += "\n"
	print(dungeon_as_string)

func _spawn_rooms() -> void: 
	var cell_size = 16 * 15
	
	for x in _dimensions.x:
		for y in _dimensions.y:
			var marker = dungeon[x][y]
			if marker:
				var variants = [t_room, box_room, l_room]
				var scene: PackedScene
				var room_type = marker["type"] if typeof(marker) == TYPE_DICTIONARY else marker
				match room_type:
					"S":
						scene = start_room
					"L":
						scene = boss_room
					_:
						scene = variants.pick_random()
						
				var room = scene.instantiate()
				room.position = Vector2(x, y) * cell_size
				room.add_to_group("rooms")  # Add room to the rooms group
				
				# Set up combat for non-start rooms
				if room_type != "S":
					room.has_combat = true
				
				add_child(room)
				
				if room.has_method("set_theme"):
					room.set_theme(floor_theme)
				
				var world_pos = room.position/16
				if room.has_method("get_non_floor_tiles"):
					var non_floor_tiles = room.get_non_floor_tiles()
					room_pos_data[world_pos] = non_floor_tiles #populate dictionary with current room data
		
				#handle door visibility based on stored connections
				if typeof(marker) == TYPE_DICTIONARY:
					var connections = marker["connections"]
					
					#check current room's connections (where it came from)
					for dir in connections:
						if dir == Vector2i.UP:
							if room.has_node("north_door"):
								room.get_node("north_door").visible = true
						elif dir == Vector2i.DOWN:
							if room.has_node("south_door"):
								room.get_node("south_door").visible = true
						elif dir == Vector2i.LEFT:
							if room.has_node("west_door"):
								room.get_node("west_door").visible = true
						elif dir == Vector2i.RIGHT:
							if room.has_node("east_door"):
								room.get_node("east_door").visible = true
					
					#check for next room's connections (where it's leading to)
					# right
					if x < _dimensions.x - 1 and typeof(dungeon[x+1][y]) == TYPE_DICTIONARY:
						if Vector2i.LEFT in dungeon[x+1][y]["connections"]:
							if room.has_node("east_door"):
								room.get_node("east_door").visible = true
					# left
					if x > 0 and typeof(dungeon[x-1][y]) == TYPE_DICTIONARY:
						if Vector2i.RIGHT in dungeon[x-1][y]["connections"]:
							if room.has_node("west_door"):
								room.get_node("west_door").visible = true
					# up
					if y > 0 and typeof(dungeon[x][y-1]) == TYPE_DICTIONARY:
						if Vector2i.DOWN in dungeon[x][y-1]["connections"]:
							if room.has_node("north_door"):
								room.get_node("north_door").visible = true
					# down
					if y < _dimensions.y - 1 and typeof(dungeon[x][y+1]) == TYPE_DICTIONARY:
						if Vector2i.UP in dungeon[x][y+1]["connections"]:
							if room.has_node("south_door"):
								room.get_node("south_door").visible = true	
								
func get_room_pos_data() -> Dictionary:
	return room_pos_data

# Helper functions for door patterns - can be called by rooms
func get_door_patterns() -> Dictionary:
	return door_patterns

func get_random_door_pattern() -> Dictionary:
	var pattern_keys = door_patterns.keys()
	var random_key = pattern_keys[randi() % pattern_keys.size()]
	return door_patterns[random_key]

func get_door_pattern_by_key(key: String) -> Dictionary:
	if door_patterns.has(key):
		return door_patterns[key]
	return {}

func validate_door_input(input: String, required_pattern: String) -> bool:
	# This function can be expanded to validate if the input matches the pattern requirements
	return input == required_pattern

func _assign_door_characters() -> void:
	var pattern = selected_pattern.pattern
	
	# Build the critical path sequence starting from the start room
	var critical_path_sequence = build_critical_path_sequence()
	
	print("Critical path sequence: ", critical_path_sequence)
	print("Pattern: ", pattern)
	
	# Assign characters to each room in the sequence
	# The first room (start) doesn't get a character, as it has no entrance door
	# Starting from the second room, assign characters from the pattern
	for i in range(1, min(critical_path_sequence.size(), pattern.length() + 1)):
		var room_pos = critical_path_sequence[i]
		var character_index = i - 1  # Offset by 1 since we skip the start room
		var character = pattern[character_index]
		
		# Store the character assignment for this room's entrance
		door_character_assignments[room_pos] = character
		print("Assigned character '", character, "' to room at ", room_pos, " (sequence index ", i, ")")
	
	# Now assign random characters to non-critical path doors
	assign_random_characters_to_non_critical_doors(pattern, critical_path_sequence)
	
	# Debug: Print final assignments dictionary
	print("Final door_character_assignments: ", door_character_assignments)

func assign_random_characters_to_non_critical_doors(pattern: String, critical_path_sequence: Array[Vector2i]):
	# Always use 1, 2, 3 for non-critical doors to maintain consistency
	var available_numbers = ["1", "2", "3"]
	
	# Find all rooms that exist but are not in the critical path
	var critical_path_set = {}
	for pos in critical_path_sequence:
		critical_path_set[pos] = true
	
	# Scan all rooms and assign random characters to non-critical ones
	for x in _dimensions.x:
		for y in _dimensions.y:
			var room_pos = Vector2i(x, y)
			var marker = dungeon[x][y]
			
			# Skip if no room exists here
			if not marker:
				continue
			
			# All rooms should be dictionaries at this point
			if typeof(marker) != TYPE_DICTIONARY:
				continue
			
			# Skip if this is the start room (no entrance door)
			if room_pos == _start:
				continue
			
			# Skip if this room is already assigned (critical path)
			if critical_path_set.has(room_pos):
				continue
			
			# Assign a random number to this non-critical room
			var random_num = available_numbers[randi() % available_numbers.size()]
			door_character_assignments[room_pos] = random_num
			print("Assigned '", random_num, "' to non-critical room at ", room_pos)

func build_critical_path_sequence() -> Array[Vector2i]:
	var sequence: Array[Vector2i] = []
	var current_pos = _start
	
	# Start with the starting room
	sequence.append(current_pos)
	
	# Follow the connections to build the sequence
	var visited = {}
	visited[current_pos] = true
	
	while sequence.size() <= _critical_path_length:
		var next_pos = find_next_critical_room(current_pos, visited)
		if next_pos == Vector2i(-1, -1):
			break
		
		sequence.append(next_pos)
		visited[next_pos] = true
		current_pos = next_pos
	
	return sequence

func find_next_critical_room(from_pos: Vector2i, visited: Dictionary) -> Vector2i:
	# Check all four directions from the current position
	var directions = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	
	for direction in directions:
		var next_pos = from_pos + direction
		
		# Check bounds
		if next_pos.x < 0 or next_pos.x >= _dimensions.x or next_pos.y < 0 or next_pos.y >= _dimensions.y:
			continue
			
		# Skip if already visited
		if visited.has(next_pos):
			continue
			
		# Check if there's a room at this position
		var room_data = dungeon[next_pos.x][next_pos.y]
		if room_data and typeof(room_data) == TYPE_DICTIONARY:
			var room_type = room_data["type"]
			
			# Check if this is a critical path room (C) or the final room (L)
			if room_type == "C" or room_type == "L":
				# Verify there's a connection between current and next room
				if has_connection_between_rooms(from_pos, next_pos):
					return next_pos
	
	return Vector2i(-1, -1)

func has_connection_between_rooms(pos1: Vector2i, pos2: Vector2i) -> bool:
	var direction = pos2 - pos1
	var room1_data = dungeon[pos1.x][pos1.y]
	var room2_data = dungeon[pos2.x][pos2.y]
	
	if not room1_data or not room2_data:
		return false
	
	if typeof(room1_data) != TYPE_DICTIONARY or typeof(room2_data) != TYPE_DICTIONARY:
		return false
	
	# Check if room2 has a connection coming from the direction of room1
	var reverse_direction = -direction
	return reverse_direction in room2_data["connections"]

# Get the character assigned to a specific room's door
func get_door_character_for_room(room_pos) -> String:
	# Convert to Vector2i if needed (handles both Vector2 and Vector2i input)
	var lookup_pos: Vector2i
	if room_pos is Vector2i:
		lookup_pos = room_pos
	else:
		lookup_pos = Vector2i(int(room_pos.x), int(room_pos.y))
	
	if door_character_assignments.has(lookup_pos):
		var character = door_character_assignments[lookup_pos]
		return character
	else:
		return ""

# Get the current hint for this dungeon
func get_current_hint() -> String:
	return current_hint

# Get the selected pattern information
func get_selected_pattern() -> Dictionary:
	return selected_pattern

# Check if a room is part of the critical path
func is_critical_path_room(room_pos) -> bool:
	# Convert to Vector2i if needed
	var lookup_pos: Vector2i
	if room_pos is Vector2i:
		lookup_pos = room_pos
	else:
		lookup_pos = Vector2i(int(room_pos.x), int(room_pos.y))
	
	return door_character_assignments.has(lookup_pos)
