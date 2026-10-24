extends Window

@onready var ui: Control = $Content

var launched_as_settings = false

func _ready():
	
	close_requested.connect(_on_close_requested)
	min_size = Vector2i(800, 560)
	popup_centered(Vector2i(800, 560))
	
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	ui.get_node("TitleLabel").position = Vector2(30, 20)
	ui.get_node("TitleLabel").size = Vector2(540, 40)
		
		
	ui.get_node("ProviderOption").position = Vector2(30, 80)
	ui.get_node("ProviderOption").size = Vector2(540, 35)

	ui.get_node("EndpointInput").position = Vector2(30,130)
	ui.get_node("EndpointInput").size = Vector2(590,35)

	ui.get_node("ModelInput").position = Vector2(30, 180)
	ui.get_node("ModelInput").size = Vector2(590, 35)

	ui.get_node("ApiKeyInput").position = Vector2(30, 230)
	ui.get_node("ApiKeyInput").size = Vector2(590, 35)

	ui.get_node("TestButton").position = Vector2(30, 300)
	ui.get_node("TestButton").size = Vector2(250, 40)

	ui.get_node("SaveButton").position = Vector2(320, 300)
	ui.get_node("SaveButton").size = Vector2(250, 40)

	ui.get_node("StatusLabel").position = Vector2(30, 370)
	ui.get_node("StatusLabel").size = Vector2(540, 35)
	
	
	$Content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	
	$Content/Background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	$Content/TitleLabel.text = "Gumi Setup"
	
	$Content/ProviderOption.clear()
	$Content/ProviderOption.add_item("Local AI", 0)
	$Content/ProviderOption.add_item("Cloud API", 1)
	
	$Content/EndpointInput.placeholder_text = "API endpoint URL"
	$Content/EndpointInput.text = "http://localhost:11434/v1"
	
	$Content/ModelInput.placeholder_text = "Model name"
	$Content/ModelInput.text = "qwen3.5:latest"
	
	$Content/ApiKeyInput.placeholder_text = "Api key (optional for local AI)"
	$Content/ApiKeyInput.secret = true
	
	$Content/TestButton.text = "Test connection"
	$Content/SaveButton.text = "Save settings"
	
	$Content/StatusLabel.text = "Choose your AI provider"
	
	$AIRequest.request_completed.connect(_on_ai_request_completed)
	
	ui.get_node("TestButton").pressed.connect(_on_test_button_pressed)
	
	ui.get_node("SaveButton").pressed.connect(_on_save_button_pressed)
	_load_settings()
	if FileAccess.file_exists("user://gumi_settings.cfg"):
		call_deferred("_start_gumi")
	
func _on_provider_option_item_selected(index: int):
	if index == 0:
		$Content/EndpointInput.text = "http://localhost:11434/v1"
		$Content/ModelInput.text = "qwen3.5:latest"
		$Content/ApiKeyInput.text = ""
		$Content/StatusLabel.text = "Using Ollama"
		
	else:
		$Content/EndpointInput.text = ""
		$Content/ModelInput.text = ""
		$Content/ApiKeyInput.text = ""
		$Content/StatusLabel.text = "Enter your API details"
		


func _on_save_button_pressed():
	var config = ConfigFile.new()
	
	config.set_value("AI", "provider", ui.get_node("ProviderOption").selected)
	config.set_value("AI", "endpoint", ui.get_node("EndpointInput").text)
	config.set_value("AI", "model", ui.get_node("ModelInput").text)
	config.set_value("AI", "api_key", ui.get_node("ApiKeyInput").text)
	
	var error = config.save("user://gumi_settings.cfg")
	
	if error == OK:
		get_tree().change_scene_to_file("res://node_2d.tscn")
		
	else:
		ui.get_node("StatusLabel").text = "Error saving settings: " + str(error)


func _load_settings():
	var config = ConfigFile.new()
	var error = config.load("user://gumi_settings.cfg")
	
	if error != OK:
		return
	
	ui.get_node("ProviderOption").select(
		config.get_value("AI", "provider", 0)
	)
	ui.get_node("EndpointInput").text = config.get_value(
		"AI", "endpoint", "http://localhost:11434/v1"
	)
	ui.get_node("ModelInput").text = config.get_value(
		"AI", "model", "qwen3.5:latest"
	)
	ui.get_node("ApiKeyInput").text = config.get_value(
		"AI", "api_key", ""
	)
	
	ui.get_node("StatusLabel").text = "Settings loaded!"

func _on_test_button_pressed():
	var endpoint = ui.get_node("EndpointInput").text.strip_edges().trim_suffix("/")
	var model = ui.get_node("ModelInput").text.strip_edges()
	var api_key = ui.get_node("ApiKeyInput").text.strip_edges()
	var status = ui.get_node("StatusLabel")
	
	if endpoint.is_empty() or model.is_empty():
		status.text = "Enter endpoint and mode!"
		return
	
	var headers = PackedStringArray([
		"Content-Type: application/json"
	])
	
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
		
	var url = endpoint + "/chat/completions"
	
	var payload = {
		"model": model,
		"messages": [
			{
				"role": "user",
				"content": "Reply with exactly: Gumi online!"
			}
		],
		"max_tokens": 30
	}
	
	var error = $AIRequest.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	
	if error == OK:
		status.text = "Connecting to AI..."
	else:
		status.text = "Request error: " + str(error)
	
	
func _on_ai_request_completed(result, response_code, _headers, body):
	var status = ui.get_node("StatusLabel")
	
	
	if result != HTTPRequest.RESULT_SUCCESS:
		status.text = "Connection failed. Check endpoint/server"
		return
		
	if response_code < 200 or response_code >= 300:
		status.text = "HTTP error: " + str(response_code) + " - " + body.get_string_from_utf8()
		return
		
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	
	if parse_error != OK:
		status.text = "Connected, but response was invalid JSON."
		return
		
	var data = json.data
	
	if data is Dictionary and data.has("choices"):
		status.text = "AI connected succesfully!"
		
	else:
		status.text = "Response recieved, but format was unexpected"

func _start_gumi():
	get_tree().change_scene_to_file("res://node_2d.tscn")

func _on_close_requested():
	if launched_as_settings:
		queue_free()
	else:
		hide()
