## ArcscriptInterpreter.gd
## Evaluates Arcscript using Godot's Expression class
## Handles conditionals, assignments, functions, and text output

class_name ArcscriptInterpreter
extends RefCounted


## Game Manager
var manager: ArcweaveManagerInstance = null

## Registry of shadow variables and their callbacks
## Format: { "variable_name": Callable }
var _shadow_variables: Dictionary = {}

## Callback for when variables change (so manager can stay in sync)
var on_variable_changed: Callable = Callable()


func _init(arcweave_manager: ArcweaveManagerInstance) -> void:
	manager = arcweave_manager


## Main entry point: evaluate a complete Arcscript segment
func evaluate(arcscript_text: String, skip_assignments: bool = false) -> String:
	if arcscript_text.is_empty():
		return ""
	
	var lines = arcscript_text.split("\n")
	var output = ""
	var i = 0
	
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("//"):
			i += 1
			continue
		
		# Handle conditionals
		if line.begins_with("if "):
			var result = _evaluate_conditional_block(lines, i, skip_assignments)
			# Add space before conditional content if we already have output
			if output != "" and result.text != "" and not output.ends_with(" "):
				output += " "
			output += result.text
			i = result.next_line
			continue
		
		# Handle assignments
		elif _is_assignment(line):
			if not skip_assignments:
				_evaluate_assignment(line)
			i += 1
			continue
		
		# Handle show() function
		elif line.begins_with("show("):
			output += _evaluate_show(line)
			i += 1
			continue
		
		# Regular text (possibly with inline expressions)
		else:
			output += _evaluate_text_line(line) + _end_of_line(i, line, lines)
			i += 1
	
	return output.strip_edges()


## Get the value for a variable,
## or calls registered callback if it's a shadowed variable.
## [br]
## Returns null if the variable doesn't exist
func get_variable_value(variable_name: String) -> Variant:
	# Check if it's a shadow variable first
	if _shadow_variables.has(variable_name):
		var callback: Callable = _shadow_variables[variable_name]
		return callback.call()
	
	# Otherwise, return the stored value
	return manager.state.variables.get(variable_name, null)


## Set the value for a variable.
## [br]
## Returns false if variable is shadowed or does not exist.
func set_variable_value(variable_name: String, value: Variant) -> bool:
	# Check if it's a shadow variable first
	if _shadow_variables.has(variable_name):
		push_warning("Tried to set shadowed variable: \"%s\" near element: %s" % [ variable_name, manager.state.current_element_id ])
	elif manager.has_variable(variable_name):
		manager.state.variables[variable_name] = value
		return true

	return false


func get_shadowed_variable_default_value(variable_name: String) -> Variant:
	if not is_shadow_variable(variable_name): return null

	return manager.state.variables.get(variable_name, null)


## Register a shadow variable with a custom callback.
## [br]
## [variable_name]: The name of the variable in Arcweave
## [br]
## [callback]: A Callable that returns the value for this variable
## [br]
## Example:
## [codeblock]
## register_shadow_variable("random_bark", func() -> String:
##     return ["Woof!", "Bark!", "Arf!"].pick_random()
## )
## [/codeblock]
func register_shadow_variable(variable_name: String, callback: Callable) -> void:
	if not callback.is_valid():
		push_error("Invalid callback provided for shadow variable: " + variable_name)
		return
	
	_shadow_variables[variable_name] = callback
	
	# Ensure the variable exists in Arcweave's global variables with a placeholder
	# This allows it to be referenced in expressions without errors
	if not manager.state.variables.has(variable_name):
		manager.state.variables[variable_name] = null


## Unregister a shadow variable.
func unregister_shadow_variable(variable_name: String) -> void:
	_shadow_variables.erase(variable_name)


## Check if a variable is a registered shadow variable.
func is_shadow_variable(variable_name: String) -> bool:
	return _shadow_variables.has(variable_name)


## Clear all shadow variables
func clear_all_shadow_variables() -> void:
	_shadow_variables.clear()


## Get all registered shadow variable names.
func get_shadow_variable_names() -> Array[String]:
	var names: Array[String] = []
	for key in _shadow_variables.keys():
		names.append(key)
	return names


## Register multiple shadow variables at once.
## [br]
## [variables]: [Dictionary] { "var_name": Callable }
## [br]
## Example:
## [codeblock]
## interpreter.register_shadow_variables({
##     "random_bark": func() -> String: return ["Woof!", "Bark!"].pick_random(),
##     "current_time": func() -> String: return Time.get_time_string_from_system()
## })
## [/codeblock]
func register_shadow_variables(variables: Dictionary) -> void:
	for var_name in variables:
		var callback = variables[var_name]
		if callback is Callable:
			register_shadow_variable(var_name, callback)
		else:
			push_error("Invalid callback for variable '%s': expected Callable" % var_name)


## Evaluate a single line of text (may contain inline expressions)
func _evaluate_text_line(line: String) -> String:
	# Handle {expression} syntax for inline evaluation
	var result = line
	var regex = RegEx.new()
	regex.compile("\\{([^}]+)\\}")
	
	for match_result in regex.search_all(line):
		var expr_text = match_result.get_string(1)
		var value = _evaluate_expression(expr_text)
		result = result.replace(match_result.get_string(0), str(value))
	
	return result


## Check if a line is an assignment statement
func _is_assignment(line: String) -> bool:
	# Must contain = but not comparison operators
	if not "=" in line:
		return false
	if "==" in line or "!=" in line or ">=" in line or "<=" in line:
		return false
	
	# Don't match HTML tags (they start with <)
	var trimmed = line.strip_edges()
	if trimmed.begins_with("<"):
		return false
	
	# Must have format: variable_name = value or variable_name += value
	# Variable names must be valid identifiers (letters, numbers, underscores)
	# and must come before the = sign
	var has_valid_var = false
	for op in ["+=", "-=", "*=", "/=", "="]:
		if op in line:
			var parts = line.split(op, true, 1)
			if parts.size() == 2:
				var var_name = parts[0].strip_edges()
				# Check if it's a valid identifier
				if var_name != "" and not " " in var_name and not "<" in var_name:
					has_valid_var = true
					break
	
	return has_valid_var


## Evaluate an assignment statement
func _evaluate_assignment(line: String) -> void:
	# Handle compound operators: +=, -=, *=, /=
	var var_name = ""
	var expr_text = ""
	var operator = ""
	
	# Check for compound assignment operators
	if "+=" in line:
		var parts = line.split("+=", true, 1)
		if parts.size() == 2:
			var_name = parts[0].strip_edges()
			expr_text = parts[1].strip_edges()
			operator = "+"
	elif "-=" in line:
		var parts = line.split("-=", true, 1)
		if parts.size() == 2:
			var_name = parts[0].strip_edges()
			expr_text = parts[1].strip_edges()
			operator = "-"
	elif "*=" in line:
		var parts = line.split("*=", true, 1)
		if parts.size() == 2:
			var_name = parts[0].strip_edges()
			expr_text = parts[1].strip_edges()
			operator = "*"
	elif "/=" in line:
		var parts = line.split("/=", true, 1)
		if parts.size() == 2:
			var_name = parts[0].strip_edges()
			expr_text = parts[1].strip_edges()
			operator = "/"
	else:
		# Regular assignment: variable = expression
		var parts = line.split("=", true, 1)
		if parts.size() != 2:
			push_error("Invalid assignment: " + line)
			return
		var_name = parts[0].strip_edges()
		expr_text = parts[1].strip_edges()
	
	if var_name == "" or expr_text == "":
		push_error("Invalid assignment: " + line)
		return
	
	# Evaluate the right side expression
	var value = _evaluate_expression(expr_text)
	
	if value != null:
		# For compound operators, combine with existing value
		if operator != "":
			var current_value = manager.state.variables.get(var_name, 0)
			if operator == "+":
				value = current_value + value
			elif operator == "-":
				value = current_value - value
			elif operator == "*":
				value = current_value * value
			elif operator == "/":
				if value != 0:
					value = current_value / value
				else:
					push_error("Division by zero in assignment: " + line)
					return
		
		set_variable_value(var_name, value)
		
		# Notify manager if callback is set
		if on_variable_changed.is_valid():
			on_variable_changed.call(var_name, value)


## Evaluate a conditional block (if/elseif/else/endif)
## TODO: adding new lines "\n" or "\n\n" needs more testing.
func _evaluate_conditional_block(lines: Array, start_index: int, skip_assignments: bool = false) -> Dictionary:
	var output = ""
	var i = start_index
	var condition_met = false
	
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		# if statement
		if line.begins_with("if "):
			var condition = line.substr(3).strip_edges()
			condition_met = _evaluate_condition(condition)
			i += 1
			
			if condition_met:
				# Execute this block
				var block_result = _execute_block_until_else_or_endif(lines, i, skip_assignments)
				output += block_result.text + "\n"
				i = _skip_to_endif(lines, i)
				break
			else:
				i = _skip_to_else_or_endif(lines, i)
		
		# elseif statement
		elif line.begins_with("elseif "):
			var condition = line.substr(7).strip_edges()
			condition_met = _evaluate_condition(condition)
			i += 1
			
			if condition_met:
				var block_result = _execute_block_until_else_or_endif(lines, i, skip_assignments)
				output += block_result.text + "\n\n"
				i = _skip_to_endif(lines, i)
				break
			else:
				i = _skip_to_else_or_endif(lines, i)
		
		# else statement
		elif line.begins_with("else"):
			i += 1
			var block_result = _execute_block_until_endif(lines, i, skip_assignments)
			output += block_result.text + "\n\n"
			i = _skip_to_endif(lines, i)
			break
		
		# endif statement
		elif line.begins_with("endif"):
			i += 1
			break
		
		else:
			i += 1
	
	return {"text": output, "next_line": i}


## Execute lines until else, elseif, or endif
func _execute_block_until_else_or_endif(lines: Array, start_index: int, skip_assignments: bool = false) -> Dictionary:
	var output = ""
	var i = start_index
	
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		if line.begins_with("elseif ") or line.begins_with("else") or line.begins_with("endif"):
			break
		
		# Recursively handle nested conditionals
		if line.begins_with("if "):
			var result = _evaluate_conditional_block(lines, i, skip_assignments)
			output += result.text
			i = result.next_line
		elif _is_assignment(line):
			if not skip_assignments:
				_evaluate_assignment(line)
			i += 1
		elif line.begins_with("show("):
			output += _evaluate_show(line)
			i += 1
		elif not line.is_empty() and not line.begins_with("//"):
			output += _evaluate_text_line(line) + _end_of_line(i, line, lines)
			i += 1
		else:
			i += 1
	
	return {"text": output, "next_line": i}


## Execute lines until endif
func _execute_block_until_endif(lines: Array, start_index: int, skip_assignments: bool = false) -> Dictionary:
	var output = ""
	var i = start_index
	
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		if line.begins_with("endif"):
			break
		
		if line.begins_with("if "):
			var result = _evaluate_conditional_block(lines, i, skip_assignments)
			output += result.text
			i = result.next_line
		elif _is_assignment(line):
			if not skip_assignments:
				_evaluate_assignment(line)
			i += 1
		elif line.begins_with("show("):
			output += _evaluate_show(line)
			i += 1
		elif not line.is_empty() and not line.begins_with("//"):
			output += _evaluate_text_line(line) + _end_of_line(i, line, lines)
			i += 1
		else:
			i += 1
	
	return {"text": output, "next_line": i}


## Skip lines until else, elseif, or endif
func _skip_to_else_or_endif(lines: Array, start_index: int) -> int:
	var i = start_index
	var depth = 1
	
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		if line.begins_with("if "):
			depth += 1
		elif line.begins_with("endif"):
			depth -= 1
			if depth == 0:
				return i
		elif (line.begins_with("elseif ") or line.begins_with("else")) and depth == 1:
			return i
		
		i += 1
	
	return i


## Skip lines until endif
func _skip_to_endif(lines: Array, start_index: int) -> int:
	var i = start_index
	var depth = 1
	
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		if line.begins_with("if "):
			depth += 1
		elif line.begins_with("endif"):
			depth -= 1
			if depth == 0:
				return i + 1
		
		i += 1
	
	return i


func _end_of_line(i: int, line: String, lines: Array) -> String:
	if i == (lines.size() - 1):
		return ""
	elif i < (lines.size() - 1):
		var next_line: String = lines[i+1].strip_edges()
		# Add a space before show() since it's inline content that needs separation
		if next_line.contains("show"):
			return " "
		# Don't add newlines if next line is a control structure - they should flow inline
		if next_line.begins_with("if ") or next_line.begins_with("endif") or next_line.begins_with("elseif ") or next_line.begins_with("else"):
			return ""
	
	return "\n\n"


## Evaluate a boolean condition
func _evaluate_condition(condition_text: String) -> bool:
	var normalized = _normalize_arcscript(condition_text)
	
	# Special handling: if the condition is just "visits(...)" without a comparison,
	# treat it as "visits(...) > 0" (Arcweave convention)
	if normalized.strip_edges().begins_with("visits(") and not (">" in normalized or "<" in normalized or "==" in normalized or "!=" in normalized):
		normalized = normalized.strip_edges() + " > 0"
	
	if _is_assignment(normalized):
		# This likely indicates test data or misconfigured condition
		push_error("Assignment in condition (likely misconfigured): \"" + condition_text + "\" near element: " + manager.state.current_element_id)
		
		# TODO: should this evaluate or not? Judging from web interface
		# _evaluate_assignment(normalized)
		return false
	else:
		# Evaluate as a boolean expression
		var result = _evaluate_expression(normalized)
		return bool(result) if result != null else false


## Evaluate an expression and return its value
func _evaluate_expression(expr_text: String) -> Variant:
	var normalized = _normalize_arcscript(expr_text)
	
	var expr = Expression.new()
	
	# Build variable lists, but use shadow variable values where applicable
	var var_names = manager.state.variables.keys()
	var var_values = []
	
	for var_name in var_names:
		# Check if this is a shadow variable
		if is_shadow_variable(var_name):
			# Get the custom value from the callback
			var_values.append(get_variable_value(var_name))
		else:
			# Use the stored value
			var_values.append(manager.state.variables[var_name])
	
	var error = expr.parse(normalized, var_names)
	if error != OK:
		push_error("Arcscript parse error: " + expr.get_error_text() + " in expression: " + expr_text)
		return null
	
	var result = expr.execute(var_values, self)
	if expr.has_execute_failed():
		push_error("Arcscript execution error: " + expr.get_error_text() + " in expression: " + expr_text)
		return null
	
	return result


## Convert Arcscript operators to Godot Expression format
func _normalize_arcscript(text: String) -> String:
	# Decode HTML entities that may appear in exported JSON
	text = ArcweaveUtils.decode_html_entities(text)
	
	# Replace Arcscript-specific operators with Godot equivalents
	text = text.replace(" is not ", " != ")
	text = text.replace(" is ", " == ")
	return text


## Evaluate show() function call
func _evaluate_show(line: String) -> String:
	# Extract content between show( and the matching )
	var start_idx = line.find("show(")
	if start_idx == -1:
		return ""
	
	var content_start = start_idx + 5  # Length of "show("
	var paren_count = 1
	var content_end = content_start
	var in_string = false
	var prev_char = ''
	
	# Find matching closing parenthesis, respecting strings
	while content_end < line.length() and paren_count > 0:
		var c = line[content_end]
		
		# Track if we're inside a string
		if c == '"' and prev_char != '\\':
			in_string = !in_string
		elif not in_string:
			if c == '(':
				paren_count += 1
			elif c == ')':
				paren_count -= 1
		
		prev_char = c
		content_end += 1
	
	# Extract the arguments string
	var args_text = ""
	if paren_count == 0:
		# Found matching paren
		args_text = line.substr(content_start, content_end - content_start - 1).strip_edges()
	else:
		# No matching paren - take rest of line
		args_text = line.substr(content_start).strip_edges()
	
	# Split and evaluate arguments
	var args = _split_arguments(args_text)
	
	# Evaluate each argument and concatenate
	var result = ""
	for arg in args:
		arg = arg.strip_edges()
		
		# Check if it's a string literal
		if arg.begins_with('"') and arg.ends_with('"') and arg.length() > 1:
			# Remove quotes and add to result
			result += arg.substr(1, arg.length() - 2)
		elif arg.begins_with('"') or arg.ends_with('"'):
			# Malformed string - try to extract what we can
			var cleaned = arg.replace('"', '')
			result += cleaned
		else:
			# It's an expression - evaluate it
			var value = _evaluate_expression(arg)
			if value != null:
				result += str(value)
	
	return result + " "


## Split function arguments respecting quotes and nesting
func _split_arguments(args_text: String) -> Array:
	var args = []
	var current_arg = ""
	var in_quotes = false
	var paren_depth = 0
	
	for i in range(args_text.length()):
		var c = args_text[i]
		
		if c == '"' and (i == 0 or args_text[i-1] != '\\'):
			in_quotes = !in_quotes
			current_arg += c
		elif c == '(' and not in_quotes:
			paren_depth += 1
			current_arg += c
		elif c == ')' and not in_quotes:
			paren_depth -= 1
			current_arg += c
		elif c == ',' and not in_quotes and paren_depth == 0:
			# This comma separates arguments
			args.append(current_arg.strip_edges())
			current_arg = ""
		else:
			current_arg += c
	
	# Add the last argument
	if current_arg.strip_edges() != "":
		args.append(current_arg.strip_edges())
	
	return args


## Built-in Arcscript functions

# Handled by @GlobalScope
#func abs(value): return abs(value)
#func sqrt(value): return sqrt(value)
#func min(args): return min(args)
#func max(args): return max(args)
#func round(value): return round(value)

func sqr(value): return value * value
func random(): return randf()

## Reset specified variables to their initial values
## Can accept a single variable name, array of names, or multiple arguments
func reset(args = null):
	var var_list = []
	
	# Handle different argument formats
	if args == null:
		# No arguments - do nothing (matches Arcweave behavior)
		return
	elif args is Array:
		# Already an array of variable names
		var_list = args
	elif args is String:
		# Single variable name
		var_list = [args]
	else:
		# Assume it's a single variable name, convert to string
		var_list = [str(args)]
	
	# Reset each specified variable
	for var_name in var_list:
		if typeof(var_name) != TYPE_STRING:
			var_name = str(var_name)
		
		if manager.project.initial_variables.has(var_name):
			var initial_value = manager.project.initial_variables[var_name]
			set_variable_value(var_name, initial_value)
			
			# Notify manager if callback is set
			if on_variable_changed.is_valid():
				on_variable_changed.call(var_name, initial_value)
		else:
			push_warning("Cannot reset variable '%s': no initial value found" % var_name)

## Reset all variables to their initial values, except those specified
## Can accept a single variable name, array of names, or multiple arguments to exclude
func resetAll(args = null):
	var exclude_list = []
	
	# Handle different argument formats
	if args == null:
		# No arguments - reset all variables
		exclude_list = []
	elif args is Array:
		# Already an array of variable names to exclude
		exclude_list = args
	elif args is String:
		# Single variable name to exclude
		exclude_list = [args]
	else:
		# Assume it's a single variable name, convert to string
		exclude_list = [str(args)]
	
	# Convert exclude_list items to strings
	var exclude_set = {}
	for var_name in exclude_list:
		if typeof(var_name) != TYPE_STRING:
			var_name = str(var_name)
		exclude_set[var_name] = true
	
	# Reset all variables except those in the exclude list
	for var_name in manager.project.initial_variables.keys():
		if not exclude_set.has(var_name):
			var initial_value = manager.project.initial_variables[var_name]
			set_variable_value(var_name, initial_value)
			
			# Notify manager if callback is set
			if on_variable_changed.is_valid():
				on_variable_changed.call(var_name, initial_value)

# reset visit counts
func resetVisits(): manager.state.visit_counts.clear()

## Roll a random number
func roll(max_val: int, multiplier: int = 1) -> int:
	return randi_range(multiplier, max_val * multiplier)


## Get visit count for an element
func visits(element_id: String = "") -> int:
	# If no element_id provided, use current element being evaluated
	var id_to_check = element_id if element_id != "" else manager.state.current_element_id
	return manager.state.visit_counts.get(id_to_check, 0)


## Example of custom function capability:
## in Acrweave you can use this function signature,
## and despite the gui complaining,
## this function will be called, evaluated, and return a value.
func custom_function(number: int) -> int:
	return number + 7
