extends Window

@onready var messages: RichTextLabel = $Content/Messages
@onready var message_input: LineEdit = $Content/InputRow/MessageInput
@onready var send_button: Button = $Content/InputRow/SendButton
@onready var new_chat_button: Button = $Content/TitleBar/CloseButton
@onready var ai_request: HTTPRequest = $AIRequest
@onready var copy_last_button: Button = $Content/CopyLastButton
@onready var message_list: VBoxContainer = $Content/ChatScroll/MessageList
@onready var chat_scroll: ScrollContainer = $Content/ChatScroll

var conversation: Array[Dictionary] = []
var conversation_history: Array[String] = []
var waiting_for_replay = false
var endpoint = ""
var model = ""
var api_key = ""

func _ready() -> void:
	min_size = Vector2i(450, 550)
	popup_centered(Vector2i(450, 550))
	
	close_requested.connect(_on_close_requested)
	send_button.pressed.connect(_on_send_pressed)
	message_input.text_submitted.connect(_on_text_submitted)
	new_chat_button.pressed.connect(_on_new_chat_pressed)
	ai_request.request_completed.connect(_on_request_completed)
	copy_last_button.pressed.connect(_on_copy_last_pressed)
	
	new_chat_button.text = "+ New Chat"
	message_input.placeholder_text = "Message Gumi..."
	
	messages.bbcode_enabled = true
	messages.text = "[center][b]Gumi[/b][/center]\n\nHi! I'm Gumi. Beep boop!"
	var config := ConfigFile.new()
	var err := config.load("user://gumi_settings.cfg")
	
	if err == OK:
		endpoint = str(config.get_value("AI", "endpoint", "")).trim_suffix("/")
		model = str(config.get_value("AI", "model", ""))
		api_key = str(config.get_value("AI", "api_key", ""))
	else:
		messages.append_text("\n\n[!] Could not load AI settings.")
	
	chat_scroll.resized.connect(_update_bubble_widths)
	
func _on_send_pressed() -> void:
	send_message()

func _on_text_submitted(_text: String) -> void:
	send_message()

func send_message() -> void:
	var message := message_input.text.strip_edges()
	
	if message.is_empty():
		return
	
	conversation_history.append(message)
	add_message_bubble("You", format_ai_response(message))
	if endpoint.is_empty() or model.is_empty():
		messages.append_text("\n[!] Set up the AI in Settings first.")
		return
	
	var api_messages: Array[Dictionary] = [
		{
			"role": "system",
			"content": "You are Gumi, a friendly desktop robot companion. Reply helpfully and naturally"
		}
	]
	
	for entry in conversation:
		api_messages.append(entry)
		
	api_messages.append({"role": "user", "content": message})
	
	var payload := {
		"model": model,
		"messages": api_messages,
		"stream": false
	}
	
	var headers := PackedStringArray([
		"Content-Type: application/json"
	])
	
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
	
	waiting_for_replay = true
	send_button.disabled = true
	
	var error := ai_request.request(
		endpoint + "/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	
	if error != OK:
		waiting_for_replay = false
		send_button.disabled = false
		messages.append_text("\n[!] Could not start request: " + str(error))
	
	message_input.clear()
	messages.scroll_to_line(messages.get_line_count() - 1)
	
	send_button.text = "Send"
	message_input.placeholder_text = "Message Gumi..."
	messages.scroll_following = true

func _on_new_chat_pressed() -> void:
	conversation_history.clear()
	for child in message_list.get_children():
		message_list.remove_child(child)
		child.queue_free()
		
	message_input.clear()
	message_input.grab_focus()
	conversation.clear()

func _on_close_requested() -> void:
	hide()


func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	waiting_for_replay = false
	send_button.disabled = false
	
	var data = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code < 200 or response_code >= 300:
		messages.append_text("\n\n[!] AI error: HTTP " + str(response_code)
		+ "\n" + body.get_string_from_utf8()
		)
		return
	
	if not data is Dictionary or not data.has("choices"):
		messages.append_text("\n\n[!] Invalid AI response.")
		return
	
	var reply: String = str(data["choices"][0]["message"]["content"])
	
	conversation.append({"role": "user", "content": conversation_history[-1]})
	conversation.append({"role": "assistant", "content": reply})
	
	add_message_bubble("Gumi", format_ai_response(reply))
	messages.scroll_to_line(messages.get_line_count() - 1)

func _on_copy_last_pressed() -> void:
	for i in range(conversation.size() - 1, -1, -1):
		if conversation[i].get("role") == "assistant":
			DisplayServer.clipboard_set(
				str(conversation[i].get("content", ""))
			)
			copy_last_button.text = "Copied!"
			return

func format_ai_response(text: String) -> String:
	var output = text
	output = output.replace("\r\n", "\n")
	
	var code_blocks: Array[String] = []
	var block_regex := RegEx.new()
	block_regex.compile("(?s)```([a-zA-Z0-9_+.-]*)[ \t]*\n(.*?)\n?```")
	print("Block matches: ", block_regex.search_all(output).size())
	
	for block_match in block_regex.search_all(output):
		var full_block := block_match.get_string()
		var language := block_match.get_string(1)
		var code := block_match.get_string(2).strip_edges()
		
		code = code.replace("[", "[lb]").replace("]", "[rb]")
		

		var formatted_block := "[bgcolor=#252b36][color=#8bd5ff]"

		if not language.is_empty():
			formatted_block += "[color=#9aa4b2]" + language + "[/color]\n"

		formatted_block += code + "[/color][/bgcolor]"

		var placeholder := "GUMICODEBLOCK" + str(code_blocks.size()) + "END"
		code_blocks.append(formatted_block)

		output = output.replace(full_block, placeholder)
	
	output = output.replace("[", "[lb]").replace("]", "[rb]")
	
	var bold_regex = RegEx.new()
	bold_regex.compile("\\*\\*(.+?)\\*\\*")
	output = bold_regex.sub(output, "[b]$1[/b]", true)
	
	var italic_regex = RegEx.new()
	italic_regex.compile("\\*(.+?)\\*")
	output = italic_regex.sub(output, "[i]$1[/i]", true)
	
	var code_regex = RegEx.new()
	code_regex.compile("(?<!`)`([^`\\n]+)`(?!`)")
	print("Inline Code Matches: ", code_regex.search_all(output).size())
	output = code_regex.sub(
		output,
		"[bgcolor=#252b36][color=#8bd5ff]$1[/color][/bgcolor]",
		true
	)
	
	var heading_regex = RegEx.new()
	heading_regex.compile("(?m)^### (.+)$")
	output = heading_regex.sub(output, "[color=#8bd5ff][b]$1[/b][/color]", true)
	
	heading_regex.compile("(?m)^## (.+)$")
	output = heading_regex.sub(output, "[color=#8bd5ff][font_size=20][b]$1[/b][/font_size][/color]", true)
	
	heading_regex.compile("(?m)^# (.+)$")
	output = heading_regex.sub(output, "[color=#8bd5ff][font_size=24][b]$1[/b][/font_size][/color]", true)
	
	var list_regex = RegEx.new()
	list_regex.compile("(?m)^[-*] (.+)$")
	output = list_regex.sub(output, "•  $1", true)
	
	var numbered_list_regex := RegEx.new()
	numbered_list_regex.compile("(?m)^\\d+\\. (.+)$")
	output = numbered_list_regex.sub(output, "•  $1", true)
	
	output = output.replace("\n- ", "\n\n•  ")
	output = output.replace("\n* ", "\n\n•  ")
	output = output.replace("\n\n\n", "\n\n")
	
	for i in range(code_blocks.size()):
		output = output.replace(
			"GUMICODEBLOCK" + str(i) + "END",
			code_blocks[i]
		)
	
	return output






func add_message_bubble(sender: String, text: String) -> void:
	var row := HBoxContainer.new()
	var bubble := PanelContainer.new()
	bubble.custom_minimum_size.x = minf(chat_scroll.size.x * 0.82, 650.0)
	var label := RichTextLabel.new()
	var name_label :=  Label.new()
	name_label.text = sender
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color("#9AA4B2"))
	

	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.selection_enabled = true
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.custom_minimum_size= Vector2(0,0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.visible = true

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#222735") if sender == "You" else Color("#171B24")
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	bubble.add_theme_stylebox_override("panel", style)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var bubble_content := VBoxContainer.new()
	bubble_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble_content.add_child(name_label)
	bubble_content.add_child(label)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_child(bubble_content)

	if sender == "You":
		row.alignment = BoxContainer.ALIGNMENT_END
	else:
		row.alignment = BoxContainer.ALIGNMENT_BEGIN

	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bubble)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_list.add_child(row)
	call_deferred("_scroll_chat_to_bottom")

func _scroll_chat_to_bottom() -> void:
	await get_tree().process_frame
	chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)

func _update_bubble_widths() -> void:
	var bubble_width: float = minf(chat_scroll.size.x * 0.82, 650.0)
	
	for row in message_list.get_children():
		if row is HBoxContainer and row.get_child_count() > 0:
			var bubble := row.get_child(0) as PanelContainer
			if bubble:
				bubble.custom_minimum_size.x = bubble_width
