extends Node

# Active combat layer for Infinite Ascension.
# Left click or Space performs a manual attack on the closest enemy in range.

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
    if not InputMap.has_action("attack"):
        InputMap.add_action("attack")
        var key := InputEventKey.new()
        key.physical_keycode = KEY_SPACE
        InputMap.action_add_event("attack", key)
    GameLogger.log_event("ACTIVE_ATTACK_READY", {"range": ATTACK_RANGE, "cooldown": ATTACK_COOLDOWN})

func _process(delta: float) -> void:
    cooldown = max(0.0, cooldown - delta)
    if player == null or not is_instance_valid(player):
        player = _find_player()
    if player == null:
        return
    if cooldown <= 0.0 and (Input.is_action_just_pressed("attack") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
        _attack()

func _find_player() -> CharacterBody3D:
    var found := get_tree().current_scene.find_child("Player", true, false)
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
        var distance := player.global_position.distance_to(enemy.global_position)
        if distance <= best:
            best = distance
            nearest = enemy
    return nearest

func _attack() -> void:
    cooldown = ATTACK_COOLDOWN
    var target: Node3D = _nearest_enemy()
    if target == null:
        GameLogger.log_event("ACTIVE_ATTACK_MISS", {"reason": "no_target"})
        return

    var level: int = 1
    var power: float = 25.0
    var reborn: int = 0
    var runtime: Node = get_tree().current_scene
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

    if hp <= 0.0:
        if runtime != null and runtime.has_method("_defeat_enemy"):
            runtime.call("_defeat_enemy", target)
