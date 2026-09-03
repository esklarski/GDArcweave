## arcweave_manager.gd
## Autoload singleton for managing Arcweave projects
## Handles loading, parsing, and navigating Arcweave story data

class_name ArcweaveManagerInstance
extends Node

## Signals for story navigation and events
signal project_updated()
signal element_changed(element: ArcweaveElement)
signal choice_presented(choices: Array)
signal variable_changed(var_name: String, value: Variant)
signal story_started()
signal story_ended()

## If true, project will be scanned for errors on load. See Debugger->Errors for output.
@export var check_project_integrity: bool = false

## The Arcscript interpreter instance
var interpreter: ArcscriptInterpreter

## Localization system instance
var localization: ArcweaveLocalization

## Runtime state (shared with interpreter - single source of truth)
var state: ArcweaveState = ArcweaveState.new()

## Project data
var project: GDArcweaveProject

## Configuration
var auto_evaluate_scripts: bool = true
var track_history: bool = true
var use_extended_html_cleaning: bool = false  # Set to true for more HTML tag support
var parse_color_tags: bool = false  # Set to true to convert HTML color tags
var clean_choice_labels: bool = true  # Set to true to clean HTML from choice button text
var present_choices: bool = true


func _init():
	# Share state with interpreter (single source of truth)
	interpreter = ArcscriptInterpreter.new(self)
	
	# Initialize localization system (pass self for data access)
	localization = ArcweaveLocalization.new(self)
	
	# Set up callback to emit variable changes
	interpreter.variable_changed.connect(variable_changed.emit)


## Load Arcweave project from JSON file
func load_project_from_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		push_error("Arcweave project file not found: " + file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open Arcweave project file: " + file_path)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	if project == null:
		var new_project := GDArcweaveProject.load_project_from_json(json_text)
		
		if not new_project == null:
			return load_from_project_resource(new_project)
		else:
			return false
	elif project.update_project(json_text):
		return load_from_project_resource(project)
	else:
		return false


func load_from_project_resource(project_resource: GDArcweaveProject) -> bool:
	if project_resource == null: return false
	project = project_resource
	
	state.reset(project.initial_variables)
	
	print("Post Initialization time")
	if check_project_integrity: _validate_project_integrity()
	project.post_initialize()
	
	project_updated.emit()
	return true


func has_project() -> bool:
	return project != null


## Start the story from the beginning if no start id is provided.
func start_story(custom_start_id: String = "") -> ArcweaveElement:
	if not has_project():
		printerr("No project, not starting arcweave flow.")
		# skip starting, but signal to allow operation without project
		story_ended.emit()
		return null
	
	# determine starting element
	var start_id: String = ""
	
	if not custom_start_id.is_empty() and project.elements.has(custom_start_id):
		start_id = custom_start_id
	else:
		start_id = project.starting_element_id
	
	if start_id == "":
		push_error("No starting element found")
		return null
	
	# start flow
	story_started.emit()
	return goto_element(start_id)


## Navigate to a specific element
func goto_element(element_id: String, increment_visit: bool = true, add_to_history: bool = true) -> ArcweaveElement:
	# Get element data
	var element: ArcweaveElement = project.elements.get(element_id)
	
	if element:
		# Track history
		if track_history and add_to_history and state.current_element_id != "":
			state.element_history.append(state.current_element_id)
			if state.element_history.size() > state.max_history_size:
				state.element_history.pop_front()
		
		state.current_element_id = element_id
		
		# Get localized title (works for both single and multi-language)
		var element_title = localization.get_element_title(element_id)
		
		# Increment visit count BEFORE evaluation (if not going back)
		# This way, visits() in the content reflects the current visit number
		if increment_visit:
			# By ID exclusively.
			state.increment_visits(element_id)
		
		# Always add evaluated_content to element (even if empty)
		element.evaluated_content = get_evaluated_element_content(element_id)
		
		# Emit signals
		element_changed.emit(element)
		
		if present_choices:
			# Get available choices
			var choices = get_choices_for_element(element_id)
			
			# Emit signals
			if choices.size() > 0:
				choice_presented.emit(choices)
			else:
				# No choices means end of story
				story_ended.emit()
	
	return element


## Get available choices from current element
func get_choices_for_element(element_id: String) -> Array:
	var element: ArcweaveElement = project.elements.get(element_id)
	
	if not element: return []
	
	var outputs := element.outputs
	var choices := []
	
	for output_id in outputs:
		var connection = project.connections.get(output_id)
		if not connection: continue
		
		var target_id = connection.targetid
		
		# Check if it's a branch or direct connection
		match connection.target_type:
			"branches":
				var incoming_label = localization.get_connection_label(output_id)
				if incoming_label == "":
					incoming_label = null
				
				var resolved = _resolve_branch(target_id)
				if resolved.target_id != "":
					var outgoing_label = localization.get_connection_label(resolved.connection_id)
					var label = outgoing_label if outgoing_label != "" else (incoming_label if incoming_label else "")
					choices.append({
						"label": _process_choice_label(label),
						"raw_label": label,
						"target_id": resolved.target_id,
						"branch_id": target_id,
						"connection_id": resolved.connection_id,
					})
			
			"elements":
				# Direct connection to another element
				var label = localization.get_connection_label(output_id)
				
				choices.append({
					"label": _process_choice_label(label),
					"raw_label": label,
					"target_id": target_id,
					"branch_id": "",
					"connection_id": output_id,
				})
			
			"jumpers":
				# Connection to a jumper
				var jumper = project.jumpers[target_id]
				var jumper_element_id = jumper.elementId
				if jumper_element_id != "":
					var label = localization.get_connection_label(output_id)
					
					choices.append({
						"label": _process_choice_label(label),
						"raw_label": label,
						"target_id": jumper_element_id,
						"branch_id": "",
						"connection_id": output_id,
					})
	
	return choices


## Styles text in a mention dictionary. Override to customize behaviour.
func style_mention(mention: Dictionary) -> String:
	return mention.label if mention.type == "component" else mention.id


## Process a choice label (clean HTML and evaluate variables)
func _process_choice_label(label) -> String:
	# set default value for when we find empty strings
	var processed_label: String = "Continue"
	
	if not label == null:
		var label_str := str(label)
		
		if not clean_choice_labels: return label_str
		
		# If auto_evaluate_scripts is enabled, preprocess and evaluate first
		if auto_evaluate_scripts:
			# Preprocess to expose Arcscript (same as element content)
			label_str = ArcweaveUtils.preprocess_arcscript_html(label_str, style_mention)
			
			# Evaluate Arcscript for DISPLAY only (no assignments)
			# Assignments will be executed when the choice is actually made
			label_str = interpreter.evaluate(label_str, true)  # true = skip assignments
			
			label_str = ArcweaveUtils.parse_content(
				label_str,
				use_extended_html_cleaning,
				parse_color_tags
			)
			
			if not label_str.is_empty():
				# only overwrite "Continue" if label contains evaluated content.
				processed_label = label_str
	
	return processed_label


## Get target element from a condition's output connection
func _get_target_from_condition(condition_obj: Dictionary) -> String:
	var output_connection_id = condition_obj.get("output", "")
	if output_connection_id == "":
		return ""
	
	return _get_target_from_connection(output_connection_id)


## Get target element ID from a connection ID
func _get_target_from_connection(connection_id: String) -> String:
	var connection = project.connections.get(connection_id)
	
	if not connection: return ""
	
	var target_id: String = ""
	
	# Check if target is a jumper or branch
	match connection.target_type:
		"elements":
			target_id = connection.targetid
		"jumpers":
			var jumper = project.jumpers.get(connection.targetid)
			if jumper:
				target_id = jumper.elementId
		"branches":
			target_id = _evaluate_branch_to_element(connection.targetid)
	
	return target_id


## Recursively evaluate a branch until we reach an element (or empty if no conditions match)
func _evaluate_branch_to_element(branch_id: String) -> String:
	return _resolve_branch(branch_id).target_id


## Evaluate a branch's conditions in order and return the first that passes.
## Returns a dict with 'target_id' and 'connection_id', or empty strings if none match.
func _resolve_branch(branch_id: String) -> Dictionary:
	var branch = project.branches.get(branch_id)
	if not branch:
		return {"target_id": "", "connection_id": ""}
	
	for condition_id in branch.condition_ids:
		var condition_obj = project.conditions.get(condition_id)
		if not condition_obj:
			continue
		
		var script = ArcweaveUtils.preprocess_arcscript_html(condition_obj.condition_script, style_mention)
		var condition_met = false
		
		if script != null and script != "":
			condition_met = interpreter.evaluate_condition(script)
		else:
			# No script = unconditional (acts as else)
			condition_met = true
		
		if condition_met:
			var connection_id = condition_obj.output
			return {
				"target_id": _get_target_from_connection(connection_id),
				"connection_id": connection_id
			}
	
	return {"target_id": "", "connection_id": ""}


## Make a choice and navigate to the target element
func make_choice(choice: Dictionary) -> ArcweaveElement:
	var target_id = choice.get("target_id", "")
	if target_id == "":
		push_error("Invalid choice: no target_id")
		return null
	
	# Execute any assignments in the choice label (if it had Arcscript)
	var raw_label = choice.get("raw_label", "")
	if auto_evaluate_scripts and raw_label != "":
		# Preprocess and evaluate with assignments ENABLED
		var preprocessed = ArcweaveUtils.preprocess_arcscript_html(raw_label, style_mention)
		interpreter.evaluate(preprocessed, false)  # false = do execute assignments
	
	# Then navigate to target
	return goto_element(target_id)


# ******************** UNTESTED METHODS ********************

## Go back to previous element in history
func go_back() -> ArcweaveElement:
	if state.element_history.size() == 0:
		push_error("No history to go back to")
		return null
	
	var previous_id := state.element_history.pop_back()
	return goto_element(previous_id, false, false)


## Get current element data
func get_current_element() -> ArcweaveElement:
	if state.current_element_id == "":
		return null
	return project.elements.get(state.current_element_id, null)


## Get element by ID
func get_element(element_id: String) -> ArcweaveElement:
	return project.elements.get(element_id, null)


## Get element by title (case-insensitive)
## DEPRECATED -- this is a bad way to get elements...
func get_element_by_title(title: String) -> ArcweaveElement:
	var title_lower := title.to_lower()
	for element_id in project.elements:
		var element := project.elements[element_id]
		if element.title.to_lower() == title_lower:
			return element
	return null


## Get element by title, scoped to a single board (looked up by its customId).
func get_element_from_board_by_title(board_custom_id: String, element_title: String) -> ArcweaveElement:
	var board := get_board_by_custom_id(board_custom_id)
	if board == null:
		push_error("No board found with customId '%s'" % board_custom_id)
		return null

	var title_lower := element_title.to_lower()
	for element_id in board.elements:
		var element: ArcweaveElement = project.elements.get(element_id)
		if element and element.title_cleaned.to_lower() == title_lower:
			return element

	return null


## Get a board by its customId (not its internal Arcweave UUID).
func get_board_by_custom_id(board_custom_id: String) -> ArcweaveBoard:
	for board in project.boards.values():
		if board.custom_id == board_custom_id:
			return board
	return null


## Returns the element's title, localized. Mirrors get_evaluated_element_content()
## but titles don't carry the <pre>/<code> script wrapping content does, so no
## Arcscript evaluation step is needed — just localization + mention styling.
func get_evaluated_element_title(element_id: String) -> String:
	var raw_title := localization.get_element_title(element_id)
	if raw_title == "":
		return ""

	var title_to_process := raw_title
	if auto_evaluate_scripts:
		title_to_process = ArcweaveUtils.preprocess_arcscript_html(raw_title, style_mention)

	return ArcweaveUtils.parse_content(title_to_process, use_extended_html_cleaning, parse_color_tags)


## Returns the element's content, localized, with arcscript evaluated according to preference flags.
## Text will contain bbcode tags, use ArcweaveUtils.strip_bbcode() to remove those too.
func get_evaluated_element_content(element_id: String) -> String:
	# Get localized content (works for both single and multi-language)
	var raw_content := localization.get_element_content(element_id)
	var evaluated_content := ""
	
	if raw_content != "":
		var content_to_evaluate := raw_content
		
		# Preprocess: Remove <code> tags from Arcscript keywords
		# Arcweave wraps if/endif/show/etc in <pre><code> tags
		if auto_evaluate_scripts:
			content_to_evaluate = ArcweaveUtils.preprocess_arcscript_html(raw_content, style_mention)
		
		# Evaluate Arcscript on preprocessed content
		# HTML tags like <a> remain but won't be treated as assignments (see _is_assignment)
		var arcscript_evaluated := content_to_evaluate
		if auto_evaluate_scripts:
			arcscript_evaluated = interpreter.evaluate(content_to_evaluate)
		
		# Then clean remaining HTML and convert to BBCode
		evaluated_content = ArcweaveUtils.parse_content(
			arcscript_evaluated, 
			use_extended_html_cleaning, 
			parse_color_tags
		)
	
	return evaluated_content


## Get component by ID
func get_component(component_id: String) -> ArcweaveComponent:
	return project.components.get(component_id, null)


# ******************** STATE ACCESSORS ********************

## Set a story variable
func set_variable(var_name: String, value) -> void:
	if interpreter.set_variable_value(var_name, value):
		variable_changed.emit(var_name, value)


## Get a story variable
func get_variable(var_name: String, default_value = null):
	var value = interpreter.get_variable_value(var_name)
	if value != null: return value
	return default_value


## Check if variable exists
func has_variable(var_name: String) -> bool:
	return state.has_variable(var_name)


## Get visit count for an element
func get_visits(element_id: String) -> int:
	return state.get_visits(element_id)


## Reset story state (variables and visits)
func reset_story_state() -> void:
	state.reset(project.initial_variables)


# ******************** PROJECT ACCESSORS ********************
# UNTESTED

## Get all elements
func get_all_elements() -> Dictionary:
	return project.elements


## Gets a board by id, returns null if not found.
func get_board(board_id: String) -> ArcweaveBoard:
	return project.boards.get(board_id)


## Get all boards
func get_all_boards() -> Array[ArcweaveBoard]:
	return project.boards.values()


## Get elements on a specific board
func get_elements_on_board(board_id: String) -> Array[ArcweaveElement]:
	var board = project.boards.get(board_id)

	if not board: return []

	var element_ids = board.elements
	var board_elements: Array[ArcweaveElement] = []
	
	for element_id in element_ids:
		var element: ArcweaveElement = project.elements.get(element_id)
		if element:
			board_elements.append(element)
	
	return board_elements


# ******************** DEBUG ********************

## Debug: Print current state
func debug_print_state() -> void:
	print("=== Arcweave Manager State ===")
	print("Current Element: ", state.current_element_id)
	print("Variables: ", state.variables)
	print("Visit Counts: ", state.visit_counts)
	print("History size: ", state.element_history.size())
	print("===============================")


# ******************** PROJECT METADATA ACCESSORS ********************
# UNTESTED

## Get the project name
func get_project_name() -> String:
	return project.project_name


## Get the project cover data
func get_project_cover() -> Dictionary:
	return project.project_cover


## Get the project cover file name (empty string if no cover)
func get_project_cover_file() -> String:
	return project.project_cover.get("file", "")


## Get the project cover type (empty string if no cover)
func get_project_cover_type() -> String:
	return project.project_cover.get("type", "")


## Get the project cover asset (returns full asset Dictionary or empty)
func get_project_cover_asset() -> Dictionary:
	var cover_file = get_project_cover_file()
	if cover_file == "":
		return {}
	
	# Search for asset by filename
	for asset_id in project.assets:
		var asset = project.assets[asset_id]
		if asset.get("name", "") == cover_file:
			return asset
	
	return {}


# ******************** ASSET ACCESSORS ********************
# UNTESTED

## Get asset by ID
func get_asset(asset_id: String) -> Dictionary:
	return project.assets.get(asset_id, {})


## Get asset by filename
func get_asset_by_name(asset_name: String) -> Dictionary:
	for asset_id in project.assets:
		var asset = project.assets[asset_id]
		if asset.get("name", "") == asset_name:
			return asset
	return {}


## Get all assets of a specific type
## Types: "image", "audio", "video", "template-image", "template-audio", "template-video"
func get_assets_by_type(asset_type: String) -> Array:
	var filtered_assets = []
	for asset_id in project.assets:
		var asset = project.assets[asset_id]
		if asset.get("type", "") == asset_type:
			filtered_assets.append(asset)
	return filtered_assets


## Get all image assets (both user-uploaded and template)
func get_all_image_assets() -> Array:
	var images = []
	images.append_array(get_assets_by_type("image"))
	images.append_array(get_assets_by_type("template-image"))
	return images


## Get all audio assets (both user-uploaded and template)
func get_all_audio_assets() -> Array:
	var audio = []
	audio.append_array(get_assets_by_type("audio"))
	audio.append_array(get_assets_by_type("template-audio"))
	return audio


## Get all video assets (both user-uploaded and template)
func get_all_video_assets() -> Array:
	var videos = []
	videos.append_array(get_assets_by_type("video"))
	videos.append_array(get_assets_by_type("template-video"))
	return videos


## Get element's cover asset (returns asset Dictionary or empty)
func get_element_cover_asset(element: ArcweaveElement) -> Dictionary:
	var cover_id = element.cover
	if cover_id == null:
		return {}
	return get_asset(cover_id)


## Get element's audio assets (returns Array of asset Dictionaries)
func get_element_audio_assets(element: ArcweaveElement) -> Array:
	var audio_assets = []
	var assets_data = element.assets
	
	if typeof(assets_data) != TYPE_DICTIONARY:
		return audio_assets
	
	var audio_list = assets_data.get("audio", [])
	if typeof(audio_list) != TYPE_ARRAY:
		return audio_assets
	
	for audio_ref in audio_list:
		if typeof(audio_ref) == TYPE_DICTIONARY:
			var audio_id = audio_ref.get("id", "")
			if audio_id != "" and project.assets.has(audio_id):
				audio_assets.append(project.assets[audio_id])
	
	return audio_assets


## Get element's video assets (returns Array of asset Dictionaries)
func get_element_video_assets(element: ArcweaveElement) -> Array:
	var video_assets = []
	var assets_data = element.assets
	
	if typeof(assets_data) != TYPE_DICTIONARY:
		return video_assets
	
	var video_list = assets_data.get("video", [])
	if typeof(video_list) != TYPE_ARRAY:
		return video_assets
	
	for video_ref in video_list:
		if typeof(video_ref) == TYPE_DICTIONARY:
			var video_id = video_ref.get("id", "")
			if video_id != "" and project.assets.has(video_id):
				video_assets.append(project.assets[video_id])
	
	return video_assets


## Get element's image assets (returns Array of asset Dictionaries)
func get_element_image_assets(element: ArcweaveElement) -> Array:
	var image_assets = []
	var assets_data := element.assets
	
	if typeof(assets_data) != TYPE_DICTIONARY:
		return image_assets
	
	var image_list = assets_data.get("images", [])
	if typeof(image_list) != TYPE_ARRAY:
		return image_assets
	
	for image_ref in image_list:
		if typeof(image_ref) == TYPE_DICTIONARY:
			var image_id = image_ref.get("id", "")
			if image_id != "" and project.assets.has(image_id):
				image_assets.append(project.assets[image_id])
	
	return image_assets


## Get component's cover asset (returns asset Dictionary or empty)
func get_component_cover_asset(component: ArcweaveComponent) -> Dictionary:
	var assets_data = component.assets
	if typeof(assets_data) != TYPE_DICTIONARY:
		return {}
	
	var cover_data = assets_data.get("cover", {})
	if typeof(cover_data) != TYPE_DICTIONARY:
		return {}
	
	var cover_id = cover_data.get("id", "")
	if cover_id == "":
		return {}
	
	return get_asset(cover_id)


## Get all assets (excluding folders)
func get_all_assets() -> Array:
	var all_assets = []
	for asset_id in project.assets:
		var asset = project.assets[asset_id]
		# Skip folders (they have root or children but no name)
		if asset.get("root", false) or asset.get("children", []).size() > 0:
			continue
		all_assets.append(asset)
	return all_assets


# ******************** LOCALIZATION ACCESSORS ********************

## Get available locales
func get_available_locales() -> Array[String]:
	var found_locales: Array[String]
	for thing in project.locales:
		found_locales.append(thing["iso"])
	
	return found_locales


## Get current locale ISO code
func get_current_locale() -> String:
	return project.current_locale


## Check if project is multi-language
func is_multi_language_project() -> bool:
	return project.is_multi_language_project


## Check if a locale is available in the project
func is_locale_available(locale_iso: String) -> bool:
	for locale in project.locales:
		if locale.get("iso", "") == locale_iso:
			return true
	return false


## Set current locale and refresh current element
func set_current_locale(locale_iso: String) -> bool:
	if not localization.change_language(locale_iso):
		return false
	
	# Re-display current element in new language
	if state.current_element_id != "":
		var element := goto_element(state.current_element_id, false)
		if not element == null:
			element_changed.emit(element)
	
	return true


## Get locale name (e.g., "English", "Español")
func get_locale_name(locale_iso: String) -> String:
	return localization.get_locale_name(locale_iso)


# ******************** COMPONENT & ATTRIBUTE ACCESSORS ********************

## Get all component data for an element (returns Array of component Dictionaries)
func get_element_component_data(element: ArcweaveElement) -> Array[ArcweaveComponent]:
	var component_ids := element.components
	var component_data: Array[ArcweaveComponent] = []
	
	for comp_id in component_ids:
		var component := project.components.get(comp_id)
		if component:
			component_data.append(component)
	
	return component_data


## Get a specific component from an element by component name
func get_element_component_by_name(element: ArcweaveElement, component_name: String) -> ArcweaveComponent:
	var component_ids := element.components
	
	for comp_id in component_ids:
		var component := project.components.get(comp_id)
		if component and component.name == component_name:
			return component
	
	return null


## Get all attributes for a component (returns Array of attribute Dictionaries)
func get_component_attributes(component: ArcweaveComponent) -> Array[ArcweaveAttribute]:
	var attribute_ids := component.attributes
	var attribute_data: Array[ArcweaveAttribute] = []
	
	for attr_id in attribute_ids:
		var attribute := project.attributes.get(attr_id)
		if attribute:
			attribute_data.append(attribute)
	
	return attribute_data


## Get a specific attribute from a component by attribute name
## Returns the attribute Dictionary, or empty dict if not found
func get_component_attribute_by_name(component: ArcweaveComponent, attribute_name: String) -> ArcweaveAttribute:
	var attribute_ids := component.attributes
	
	for attr_id in attribute_ids:
		var attribute := project.attributes.get(attr_id)
		if attribute and attribute.name == attribute_name:
			return attribute
	
	return null


## Get an attribute by ID
func get_attribute(attribute_id: String) -> ArcweaveAttribute:
	return project.attributes.get(attribute_id, null)


## Get attribute value by ID
func get_attribute_value(attribute_id: String, default_value = null) -> Variant:
	var attr := get_attribute(attribute_id)
	if attr == null or not attr.has_value():
		return default_value
	
	return attr.get_data()


## Get attribute type
func get_attribute_type(attribute_id: String) -> String:
	var attr := get_attribute(attribute_id)
	if attr == null: return ""
	
	return attr.get_type()


## Convenience method: Get attribute value from component by name
func get_component_attribute_value(component: ArcweaveComponent, attribute_name: String, default_value = null) -> Variant:
	var attribute := get_component_attribute_by_name(component, attribute_name)
	if attribute == null:
		return default_value
	return get_attribute_value(attribute.id, default_value)


## Convenience method: Get attribute from element's component by names
## Usage: get_element_attribute_value(element, "Testing", "name", "default")
func get_element_attribute_value(element: ArcweaveElement, component_name: String, attribute_name: String, default_value = null) -> Variant:
	var component := get_element_component_by_name(element, component_name)
	if component == null:
		return default_value
	
	return get_component_attribute_value(component, attribute_name, default_value)


## Get all sub-components from a component (recursively resolves component-list attributes)
func get_component_subcomponents(component: ArcweaveComponent, recursive: bool = false) -> Array[ArcweaveComponent]:
	var subcomponents: Array[ArcweaveComponent] = []
	var attributes := get_component_attributes(component)
	
	for attr in attributes:
		var attr_type := get_attribute_type(attr.id)
		if attr_type == "component-list":
			var component_ids := get_attribute_value(attr.id, [])
			
			for comp_id in component_ids:
				var subcomp := project.components.get(comp_id)
				if subcomp:
					subcomponents.append(subcomp)
					
					# Recursively get nested subcomponents if requested
					if recursive:
						var nested = get_component_subcomponents(subcomp, true)
						subcomponents.append_array(nested)
	
	return subcomponents


## Debug print all components and attributes for an element
func debug_print_element_components(element: ArcweaveElement) -> void:
	print("=== Element Components Debug ===")
	print("Element ID: ", element.id)
	print("Element Title: ", element.title)
	
	var components_data := get_element_component_data(element)
	print("Components: ", components_data.size())
	
	for comp in components_data:
		print("\n  Component: ", comp.name)
		print("    ID: ", comp.id)
		
		var attrs := get_component_attributes(comp)
		print("    Attributes: ", attrs.size())
		
		for attr in attrs:
			var attr_name := attr.name
			var attr_type := get_attribute_type(attr.id)
			var attr_value := get_attribute_value(attr.id)
			
			print("      - ", attr_name if attr_name != null else "[unnamed]", 
				  " (", attr_type, "): ", attr_value)
			
			# If it's a component-list, show the referenced components
			if attr_type == "component-list":
				var subcomps := get_component_subcomponents(comp, true)
				for subcomp in subcomps:
					print("        -> ", subcomp.name)
	
	print("================================")


## Walk every entity in the project and warn about dangling id references
## (missing components/attributes/outputs/etc). Purely diagnostic - never
## mutates or removes anything. Run once at load so broken data surfaces
## immediately instead of as a blank mention or silent no-op mid-playthrough.
func _validate_project_integrity() -> void:
	var warning_count := 0
	
	for element in project.elements.values():
		for component_id in element.components:
			if not project.components.has(component_id):
				push_warning("Element '%s' (%s) references missing component '%s'" % [element.title, element.id, component_id])
				warning_count += 1
		for attribute_id in element.attributes:
			if not project.attributes.has(attribute_id):
				push_warning("Element '%s' (%s) references missing attribute '%s'" % [element.title, element.id, attribute_id])
				warning_count += 1
		for output_id in element.outputs:
			if not (project.connections.has(output_id) or project.branches.has(output_id) or project.jumpers.has(output_id)):
				push_warning("Element '%s' (%s) references missing output '%s'" % [element.title, element.id, output_id])
				warning_count += 1
	
	for board in project.boards.values():
		for element_id in board.elements:
			if not project.elements.has(element_id):
				push_warning("Board '%s' (%s) references missing element '%s'" % [board.name, board.id, element_id])
				warning_count += 1
		for jumper_id in board.jumpers:
			if not project.jumpers.has(jumper_id):
				push_warning("Board '%s' (%s) references missing jumper '%s'" % [board.name, board.id, jumper_id])
				warning_count += 1
		for branch_id in board.branches:
			if not project.branches.has(branch_id):
				push_warning("Board '%s' (%s) references missing branch '%s'" % [board.name, board.id, branch_id])
				warning_count += 1
		for connection_id in board.connections:
			if not project.connections.has(connection_id):
				push_warning("Board '%s' (%s) references missing connection '%s'" % [board.name, board.id, connection_id])
				warning_count += 1
		for attribute_id in board.variables:
			var attribute: ArcweaveAttribute = project.attributes.get(attribute_id)
			if attribute == null:
				push_warning("Board '%s' (%s) references missing variable/attribute '%s'" % [board.name, board.id, attribute_id])
				warning_count += 1
			elif attribute.cId != "" and attribute.cId != board.id:
				push_warning("Board variable '%s' (%s) cId '%s' does not match owning board '%s'" % [attribute.name, attribute.id, attribute.cId, board.id])
				warning_count += 1
	
	for component in project.components.values():
		for attribute_id in component.attributes:
			var attribute: ArcweaveAttribute = project.attributes.get(attribute_id)
			if attribute == null:
				push_warning("Component '%s' (%s) references missing attribute '%s'" % [component.name, component.id, attribute_id])
				warning_count += 1
			elif attribute.cId != "" and attribute.cId != component.id:
				push_warning("Attribute '%s' (%s) cId '%s' does not match owning component '%s'" % [attribute.name, attribute.id, attribute.cId, component.id])
				warning_count += 1
	
	for connection in project.connections.values():
		if connection.sourceid != "" and not (project.elements.has(connection.sourceid) or project.branches.has(connection.sourceid) or project.conditions.has(connection.sourceid)):
			push_warning("Connection '%s' has missing source element '%s'" % [connection.id, connection.sourceid])
			warning_count += 1
		if connection.targetid != "" and not (project.elements.has(connection.targetid) or project.branches.has(connection.targetid) or project.jumpers.has(connection.targetid)):
			push_warning("Connection '%s' has missing target '%s' (target_type: %s)" % [connection.id, connection.targetid, connection.target_type])
			warning_count += 1
	
	for branch in project.branches.values():
		for condition_id in branch.condition_ids:
			if not project.conditions.has(condition_id):
				push_warning("Branch '%s' references missing condition '%s'" % [branch.id, condition_id])
				warning_count += 1
	
	for jumper in project.jumpers.values():
		if jumper.elementId != "" and not project.elements.has(jumper.elementId):
			push_warning("Jumper '%s' targets missing element '%s'" % [jumper.id, jumper.elementId])
			warning_count += 1
	
	if warning_count > 0:
		push_warning("Arcweave project integrity check found %d issue(s) - see warnings above." % warning_count)
	else:
		print("Arcweave project integrity check passed with no issues.")
