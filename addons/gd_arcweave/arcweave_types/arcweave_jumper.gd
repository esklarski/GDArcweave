## arcweave_jumper.gd
## Type-safe representation of an Arcweave jumper
## Jumpers allow navigation to specific elements, enabling non-linear flow

class_name ArcweaveJumper
extends Resource

## Unique identifier for this jumper
@export var id: String = ""

## ID of the element this jumper points to
@export var elementId: String = ""


## Create a jumper from parsed JSON dictionary
static func from_dict(data: Dictionary, jumper_id: String) -> ArcweaveJumper:
	var jumper = ArcweaveJumper.new()
	
	jumper.id = jumper_id
	jumper.elementId = data.get("elementId", "")
	
	return jumper


## Convert jumper back to dictionary (for serialization/export)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"elementId": elementId
	}


## Check if jumper has a valid element ID
func has_element() -> bool:
	return elementId != ""


## Check if jumper is valid
func is_valid() -> bool:
	return has_element()


## Get a debug-friendly string representation
func _to_string() -> String:
	return "ArcweaveJumper(id=%s, element=%s)" % [id, elementId]
