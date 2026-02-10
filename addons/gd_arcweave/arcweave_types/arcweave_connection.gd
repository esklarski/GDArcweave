## arcweave_connection.gd
## Type-safe representation of an Arcweave connection
## Connections link elements together in the narrative flow

class_name ArcweaveConnection
extends Resource

## Unique identifier for this connection
@export var id: String = ""

## Optional label for the connection, null if not present
@export var label: String = ""

## ID of the source element
@export var sourceid: String = ""

## ID of the target element
@export var targetid: String = ""


## Create a connection from parsed JSON dictionary
static func from_dict(data: Dictionary, connection_id: String) -> ArcweaveConnection:
	var connection = ArcweaveConnection.new()
	
	connection.id = connection_id
	var data_label  = data.get("label", "")
	connection.label = data_label if data_label else ""
	connection.sourceid = data.get("sourceid", "")
	connection.targetid = data.get("targetid", "")
	
	return connection


## Convert connection back to dictionary (for serialization/export)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"label": label,
		"sourceid": sourceid,
		"targetid": targetid
	}


## Check if connection has a label
func has_label() -> bool:
	return label != ""


## Check if connection is valid (has both source and target)
func is_valid() -> bool:
	return sourceid != "" and targetid != ""


## Get a debug-friendly string representation
func _to_string() -> String:
	var label_str = " (%s)" % label if has_label() else ""
	return "ArcweaveConnection(id=%s, %s->%s%s)" % [id, sourceid, targetid, label_str]
