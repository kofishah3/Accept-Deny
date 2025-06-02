extends Node

var floor_decor: Array[Vector2i] = [
	Vector2i(1,10), Vector2i(2,10), Vector2i(3,10), Vector2i(4,10),
	Vector2i(1,11), Vector2i(2,11), Vector2i(3,11), Vector2i(4,11),
	Vector2i(1,12), Vector2i(2,12), Vector2i(3,12), Vector2i(4,12),
	Vector2i(1,13), Vector2i(2,13), Vector2i(3,13), Vector2i(4,13),
	Vector2i(1,14), Vector2i(2,14), Vector2i(3,14), Vector2i(4,14),
]

var wall_decor: Array[Vector2i] = [
	Vector2i(1,1), Vector2i(2,1), Vector2i(3,1), Vector2i(4,1),
	Vector2i(1,2), Vector2i(2,2), Vector2i(3,2), Vector2i(4,2),
	Vector2i(1,3), Vector2i(2,3), Vector2i(3,3), Vector2i(4,3),
	Vector2i(1,4), Vector2i(2,4), Vector2i(3,4), Vector2i(4,4),
	Vector2i(1,5), Vector2i(2,5), Vector2i(3,5), Vector2i(4,5),
	Vector2i(1,6), Vector2i(2,6), Vector2i(3,6), Vector2i(4,6),
]

func get_random_floor_decor() -> Vector2i:
	#Returns a random atlas coord from the list
	return floor_decor.pick_random()

func get_random_wall_decor() -> Vector2i:
	#Returns a random atlas coord from the list
	return wall_decor.pick_random()
