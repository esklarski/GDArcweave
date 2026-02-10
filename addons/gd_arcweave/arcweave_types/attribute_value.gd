## Nested class representing the typed value of an attribute
class_name  AttributeValue
extends Resource

## Type of the attribute value (e.g., "string", "number", "boolean", etc.)
@export var type: String = ""

## The actual data/value
@export var data: Variant = null

## Is this plain text?
@export var plain: bool = false

## Create an AttributeValue from a dictionary
static func from_dict(value_dict: Dictionary) -> AttributeValue:
    var av = AttributeValue.new()
    av.type = value_dict.get("type", "")
    av.data = value_dict.get("data", null)
    av.plain = value_dict.get("plain", false)
    return av

## Convert back to dictionary
func to_dict() -> Dictionary:
    return {
        "type": type,
        "data": data,
        "plain" : plain
    }

## Check if value has data set
func has_data() -> bool:
    return data != null

## Get a string representation
func to_string() -> String:
    return "AttributeValue(type=%s, data=%s)" % [type, str(data)]