## arcweave_manager.gd
## Autoload singleton for managing Arcweave projects
## Handles loading, parsing, and navigating Arcweave story data

class_name ArcweaveManagerInstance
extends Node

## Signals for story navigation and events
signal element_changed(element: ArcweaveElement)
signal choice_presented(choices: Array)
signal variable_changed(var_name: String, value: Variant)
signal story_started()
signal story_ended()

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


func _init():
	# Share state with interpreter (single source of truth)
	interpreter = ArcscriptInterpreter.new(self)
	
	# Initialize localization system (pass self for data access)
	localization = ArcweaveLocalization.new(self)
	
	# Set up callback to emit variable changes
	interpreter.on_variable_changed = func(var_name: String, value: Variant):
		variable_changed.emit(var_name, value)


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
		state.initial_variables = project.initial_variables
		state.reset()
		return true
	else:
		return false


func load_from_project_resource(project_resource: GDArcweaveProject) -> bool:
	project = project_resource
	
	state.initial_variables = project_resource.initial_variables
	state.reset()
	
	return not project_resource == null


func has_project() -> bool:
	return project != null


## Start the story from the beginning if no start id is provided.
func start_story(custom_start_id: String = "") -> void:
	# Determine starting element
	var start_id = custom_start_id if custom_start_id != "" else project.starting_element_id
	
	if start_id == "":
		push_error("No starting element found")
		return
	
	story_started.emit()
	goto_element(start_id)


## Navigate to a specific element
func goto_element(element_id: String, increment_visit: bool = true) -> ArcweaveElement:
	if not project.elements.has(element_id):
		push_error("Element not found: " + element_id)
		return null
	
	# Track history
	if track_history and state.current_element_id != "":
		state.element_history.append(state.current_element_id)
		if state.element_history.size() > state.max_history_size:
			state.element_history.pop_front()
	
	state.current_element_id = element_id
	
	# Get element data
	var element: ArcweaveElement = project.elements[element_id]
	
	# Get localized title (works for both single and multi-language)
	var element_title = localization.get_element_title(element_id)
	
	# Increment visit count BEFORE evaluation (if not going back)
	# This way, visits() in the content reflects the current visit number
	if increment_visit:
		
		# By ID (note: state.visit_counts and interpreter.visit_tracker are the same dictionary)
		state.visit_counts[element_id] = state.visit_counts.get(element_id, 0) + 1
		
		# Also track by element title for easier Arcscript references
		if element_title != "":
			# Clean HTML from title (titles can have HTML tags in Arcweave)
			var clean_title = ArcweaveUtils.strip_bbcode(
				ArcweaveUtils.clean_string(element_title)
			).strip_edges()
			
			if clean_title != "":
				state.visit_counts[clean_title] = state.visit_counts.get(clean_title, 0) + 1
	
	# Get localized content (works for both single and multi-language)
	var raw_content = localization.get_element_content(element_id)
	var evaluated_content = ""
	
	if raw_content != "":
		var content_to_evaluate = raw_content
		
		# Preprocess: Remove <code> tags from Arcscript keywords
		# Arcweave wraps if/endif/show/etc in <pre><code> tags
		if auto_evaluate_scripts:
			content_to_evaluate = ArcweaveUtils.preprocess_arcscript_html(raw_content)
		
		# Evaluate Arcscript on preprocessed content
		# HTML tags like <a> remain but won't be treated as assignments (see _is_assignment)
		var arcscript_evaluated = content_to_evaluate
		if auto_evaluate_scripts:
			arcscript_evaluated = interpreter.evaluate(content_to_evaluate)
		
		# Then clean remaining HTML and convert to BBCode
		evaluated_content = ArcweaveUtils.parse_content(
			arcscript_evaluated, 
			use_extended_html_cleaning, 
			parse_color_tags
		)
	
	# Always add evaluated_content to element (even if empty)
	element["evaluated_content"] = evaluated_content
	
	# Get available choices
	var choices = get_choices_for_element(element_id)
	
	# Emit signals
	element_changed.emit(element)
	if choices.size() > 0:
		choice_presented.emit(choices)
	else:
		# No choices means end of story
		story_ended.emit()
	
	return element


## Get available choices from current element
func get_choices_for_element(element_id: String) -> Array:
	if not project.elements.has(element_id):
		return []
	
	var element: ArcweaveElement = project.elements[element_id]
	var outputs := element.outputs
	var choices := []
	
	for output_id in outputs:
		# Get the connection
		if not project.connections.has(output_id):
			continue
		
		var connection = project.connections[output_id]
		var target_id = connection.targetid
		
		# Check if it's a branch or direct connection
		if project.branches.has(target_id):
			# It's a branch - evaluate conditions
			var branch = project.branches[target_id]
			var condition_ids = branch.condition_ids
			
			# Store the incoming connection label (element -> branch) as fallback
			var incoming_label = localization.get_connection_label(output_id)
			if incoming_label == "":
				incoming_label = null
			
			var condition_met = false
			var output_target = ""
			var output_connection_id = ""
			
			# Evaluate conditions (if any)
			if condition_ids.size() > 0:
				for condition_id in condition_ids:
					if project.conditions.has(condition_id):
						var condition_obj = project.conditions[condition_id]
						var script = condition_obj.condition_script
						if script != null and script != "":
							condition_met = interpreter._evaluate_condition(script)
						else:
							# No script means unconditional (like else)
							condition_met = true
						
						if condition_met:
							# Get the output connection for this condition
							output_connection_id = condition_obj.output
							output_target = _get_target_from_connection(output_connection_id)
							break
			
			if condition_met and output_target != "":
				# CORRECTED LABEL LOGIC (matching official web player):
				var label = null
				
				# FIRST: Try outgoing connection label (condition -> element)
				if output_connection_id != "":
					var outgoing_label = localization.get_connection_label(output_connection_id)
					if outgoing_label != "":
						label = outgoing_label
				
				# SECOND: If outgoing is null, try incoming connection label (element -> branch)
				if label == null:
					label = incoming_label
				
				# FOURTH: Final fallback
				if label == null:
					label = "Continue"
				
				choices.append({
					"label": _process_choice_label(label),
					"raw_label": label,
					"target_id": output_target,
					"branch_id": target_id,
					"connection_id": output_connection_id,
				})
		
		elif project.elements.has(target_id):
			# Direct connection to another element
			var label = localization.get_connection_label(output_id)
			if label == "" or label == null:
				label = "Continue"
			choices.append({
				"label": _process_choice_label(label),
				"raw_label": label,
				"target_id": target_id,
				"branch_id": "",
				"connection_id": output_id,
			})
		
		elif project.jumpers.has(target_id):
			# Connection to a jumper
			var jumper = project.jumpers[target_id]
			var jumper_element_id = jumper.elementId
			if jumper_element_id != "":
				var label = localization.get_connection_label(output_id)
				if label == "" or label == null:
					label = "Continue"
				choices.append({
					"label": _process_choice_label(label),
					"raw_label": label,
					"target_id": jumper_element_id,
					"branch_id": "",
					"connection_id": output_id,
				})
	
	return choices


## Process a choice label (clean HTML and evaluate variables)
func _process_choice_label(label) -> String:
	# Handle null or non-string labels
	if label == null:
		return "Continue"
	
	var label_str = str(label)
	
	if not clean_choice_labels or label_str.is_empty():
		return label_str if label_str != "" else "Continue"
	
	var processed_label = label_str
	
	# If auto_evaluate_scripts is enabled, preprocess and evaluate first
	if auto_evaluate_scripts:
		# Preprocess to expose Arcscript (same as element content)
		processed_label = ArcweaveUtils.preprocess_arcscript_html(label_str)
		
		# Evaluate Arcscript for DISPLAY only (no assignments)
		# Assignments will be executed when the choice is actually made
		processed_label = interpreter.evaluate(processed_label, true)  # true = skip assignments
	
	# Then clean any remaining HTML and convert to BBCode
	processed_label = ArcweaveUtils.parse_content(
		processed_label,
		use_extended_html_cleaning,
		parse_color_tags
	)
	
	return processed_label


## Get target element from a condition's output connection
func _get_target_from_condition(condition_obj: Dictionary) -> String:
	var output_connection_id = condition_obj.get("output", "")
	if output_connection_id == "":
		return ""
	
	return _get_target_from_connection(output_connection_id)


## Get target element ID from a connection ID
func _get_target_from_connection(connection_id: String) -> String:
	if not project.connections.has(connection_id):
		return ""
	
	var connection = project.connections[connection_id]
	var target_id = connection.targetid
	
	# Check if target is a jumper
	if project.jumpers.has(target_id):
		var jumper = project.jumpers[target_id]
		target_id = jumper.elementId
	
	# Check if target is a branch - recursively evaluate it
	if project.branches.has(target_id):
		target_id = _evaluate_branch_to_element(target_id)
	
	return target_id


## Recursively evaluate a branch until we reach an element (or empty if no conditions match)
func _evaluate_branch_to_element(branch_id: String) -> String:
	if not project.branches.has(branch_id):
		return ""
	
	var branch = project.branches[branch_id]
	var condition_ids = branch.condition_ids
	
	# Evaluate conditions in order
	for condition_id in condition_ids:
		if not project.conditions.has(condition_id):
			continue
		
		var condition_obj = project.conditions[condition_id]
		var script = condition_obj.condition_script
		var condition_met = false
		
		if script != null and script != "":
			condition_met = interpreter._evaluate_condition(script)
		else:
			# No script means unconditional (like else)
			condition_met = true
		
		if condition_met:
			# Get the output connection for this condition
			var output_connection_id = condition_obj.output
			if output_connection_id == "":
				return ""
			
			# Recursively resolve the target (might be another branch, jumper, or element)
			return _get_target_from_connection(output_connection_id)
	
	# No conditions matched - return empty (dead end)
	return ""


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
		var preprocessed = ArcweaveUtils.preprocess_arcscript_html(raw_label)
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
	state.current_element_id = previous_id
	
	# Don't add to history or increment visits when going back
	var old_track := track_history
	track_history = false
	var element := goto_element(previous_id, false)  # false = don't increment visits
	track_history = old_track
	
	return element


## Get current element data
func get_current_element() -> ArcweaveElement:
	if state.current_element_id == "":
		return null
	return project.elements.get(state.current_element_id, null)


## Get element by ID
func get_element(element_id: String) -> ArcweaveElement:
	return project.elements.get(element_id, null)


## Get element by title (case-insensitive)
func get_element_by_title(title: String) -> ArcweaveElement:
	var title_lower := title.to_lower()
	for element_id in project.elements:
		var element := project.elements[element_id]
		if element.title.to_lower() == title_lower:
			return element
	return null


## Get component by ID
func get_component(component_id: String) -> ArcweaveComponent:
	return project.components.get(component_id, {})


# ******************** STATE ACCESSORS ********************

## Set a story variable
func set_variable(var_name: String, value) -> void:
	state.set_variable(var_name, value)
	variable_changed.emit(var_name, value)


## Get a story variable
func get_variable(var_name: String, default_value = null):
	return state.get_variable(var_name, default_value)


## Check if variable exists
func has_variable(var_name: String) -> bool:
	return state.has_variable(var_name)


## Get visit count for an element
func get_visits(element_id: String) -> int:
	return state.get_visits(element_id)


## Reset story state (variables and visits)
func reset_story_state() -> void:
	state.reset()
	state.reset_variables()


# ******************** PROJECT ACCESSORS ********************
# UNTESTED

## Get all elements
func get_all_elements() -> Dictionary:
	return project.elements


## Get all boards
func get_all_boards() -> Array[ArcweaveBoard]:
	return project.boards.values()


## Get elements on a specific board
func get_elements_on_board(board_id: String) -> Array[ArcweaveElement]:
	if not project.boards.has(board_id):
		return []
	
	var board = project.boards[board_id]
	var element_ids = board.elements
	var board_elements: Array[ArcweaveElement] = []
	
	for element_id in element_ids:
		if project.elements.has(element_id):
			board_elements.append(project.elements[element_id])
	
	return board_elements


# ******************** LOAD/SAVE STATE ********************
# UNTESTED

## Save story state to a dictionary (for compatibility)
func save_state() -> Dictionary:
	return state.to_dict()


## Load story state from a dictionary (for compatibility)
func load_state(data: Dictionary) -> void:
	state.from_dict(data)
	
	# Emit current element
	if state.current_element_id != "" and project.elements.has(state.current_element_id):
		element_changed.emit(project.elements[state.current_element_id])


## Save state to file (new Resource-based save)
func save_state_to_file(file_path: String) -> bool:
	return state.save_to_file(file_path)


## Load state from file (new Resource-based load)
func load_state_from_file(file_path: String) -> bool:
	var loaded_state = ArcweaveState.load_from_file(file_path)
	if loaded_state == null:
		return false
	
	# Replace our state with the loaded one
	state = loaded_state
	
	# Re-share with interpreter and localization
	interpreter.state = loaded_state
	localization.state = loaded_state
	
	# Emit current element
	if state.current_element_id != "" and project.elements.has(state.current_element_id):
		element_changed.emit(project.elements[state.current_element_id])
	
	return true


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
		if project.components.has(comp_id):
			component_data.append(project.components[comp_id])
	
	return component_data


## Get a specific component from an element by component name
func get_element_component_by_name(element: ArcweaveElement, component_name: String) -> ArcweaveComponent:
	var component_ids := element.components
	
	for comp_id in component_ids:
		if project.components.has(comp_id):
			var comp := project.components[comp_id]
			if comp.name == component_name:
				return comp
	
	return null


## Get all attributes for a component (returns Array of attribute Dictionaries)
func get_component_attributes(component: ArcweaveComponent) -> Array[ArcweaveAttribute]:
	var attribute_ids := component.attributes
	var attribute_data: Array[ArcweaveAttribute] = []
	
	for attr_id in attribute_ids:
		if project.attributes.has(attr_id):
			attribute_data.append(project.attributes[attr_id])
	
	return attribute_data


## Get a specific attribute from a component by attribute name
## Returns the attribute Dictionary, or empty dict if not found
func get_component_attribute_by_name(component: ArcweaveComponent, attribute_name: String) -> ArcweaveAttribute:
	var attribute_ids := component.attributes
	
	for attr_id in attribute_ids:
		if project.attributes.has(attr_id):
			var attr := project.attributes[attr_id]
			if attr.name == attribute_name:
				return attr
	
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
				if project.components.has(comp_id):
					var subcomp := project.components[comp_id]
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
