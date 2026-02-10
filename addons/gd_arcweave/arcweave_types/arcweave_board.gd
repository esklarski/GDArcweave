## arcweave_board.gd
## Type-safe representation of an Arcweave board
## Boards organize elements, branches, and jumpers into logical groupings

class_name ArcweaveBoard
extends Resource

## Unique identifier for this board
@export var id: String = ""

## Name of the board
@export var name: String = ""

## Array of element IDs on this board
@export var elements: Array[String] = []

## Array of jumper IDs on this board
@export var jumpers: Array[String] = []

## Array of branch IDs on this board
@export var branches: Array[String] = []

## Array of connection ID's on this board
@export var connections: Array[String] = []

## Whether this is the root/starting board
@export var root: bool = false


## Create a board from parsed JSON dictionary
static func from_dict(data: Dictionary, board_id: String) -> ArcweaveBoard:
	var board = ArcweaveBoard.new()
	
	board.id = board_id
	board.name = data.get("name", "")
	board.root = data.get("root", false)
	
	# Parse elements array
	var elems = data.get("elements", [])
	if typeof(elems) == TYPE_ARRAY:
		board.elements.clear()
		for elem_id in elems:
			if typeof(elem_id) == TYPE_STRING:
				board.elements.append(elem_id)
	
	# Parse jumpers array
	var jumps = data.get("jumpers", [])
	if typeof(jumps) == TYPE_ARRAY:
		board.jumpers.clear()
		for jump_id in jumps:
			if typeof(jump_id) == TYPE_STRING:
				board.jumpers.append(jump_id)
	
	# Parse branches array
	var branchs = data.get("branches", [])
	if typeof(branchs) == TYPE_ARRAY:
		board.branches.clear()
		for branch_id in branchs:
			if typeof(branch_id) == TYPE_STRING:
				board.branches.append(branch_id)
	
	# Parse connections array
	var connections = data.get("connections", [])
	if typeof(connections) == TYPE_ARRAY:
		board.connections.clear()
		for connection_id in connections:
			if typeof(connection_id) == TYPE_STRING:
				board.connections.append(connection_id)
	
	return board


## Convert board back to dictionary (for serialization/export)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"elements": elements.duplicate(),
		"jumpers": jumpers.duplicate(),
		"branches": branches.duplicate(),
		"connections" : connections.duplicate(),
		"root": root
	}


## Check if board has a name
func has_name() -> bool:
	return name != ""


## Check if board is the root board
func is_root() -> bool:
	return root


## Check if board has any elements
func has_elements() -> bool:
	return elements.size() > 0


## Check if board has any jumpers
func has_jumpers() -> bool:
	return jumpers.size() > 0


## Check if board has any branches
func has_branches() -> bool:
	return branches.size() > 0


## Check if board has any connections
func has_some_connections() -> bool:
	return branches.size() > 0


## Get the number of elements on this board
func get_element_count() -> int:
	return elements.size()


## Get the number of jumpers on this board
func get_jumper_count() -> int:
	return jumpers.size()


## Get the number of branches on this board
func get_branch_count() -> int:
	return branches.size()


## Get the number of branches on this board
func get_connections_count() -> int:
	return connections.size()


## Get the first element ID (useful for finding starting points)
func get_first_element_id() -> String:
	if elements.size() > 0:
		return elements[0]
	return ""


## Check if board contains a specific element
func contains_element(element_id: String) -> bool:
	return elements.has(element_id)


## Check if board contains a specific jumper
func contains_jumper(jumper_id: String) -> bool:
	return jumpers.has(jumper_id)


## Check if board contains a specific branch
func contains_branch(branch_id: String) -> bool:
	return branches.has(branch_id)


## Check if board contains a specific connection
func contains_connection(connection_id: String) -> bool:
	return connections.has(connection_id)


## Get total item count (elements + jumpers + branches)
func get_total_item_count() -> int:
	return elements.size() + jumpers.size() + branches.size() + connections.size()


## Check if board is empty
func is_empty() -> bool:
	return get_total_item_count() == 0


## Get a debug-friendly string representation
func _to_string() -> String:
	var name_str = " '%s'" % name if has_name() else ""
	var root_str = " [ROOT]" if is_root() else ""
	return "ArcweaveBoard(id=%s%s%s, elements=%d, jumpers=%d, branches=%d)" % [
		id, name_str, root_str, elements.size(), jumpers.size(), branches.size()
	]
