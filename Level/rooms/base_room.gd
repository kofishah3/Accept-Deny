extends Node2D
class_name BaseRoom

signal player_entered(room)
signal combat_triggered(room, enemies)

@export var has_combat := false
@export var enemy_data := []  # Array of enemy definitions for this room
@export var combat_positions := []  # Array of Vector2i positions for combatants

var player_in_room := false
var combat_completed := false

func _ready() -> void:
	# Connect to area signals for player detection
	for door in [$north_door, $east_door, $south_door, $west_door]:
		if door.has_node("Area2D"):
			door.get_node("Area2D").connect("body_entered", Callable(self, "_on_door_area_entered"))
			door.get_node("Area2D").connect("body_exited", Callable(self, "_on_door_area_exited"))

func _on_door_area_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not player_in_room:
		player_in_room = true
		emit_signal("player_entered", self)
		
		# Trigger combat if this room has combat and it hasn't been completed
		if has_combat and not combat_completed and enemy_data.size() > 0:
			emit_signal("combat_triggered", self, enemy_data)

func _on_door_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_room = false

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
