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
- ✅ Shadowing project variables with user defined `Callable`s
- ⚠️ Image, audio, and video assets parsed, but not retrieved.
- ❌ Note objects not implemented
- ❌ Coordinates not parsed


## Quick Start

1. Export your Arcweave project as JSON
2. Copy the gd_arcweave folder into your `res://addons` folder
3. Enable the plugin in Project Settings

Enabling the plugin will create an autoload entry of the base `ArcweaveManagerInstance` class. It is assumed that the user will extend this class to implement custom functionality, but this fallback autoload provides all the necessary features to run the project test scene. If you override this autoload, enabling the plugin is not required.

An example of connecting to the autoload and starting a project:
```c++
@export_file_path("*.json") var arcweave_project_json: String

func _ready():
	ArcweaveManager.element_changed.connect(_on_element_changed)
	ArcweaveManager.choice_presented.connect(_on_choice_presented)
	
	if ArcweaveManager.load_project_from_file(arcweave_project_json):
		ArcweaveManager.start_story()
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

In the full project see: `res://testing/arcweave_project_manager/gd_arcweave_test.tscn` for a more complete example.


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
