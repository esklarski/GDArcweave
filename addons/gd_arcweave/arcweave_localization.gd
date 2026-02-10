## arcweave_localization.gd
## Handles multi-language support for Arcweave projects
## Manages locales, translations, and fallback chains

class_name ArcweaveLocalization
extends RefCounted

## Reference to manager (for accessing project data)
var manager: ArcweaveManagerInstance


func _init(arcweave_manager: ArcweaveManagerInstance) -> void:
	manager = arcweave_manager


## Change the current language
## Returns true if successful, false if locale not available
func change_language(locale_iso: String) -> bool:
	if not manager.project.is_multi_language_project:
		push_warning("Cannot change language: project is single-language")
		return false
	
	if not manager.is_locale_available(locale_iso):
		push_warning("Locale not available: " + locale_iso)
		return false
	
	var old_locale = manager.state.current_locale
	manager.state.current_locale = locale_iso
	
	print("Language changed: ", old_locale, " -> ", locale_iso)
	return true


## Get locale name (e.g., "English", "Español")
func get_locale_name(locale_iso: String) -> String:
	for locale in manager.project.locales:
		if locale.get("iso", "") == locale_iso:
			return locale.get("name", locale_iso)
	return locale_iso


## Get fallback locale chain for a given locale
## Returns an array of locale ISOs to try in order, including the original locale
## For example, if "de" has base "en", returns ["de", "en"]
func get_fallback_chain(locale_iso: String) -> Array[String]:
	var chain: Array[String] = [locale_iso]
	var visited: Dictionary = {locale_iso: true}  # Prevent infinite loops
	var current_locale = locale_iso
	
	# Follow the base chain
	while true:
		var base_locale = _get_base_locale(current_locale)
		if base_locale == null or base_locale == "" or visited.has(base_locale):
			break
		
		chain.append(base_locale)
		visited[base_locale] = true
		current_locale = base_locale
	
	return chain


## Get the base locale for a given locale ISO
func _get_base_locale(locale_iso: String) -> String:
	for locale in manager.project.locales:
		if locale.get("iso", "") == locale_iso:
			var base = locale.get("base", null)
			if base != null:
				return base
			return ""
	return ""


func _get_localized_field(
	item_id: String, 
	field_name: String,
	fallback_callback: Callable,  # Function to get non-localized value
	locale: String = ""
) -> String:
	if locale == "":
		locale = manager.state.current_locale
	
	# Try multi-language format first
	if manager.project.is_multi_language_project and manager.project.contents.has(item_id):
		var content_data = manager.project.contents[item_id]
		if typeof(content_data) == TYPE_DICTIONARY and content_data.has(field_name):
			var field_data = content_data[field_name]
			var fallback_chain = get_fallback_chain(locale)
			
			for i in range(fallback_chain.size()):
				var try_locale = fallback_chain[i]
				if typeof(field_data) == TYPE_DICTIONARY and field_data.has(try_locale):
					var locale_data = field_data[try_locale]
					if typeof(locale_data) == TYPE_DICTIONARY:
						var text = locale_data.get("text", "")
						var status = get_translation_status(item_id, try_locale)
						
						if status != "untranslated" or try_locale == fallback_chain.back():
							if i > 0:
								var original_status = get_translation_status(item_id, locale)
								if original_status == "untranslated":
									push_warning("Missing translation for %s (id: %s, locale: %s) - falling back to '%s'" 
										% [field_name, item_id, locale, try_locale])
							return text
	
	# Fall back to single-language format
	return fallback_callback.call(item_id)


## Get element title in current or specified language
## Works with both single-language and multi-language JSON
## Falls back to base language if translation status is "untranslated"
func get_element_title(element_id: String, locale: String = "") -> String:
	return _get_localized_field(element_id, "title",
		func(id): return manager.project.elements[id].title if manager.project.elements.has(id) else "",
		locale)


## Get element content in current or specified language
## Works with both single-language and multi-language JSON
## Falls back to base language if translation status is "untranslated"
func get_element_content(element_id: String, locale: String = "") -> String:
	return _get_localized_field(element_id, "content",
		func(id): return manager.project.elements[id].content if manager.project.elements.has(id) else "",
		locale)


## Get component name in current or specified language
## Works with both single-language and multi-language JSON
## Falls back to base language if translation status is "untranslated"
func get_component_name(component_id: String, locale: String = "") -> String:
	return _get_localized_field(component_id, "name",
		func(id): return manager.project.components[id].name if manager.project.components.has(id) else "", 
		locale)


## Get connection label in current or specified language
## Works with both single-language and multi-language JSON
## Falls back to base language if translation status is "untranslated"
func get_connection_label(connection_id: String, locale: String = "") -> String:
	return _get_localized_field(connection_id, "label",
		func(id): return str(manager.project.connections[id].label) if manager.project.connections.has(id) and manager.project.connections[id].label != null else "", 
		locale)


## Get translation status for an item in a specific locale
## Returns: "final", "review", "untranslated", or "" if not found
func get_translation_status(item_id: String, locale: String = "") -> String:
	if locale == "":
		locale = manager.state.current_locale
	
	if not manager.project.is_multi_language_project:
		return ""
	
	if manager.project.contents.has(item_id):
		var content_data = manager.project.contents[item_id]
		if typeof(content_data) == TYPE_DICTIONARY and content_data.has("_status"):
			var status_data = content_data["_status"]
			if typeof(status_data) == TYPE_DICTIONARY:
				return status_data.get(locale, "")
	
	return ""
