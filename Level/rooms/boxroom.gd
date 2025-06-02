extends "res://Level/rooms/base_room.gd"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	add_to_group("rooms")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func set_doors(neighbors: Dictionary) -> void:
	$north_door.visible = neighbors.get("up", false)
	$east_door.visible = neighbors.get("right", false)
	$south_door.visible = neighbors.get("down", false)
	$west_door.visible = neighbors.get("left", false)
