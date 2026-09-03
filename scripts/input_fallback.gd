extends Node

# Sole desktop movement controller.
# WASD moves the character. The mouse controls the camera only.

const PLAYER_SPEED := 7.0
const PLAYER_ACCEL := 30.0
const GRAVITY := 22.0

var player: CharacterBody3D
var camera_pivot: Node3D
var key_w := false
var key_a := false
var key_s := false
var key_d := false
var _reported_player := false
var _reported_camera := false
var _reported_movement := false
var _last_position := Vector3.ZERO
var _diagnostic_timer := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 100
    # game_runtime used to move the player as well. Disable only its physics
    # callback so this controller is the single source of character movement.
    call_deferred("_disable_runtime_movement")
    _log("INPUT_FALLBACK_READY", {"mode": "WASD_ONLY", "camera": "MOUSE_ONLY"})

func _disable_runtime_movement() -> void:
    var runtime := get_tree().current_scene
    if runtime != null and runtime.has_method("_move_player"):
        runtime.set_physics_process(false)
        _log("RUNTIME_MOVEMENT_DISABLED", {})

func _input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key := event as InputEventKey
    if key.echo:
        return

    var pressed := key.pressed
    # Use logical key codes: WASD means the actual W/A/S/D keys, independent
    # of the physical position of keys on an AZERTY keyboard.
    match key.keycode:
        KEY_W:
            key_w = pressed
        KEY_A:
            key_a = pressed
        KEY_S:
            key_s = pressed
        KEY_D:
            key_d = pressed

    if pressed and key.keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
        _log("INPUT_KEY_DOWN", {"key": OS.get_keycode_string(key.keycode)})

func _physics_process(delta: float) -> void:
    if player == null or not is_instance_valid(player):
        player = _find_player()
        if player != null and not _reported_player:
            _reported_player = true
            _last_position = player.global_position
            _log("INPUT_PLAYER_FOUND", {"position": str(player.global_position)})

    if camera_pivot == null or not is_instance_valid(camera_pivot):
        camera_pivot = _find_camera_pivot()
        if camera_pivot != null and not _reported_camera:
            _reported_camera = true
            _log("INPUT_CAMERA_FOUND", {})

    if player == null or camera_pivot == null:
        return

    # Poll the engine state as well as the key events. This avoids losing a
    # key-up/down event when a Control node has keyboard focus.
    var live_w := Input.is_key_pressed(KEY_W)
    var live_a := Input.is_key_pressed(KEY_A)
    var live_s := Input.is_key_pressed(KEY_S)
    var live_d := Input.is_key_pressed(KEY_D)

    var input := Vector2(
        float(int(key_d or live_d) - int(key_a or live_a)),
        float(int(key_w or live_w) - int(key_s or live_s))
    )
    if input.length() > 1.0:
        input = input.normalized()

    var forward := -camera_pivot.global_transform.basis.z
    var right := camera_pivot.global_transform.basis.x
    forward.y = 0.0
    right.y = 0.0
    if forward.length_squared() > 0.001:
        forward = forward.normalized()
    if right.length_squared() > 0.001:
        right = right.normalized()

    # WASD controls the character relative to the camera direction.
    # No keyboard input is used to rotate the camera.
    var direction := right * input.x + forward * input.y
    if direction.length_squared() > 1.0:
        direction = direction.normalized()

    var target_velocity := direction * PLAYER_SPEED
    player.velocity.x = move_toward(player.velocity.x, target_velocity.x, PLAYER_ACCEL * delta)
    player.velocity.z = move_toward(player.velocity.z, target_velocity.z, PLAYER_ACCEL * delta)
    if player.is_on_floor():
        player.velocity.y = -0.2
    else:
        player.velocity.y -= GRAVITY * delta
    player.move_and_slide()

    var pos := player.global_position
    if not _reported_movement and pos.distance_to(_last_position) > 0.01:
        _reported_movement = true
        _log("INPUT_MOVEMENT_ACTIVE", {
            "from": str(_last_position),
            "to": str(pos),
            "velocity": str(player.velocity)
        })

    _diagnostic_timer += delta
    if _diagnostic_timer >= 2.0:
        _diagnostic_timer = 0.0
        _log("INPUT_STATE", {
            "keys": {"w": live_w, "a": live_a, "s": live_s, "d": live_d},
            "position": str(pos),
            "velocity": str(player.velocity)
        })

    # Character rotation follows movement direction. Camera rotation remains
    # entirely controlled by the mouse in game_runtime.gd.
    if direction.length_squared() > 0.01:
        var desired := atan2(direction.x, direction.z)
        player.rotation.y = lerp_angle(player.rotation.y, desired, 0.16)

func _find_player() -> CharacterBody3D:
    var root := get_tree().root
    var found := root.find_child("Player", true, false)
    return found as CharacterBody3D

func _find_camera_pivot() -> Node3D:
    if player == null:
        return null
    return player.get_node_or_null("CameraPivot") as Node3D

func _log(event_name: String, data: Dictionary = {}) -> void:
    var logger := get_node_or_null("/root/GameLogger")
    if logger != null and logger.has_method("log_event"):
        logger.call("log_event", event_name, data)
