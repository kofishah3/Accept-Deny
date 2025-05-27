extends Node2D

@export var _dimensions : Vector2i = Vector2i(7,5) #max number of dungeon rooms
@export var _start : Vector2i = Vector2i(-1,-1)
@export var _critical_path_length : int = 6
@export var _branches : int = 3
@export var _branch_length : Vector2i = Vector2i(1,2)

var _branch_candidates : Array[Vector2i] #list of rooms that can have branches
var dungeon : Array

func _ready() -> void:
	_initalize_dungeon()
	_place_entrance()
	_generate_critical_path(_start, _critical_path_length, "C")
	_generate_branches()
	_print_dungeon()
	queue_redraw()
	
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
		if _generate_critical_path(candidate, randi_range(_branch_length.x, _branch_length.y), str(branches_created + 1)):
			branches_created += 1
		else:
			_branch_candidates.erase(candidate)
	
func _generate_critical_path(from: Vector2i, length : int, marker : String) -> bool:
	if length == 0: #return path successful has reached the end
		return true
		
	var current : Vector2i = from
	var direction : Vector2i
	match randi_range(0, 3):
		0:
			direction = Vector2i.UP
		1:
			direction = Vector2i.RIGHT
		2:
			direction = Vector2i.DOWN
		3:
			direction = Vector2i.LEFT
#	makes sure that the chosen direction is vlid and can keep producing more rooms
	for i in 4:
		if (current.x + direction.x >= 0 and current.x + direction.x < _dimensions.x 
		and current.y + direction.y >= 0 and current.y + direction.y < _dimensions.y
		and not dungeon[current.x + direction.x][current.y + direction.y]):
			current += direction
			if length == 1 and marker == "C":
				dungeon[current.x][current.y] = "L"
			else:			
				dungeon[current.x][current.y] = marker
			if length > 1:
				_branch_candidates.append(current)
			if _generate_critical_path(current, length - 1, marker):				
				return true
			else:
				_branch_candidates.erase(current)
				dungeon[current.x][current.y] = 0
				current -= direction
		direction = Vector2i(direction.y, -direction.x)
	return false
			
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

#for debugging just drawing rectangles for now instead of using the actual tiles
func _draw() -> void:
	var cell_size = 16
	for x in _dimensions.x:
		for y in _dimensions.y:
			var value = dungeon[x][y]
			if value:
				var pos = Vector2(x, y) * cell_size
				var color : Color
				match value:
					"S":
						color = Color.GREEN
					"C":
						color = Color.BLUE
					"L":
						color = Color.GOLD
					_:
						color = Color.RED
				draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), color)
