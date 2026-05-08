class_name MessageLogNode
extends Node
## In-game message log, mirroring Shattered PD's scrolling text log.
## Messages are displayed in the UI and stored for scrollback.

## Emitted whenever a new message is appended.
@warning_ignore("unused_signal")
signal message_added(entry: Dictionary)
## Emitted when the log is cleared.
@warning_ignore("unused_signal")
signal log_cleared

## Maximum number of entries retained before oldest are pruned.
const MAX_MESSAGES: int = 100

## Internal storage. Each entry is { "text": String, "color": Color, "turn": int }.
var _entries: Array[Dictionary] = []

## Current turn counter, set externally by TurnManager so messages can be grouped.
var current_turn: int = 0

# --- Public API ---

## Add a plain white message.
func add(text: String, color: Color = Color.WHITE) -> void:
	var entry: Dictionary = {
		"text": text,
		"color": color,
		"turn": current_turn,
	}
	_entries.append(entry)
	# Prune oldest if over capacity.
	while _entries.size() > MAX_MESSAGES:
		_entries.pop_front()
	message_added.emit(entry)

## Convenience: add a positive (green) message.
func add_positive(text: String) -> void:
	add(text, Color(0.4, 1.0, 0.4))

## Convenience: add a negative (red) message.
func add_negative(text: String) -> void:
	add(text, Color(1.0, 0.3, 0.3))

## Convenience: add a warning (yellow/orange) message.
func add_warning(text: String) -> void:
	add(text, Color(1.0, 0.85, 0.3))

## Convenience: add an info (light blue) message.
func add_info(text: String) -> void:
	add(text, Color(0.5, 0.8, 1.0))

## Clear all log entries.
func clear() -> void:
	_entries.clear()
	log_cleared.emit()

## Return the full log array (read-only copy).
func get_entries() -> Array[Dictionary]:
	return _entries.duplicate()

## Return the N most recent entries.
func get_recent(count: int = 5) -> Array[Dictionary]:
	var start: int = maxi(0, _entries.size() - count)
	return _entries.slice(start)

## Return total entry count.
func entry_count() -> int:
	return _entries.size()
