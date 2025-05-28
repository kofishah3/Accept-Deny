extends Node2D

@export var _dimensions : Vector2i = Vector2i(10,3) #max number of dungeon rooms
@export var _start : Vector2i = Vector2i(-1,-1)
@export var _critical_path_length : int = 6
@export var _branches : int = 2
@export var _branch_length : Vector2i = Vector2i(1,2)

@onready var t_room = preload("res://Level/rooms/dungeon_room1.tscn")
@onready var l_room = preload("res://Level/rooms/dungeon_room2.tscn")
@onready var box_room = preload("res://Level/rooms/dungeon_room3.tscn")

var _branch_candidates : Array[Vector2i] #list of rooms that can have branches
var dungeon : Array

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
	dungeon[_start.x][_start.y] = "S"

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

			if length == 1 and marker == "C":
				dungeon[current.x][current.y] = "L"
			else:
				dungeon[current.x][current.y] = marker

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
			if dungeon[x][y]:
				dungeon_as_string += "[" + str(dungeon[x][y]) + "]"
			else:
				dungeon_as_string += "   "
		dungeon_as_string += "\n"
	print(dungeon_as_string)

func _spawn_rooms() -> void: 
	var cell_size = 16 * 10
	
	for x in _dimensions.x:
		for y in _dimensions.y:
			var marker = dungeon[x][y]
			if marker:
				var scene: PackedScene
				match marker:
					"S":
						scene = box_room
					"C":
						scene = box_room
					"L":
						scene = t_room
					_:
						scene = l_room
				var room = scene.instantiate()
				room.position = Vector2(x, y) * cell_size
				add_child(room)
