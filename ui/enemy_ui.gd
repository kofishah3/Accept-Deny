extends Control

func _ready():
	# Set the UI to be visible above other elements
	show_behind_parent = false
	top_level = true
	
	# Remove AP-related nodes if they exist
	if has_node("ActionPointsBar"):
		$ActionPointsBar.queue_free()
	if has_node("ActionPointsLabel"):
		$ActionPointsLabel.queue_free() 