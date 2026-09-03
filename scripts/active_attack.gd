extends Node

# Manual combat layer for Infinite Ascension.
# Uses input events instead of polling the action map.

const ATTACK_RANGE: float = 6.0
const ATTACK_COOLDOWN: float = 0.55
const BASE_MULTIPLIER: float = 0.85
const CRIT_CHANCE: float = 0.15
const CRIT_MULTIPLIER: float = 1.75

var cooldown: float = 0.0
var player: CharacterBody3D
var last_target: Node3D

func _ready() -> void:
    process_priority = 100
    GameLogger.log_event("ACTIVE_ATTACK_READY", {"range": ATTACK_RANGE, "cooldown": ATTACK_COOLDOWN})

func _process(delta: float) -> void:
    cooldown = max(0.0, cooldown - delta)
    if player == null or not is_instance_valid(player):
        player = _find_player()

func _input(event: InputEvent) -> void:
    if get_tree().paused or cooldown > 0.0:
        return
    var trigger := false
    if event is InputEventKey:
        var key_event := event as InputEventKey
        trigger = key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_SPACE
    elif event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        trigger = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
    if trigger:
        _attack()

func _find_player() -> CharacterBody3D:
    var scene := get_tree().current_scene
    if scene == null:
        return null
    var found := scene.find_child("Player", true, false)
    return found as CharacterBody3D

func _nearest_enemy() -> Node3D:
    var nearest: Node3D = null
    var best: float = ATTACK_RANGE
    var root := get_tree().current_scene
    if root == null or player == null:
        return null
    for node in root.find_children("Enemy", "Node3D", true, false):
        var enemy := node as Node3D
        if enemy == null or not is_instance_valid(enemy):
            continue
        if not enemy.has_meta("hp"):
            continue
        var distance: float = player.global_position.distance_to(enemy.global_position)
        if distance <= best:
            best = distance
            nearest = enemy
    return nearest

func _attack() -> void:
    if player == null or not is_instance_valid(player):
        player = _find_player()
    if player == null:
        GameLogger.log_event("ACTIVE_ATTACK_MISS", {"reason": "player_not_found"})
        return

    cooldown = ATTACK_COOLDOWN
    var target: Node3D = _nearest_enemy()
    if target == null:
        GameLogger.log_event("ACTIVE_ATTACK_MISS", {"reason": "no_target"})
        return

    var runtime: Node = get_tree().current_scene
    var level: int = 1
    var power: float = 25.0
    var reborn: int = 0
    if runtime != null:
        var runtime_level: Variant = runtime.get("level")
        var runtime_power: Variant = runtime.get("power")
        var runtime_reborn: Variant = runtime.get("reborn")
        if runtime_level != null:
            level = int(runtime_level)
        if runtime_power != null:
            power = float(runtime_power)
        if runtime_reborn != null:
            reborn = int(runtime_reborn)

    var damage: int = max(1, int(power * BASE_MULTIPLIER + float(level) * 2.0 + float(reborn) * 5.0))
    var critical: bool = randf() < CRIT_CHANCE
    if critical:
        damage = int(round(float(damage) * CRIT_MULTIPLIER))

    var hp: float = float(target.get_meta("hp")) - float(damage)
    target.set_meta("hp", hp)
    last_target = target

    if runtime != null and runtime.get("total_damage") != null:
        runtime.set("total_damage", int(runtime.get("total_damage")) + damage)
    if runtime != null and runtime.get("combat_label") != null:
        var combat_label: Label = runtime.get("combat_label") as Label
        if combat_label != null:
            combat_label.text = "⚔ ATTAQUE %s%s · -%d PV" % [str(target.get_meta("name")), " · CRITIQUE" if critical else "", damage]

    GameLogger.log_event("ACTIVE_ATTACK", {
        "target": str(target.get_meta("name")),
        "damage": damage,
        "critical": critical,
        "remaining_hp": hp
    })

    if hp <= 0.0 and runtime != null and runtime.has_method("_defeat_enemy"):
        runtime.call("_defeat_enemy", target)
