extends Node2D

func _on_restart_pressed():
	get_tree().change_scene_to_file("res://main.tscn")

func _on_exit_pressed():
	get_tree().change_scene_to_file("res://ui/main-menu screen/main_menu.tscn")
