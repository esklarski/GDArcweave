## arcweave_component.gd
## Type-safe representation of an Arcweave component
## Components are reusable data containers that can be attached to elements

class_name ArcweaveComponent
extends Resource

## Unique identifier for this component
@export var id: String = ""

## Component name (can be localized)
@export var name: String = ""

## Array of attribute IDs attached to this component
@export var attributes: Array[String] = []

## Assets attached to this component
@export var assets: Dictionary = {}  # {cover: {id: String}, images: Array, audio: Array, video: Array}


## Create a component from parsed JSON dictionary
static func from_dict(data: Dictionary, project_id: String) -> ArcweaveComponent:
	var component = ArcweaveComponent.new()
	
	component.id = project_id
	component.name = data.get("name", "")
	
	# Parse attributes array
	var attrs = data.get("attributes", [])
	if typeof(attrs) == TYPE_ARRAY:
		component.attributes.clear()
		for attr_id in attrs:
			if typeof(attr_id) == TYPE_STRING:
				component.attributes.append(attr_id)
	
	# Parse assets
	var assets_data = data.get("assets", {})
	if typeof(assets_data) == TYPE_DICTIONARY:
		component.assets = assets_data.duplicate(true)
	
	return component


## Convert component back to dictionary (for serialization/export)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"attributes": attributes.duplicate(),
		"assets": assets.duplicate(true),
	}


## Get the cover asset ID if present
func get_cover_id() -> String:
	if typeof(assets) == TYPE_DICTIONARY and assets.has("cover"):
		var cover_data = assets["cover"]
		if typeof(cover_data) == TYPE_DICTIONARY:
			return cover_data.get("id", "")
	return ""


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


## Check if component has any attributes
func has_attributes() -> bool:
	return attributes.size() > 0


## Check if component has a cover asset
func has_cover() -> bool:
	return get_cover_id() != ""


## Get a debug-friendly string representation
func to_string() -> String:
	return "ArcweaveComponent(id=%s, name=%s, attributes=%d)" % [id, name, attributes.size()]
