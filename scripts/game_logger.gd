extends Node

const DEFAULT_LOG_PATH := "user://infinite_ascension_runtime.log"
const WINDOWS_LOG_RELATIVE := "InfiniteAscension/Logs/game.log"
const LOG_ENDPOINT := "https://infinite-ascension-log-ingest.matthprizee55.workers.dev/"
const MAX_LOG_BYTES := 1024 * 1024
const LIVE_UPLOAD_INTERVAL := 20.0

var log_path := DEFAULT_LOG_PATH
var _file: FileAccess
var _last_flush := 0.0
var _last_live_upload := 0.0
var _http: HTTPRequest
var _session_id := ""
var _upload_pending := false

func _ready() -> void:
    var external_path := OS.get_environment("INFINITE_ASCENSION_LOG_PATH").strip_edges()
    if not external_path.is_empty():
        log_path = external_path
    elif OS.get_name() == "Windows":
        var local_app_data := OS.get_environment("LOCALAPPDATA").strip_edges()
        if not local_app_data.is_empty():
            log_path = local_app_data.path_join(WINDOWS_LOG_RELATIVE)

    _session_id = "%s-%s" % [str(Time.get_unix_time_from_system()), str(randi())]
    _http = HTTPRequest.new()
    add_child(_http)
    _http.request_completed.connect(_on_upload_completed)
    _open_log()
    log_event("GAME_START", {"platform": OS.get_name(), "log_path": log_path, "session": _session_id})

func _process(delta: float) -> void:
    _last_flush += delta
    _last_live_upload += delta
    if _last_flush >= 2.0:
        _last_flush = 0.0
        if _file:
            _file.flush()
    if _last_live_upload >= LIVE_UPLOAD_INTERVAL:
        _last_live_upload = 0.0
        _upload_live_log()

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

func _upload_live_log() -> void:
    if _upload_pending or _http == null or _file == null:
        return
    _file.flush()
    if not FileAccess.file_exists(log_path):
        return

    var reader := FileAccess.open(log_path, FileAccess.READ)
    if reader == null:
        return
    var log := reader.get_as_text()
    reader.close()
    if log.is_empty() or log.length() > 500000:
        return

    var payload := JSON.stringify({
        "build": OS.get_environment("INFINITE_ASCENSION_BUILD") if not OS.get_environment("INFINITE_ASCENSION_BUILD").is_empty() else "0",
        "session": _session_id,
        "live": true,
        "log": log
    })
    var headers := PackedStringArray(["Content-Type: application/json"])
    _upload_pending = true
    var err := _http.request(LOG_ENDPOINT, headers, HTTPClient.METHOD_POST, payload)
    if err != OK:
        _upload_pending = false
        log_event("LIVE_LOG_UPLOAD_ERROR", {"error": err})

func _on_upload_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
    _upload_pending = false
    if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
        log_event("LIVE_LOG_UPLOAD_FAILED", {"result": result, "http": response_code})
    else:
        log_event("LIVE_LOG_UPLOAD_OK", {"http": response_code})

func _open_log() -> void:
    var directory := log_path.get_base_dir()
    if not directory.is_empty() and not directory.begins_with("user://"):
        DirAccess.make_dir_recursive_absolute(directory)

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
