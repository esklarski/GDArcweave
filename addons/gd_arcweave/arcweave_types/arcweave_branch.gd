## arcweave_branch.gd
## Type-safe representation of an Arcweave branch
## Branches contain multiple conditions for conditional narrative flow

class_name ArcweaveBranch
extends Resource

## Unique identifier for this branch
@export var id: String = ""

## Array of condition IDs attached to this branch (if, elseif, else)
@export var condition_ids: Array[String] = []


## Create a branch from parsed JSON dictionary
static func from_dict(data: Dictionary, branch_id: String) -> ArcweaveBranch:
	var branch = ArcweaveBranch.new()
	
	branch.id = branch_id
	
	# Parse conditions object into condition_ids array
	var conditions_obj = data.get("conditions", {})
	if typeof(conditions_obj) == TYPE_DICTIONARY:
		# If condition (required)
		if conditions_obj.has("ifCondition"):
			branch.condition_ids.append(conditions_obj["ifCondition"])
		
		# ElseIf conditions (optional, can be multiple)
		if conditions_obj.has("elseIfConditions"):
			var elseif_conditions = conditions_obj["elseIfConditions"]
			if typeof(elseif_conditions) == TYPE_ARRAY:
				for elseif_id in elseif_conditions:
					if typeof(elseif_id) == TYPE_STRING:
						branch.condition_ids.append(elseif_id)
		
		# Else condition (optional)
		if conditions_obj.has("elseCondition"):
			branch.condition_ids.append(conditions_obj["elseCondition"])
	
	return branch


## Convert branch back to dictionary (for serialization/export)
func to_dict() -> Dictionary:
	# Reconstruct the conditions object from condition_ids
	var conditions_obj = {}
	
	if condition_ids.size() > 0:
		conditions_obj["ifCondition"] = condition_ids[0]
		
		if condition_ids.size() > 2:
			var elseif_array = []
			for i in range(1, condition_ids.size() - 1):
				elseif_array.append(condition_ids[i])
			conditions_obj["elseIfConditions"] = elseif_array
			conditions_obj["elseCondition"] = condition_ids[condition_ids.size() - 1]
		elif condition_ids.size() == 2:
			# Could be either elseif or else - assume else for simplicity
			conditions_obj["elseCondition"] = condition_ids[1]
	
	return {
		"id": id,
		"conditions": conditions_obj
	}


## Check if branch has any conditions
func has_conditions() -> bool:
	return condition_ids.size() > 0


## Get the number of conditions
func get_condition_count() -> int:
	return condition_ids.size()


## Check if branch has an if condition (should always be true for valid branches)
func has_if_condition() -> bool:
	return condition_ids.size() > 0


## Check if branch has elseif conditions
func has_elseif_conditions() -> bool:
	return condition_ids.size() > 2


## Check if branch has an else condition
func has_else_condition() -> bool:
	return condition_ids.size() > 1


## Get the if condition ID
func get_if_condition_id() -> String:
	if condition_ids.size() > 0:
		return condition_ids[0]
	return ""


## Get array of elseif condition IDs
func get_elseif_condition_ids() -> Array[String]:
	var elseif_ids: Array[String] = []
	if condition_ids.size() > 2:
		for i in range(1, condition_ids.size() - 1):
			elseif_ids.append(condition_ids[i])
	return elseif_ids


## Get the else condition ID (if it exists)
func get_else_condition_id() -> String:
	if condition_ids.size() > 1:
		return condition_ids[condition_ids.size() - 1]
	return ""


## Get a debug-friendly string representation
func _to_string() -> String:
	return "ArcweaveBranch(id=%s, conditions=%d)" % [id, condition_ids.size()]
