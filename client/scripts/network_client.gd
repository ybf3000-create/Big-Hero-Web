extends Node

signal realtime_authenticated
signal realtime_disconnected(message: String)
signal kicked(message: String)

const RULES_VERSION := "network-1"
const DESKTOP_SERVER_URL := "http://127.0.0.1:3000"
const HEARTBEAT_SECONDS := 10.0
const RECONNECT_SECONDS := 30.0

var session_token := ""
var session_id := ""
var account: Dictionary = {}
var character: Variant = null

var _http: HTTPRequest
var _request_in_flight := false
var _websocket := WebSocketPeer.new()
var _websocket_authenticated := false
var _authentication_sent := false
var _heartbeat_elapsed := 0.0
var _reconnect_elapsed := 0.0
var _reconnect_attempt_elapsed := 0.0
var _should_reconnect := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	set_process(true)


func register_account(username: String, password: String, password_confirm: String, invite_code: String) -> Dictionary:
	return await _request_json(
		"/api/v1/auth/register",
		HTTPClient.METHOD_POST,
		{
			"request_id": create_request_id(),
			"rules_version": RULES_VERSION,
			"username": username,
			"password": password,
			"password_confirm": password_confirm,
			"invite_code": invite_code,
		}
	)


func login(username: String, password: String) -> Dictionary:
	var response := await _request_json(
		"/api/v1/auth/login",
		HTTPClient.METHOD_POST,
		{
			"rules_version": RULES_VERSION,
			"username": username,
			"password": password,
		}
	)
	if response.get("ok", false):
		var session: Dictionary = response.get("session", {})
		session_token = str(session.get("token", ""))
		session_id = str(session.get("id", ""))
		account = response.get("account", {})
		character = response.get("character")
		_connect_realtime()
	return response


func create_character(character_name: String) -> Dictionary:
	var response := await _request_json(
		"/api/v1/characters",
		HTTPClient.METHOD_POST,
		{
			"request_id": create_request_id(),
			"rules_version": RULES_VERSION,
			"name": character_name,
		},
		true
	)
	if response.get("ok", false):
		character = response.get("character")
	return response


func logout() -> void:
	_should_reconnect = false
	if not session_token.is_empty():
		await _request_json("/api/v1/auth/logout", HTTPClient.METHOD_POST, {}, true)
	if _websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_websocket.close(1000, "logout")
	session_token = ""
	session_id = ""
	account.clear()
	character = null
	_websocket_authenticated = false


func create_request_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func _request_json(path: String, method: HTTPClient.Method, payload: Dictionary, authenticated := false) -> Dictionary:
	if _request_in_flight:
		return _error_response("REQUEST_IN_PROGRESS", "上一项操作仍在处理中")
	_request_in_flight = true

	var headers := PackedStringArray(["Content-Type: application/json"])
	if authenticated:
		if session_token.is_empty():
			_request_in_flight = false
			return _error_response("SESSION_INVALID", "登录已失效，请重新登录")
		headers.append("Authorization: Bearer " + session_token)

	var request_error := _http.request(
		_api_base_url() + path,
		headers,
		method,
		JSON.stringify(payload)
	)
	if request_error != OK:
		_request_in_flight = false
		return _error_response("NETWORK_ERROR", "无法连接服务器")

	var completed: Array = await _http.request_completed
	_request_in_flight = false
	var result := int(completed[0])
	var response_code := int(completed[1])
	var response_body := completed[3] as PackedByteArray
	if result != HTTPRequest.RESULT_SUCCESS:
		return _error_response("NETWORK_ERROR", "网络连接中断，请稍后重试")

	var json := JSON.new()
	if json.parse(response_body.get_string_from_utf8()) != OK:
		return _error_response("INVALID_RESPONSE", "服务器返回了无法识别的数据")
	var parsed: Variant = json.get_data()
	if parsed is not Dictionary:
		return _error_response("INVALID_RESPONSE", "服务器返回了无法识别的数据")
	var response := parsed as Dictionary
	response["http_status"] = response_code
	return response


func _process(delta: float) -> void:
	_websocket.poll()
	var state := _websocket.get_ready_state()
	while _websocket.get_available_packet_count() > 0:
		_handle_realtime_message(_websocket.get_packet().get_string_from_utf8())
	if state == WebSocketPeer.STATE_OPEN:
		_reconnect_elapsed = 0.0
		_reconnect_attempt_elapsed = 0.0
		if not _authentication_sent and not session_token.is_empty():
			_websocket.send_text(JSON.stringify({
				"type": "authenticate",
				"token": session_token,
			}))
			_authentication_sent = true
		if _websocket_authenticated:
			_heartbeat_elapsed += delta
			if _heartbeat_elapsed >= HEARTBEAT_SECONDS:
				_heartbeat_elapsed = 0.0
				_websocket.send_text(JSON.stringify({"type": "heartbeat"}))
	elif state == WebSocketPeer.STATE_CLOSED and _should_reconnect and not session_token.is_empty():
		_websocket_authenticated = false
		_authentication_sent = false
		_reconnect_elapsed += delta
		_reconnect_attempt_elapsed += delta
		if _reconnect_elapsed >= RECONNECT_SECONDS:
			_should_reconnect = false
			realtime_disconnected.emit("连接已断开，请重新登录")
		elif _reconnect_attempt_elapsed >= 2.0:
			_reconnect_attempt_elapsed = 0.0
			_connect_realtime(false)


func _connect_realtime(reset_window := true) -> void:
	if session_token.is_empty():
		return
	if reset_window:
		_reconnect_elapsed = 0.0
	_should_reconnect = true
	_websocket = WebSocketPeer.new()
	_websocket_authenticated = false
	_authentication_sent = false
	_heartbeat_elapsed = 0.0
	var error := _websocket.connect_to_url(_websocket_url())
	if error != OK:
		_websocket = WebSocketPeer.new()


func _handle_realtime_message(text: String) -> void:
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var message: Variant = json.get_data()
	if message is not Dictionary:
		return
	var data := message as Dictionary
	match str(data.get("type", "")):
		"authenticated":
			_websocket_authenticated = true
			realtime_authenticated.emit()
		"heartbeat_ack":
			pass
		"error":
			var code := str(data.get("code", ""))
			var detail := str(data.get("message", "连接已结束"))
			if code == "KICKED" or code == "REPLACED_BY_NEW_LOGIN":
				_should_reconnect = false
				session_token = ""
				kicked.emit(detail)


func _api_base_url() -> String:
	if OS.has_feature("web"):
		var origin: Variant = JavaScriptBridge.eval("window.location.origin", true)
		if origin != null and not str(origin).is_empty():
			return str(origin)
	return str(ProjectSettings.get_setting("network/server_url", DESKTOP_SERVER_URL)).trim_suffix("/")


func _websocket_url() -> String:
	var base := _api_base_url()
	if base.begins_with("https://"):
		return "wss://" + base.trim_prefix("https://") + "/ws"
	return "ws://" + base.trim_prefix("http://") + "/ws"


func _error_response(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": {
			"code": code,
			"message": message,
		},
	}
