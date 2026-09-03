extends Node

# Desktop movement fallback. Uses keyboard events instead of relying on InputMap.
# This makes WASD independent from stale or broken action-map entries.

const PLAYER_SPEED := 7.0
const PLAYER_ACCEL := 24.0

var player: CharacterBody3D
var camera_pivot: Node3D
var key_w := false
var key_a := false
var key_s := false
var key_d := false
var _reported_player := false
var _reported_movement := false
var _last_position := Vector3.ZERO
var _diagnostic_timer := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 100
    GameLogger.log_event("INPUT_FALLBACK_READY", {"mode": "event_driven", "keys": "WASD"})

func _input(event: InputEvent) -> void:
    if event is not InputEventKey:
        return
    var key := event as InputEventKey
    if key.echo:
        return
    var pressed := key.pressed
    match key.physical_keycode:
        KEY_W:
            key_w = pressed
        KEY_A:
            key_a = pressed
        KEY_S:
            key_s = pressed
        KEY_D:
            key_d = pressed

    if pressed and key.physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
        GameLogger.log_event("INPUT_KEY_DOWN", {"key": OS.get_keycode_string(key.physical_keycode)})

func _physics_process(delta: float) -> void:
    if player == null or not is_instance_valid(player):
        player = _find_player()
        camera_pivot = _find_camera_pivot()
        if player != null and not _reported_player:
            _reported_player = true
            _last_position = player.global_position
            GameLogger.log_event("INPUT_PLAYER_FOUND", {"position": str(player.global_position)})

    if player == null or camera_pivot == null:
        return

    var input := Vector2(
        float(int(key_d) - int(key_a)),
        float(int(key_w) - int(key_s))
    )
    if input.length() > 1.0:
        input = input.normalized()

    if input.length() <= 0.01:
        return

    var forward := -camera_pivot.global_transform.basis.z
    var right := camera_pivot.global_transform.basis.x
    forward.y = 0.0
    right.y = 0.0
    forward = forward.normalized()
    right = right.normalized()
    var direction := (right * input.x + forward * input.y).normalized()

    var target_velocity := direction * PLAYER_SPEED
    player.velocity.x = move_toward(player.velocity.x, target_velocity.x, PLAYER_ACCEL * delta)
    player.velocity.z = move_toward(player.velocity.z, target_velocity.z, PLAYER_ACCEL * delta)
    if player.is_on_floor():
        player.velocity.y = -0.2
    else:
        player.velocity.y -= 22.0 * delta
    player.move_and_slide()

    var pos := player.global_position
    if not _reported_movement and pos.distance_to(_last_position) > 0.01:
        _reported_movement = true
        GameLogger.log_event("INPUT_MOVEMENT_ACTIVE", {
            "from": str(_last_position),
            "to": str(pos),
            "velocity": str(player.velocity)
        })

    _diagnostic_timer += delta
    if _diagnostic_timer >= 2.0:
        _diagnostic_timer = 0.0
        GameLogger.log_event("INPUT_STATE", {
            "keys": {"w": key_w, "a": key_a, "s": key_s, "d": key_d},
            "position": str(pos),
            "velocity": str(player.velocity)
        })

    var desired := atan2(direction.x, direction.z)
    player.rotation.y = lerp_angle(player.rotation.y, desired, 0.16)

func _find_player() -> CharacterBody3D:
    var scene := get_tree().current_scene
    if scene == null:
        return null
    var found := scene.find_child("Player", true, false)
    return found as CharacterBody3D

func _find_camera_pivot() -> Node3D:
    if player == null:
        return null
    return player.get_node_or_null("CameraPivot") as Node3D