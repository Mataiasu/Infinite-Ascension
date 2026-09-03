extends Node

const DEFAULT_LOG_PATH := "user://infinite_ascension_runtime.log"
const MAX_LOG_BYTES := 1024 * 1024

var log_path := DEFAULT_LOG_PATH
var _file: FileAccess
var _last_flush := 0.0

func _ready() -> void:
    var external_path := OS.get_environment("INFINITE_ASCENSION_LOG_PATH").strip_edges()
    if not external_path.is_empty():
        log_path = external_path
    _open_log()
    log_event("GAME_START", {"platform": OS.get_name(), "log_path": log_path})

func _process(delta: float) -> void:
    _last_flush += delta
    if _last_flush >= 2.0:
        _last_flush = 0.0
        if _file:
            _file.flush()

func _exit_tree() -> void:
    if _file:
        log_event("GAME_EXIT", {})
        _file.flush()
        _file.close()

func log_event(event_name: String, data: Dictionary = {}) -> void:
    if _file == null:
        _open_log()
    if _file == null:
        return
    _file.store_line(JSON.stringify({
        "ts": Time.get_datetime_string_from_system(true, true),
        "event": event_name,
        "data": data
    }))

func _open_log() -> void:
    if FileAccess.file_exists(log_path):
        var old := FileAccess.open(log_path, FileAccess.READ)
        if old:
            var content := old.get_as_text()
            old.close()
            if content.to_utf8_buffer().size() > MAX_LOG_BYTES:
                var lines := content.split("\n")
                lines = lines.slice(max(0, lines.size() - 5000))
                var rotated := FileAccess.open(log_path, FileAccess.WRITE)
                if rotated:
                    rotated.store_string("\n".join(lines))
                    rotated.close()
    _file = FileAccess.open(log_path, FileAccess.WRITE_READ)
