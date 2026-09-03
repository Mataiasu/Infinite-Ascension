extends Node

# Sole desktop movement controller.
# W/A/S/D move the character. Mouse controls the camera only.

const PLAYER_SPEED := 7.0
const PLAYER_ACCEL := 30.0
const GRAVITY := 22.0

var player: CharacterBody3D
var camera_pivot: Node3D
var key_w := false
var key_a := false
var key_s := false
var key_d := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 100
    call_deferred("_disable_runtime_movement")
    _log("INPUT_FALLBACK_READY", {"movement": "WASD", "camera": "MOUSE_ONLY"})

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
    # key_label is the key actually printed on the active keyboard layout.
    # This gives literal W/A/S/D controls without turning Z/Q into movement.
    match key.key_label:
        KEY_W:
            key_w = pressed
        KEY_A:
            key_a = pressed
        KEY_S:
            key_s = pressed
        KEY_D:
            key_d = pressed

func _physics_process(delta: float) -> void:
    if player == null or not is_instance_valid(player):
        player = _find_player()
    if camera_pivot == null or not is_instance_valid(camera_pivot):
        camera_pivot = _find_camera_pivot()
    if player == null or camera_pivot == null:
        return

    var input := Vector2(
        float(int(key_d) - int(key_a)),
        float(int(key_w) - int(key_s))
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

    # IMPORTANT: do not rotate the character here. CameraPivot is a child of
    # Player, so rotating Player would also rotate the camera. The camera is
    # therefore rotated exclusively by mouse input in game_runtime.gd.

func _find_player() -> CharacterBody3D:
    var found := get_tree().root.find_child("Player", true, false)
    return found as CharacterBody3D

func _find_camera_pivot() -> Node3D:
    if player == null:
        return null
    return player.get_node_or_null("CameraPivot") as Node3D

func _log(event_name: String, data: Dictionary = {}) -> void:
    var logger := get_node_or_null("/root/GameLogger")
    if logger != null and logger.has_method("log_event"):
        logger.call("log_event", event_name, data)
