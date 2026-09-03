extends Node

# Robust keyboard fallback for desktop builds.
# The normal InputMap remains supported, but this path bypasses action-map issues
# by reading the physical keyboard directly. It only takes over when the action
# vector is neutral, so it cannot double the normal movement.

const PLAYER_SPEED := 7.0
const PLAYER_ACCEL := 24.0
const PROCESS_PRIORITY := 100

var player: CharacterBody3D
var camera_pivot: Node3D
var _reported := false

func _ready() -> void:
    process_priority = PROCESS_PRIORITY
    GameLogger.log_event("INPUT_FALLBACK_READY", {})

func _process(delta: float) -> void:
    if get_tree().paused:
        return
    if player == null or not is_instance_valid(player):
        player = _find_player()
        camera_pivot = _find_camera_pivot()
    if player == null or camera_pivot == null:
        return

    # Let the existing InputMap movement win when it works.
    var mapped := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if mapped.length() > 0.01:
        return

    var x := 0.0
    var z := 0.0
    if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
        x -= 1.0
    if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
        x += 1.0
    if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
        z += 1.0
    if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
        z -= 1.0

    var input := Vector2(x, z)
    if input.length() <= 0.01:
        return
    input = input.normalized()

    var forward := -camera_pivot.global_transform.basis.z
    var right := camera_pivot.global_transform.basis.x
    forward.y = 0
    right.y = 0
    forward = forward.normalized()
    right = right.normalized()
    var direction := right * input.x + forward * input.y
    direction.y = 0
    direction = direction.normalized()

    var target_velocity := direction * PLAYER_SPEED
    player.velocity.x = move_toward(player.velocity.x, target_velocity.x, PLAYER_ACCEL * delta)
    player.velocity.z = move_toward(player.velocity.z, target_velocity.z, PLAYER_ACCEL * delta)
    player.move_and_slide()

    if direction.length() > 0.1:
        var desired := atan2(direction.x, direction.z)
        player.rotation.y = lerp_angle(player.rotation.y, desired, 0.16)

    if not _reported:
        _reported = true
        GameLogger.log_event("INPUT_FALLBACK_MOVEMENT_ACTIVE", {"keys": "WASD/arrows"})

func _find_player() -> CharacterBody3D:
    var found := get_tree().current_scene.find_child("Player", true, false)
    return found as CharacterBody3D

func _find_camera_pivot() -> Node3D:
    if player == null:
        return null
    return player.get_node_or_null("CameraPivot") as Node3D
