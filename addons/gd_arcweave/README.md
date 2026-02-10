# Arcweave Interpreter for Godot

A GDScript interpreter for [Arcweave](https://arcweave.com) interactive narrative projects in Godot 4.

## ⚠️ Status

**Early stage and largely untested.** Use at your own risk. Contributions and bug reports welcome.

## Features

Load and navigate Arcweave story projects exported as JSON, with support for:

- ✅ Elements, Boards, Branches, Jumpers, and Connections, Components, and Attributes
- ✅ Arcscript evaluation (Conditions, Variables, Expressions)
- ✅ Built-in Arcscript functions (`visits()`, `reset()`, `roll()`, etc.)
- ✅ Multi-language projects with fallback chains
- ✅ Visit tracking and history
- ✅ HTML to BBCode conversion
- ⚠️ Image, audio, and video assets parsed, but not retrieved.
- ❌ Note objects not implemented
- ❌ Coordinates not parsed

## Quick Start

1. Export your Arcweave project as JSON
2. Add the scripts to your Godot project

### Method 1: instance manager in a script

Instance and connect to an `ArcweaveManager` then load json project.

```gdscript
var arcweave_manager: ArcweaveManagerInstance

func _ready():
	arcweave_manager = ArcweaveManagerInstance.new()

	# Connect signals
	arcweave_manager.element_changed.connect(_on_element_changed)
	arcweave_manager.choice_presented.connect(_on_choices_presented)
	arcweave_manager.story_ended.connect(_on_story_ended)
	
	# Load and start
	if arcweave_manager.load_project_from_file(arcweave_project_json):
		arcweave_manager.start_story()
	else:
		$StoryText.text = "Failed to load story!"

func _on_element_changed(element):
	print(element.evaluated_content)

func _on_choice_presented(choices):
	for choice in choices:
		print(choice.label)
	
	await get_tree().create_timer(2.0).timeout
	ArcweaveManager.make_choice(choices.pick_random())
```

### Method 2: via autoload

Set `arcweave_manager.gd` as an autoload `ArcweaveManager` in Project Settings.
Connect to signals and load json project.

```gdscript
func _ready():
	ArcweaveManager.element_changed.connect(_on_element_changed)
	ArcweaveManager.choice_presented.connect(_on_choice_presented)
	ArcweaveManager.load_project_from_file(arcweave_project_json)
	ArcweaveManager.start_story()

func _on_element_changed(element):
	print(element.evaluated_content)

func _on_choice_presented(choices):
	for choice in choices:
		print(choice.label)
	
	await get_tree().create_timer(2.0).timeout
	ArcweaveManager.make_choice(choices.pick_random())
```

## Documentation

See the [Arcweave JSON Reference](https://docs.arcweave.com/integrations/json) for the official format specification.

## Fonts

Fonts used are available from [Google Fonts](https://fonts.google.com/):
- Archivo: Regular, Bold, Italic
- Doto: Medium
- NotoColorEmoji: Regular

## License

MIT License - Copyright (c) 2025

Permission is hereby granted, free of charge, to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of this software, subject to including this notice in all copies.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
