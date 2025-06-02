extends Node2D

@export var _dimensions : Vector2i = Vector2i(10,3) #max number of dungeon rooms
@export var _start : Vector2i = Vector2i(0,0) #-1, -1 for completely random start point
@export var _critical_path_length : int = 5 #number of rooms to get to final room
@export var _branches : int = 2 #number of extra rooms 
@export var _branch_length : Vector2i = Vector2i(1,1) 
@export var floor_theme : int = 3

@onready var t_room = preload("res://Level/rooms/troom.tscn")
@onready var l_room = preload("res://Level/rooms/lroom.tscn")
@onready var box_room = preload("res://Level/rooms/boxroom.tscn")
@onready var start_room = preload("res://Level/rooms/startroom.tscn")

var _branch_candidates : Array[Vector2i] #list of rooms that can have branches
var dungeon : Array #the array should be a dictionary of the level data

func _ready() -> void:
	_initalize_dungeon()
	_place_entrance()
	_generate_critical_path(_start, _critical_path_length, "C", Vector2i.ZERO)
	_generate_branches()
	_print_dungeon()
	_spawn_rooms()
	
func _initalize_dungeon() -> void:
	for x in _dimensions.x:
		dungeon.append([])
		for y in _dimensions.y:
			dungeon[x].append(0)
			
func _place_entrance() -> void:
	if _start.x < 0 or _start.x >= _dimensions.x:
		_start.x = randi_range(0, _dimensions.x - 1)
	if _start.y < 0 or _start.y >= _dimensions.y:
		_start.y = randi_range(0, _dimensions.y - 1)
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
	for y in range(_dimensions.y - 1, -1, -1):
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
		for y in range(_dimensions.y - 1, -1, -1):
			var marker = dungeon[x][y]
			if marker:
				var variants = [t_room, box_room]
				var scene: PackedScene
				var room_type = marker["type"] if typeof(marker) == TYPE_DICTIONARY else marker
				match room_type:
					"S":
						scene = start_room
					"L":
						scene = l_room
					_:
						scene = variants.pick_random()
						
				var room = scene.instantiate()
				room.position = Vector2(x, _dimensions.y - 1 - y) * cell_size
				room.add_to_group("rooms")  # Add room to the rooms group
				add_child(room)
				
				if room.has_method("set_theme"):
					room.set_theme(floor_theme)
				
				#handle door visibility based on stored connections
				if typeof(marker) == TYPE_DICTIONARY:
					var connections = marker["connections"]
					
					#check current room's connections (where it came from)
					for dir in connections:
						if dir == Vector2i.UP:
							if room.has_node("south_door"):
								room.get_node("south_door").visible = true
						elif dir == Vector2i.DOWN:
							if room.has_node("north_door"):
								room.get_node("north_door").visible = true
						elif dir == Vector2i.LEFT:
							if room.has_node("east_door"):
								room.get_node("east_door").visible = true
						elif dir == Vector2i.RIGHT:
							if room.has_node("west_door"):
								room.get_node("west_door").visible = true
					
					#check for next room's connections (where it's leading to)
					# right
					if x < _dimensions.x - 1 and typeof(dungeon[x+1][y]) == TYPE_DICTIONARY:
						if Vector2i.LEFT in dungeon[x+1][y]["connections"]:
							if room.has_node("west_door"):
								room.get_node("west_door").visible = true
					# left
					if x > 0 and typeof(dungeon[x-1][y]) == TYPE_DICTIONARY:
						if Vector2i.RIGHT in dungeon[x-1][y]["connections"]:
							if room.has_node("east_door"):
								room.get_node("east_door").visible = true
					# up
					if y > 0 and typeof(dungeon[x][y-1]) == TYPE_DICTIONARY:
						if Vector2i.DOWN in dungeon[x][y-1]["connections"]:
							if room.has_node("south_door"):
								room.get_node("south_door").visible = true
					# down
					if y < _dimensions.y - 1 and typeof(dungeon[x][y+1]) == TYPE_DICTIONARY:
						if Vector2i.UP in dungeon[x][y+1]["connections"]:
							if room.has_node("north_door"):
								room.get_node("north_door").visible = true
