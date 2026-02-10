## arcweave_attribute.gd
## Type-safe representation of an Arcweave attribute
## Attributes are data fields that can be attached to components and define their properties

class_name ArcweaveAttribute
extends Resource

## Unique identifier for this attribute
@export var id: String = ""

## Attribute name (can be null or localized)
@export var name: Variant = null

## Component type this attribute belongs to
@export var cType: String = ""

## Component ID this attribute is associated with
@export var cId: String = ""

## Value data for this attribute
@export var value: AttributeValue = null


## Create an attribute from parsed JSON dictionary
static func from_dict(data: Dictionary, attribute_id: String) -> ArcweaveAttribute:
	var attribute = ArcweaveAttribute.new()
	
	attribute.id = attribute_id
	attribute.name = data.get("name", null)
	attribute.cType = data.get("cType", "")
	attribute.cId = data.get("cId", "")
	
	# Parse value
	var value_data = data.get("value", {})
	if typeof(value_data) == TYPE_DICTIONARY and not value_data.is_empty():
		attribute.value = AttributeValue.from_dict(value_data)
	
	return attribute


## Convert attribute back to dictionary (for serialization/export)
func to_dict() -> Dictionary:
	var result = {
		"id": id,
		"name": name,
		"cType": cType,
		"cId": cId,
	}
	
	if value != null:
		result["value"] = value.to_dict()
	else:
		result["value"] = {}
	
	return result


## Check if attribute has a name set
func has_name() -> bool:
	return name != null and name != ""


## Get the attribute name as a string, or empty string if null
func get_name_string() -> String:
	if name == null:
		return ""
	return str(name)


## Check if attribute has a value
func has_value() -> bool:
	return value != null and value.has_data()


## Get the attribute's data value
func get_data(default_value: Variant = null) -> Variant:
	if value != null:
		return value.data if value.has_data() else default_value
	return default_value


## Get the attribute's type
func get_type() -> String:
	if value != null:
		return value.type
	return ""


## Check if the attribute belongs to a specific component
func belongs_to_component(component_id: String) -> bool:
	return cId == component_id


## Get a debug-friendly string representation
func to_string() -> String:
	var name_str = get_name_string()
	if name_str == "":
		name_str = "<unnamed>"
	return "ArcweaveAttribute(id=%s, name=%s, cType=%s)" % [id, name_str, cType]
