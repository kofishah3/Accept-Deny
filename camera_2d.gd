extends Camera2D

@export var transition_speed: float = 2.0
@export var zoom_speed: float = 2.0
@export var room_padding: float = 1.2  # Add 20% padding around the room

var target_position: Vector2
var target_zoom: Vector2
var is_transitioning: bool = false
var player: Node2D
var current_room_rect: Rect2
var is_in_room: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get the player node
	player = get_node("/root/main/Player")
	
	# Connect to all room signals
	for room in get_tree().get_nodes_in_group("rooms"):
		room.player_entered.connect(_on_room_player_entered)
		room.player_exited.connect(_on_room_player_exited)
	
	# Set initial position to player
	if player:
		position = player.position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_transitioning:
		# Smoothly move camera to target position
		position = position.lerp(target_position, delta * transition_speed)
		
		# Smoothly adjust zoom
		zoom = zoom.lerp(target_zoom, delta * zoom_speed)
		
		# Check if we're close enough to target to stop transitioning
		if position.distance_to(target_position) < 1.0 and zoom.distance_to(target_zoom) < 0.01:
			is_transitioning = false
			position = target_position
			zoom = target_zoom
	elif is_in_room:
		# Stay centered on the room
		position = current_room_rect.get_center()
	else:
		# Follow player when not in a room
		position = player.position

func _on_room_player_entered(room_rect: Rect2) -> void:
	is_in_room = true
	current_room_rect = room_rect
	
	# Calculate the center of the room
	target_position = room_rect.get_center()
	
	# Calculate zoom level to fit the room with padding
	var viewport_size = get_viewport_rect().size
	var room_size = room_rect.size * room_padding
	var zoom_x = viewport_size.x / room_size.x
	var zoom_y = viewport_size.y / room_size.y
	target_zoom = Vector2(min(zoom_x, zoom_y), min(zoom_x, zoom_y))
	
	# Start transition
	is_transitioning = true

func _on_room_player_exited() -> void:
	is_in_room = false
	target_zoom = Vector2.ONE  # Reset to default zoom
	is_transitioning = true
