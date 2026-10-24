extends Window

@onready var messages: RichTextLabel = $Content/Messages
@onready var message_input: LineEdit = $Content/InputRow/MessageInput
@onready var send_button: Button = $Content/InputRow/SendButton
@onready var new_chat_button: Button = $Content/TitleBar/CloseButton
@onready var ai_request: HTTPRequest = $AIRequest
@onready var copy_last_button: Button = $Content/CopyLastButton

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
	
func _on_send_pressed() -> void:
	send_message()

func _on_text_submitted(_text: String) -> void:
	send_message()

func send_message() -> void:
	var message := message_input.text.strip_edges()
	
	if message.is_empty():
		return
	
	conversation_history.append(message)
	messages.append_text("\n\n[b]You:[/b] " + message)
	messages.append_text("\n[b]Gumi:[/b] Got the message! Beep boop!")
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

func _on_new_chat_pressed() -> void:
	conversation_history.clear()
	messages.clear()
	messages.append_text("[center][b]New chat[/b][/center]\n\nHi! Here we go again.")
	message_input.clear()
	message_input.grab_focus()

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
	
	messages.append_text("\n\n[b]Gumi:[/b] " + reply)
	messages.scroll_to_line(messages.get_line_count() - 1)

func _on_copy_last_pressed() -> void:
	for i in range(conversation.size() - 1, -1, -1):
		DisplayServer.clipboard_set(
			str(conversation[i].get("content", ""))
		)
		copy_last_button.text = "Copied!"
		return
