extends Control


@export_file_path("*.json") var arcweave_project_json: String
@export var custom_start_id: String = ""
@export var option_button_scene: PackedScene
@export var randomize_locale: bool = false


func _ready():
	# Connect signals
	ArcweaveManager.element_changed.connect(_on_element_changed)
	ArcweaveManager.choice_presented.connect(_on_choices_presented)
	ArcweaveManager.story_ended.connect(_on_story_ended)
	
	# Load and start
	if ArcweaveManager.load_project_from_file(arcweave_project_json):
		ArcweaveManager.start_story(custom_start_id)

		if ArcweaveManager.project.is_multi_language_project and randomize_locale:
			var available_locales = ArcweaveManager.get_available_locales()
			available_locales.shuffle()
			var random_locale = available_locales.pick_random()
			ArcweaveManager.set_current_locale( random_locale )
	else:
		$StoryText.text = "Failed to load story!"


func _on_element_changed(element: ArcweaveElement):
	# Display the story text
	ArcweaveManager.debug_print_element_components(element)
	var content = element.evaluated_content
	if content.is_empty():
		content = element.content
	%StoryText.text = content


func _on_choices_presented(choices: Array):
	# Clear old buttons
	for child in %Choices.get_children():
		child.queue_free()
	
	# Create new buttons
	for choice in choices:
		var button = option_button_scene.instantiate()
		button.text = choice.get("label", "Continue")
		button.pressed.connect(func(): ArcweaveManager.make_choice(choice))
		%Choices.add_child(button)

func _on_story_ended():
	# Clear old buttons
	for child in %Choices.get_children():
		child.queue_free()

	# Add "[The End]" to current story
	%StoryText.text += "\n\n[The End]"

	# Add restart button
	var restart = Button.new()  # Or use your scene
	restart.text = "Restart"
	restart.pressed.connect(_on_restart_pressed)
	%Choices.add_child(restart)


func _on_restart_pressed():
	# Clear the text before restarting
	%StoryText.text = ""

	# Reset and start the story
	ArcweaveManager.reset_story_state()
	ArcweaveManager.start_story(custom_start_id)
