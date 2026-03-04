extends Node

func debug(message) -> void:
	if not AppState.is_debug_logs_enabled():
		return
	print(message)

func warn(message) -> void:
	if not AppState.is_debug_logs_enabled():
		return
	push_warning(str(message))

func error(message) -> void:
	push_error(str(message))

