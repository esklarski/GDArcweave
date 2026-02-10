## arcweave_utils.gd
## Utility functions for Arcweave integration
## Handles HTML to BBCode conversion and other helpers

class_name ArcweaveUtils


const CODE_HEX_COLOR = "#27b7f5"


## Extract Arcweave component mentions from span tags
## Returns array of dictionaries with mention info: [{id, label, type, original_tag}, ...]
static func extract_mentions(s: String) -> Array:
	var mentions = []
	var regex = RegEx.new()
	regex.compile('<span[^>]*class="[^"]*mention[^"]*"[^>]*data-id="([^"]*)"[^>]*data-label="([^"]*)"[^>]*data-type="([^"]*)"[^>]*>([^<]*)</span>')
	
	var matches = regex.search_all(s)
	for match in matches:
		mentions.append({
			"original_tag": match.get_string(0),
			"id": match.get_string(1),
			"label": match.get_string(2),
			"type": match.get_string(3),
			"content": match.get_string(4)
		})
	
	return mentions


## Replace Arcweave mentions with styled BBCode
## style_callback: func(mention_dict) -> String that returns BBCode formatting
static func replace_mentions_with_style(s: String, style_callback: Callable = Callable()) -> String:
	var mentions = extract_mentions(s)
	
	for mention in mentions:
		var replacement = mention["label"]
		
		# Apply custom styling if callback provided
		if style_callback.is_valid():
			replacement = style_callback.call(mention)
		
		s = s.replace(mention["original_tag"], replacement)
	
	return s


## Convert HTML tags from Arcweave to Godot RichTextLabel BBCode tags
static func clean_string(s: String) -> String:
	if s.is_empty():
		return s
	
	# First, handle Arcweave component mentions (preserve the label text)
	# Pattern matches: <span class="mention..." data-label="Text">...</span>
	var regex = RegEx.new()
	regex.compile('<span[^>]*class="[^"]*mention[^"]*"[^>]*data-label="([^"]*)"[^>]*>.*?</span>')
	s = regex.sub(s, "$1", true)  # Replace with just the label (group 1)
	
	# Replace common HTML tags with temporary placeholders
	# (to avoid them being stripped by the regex)
	s = s.replace("<strong>", "{bold}")
	s = s.replace("</strong>", "{/bold}")
	s = s.replace("<em>", "{italic}")
	s = s.replace("</em>", "{/italic}")
	
	# Handle HTML entities
	s = s.replace("&lt;", "")
	s = s.replace("&gt;", "")
	
	# Convert paragraph breaks to newlines
	s = s.replace("</p>", "\n\n")
	
	# Handle code blocks
	s = s.replace("<code>", "{code}")
	s = s.replace("</code>", "{/code}")
	
	# Remove all remaining HTML tags
	regex = RegEx.new()
	regex.compile("<[^>]*>")
	s = regex.sub(s, "", true)  # true = replace all occurrences
	
	# Convert placeholders to Godot BBCode
	s = s.replace("{bold}", "[b]")
	s = s.replace("{/bold}", "[/b]")
	s = s.replace("{italic}", "[i]")
	s = s.replace("{/italic}", "[/i]")
	s = s.replace("{code}", "[color=" + CODE_HEX_COLOR + "]")
	s = s.replace("{/code}", "[/color]\n")
	
	# Trim trailing whitespace
	s = s.strip_edges(false, true)  # strip_edges(strip_begin, strip_end)
	
	return s


## Extended version with more HTML tag support
static func clean_string_extended(s: String) -> String:
	if s.is_empty():
		return s
	
	# First, handle Arcweave component mentions
	var regex = RegEx.new()
	regex.compile('<span[^>]*class="[^"]*mention[^"]*"[^>]*data-label="([^"]*)"[^>]*>.*?</span>')
	s = regex.sub(s, "$1", true)
	
	# Basic formatting
	s = s.replace("<strong>", "{bold}")
	s = s.replace("</strong>", "{/bold}")
	s = s.replace("<b>", "{bold}")
	s = s.replace("</b>", "{/bold}")
	
	s = s.replace("<em>", "{italic}")
	s = s.replace("</em>", "{/italic}")
	s = s.replace("<i>", "{italic}")
	s = s.replace("</i>", "{/italic}")
	
	s = s.replace("<u>", "{underline}")
	s = s.replace("</u>", "{/underline}")
	
	s = s.replace("<s>", "{strikethrough}")
	s = s.replace("</s>", "{/strikethrough}")
	
	# Headers
	s = s.replace("<h1>", "{h1}")
	s = s.replace("</h1>", "{/h1}")
	s = s.replace("<h2>", "{h2}")
	s = s.replace("</h2>", "{/h2}")
	s = s.replace("<h3>", "{h3}")
	s = s.replace("</h3>", "{/h3}")
	
	# Lists
	s = s.replace("<ul>", "{ul}")
	s = s.replace("</ul>", "{/ul}")
	s = s.replace("<ol>", "{ol}")
	s = s.replace("</ol>", "{/ol}")
	s = s.replace("<li>", "{li}")
	s = s.replace("</li>", "{/li}")
	
	# Line breaks and paragraphs
	s = s.replace("<br>", "\n")
	s = s.replace("<br/>", "\n")
	s = s.replace("<br />", "\n")
	s = s.replace("</p>", "\n\n")
	s = s.replace("<p>", "")
	
	# Code blocks
	s = s.replace("<code>", "{code}")
	s = s.replace("</code>", "{/code}")
	s = s.replace("<pre>", "{pre}")
	s = s.replace("</pre>", "{/pre}")
	
	# HTML entities
	s = s.replace("&lt;", "<")
	s = s.replace("&gt;", ">")
	s = s.replace("&amp;", "&")
	s = s.replace("&quot;", '"')
	s = s.replace("&apos;", "'")
	s = s.replace("&nbsp;", " ")
	
	# Remove all remaining HTML tags
	regex = RegEx.new()
	regex.compile("<[^>]*>")
	s = regex.sub(s, "", true)
	
	# Convert placeholders to Godot BBCode
	s = s.replace("{bold}", "[b]")
	s = s.replace("{/bold}", "[/b]")
	
	s = s.replace("{italic}", "[i]")
	s = s.replace("{/italic}", "[/i]")
	
	s = s.replace("{underline}", "[u]")
	s = s.replace("{/underline}", "[/u]")
	
	s = s.replace("{strikethrough}", "[s]")
	s = s.replace("{/strikethrough}", "[/s]")
	
	s = s.replace("{h1}", "[font_size=32][b]")
	s = s.replace("{/h1}", "[/b][/font_size]\n")
	
	s = s.replace("{h2}", "[font_size=24][b]")
	s = s.replace("{/h2}", "[/b][/font_size]\n")
	
	s = s.replace("{h3}", "[font_size=18][b]")
	s = s.replace("{/h3}", "[/b][/font_size]\n")
	
	s = s.replace("{ul}", "")
	s = s.replace("{/ul}", "\n")
	s = s.replace("{ol}", "")
	s = s.replace("{/ol}", "\n")
	s = s.replace("{li}", "  • ")
	s = s.replace("{/li}", "\n")
	
	s = s.replace("{code}", "[color=" + CODE_HEX_COLOR + "]")
	s = s.replace("{/code}", "[/color]")
	
	s = s.replace("{pre}", "[code]")
	s = s.replace("{/pre}", "[/code]\n")
	
	# Trim trailing whitespace
	s = s.strip_edges(false, true)
	
	return s


## Preprocess HTML to expose Arcscript keywords for evaluation
## Arcweave wraps keywords like 'if', 'endif', 'show' in <pre><code> tags
static func preprocess_arcscript_html(html: String) -> String:
	var processed = html
	
	# First, decode HTML entities
	processed = decode_html_entities(processed)
	
	# First, extract content from mention spans and replace with just the label
	# This is important for Arcscript function calls like visits(element_name)
	var regex = RegEx.new()
	regex.compile('<span[^>]+class="[^"]*mention[^"]*"[^>]+data-label="([^"]+)"[^>]*>.*?<\\/span>')
	processed = regex.sub(processed, '"$1"', true)  # Replace with quoted label
	
	# Strip <pre> and <code> tags (with or without attributes) that wrap Arcscript
	regex.compile('<pre[^>]*>')
	processed = regex.sub(processed, "", true)
	processed = processed.replace("</pre>", "\n")  # Convert to newline
	
	regex.compile('<code[^>]*>')
	processed = regex.sub(processed, "", true)
	processed = processed.replace("</code>", "")
	
	# Convert paragraph tags to newlines for the interpreter
	regex.compile('<p[^>]*>')
	processed = regex.sub(processed, "", true)
	processed = processed.replace("</p>", "\n")
	
	# Handle blockquote tags
	processed = processed.replace("<blockquote>", "")
	processed = processed.replace("</blockquote>", "\n")
	
	# Clean up multiple consecutive newlines
	var newline_regex = RegEx.new()
	newline_regex.compile("\n{3,}")
	processed = newline_regex.sub(processed, "\n\n", true)
	
	return processed


static func decode_html_entities(text: String) -> String:
	var result = text
	
	# Common HTML entities
	result = result.replace("&amp;", "&")
	result = result.replace("&lt;", "<")
	result = result.replace("&gt;", ">")
	result = result.replace("&quot;", '"')
	result = result.replace("&#39;", "'")
	result = result.replace("&apos;", "'")
	result = result.replace("&nbsp;", " ")
	
	# Numeric entities (basic support)
	var regex = RegEx.new()
	regex.compile("&#(\\d+);")
	var matches = regex.search_all(result)
	for match_obj in matches:
		var code = int(match_obj.get_string(1))
		var char = char(code)
		result = result.replace(match_obj.get_string(0), char)
	
	# Hex entities
	regex.compile("&#x([0-9a-fA-F]+);")
	matches = regex.search_all(result)
	for match_obj in matches:
		var code = ("0x" + match_obj.get_string(1)).hex_to_int()
		var char = char(code)
		result = result.replace(match_obj.get_string(0), char)
	
	return result


## Strip all BBCode/formatting tags (for plain text display)
static func strip_bbcode(s: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[/?[^\\]]*\\]")
	return regex.sub(s, "", true)


## Convert color hex codes in HTML to BBCode
static func convert_color_tags(s: String) -> String:
	# Match <span style="color: #rrggbb"> or <font color="#rrggbb">
	var regex = RegEx.new()
	
	# Handle span style colors
	regex.compile("<span[^>]*style=[\"']color:\\s*#([0-9a-fA-F]{6})[\"'][^>]*>")
	var matches = regex.search_all(s)
	for match in matches:
		var full_match = match.get_string(0)
		var color = match.get_string(1)
		s = s.replace(full_match, "[color=#" + color + "]")
	s = s.replace("</span>", "[/color]")
	
	# Handle font color
	regex.compile("<font[^>]*color=[\"']#([0-9a-fA-F]{6})[\"'][^>]*>")
	matches = regex.search_all(s)
	for match in matches:
		var full_match = match.get_string(0)
		var color = match.get_string(1)
		s = s.replace(full_match, "[color=#" + color + "]")
	s = s.replace("</font>", "[/color]")
	
	return s


## Helper to apply formatting to a RichTextLabel
static func apply_to_label(label: RichTextLabel, html_text: String, use_extended: bool = false) -> void:
	if label == null:
		return
	
	var cleaned = clean_string_extended(html_text) if use_extended else clean_string(html_text)
	label.bbcode_enabled = true
	label.text = cleaned


## Parse and clean content in a single call (convenience method)
static func parse_content(content: String, extended: bool = false, parse_colors: bool = false) -> String:
	if content.is_empty():
		return content
	
	# Optionally convert color tags first
	if parse_colors:
		content = convert_color_tags(content)
	
	# Clean HTML to BBCode
	if extended:
		return clean_string_extended(content)
	else:
		return clean_string(content)
