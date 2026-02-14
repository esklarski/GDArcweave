## ArcweaveState.gd
## Resource that holds all runtime state for an Arcweave story
## Can be saved/loaded to persist game state

class_name ArcweaveState
extends Resource

## Story variables (shared between manager and interpreter)
@export var variables: Dictionary = {}

## Initial variable values (for reset functionality)
## Treat as read only, or there's going to be issues.
@export var initial_variables: Dictionary = {}

## Visit counts by element ID and title
@export var visit_counts: Dictionary = {}

## Current element being displayed
@export var current_element_id: String = ""

## Element navigation history
@export var element_history: Array[String] = []

## Maximum history size
@export var max_history_size: int = 50

## Localization support
@export var current_locale: String = "en"


## Create a new state with default values
func _init():
	variables = {}
	initial_variables = {}
	visit_counts = {}
	current_element_id = ""
	element_history = []
	current_locale = "en"


## Reset state to initial values
func reset() -> void:
	variables.clear()
	visit_counts.clear()
	current_element_id = ""
	element_history.clear()
	
	reset_variables()


## Reset all variables to initial values.
func reset_variables() -> void:
	for var_name in initial_variables.keys():
		var initial_value = initial_variables[var_name]
		variables[var_name] = initial_value


## Check if variable exists
func has_variable(var_name: String) -> bool:
	return variables.has(var_name)


## Get visit count for an element (by ID or title)
func get_visits(element_key: String) -> int:
	return visit_counts.get(element_key, 0)


## Increment visit count for an element
func increment_visits(element_key: String) -> void:
	visit_counts[element_key] = visit_counts.get(element_key, 0) + 1


## Add element to history
func add_to_history(element_id: String) -> void:
	if element_id != "":
		element_history.append(element_id)
		if element_history.size() > max_history_size:
			element_history.pop_front()


## Get previous element from history
func pop_history() -> String:
	if element_history.size() > 0:
		return element_history.pop_back()
	return ""


## Save state to file
func save_to_file(file_path: String) -> bool:
	var result = ResourceSaver.save(self, file_path)
	if result != OK:
		push_error("Failed to save state to: " + file_path)
		return false
	return true


## Load state from file
static func load_from_file(file_path: String) -> ArcweaveState:
	if not FileAccess.file_exists(file_path):
		push_error("State file not found: " + file_path)
		return null
	
	var state = ResourceLoader.load(file_path)
	if state == null or not state is ArcweaveState:
		push_error("Failed to load state from: " + file_path)
		return null
	
	return state


## Create a duplicate of this state
func duplicate_state() -> ArcweaveState:
	var new_state = ArcweaveState.new()
	new_state.variables = variables.duplicate(true)
	new_state.initial_variables = initial_variables.duplicate(true)
	new_state.visit_counts = visit_counts.duplicate(true)
	new_state.current_element_id = current_element_id
	new_state.element_history = element_history.duplicate()
	new_state.max_history_size = max_history_size
	new_state.current_locale = current_locale
	return new_state
