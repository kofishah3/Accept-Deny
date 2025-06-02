extends Node2D
class_name BaseRoom

signal player_entered(room_rect: Rect2)
signal player_exited
signal combat_triggered(room, enemies)

@export var has_combat := false
@export var enemy_data := []  # Array of enemy definitions for this room
@export var combat_positions := []  # Array of Vector2i positions for combatants
@export var room_width: int = 20  # Width in grid cells
@export var room_height: int = 15  # Height in grid cells

var player_in_room := false
var combat_completed := false
var room_rect: Rect2
var room_area: Area2D

func _ready() -> void:
	# Create room area for player detection
	room_area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	var grid_manager = get_node("/root/main/GridManager")
	var cell_size = grid_manager.GRID_SIZE
	shape.size = Vector2(room_width * cell_size, room_height * cell_size)
	collision.shape = shape
	room_area.add_child(collision)
	add_child(room_area)
	
	# Connect area signals
	room_area.body_entered.connect(_on_room_area_entered)
	room_area.body_exited.connect(_on_room_area_exited)
	
	# Calculate room boundaries in world coordinates
	var top_left = grid_manager.grid_to_world(Vector2.ZERO)
	room_rect = Rect2(top_left, Vector2(room_width * cell_size, room_height * cell_size))

func _on_room_area_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not player_in_room:
		player_in_room = true
		player_entered.emit(room_rect)
		
		# Trigger combat if this room has combat and it hasn't been completed
		if has_combat and not combat_completed and enemy_data.size() > 0:
			emit_signal("combat_triggered", self, enemy_data)

func _on_room_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_room = false
		player_exited.emit()

func set_doors(neighbors: Dictionary) -> void:
	$north_door.visible = neighbors.get("up", false)
	$east_door.visible = neighbors.get("right", false)
	$south_door.visible = neighbors.get("down", false)
	$west_door.visible = neighbors.get("left", false)

func get_combat_position() -> Vector2i:
	# Return the player's combat position (usually center of room)
	return Vector2i(5, 5)  # Default to center, override in specific room types if needed

func get_enemy_position(enemy_data: Dictionary) -> Vector2i:
	# Return a position for the enemy based on available combat positions
	if combat_positions.size() > 0:
		return combat_positions[randi() % combat_positions.size()]
	return Vector2i(7, 5)  # Default position if no specific positions defined

func combat_finished() -> void:
	combat_completed = true
	# Add any room-specific logic for when combat is finished
	# For example, opening treasure chests, revealing secrets, etc. 
