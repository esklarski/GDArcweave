## arcscript_condition.gd
## Type-safe representation of an Arcscript condition
## Conditions control branching logic in the narrative flow

class_name ArcscriptCondition
extends Resource

## Unique identifier for this condition
@export var id: String = ""

## Arcscript code for this condition (can be null)
@export var condition_script: String = ""

## ID of the output this condition leads to
@export var output: String = ""


## Create a condition from parsed JSON dictionary
static func from_dict(data: Dictionary, condition_id: String) -> ArcscriptCondition:
	var condition = ArcscriptCondition.new()
	
	condition.id = condition_id

	var found_script = data.get("script", null)
	condition.condition_script = found_script if found_script else ""

	if not condition.condition_script.is_empty():
		condition.condition_script = ArcweaveUtils.preprocess_arcscript_html(condition.condition_script)
	
	var data_output = data.get("output", "")
	condition.output = data_output if data_output else ""
	
	return condition


## Convert condition back to dictionary (for serialization/export)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"script": condition_script,
		"output": output
	}


## Check if condition has a script
func has_script() -> bool:
	return condition_script != null and condition_script != ""


## Get the script as a string, or empty string if null
func get_script_string() -> String:
	if condition_script == null:
		return ""
	return str(condition_script)


## Check if condition has an output
func has_output() -> bool:
	return output != ""


## Check if this is an "else" condition (no script)
func is_else_condition() -> bool:
	return not has_script()


## Get a debug-friendly string representation
func _to_string() -> String:
	var script_preview = get_script_string()
	if script_preview.length() > 30:
		script_preview = script_preview.substr(0, 27) + "..."
	
	if is_else_condition():
		return "ArcscriptCondition(id=%s, else->%s)" % [id, output]
	else:
		return "ArcscriptCondition(id=%s, if '%s'->%s)" % [id, script_preview, output]
