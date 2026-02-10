## arcweave_element.gd
## Type-safe representation of an Arcweave element
## Elements are the core narrative nodes containing content, choices, and branching logic

class_name ArcweaveElement
extends Resource

## Unique identifier for this element
@export var id: String = ""

## Title of the element (can be displayed as a header or used for navigation)
@export var title: String = ""

## Raw content text of the element (may contain Arcscript code)
@export var content: String = ""

## Array of component IDs attached to this element
@export var components: Array[String] = []

## Array of output IDs (connections, branches, jumpers) from this element
@export var outputs: Array[String] = []

# ## Theme/styling information
# @export var theme: Dictionary = {}

## Cover asset ID (if present)
@export var cover: Variant = null

## Assets attached to this element (audio, video, images)
@export var assets: Dictionary = {}

## Evaluated content (set at runtime after Arcscript processing)
## This is not serialized/exported, it's computed on demand
var evaluated_content: String = ""


## Create an element from parsed JSON dictionary
static func from_dict(data: Dictionary, element_id: String) -> ArcweaveElement:
	var element = ArcweaveElement.new()
	
	element.id = element_id
	element.title = data.get("title", "")
	element.content = data.get("content", "")
	
	# Parse components array
	var comps = data.get("components", [])
	if typeof(comps) == TYPE_ARRAY:
		element.components.clear()
		for comp_id in comps:
			if typeof(comp_id) == TYPE_STRING:
				element.components.append(comp_id)
	
	# Parse outputs array
	var outs = data.get("outputs", [])
	if typeof(outs) == TYPE_ARRAY:
		element.outputs.clear()
		for out_id in outs:
			if typeof(out_id) == TYPE_STRING:
				element.outputs.append(out_id)
	
	# # Parse theme
	# var theme_data = data.get("theme", {})
	# if typeof(theme_data) == TYPE_DICTIONARY:
	# 	element.theme = theme_data.duplicate(true)
	
	# Parse assets
	var assets_data = data.get("assets", {})
	if typeof(assets_data) == TYPE_DICTIONARY:
		element.assets = assets_data.duplicate(true)
		
		# Extract cover image if present
		if element.assets.has("cover"):
			var cover_data = element.assets["cover"]
			if typeof(cover_data) == TYPE_DICTIONARY:
				element.cover = cover_data.get("id", null)
	
	return element


## Convert element back to dictionary (for serialization/export)
func to_dict() -> Dictionary:
	var result = {
		"id": id,
		"title": title,
		"content": content,
		"components": components.duplicate(),
		"outputs": outputs.duplicate(),
		# "theme": theme.duplicate(true),
		"assets": assets.duplicate(true)
	}
	
	# Don't include evaluated_content in serialization as it's runtime-only
	
	return result


## Check if element has a title
func has_title() -> bool:
	return title != ""


## Check if element has content
func has_content() -> bool:
	return content != ""


## Check if element has evaluated content
func has_evaluated_content() -> bool:
	return evaluated_content != ""


## Check if element has any components
func has_components() -> bool:
	return components.size() > 0


## Check if element has any outputs
func has_outputs() -> bool:
	return outputs.size() > 0


## Get the cover asset ID if present
func get_cover_id() -> String:
	if cover != null and typeof(cover) == TYPE_STRING:
		return cover
	return ""


## Check if element has a cover asset
func has_cover() -> bool:
	return get_cover_id() != ""


## Get array of image asset IDs
func get_image_ids() -> Array[String]:
	var image_ids: Array[String] = []
	
	if typeof(assets) != TYPE_DICTIONARY:
		return image_ids
	
	var images = assets.get("images", [])
	if typeof(images) != TYPE_ARRAY:
		return image_ids
	
	for img in images:
		if typeof(img) == TYPE_DICTIONARY:
			var img_id = img.get("id", "")
			if img_id != "":
				image_ids.append(img_id)
	
	return image_ids


## Get array of audio asset IDs
func get_audio_ids() -> Array[String]:
	var audio_ids: Array[String] = []
	
	if typeof(assets) != TYPE_DICTIONARY:
		return audio_ids
	
	var audios = assets.get("audio", [])
	if typeof(audios) != TYPE_ARRAY:
		return audio_ids
	
	for audio in audios:
		if typeof(audio) == TYPE_DICTIONARY:
			var audio_id = audio.get("id", "")
			if audio_id != "":
				audio_ids.append(audio_id)
	
	return audio_ids


## Get array of video asset IDs
func get_video_ids() -> Array[String]:
	var video_ids: Array[String] = []
	
	if typeof(assets) != TYPE_DICTIONARY:
		return video_ids
	
	var videos = assets.get("video", [])
	if typeof(videos) != TYPE_ARRAY:
		return video_ids
	
	for video in videos:
		if typeof(video) == TYPE_DICTIONARY:
			var video_id = video.get("id", "")
			if video_id != "":
				video_ids.append(video_id)
	
	return video_ids


## Check if element has any image assets
func has_images() -> bool:
	return get_image_ids().size() > 0


## Check if element has any audio assets
func has_audio() -> bool:
	return get_audio_ids().size() > 0


## Check if element has any video assets
func has_video() -> bool:
	return get_video_ids().size() > 0


## Get a debug-friendly string representation
func _to_string() -> String:
	var title_str = " '%s'" % title if has_title() else ""
	var output_count = outputs.size()
	var component_count = components.size()
	return "ArcweaveElement(id=%s%s, outputs=%d, components=%d)" % [id, title_str, output_count, component_count]
