@tool
extends EditorPlugin


func _get_plugin_name() -> String:
	return "GD Arcweave"


func _enter_tree() -> void:
	if not ProjectSettings.has_setting("autoload/ArcweaveManager"):
		print("GD Arcweave loading fallback autoload.")
		add_autoload_singleton("ArcweaveManager", "res://addons/gd_arcweave/example/arcweave_manager_autoload.gd")


func _exit_tree() -> void:
	if ProjectSettings.has_setting("autoload/ArcweaveManager")\
	and (
		ProjectSettings.get_setting("autoload/ArcweaveManager").contains("cy10po08uunow")\
		or \
		ProjectSettings.get_setting("autoload/ArcweaveManager").contains("arcweave_manager_autoload.gd")
	):
		remove_autoload_singleton("ArcweaveManager")
