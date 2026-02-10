@tool
class_name RichTextButton extends Control

signal button_down
signal button_up
signal pressed
signal toggled(toggled_on: bool)


@onready var button: Button = %Button
@onready var rich_text_label: RichTextLabel = %RichTextLabel

@export var text: String = "":
	set = _set_text


func _ready():
	if not Engine.is_editor_hint():
		button.button_down.connect( button_down.emit )
		button.button_up.connect( button_up.emit )
		button.pressed.connect( pressed.emit )
		button.toggled.connect( toggled.emit )
	_set_text(text)


func set_min_size(min_size: Vector2) -> void:
	custom_minimum_size = min_size


func _set_text(p_text: String) -> void:
	if not is_node_ready(): await ready
	text = p_text
	rich_text_label.text = text
	rich_text_label.update_minimum_size()
