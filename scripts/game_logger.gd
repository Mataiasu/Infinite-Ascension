extends Node

const LOG_PATH := "user://infinite_ascension_runtime.log"
const MAX_LOG_BYTES := 1024 * 1024

var _file: FileAccess
var _last_flush := 0.0

func _ready() -> void:
    _open_log()
    log_event("GAME_START", {"platform": OS.get_name()})

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
    _file.store_line(JSON.stringify({"ts": Time.get_datetime_string_from_system(true, true), "event": event_name, "data": data}))

func _open_log() -> void:
    if FileAccess.file_exists(LOG_PATH):
        var old := FileAccess.open(LOG_PATH, FileAccess.READ)
        if old:
            var content := old.get_as_text()
            old.close()
            if content.to_utf8_buffer().size() > MAX_LOG_BYTES:
                var lines := content.split("\n")
                lines = lines.slice(max(0, lines.size() - 5000))
                var rotated := FileAccess.open(LOG_PATH, FileAccess.WRITE)
                if rotated:
                    rotated.store_string("\n".join(lines))
                    rotated.close()
    _file = FileAccess.open(LOG_PATH, FileAccess.WRITE_READ)
