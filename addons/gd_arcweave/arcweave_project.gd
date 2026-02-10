class_name GDArcweaveProject extends Resource

signal project_updated()

## Exported project JSON. Export project -> JSON
@export_file_path("*.json") var arcweave_project_json: String

## Project metadata
@export var project_name: String = ""
@export var project_cover: Dictionary = {}  # {file: String, type: String}
@export var starting_element_id: String = ""

## Initial variable values (for reset functionality)
@export var initial_variables: Dictionary = {}

## Story structure
@export var boards: Dictionary[StringName, ArcweaveBoard] = {}
@export var elements: Dictionary[StringName, ArcweaveElement] = {}
@export var jumpers: Dictionary[StringName, ArcweaveJumper] = {}
@export var branches: Dictionary[StringName, ArcweaveBranch] = {}
@export var conditions: Dictionary[StringName, ArcscriptCondition] = {}
@export var connections: Dictionary[StringName, ArcweaveConnection] = {}
@export var components: Dictionary[StringName, ArcweaveComponent] = {}
@export var attributes: Dictionary[StringName, ArcweaveAttribute] = {}
@export var assets: Dictionary = {}    # id -> asset data

## Multi-language content storage
@export var is_multi_language_project: bool = false
@export var locales: Array = []  # [{name: "English", iso: "en", base: null}, ...]
@export var contents: Dictionary = {}


## Load Arcweave project from JSON string
static func load_project_from_json(json_text: String) -> GDArcweaveProject:
	var data := parse_arcweave_json(json_text)
	
	if data.is_empty(): return null
	
	var new_project := GDArcweaveProject.new()
	if new_project.load_project_from_data(data):
		return new_project
	else:
		return null


static func parse_arcweave_json(json_text: String) -> Dictionary:
	var json := JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("Failed to parse Arcweave JSON: " + json.get_error_message())
		return {}
	
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid Arcweave data format")
		return {}
	
	return data


func update_project(json_text: String) -> bool:
	var data := parse_arcweave_json(json_text)
	if data.is_empty(): return false
	return load_project_from_data(data)


## Load Arcweave project from Dictionary
func load_project_from_data(data: Dictionary) -> bool:
	# Parse project metadata
	project_name = data.get("name", "")
	# Handle null cover gracefully
	var cover_data = data.get("cover", null)
	if cover_data != null and typeof(cover_data) == TYPE_DICTIONARY:
		project_cover = cover_data
	else:
		project_cover = {}
	
	# Check for multi-language format
	var has_contents = data.has("contents")
	var has_locales = data.has("locales")
	
	if has_contents and has_locales:
		# Multi-language JSON format
		is_multi_language_project = true
		parse_locales(data.get("locales", []))
		parse_contents(data.get("contents", {}))
		print("Multi-language project detected - ", locales.size(), " languages")
	else:
		# Single-language JSON format
		is_multi_language_project = false
		locales.clear()
		contents.clear()
		# state.current_locale = "en"
		print("Single-language project detected")
	
	# Parse all the different entity types
	_parse_boards(data.get("boards", {}))
	_parse_elements(data.get("elements", {}))
	_parse_jumpers(data.get("jumpers", {}))
	_parse_branches(data.get("branches", {}))
	_parse_conditions(data.get("conditions", {}))  # Parse conditions
	_parse_connections(data.get("connections", {}))
	_parse_components(data.get("components", {}))
	_parse_attributes(data.get("attributes", {}))  # Parse attributes
	_parse_assets(data.get("assets", {}))
	
	# Find starting element
	starting_element_id = _find_starting_element(data)
	
	# Initialize variables from project
	_initialize_project_variables(data.get("variables", {}))
	
	print("Arcweave project imported successfully")
	print("  Project name: ", project_name)
	print("  Elements: ", elements.size())
	print("  Boards: ", boards.size())
	print("  Branches: ", branches.size())
	print("  Components: ", components.size())
	print("  Starting element: ", starting_element_id)
	if not project_cover.is_empty():
		print("  Project cover: ", project_cover.get("file", ""))
	
	project_updated.emit()
	#TODO: some actual error checking....
	return true


## Parse locales from multi-language project data
func parse_locales(locales_data: Array) -> void:
	locales.clear()
	
	for locale_data in locales_data:
		if typeof(locale_data) == TYPE_DICTIONARY:
			locales.append({
				"name": locale_data.get("name", ""),
				"iso": locale_data.get("iso", ""),
				"base": locale_data.get("base", null)
			})


## Parse contents from multi-language project data
func parse_contents(contents_data: Dictionary) -> void:
	contents.clear()
	
	for item_id in contents_data:
		contents[item_id] = contents_data[item_id]


## Parse elements from project data
func _parse_elements(elements_data: Dictionary) -> void:
	elements.clear()
	
	for element_id in elements_data:
		var element = elements_data[element_id]
		elements[element_id] = ArcweaveElement.from_dict(element, element_id)


## Parse boards from project data
func _parse_boards(boards_data: Dictionary) -> void:
	boards.clear()
	
	for board_id in boards_data:
		var board = boards_data[board_id]

		if not board.has("children"):
			boards[board_id] = ArcweaveBoard.from_dict(board, board_id)


## Parse jumpers from project data
func _parse_jumpers(jumpers_data: Dictionary) -> void:
	jumpers.clear()
	
	for jumper_id in jumpers_data:
		var jumper = jumpers_data[jumper_id]
		jumpers[jumper_id] = ArcweaveJumper.from_dict(jumper, jumper_id)


## Parse branches from project data
func _parse_branches(branches_data: Dictionary) -> void:
	branches.clear()
	
	for branch_id in branches_data:
		var branch = branches_data[branch_id]
		branches[branch_id] = ArcweaveBranch.from_dict(branch, branch_id)


## Parse conditions from project data
func _parse_conditions(conditions_data: Dictionary) -> void:
	conditions.clear()
	
	for condition_id in conditions_data:
		var condition = conditions_data[condition_id]
		conditions[condition_id] = ArcscriptCondition.from_dict(condition, condition_id)


## Parse connections from project data
func _parse_connections(connections_data: Dictionary) -> void:
	connections.clear()
	
	for connection_id in connections_data:
		var connection = connections_data[connection_id]
		connections[connection_id] = ArcweaveConnection.from_dict(connection, connection_id)


## Parse components from project data
func _parse_components(components_data: Dictionary) -> void:
	components.clear()
	
	for component_id in components_data:
		var component = components_data[component_id]
		
		# We don't care about "folder" components
		if not component.has("children"):
			components[component_id] =  ArcweaveComponent.from_dict(component, component_id)


## Parse attributes from project data
func _parse_attributes(attributes_data: Dictionary) -> void:
	attributes.clear()
	
	for attribute_id in attributes_data:
		var attribute = attributes_data[attribute_id]
		attributes[attribute_id] = ArcweaveAttribute.from_dict(attribute, attribute_id)


## Parse assets from project data
func _parse_assets(assets_data: Dictionary) -> void:
	assets.clear()
	
	for asset_id in assets_data:
		var asset = assets_data[asset_id]
		assets[asset_id] = {
			"id": asset_id,
			"name": asset.get("name", ""),
			"type": asset.get("type", ""),  # image, audio, video, template-image, template-audio, template-video
			"root": asset.get("root", false),
			"children": asset.get("children", []),
		}


## Initialize project variables
func _initialize_project_variables(variables_data: Dictionary) -> void:
	# Arcweave variables are organized in a tree (folders and variables)
	# Only items with "name" are actual variables
	for var_id in variables_data:
		var var_data = variables_data[var_id]
		
		# Skip folders (they have "root" or "children" but no "name")
		if not var_data.has("name"):
			continue
		
		var var_name = var_data.get("name", "")
		if var_name == "":
			continue
		
		var value = var_data.get("value", null)
		
		# Convert type if specified
		var var_type = var_data.get("type", "")
		
		# Proper type conversion
		match var_type:
			"integer", "number":
				if value != null:
					value = int(value)
				else:
					value = 0
			
			"boolean", "bool":
				if value != null:
					# Handle various boolean representations
					if typeof(value) == TYPE_STRING:
						value = value.to_lower() in ["true", "1", "yes"]
					else:
						value = bool(value)
				else:
					value = false
			
			"string":
				value = str(value) if value != null else ""
			
			_:
				# Keep original value for unknown types
				pass
		
		# Store initial values
		initial_variables[var_name] = value  # Store for reset() and resetAll()
		print("  Initialized variable: ", var_name, " = ", value)


## Find the starting element (first element in root board)
func _find_starting_element(data: Dictionary) -> String:
	# Try to find the starting element
	# Method 1: Check for startingElement field (can be null)
	var starting_id = data.get("startingElement", null)
	if starting_id != null and typeof(starting_id) == TYPE_STRING and starting_id != "":
		return starting_id
	
	# Method 2: Look for root board's starting element
	var boards_data = data.get("boards", {})
	if typeof(boards_data) == TYPE_DICTIONARY:
		for board_id in boards_data:
			var board = boards_data[board_id]
			if typeof(board) == TYPE_DICTIONARY and board.get("root", false):
				var elements_list = board.get("elements", [])
				if typeof(elements_list) == TYPE_ARRAY and elements_list.size() > 0:
					return elements_list[0]
	
	# Method 3: Just return the first element
	var elements = data.get("elements","")
	if elements.size() > 0:
		return elements.keys()[0]
	
	return ""
