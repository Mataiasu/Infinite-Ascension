extends Node

const SAVE_PATH := "user://infinite_ascension_save.json"
const SAVE_INTERVAL := 30.0

var elapsed := 0.0
var loaded := false

func _process(delta: float) -> void:
    elapsed += delta
    var scene := get_tree().current_scene
    if scene == null or not scene.has_method("_refresh"):
        return

    if not loaded:
        loaded = true
        load_game(scene)
        scene.call_deferred("_refresh")

    if elapsed >= SAVE_INTERVAL:
        elapsed = 0.0
        save_game(scene)

func save_game(scene: Node) -> void:
    var data := {
        "version": 1,
        "saved_at": Time.get_datetime_string_from_system(),
        "level": int(scene.get("level")),
        "xp": float(scene.get("xp")),
        "reborn": int(scene.get("reborn")),
        "power": float(scene.get("power")),
        "gold": int(scene.get("gold")),
        "world_tier": int(scene.get("world_tier")),
        "group_levels": scene.get("group_levels"),
        "frontier_min": int(scene.get("frontier_min")),
        "frontier_max": int(scene.get("frontier_max")),
        "zone_index": int(scene.get("zone_index"))
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "  "))
        file.close()

func load_game(scene: Node) -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return

    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return

    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if not parsed is Dictionary:
        return

    scene.set("level", int(parsed.get("level", scene.get("level"))))
    scene.set("xp", float(parsed.get("xp", scene.get("xp"))))
    scene.set("reborn", int(parsed.get("reborn", scene.get("reborn"))))
    scene.set("power", float(parsed.get("power", scene.get("power"))))
    scene.set("gold", int(parsed.get("gold", scene.get("gold"))))
    scene.set("world_tier", int(parsed.get("world_tier", scene.get("world_tier"))))
    scene.set("frontier_min", int(parsed.get("frontier_min", scene.get("frontier_min"))))
    scene.set("frontier_max", int(parsed.get("frontier_max", scene.get("frontier_max"))))
    scene.set("zone_index", int(parsed.get("zone_index", scene.get("zone_index"))))

    var levels = parsed.get("group_levels", scene.get("group_levels"))
    if levels is Array and levels.size() > 0:
        scene.set("group_levels", levels)

func _exit_tree() -> void:
    var scene := get_tree().current_scene
    if scene != null and scene.has_method("_refresh"):
        save_game(scene)
