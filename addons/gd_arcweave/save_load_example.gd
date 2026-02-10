## save_load_example.gd
## Example showing how to save and load Arcweave state

extends Node


func _ready():
	# Example 1: Save state to Resource file (.tres or .res)
	save_state_example()
	
	# Example 2: Load state from Resource file
	load_state_example()
	
	# Example 3: Set variables from external scripts
	set_variables_example()


## Save current story state to a file
func save_state_example():
	# Save as text resource (.tres) - human readable
	var success = ArcweaveManager.save_state_to_file("user://save_game.tres")
	if success:
		print("State saved to user://save_game.tres")
	
	# Or save as binary resource (.res) - smaller, faster
	success = ArcweaveManager.save_state_to_file("user://save_game.res")
	if success:
		print("State saved to user://save_game.res")


## Load story state from a file
func load_state_example():
	var success = ArcweaveManager.load_state_from_file("user://save_game.tres")
	if success:
		print("State loaded from user://save_game.tres")
		print("Current element: ", ArcweaveManager.state.current_element_id)
		print("Variables: ", ArcweaveManager.state.variables)
		print("Visits: ", ArcweaveManager.state.visit_counts)


## Set variables from your game code
func set_variables_example():
	# Direct access to state (single source of truth!)
	ArcweaveManager.state.variables["player_name"] = "Alice"
	ArcweaveManager.state.variables["gold"] = 100
	ArcweaveManager.state.variables["has_key"] = true
	
	# Or use the convenience method (also emits signal)
	ArcweaveManager.set_variable("health", 50)
	
	# Check variables
	var health = ArcweaveManager.get_variable("health", 100)
	print("Player health: ", health)
	
	# Check visits
	var painting_visits = ArcweaveManager.state.get_visits("Examine the painting")
	print("Times examined painting: ", painting_visits)


## Example: Auto-save on element change
func setup_autosave():
	ArcweaveManager.element_changed.connect(_on_element_changed)


func _on_element_changed(element: Dictionary):
	# Auto-save whenever the player moves to a new element
	ArcweaveManager.save_state_to_file("user://autosave.res")
	print("Auto-saved!")


## Example: Save/Load UI buttons
func _on_save_button_pressed():
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_USERDATA
	file_dialog.filters = ["*.tres ; Text Resource", "*.res ; Binary Resource"]
	file_dialog.file_selected.connect(func(path):
		ArcweaveManager.save_state_to_file(path)
		print("Saved to: ", path)
	)
	add_child(file_dialog)
	file_dialog.popup_centered()


func _on_load_button_pressed():
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_USERDATA
	file_dialog.filters = ["*.tres ; Text Resource", "*.res ; Binary Resource"]
	file_dialog.file_selected.connect(func(path):
		ArcweaveManager.load_state_from_file(path)
		print("Loaded from: ", path)
	)
	add_child(file_dialog)
	file_dialog.popup_centered()


## Example: Access state for debugging
func debug_current_state():
	print("=== Current Arcweave State ===")
	print("Element: ", ArcweaveManager.state.current_element_id)
	print("Variables:")
	for var_name in ArcweaveManager.state.variables:
		print("  ", var_name, " = ", ArcweaveManager.state.variables[var_name])
	print("Visit counts:")
	for element_key in ArcweaveManager.state.visit_counts:
		print("  ", element_key, " = ", ArcweaveManager.state.visit_counts[element_key])
