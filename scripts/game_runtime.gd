extends Node3D

# Infinite Ascension — playable vertical slice
# Third-person exploration, WASD movement, mouse camera, enemies, auto-combat,
# XP/levels, Reborn progression, procedural scenery and local save.

const XP_PER_LEVEL := 100.0
const REBORN_LEVEL := 25
const PLAYER_SPEED := 7.0
const PLAYER_ACCEL := 24.0
const GRAVITY := 22.0
const ATTACK_INTERVAL := 1.0
const ATTACK_RANGE := 4.0
const ENEMY_ATTACK_RANGE := 2.2
const MAX_ENEMIES := 12
const WORLD_SIZE := 110.0

var level := 1
var xp := 0.0
var reborn := 0
var power := 25.0
var hp := 100.0
var max_hp := 100.0
var gold := 50
var kills := 0
var total_damage := 0
var frontier_min := 1
var frontier_max := 5
var zone_index := 0

var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var enemies: Array[Node3D] = []
var attack_timer := 0.0
var enemy_attack_timer := 0.0
var spawn_timer := 0.0
var autosave_timer := 0.0
var mouse_captured := true
var last_message := "Explore le monde."

var zone_names := ["Forêt des Brumes", "Vallée des Cendres", "Cité Fracturée", "Océan Céleste", "Royaume Mécanique", "Abysses Stellaires", "Frontière Infinie"]
var zone_biomes := ["Sylvestre", "Volcanique", "Ruines", "Aérien", "Mécanique", "Cosmique", "Inconnu"]
var zone_colors := [Color("#193226"), Color("#3a211b"), Color("#29243a"), Color("#243a50"), Color("#283738"), Color("#302144"), Color("#20182f")]

var level_label: Label
var hp_label: Label
var xp_label: Label
var zone_label: Label
var combat_label: Label
var stats_label: Label
var hint_label: Label
var message_label: Label
var reborn_button: Button
var crosshair: Label

func _ready() -> void:
    randomize()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _build_world()
    _build_player()
    _build_camera()
    _build_hud()
    _load_save()
    _update_frontier()
    _apply_zone_visuals()
    _spawn_initial_enemies()
    _refresh_hud()
    _message("Infinite Ascension — exploration libre")

func _process(delta: float) -> void:
    _move_player(delta)
    _move_enemies(delta)
    _auto_combat(delta)
    _enemy_attacks(delta)
    _spawn_loop(delta)
    _autosave(delta)
    _update_camera()
    _refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and mouse_captured:
        camera_pivot.rotate_y(-event.relative.x * 0.004)
        camera.rotation.x = clamp(camera.rotation.x - event.relative.y * 0.003, deg_to_rad(-65), deg_to_rad(20))
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        mouse_captured = not mouse_captured
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not mouse_captured:
        mouse_captured = true
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_world() -> void:
    var ground := StaticBody3D.new()
    ground.name = "WorldGround"
    add_child(ground)

    var mesh_instance := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(WORLD_SIZE, WORLD_SIZE)
    mesh_instance.mesh = plane
    var mat := StandardMaterial3D.new()
    mat.albedo_color = zone_colors[0]
    mat.roughness = 1.0
    mesh_instance.material_override = mat
    ground.add_child(mesh_instance)

    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(WORLD_SIZE, 0.2, WORLD_SIZE)
    shape.shape = box
    shape.position.y = -0.1
    ground.add_child(shape)

    # A simple procedural world: trees, rocks and glowing crystals.
    for i in range(95):
        var p := Vector3(randf_range(-WORLD_SIZE * 0.47, WORLD_SIZE * 0.47), 0, randf_range(-WORLD_SIZE * 0.47, WORLD_SIZE * 0.47))
        if p.length() < 8.0:
            continue
        _create_tree(p, randf_range(0.8, 1.35)) if i % 3 != 0 else _create_rock(p)

    for i in range(14):
        var p := Vector3(randf_range(-45, 45), 0, randf_range(-45, 45))
        if p.length() < 10:
            continue
        _create_crystal(p)

func _create_tree(pos: Vector3, scale_value: float) -> void:
    var root := Node3D.new()
    root.position = pos
    root.scale = Vector3.ONE * scale_value
    add_child(root)

    var trunk := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.height = 2.8
    cylinder.top_radius = 0.22
    cylinder.bottom_radius = 0.35
    trunk.mesh = cylinder
    var trunk_mat := StandardMaterial3D.new()
    trunk_mat.albedo_color = Color("#35261d")
    trunk.material_override = trunk_mat
    trunk.position.y = 1.4
    root.add_child(trunk)

    var crown := MeshInstance3D.new()
    var cone := SphereMesh.new()
    cone.height = 3.8
    cone.radius = 1.5
    crown.mesh = cone
    var leaf_mat := StandardMaterial3D.new()
    leaf_mat.albedo_color = Color("#2e6b4a")
    crown.material_override = leaf_mat
    crown.position.y = 3.4
    root.add_child(crown)

func _create_rock(pos: Vector3) -> void:
    var rock := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.height = randf_range(0.7, 1.8)
    sphere.radius = randf_range(0.5, 1.2)
    rock.mesh = sphere
    rock.position = pos + Vector3(0, sphere.height * 0.5, 0)
    rock.scale.x = randf_range(0.7, 1.5)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#42485b")
    mat.roughness = 0.9
    rock.material_override = mat
    add_child(rock)

func _create_crystal(pos: Vector3) -> void:
    var crystal := MeshInstance3D.new()
    var prism := PrismMesh.new()
    prism.size = Vector3(0.5, 1.8, 0.5)
    crystal.mesh = prism
    crystal.position = pos + Vector3(0, 0.9, 0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#8f63ff")
    mat.emission_enabled = true
    mat.emission = Color("#6c37b8")
    mat.emission_energy_multiplier = 2.0
    crystal.material_override = mat
    add_child(crystal)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 1.0, 0)
    add_child(player)

    var collision := CollisionShape3D.new()
    var capsule_shape := CapsuleShape3D.new()
    capsule_shape.height = 1.8
    capsule_shape.radius = 0.42
    collision.shape = capsule_shape
    player.add_child(collision)

    var mesh := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.height = 1.8
    capsule.radius = 0.42
    mesh.mesh = capsule
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#a66cff")
    mat.emission_enabled = true
    mat.emission = Color("#542b91")
    mat.emission_energy_multiplier = 1.2
    mesh.material_override = mat
    mesh.position.y = 0.9
    player.add_child(mesh)

    var light := OmniLight3D.new()
    light.light_color = Color("#a66cff")
    light.light_energy = 0.8
    light.omni_range = 6.0
    light.position.y = 1.2
    player.add_child(light)

func _build_camera() -> void:
    camera_pivot = Node3D.new()
    camera_pivot.name = "CameraPivot"
    player.add_child(camera_pivot)
    camera_pivot.position.y = 1.5

    camera = Camera3D.new()
    camera.position = Vector3(0, 4.0, 8.5)
    camera.rotation_degrees.x = -14.0
    camera.current = true
    camera.fov = 72.0
    camera_pivot.add_child(camera)

func _update_camera() -> void:
    camera.position = camera.position.lerp(Vector3(0, 4.0, 8.5), 0.12)

func _move_player(delta: float) -> void:
    if player == null:
        return
    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var forward := -camera_pivot.global_transform.basis.z
    var right := camera_pivot.global_transform.basis.x
    var direction := (right * input.x + forward * input.y)
    direction.y = 0
    if direction.length() > 1.0:
        direction = direction.normalized()

    var target_velocity := direction * PLAYER_SPEED
    player.velocity.x = move_toward(player.velocity.x, target_velocity.x, PLAYER_ACCEL * delta)
    player.velocity.z = move_toward(player.velocity.z, target_velocity.z, PLAYER_ACCEL * delta)
    if not player.is_on_floor():
        player.velocity.y -= GRAVITY * delta
    else:
        player.velocity.y = -0.2
    player.move_and_slide()
    player.position.x = clamp(player.position.x, -WORLD_SIZE * 0.48, WORLD_SIZE * 0.48)
    player.position.z = clamp(player.position.z, -WORLD_SIZE * 0.48, WORLD_SIZE * 0.48)

    if direction.length() > 0.1:
        var desired := atan2(direction.x, direction.z)
        player.rotation.y = lerp_angle(player.rotation.y, desired, 0.16)

func _spawn_initial_enemies() -> void:
    for i in range(8):
        _spawn_enemy()

func _spawn_enemy() -> void:
    if enemies.size() >= MAX_ENEMIES:
        return
    var enemy := CharacterBody3D.new()
    enemy.name = "Enemy"
    var angle := randf() * TAU
    var distance := randf_range(10.0, 32.0)
    enemy.position = player.position + Vector3(cos(angle) * distance, 0.9, sin(angle) * distance)
    enemy.position.x = clamp(enemy.position.x, -45.0, 45.0)
    enemy.position.z = clamp(enemy.position.z, -45.0, 45.0)
    add_child(enemy)

    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.height = 1.6
    shape.radius = 0.45
    collision.shape = shape
    enemy.add_child(collision)

    var visual := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.height = 1.6
    mesh.radius = 0.45
    visual.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#d85a79") if randi_range(0, 1) == 0 else Color("#657ee8")
    mat.emission_enabled = true
    mat.emission = mat.albedo_color * 0.15
    visual.material_override = mat
    visual.position.y = 0.8
    enemy.add_child(visual)

    enemy.set_meta("level", randi_range(frontier_min, frontier_max))
    enemy.set_meta("hp", float(int(enemy.get_meta("level")) * 30 + 30))
    enemy.set_meta("max_hp", enemy.get_meta("hp"))
    enemy.set_meta("damage", float(int(enemy.get_meta("level")) * 2 + 3))
    enemy.set_meta("name", ["Brumeux", "Ravager", "Cendreux"][randi_range(0, 2)])
    enemies.append(enemy)

func _move_enemies(delta: float) -> void:
    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        var distance := enemy.global_position.distance_to(player.global_position)
        if distance > ENEMY_ATTACK_RANGE:
            var direction := (player.global_position - enemy.global_position)
            direction.y = 0
            direction = direction.normalized()
            enemy.velocity = direction * min(2.4 + float(enemy.get_meta("level")) * 0.08, 4.0)
            enemy.move_and_slide()
            enemy.rotation.y = lerp_angle(enemy.rotation.y, atan2(direction.x, direction.z), 0.1)
        else:
            enemy.velocity = Vector3.ZERO

func _nearest_enemy(max_distance := ATTACK_RANGE) -> Node3D:
    var nearest: Node3D = null
    var best := max_distance
    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        var distance := player.global_position.distance_to(enemy.global_position)
        if distance < best:
            best = distance
            nearest = enemy
    return nearest

func _auto_combat(delta: float) -> void:
    attack_timer += delta
    if attack_timer < ATTACK_INTERVAL:
        return
    attack_timer = 0.0
    var target := _nearest_enemy()
    if target == null:
        combat_label.text = "Aucune cible proche — explore pour trouver des ennemis."
        return
    var damage := max(1, int(power * 0.55 + level * 2.0 + reborn * 5.0))
    target.set_meta("hp", float(target.get_meta("hp")) - damage)
    total_damage += damage
    combat_label.text = "⚔ %s Niv.%d · -%d PV" % [target.get_meta("name"), int(target.get_meta("level")), damage]
    _message("Attaque automatique : %s" % target.get_meta("name"))
    if float(target.get_meta("hp")) <= 0:
        _defeat_enemy(target)

func _enemy_attacks(delta: float) -> void:
    enemy_attack_timer += delta
    if enemy_attack_timer < 1.3:
        return
    enemy_attack_timer = 0.0
    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        if enemy.global_position.distance_to(player.global_position) <= ENEMY_ATTACK_RANGE:
            hp -= float(enemy.get_meta("damage"))
    if hp <= 0:
        _player_defeated()

func _defeat_enemy(enemy: Node3D) -> void:
    var enemy_level := int(enemy.get_meta("level"))
    var reward_xp := 18 + enemy_level * 7
    var reward_gold := 5 + enemy_level * 3
    xp += reward_xp
    gold += reward_gold
    kills += 1
    power += 1.5 + enemy_level * 0.12
    _message("Victoire · +%d XP · +%d or" % [reward_xp, reward_gold])
    enemy.queue_free()
    enemies.erase(enemy)
    while xp >= XP_PER_LEVEL:
        xp -= XP_PER_LEVEL
        level += 1
        max_hp += 12 + reborn * 2
        hp = max_hp
        power += 8 + reborn * 2
        _message("Niveau %d atteint" % level)
        if level % 5 == 0:
            _update_frontier()

func _player_defeated() -> void:
    hp = max_hp
    gold = max(0, gold - 10)
    player.position = Vector3.ZERO
    _message("Défaite · retour au point de départ · -10 or")

func _spawn_loop(delta: float) -> void:
    spawn_timer += delta
    if spawn_timer >= 4.0:
        spawn_timer = 0
        if enemies.size() < MAX_ENEMIES:
            _spawn_enemy()

func _update_frontier() -> void:
    var average := (level + group_levels_average()) / 2.0
    frontier_min = max(1, int(floor(average)))
    frontier_max = frontier_min + 4
    zone_index = clamp(int(level / 10), 0, zone_names.size() - 1)

func group_levels_average() -> float:
    return float(level + max(1, level - 1) + level + 1) / 3.0

func _apply_zone_visuals() -> void:
    var world_ground := get_node_or_null("WorldGround/MeshInstance3D")
    if world_ground:
        var mat := world_ground.material_override as StandardMaterial3D
        if mat:
            mat.albedo_color = zone_colors[zone_index]

func _reborn() -> void:
    if level < REBORN_LEVEL:
        _message("Reborn disponible au niveau %d." % REBORN_LEVEL)
        return
    reborn += 1
    level = 1
    xp = 0
    power = 25 + reborn * 12
    max_hp = 100 + reborn * 15
    hp = max_hp
    gold += 100 + reborn * 50
    _update_frontier()
    _apply_zone_visuals()
    _message("REBORN %d · bonus permanent obtenu" % reborn)
    _save()

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)

    var top := PanelContainer.new()
    top.position = Vector2(18, 16)
    top.size = Vector2(560, 112)
    top.add_theme_stylebox_override("panel", _panel(Color("#0b1020dd")))
    layer.add_child(top)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 4)
    top.add_child(box)

    level_label = _label("NIVEAU 1 · REBORN 0", 20, Color("#f0f2ff")); box.add_child(level_label)
    hp_label = _label("PV", 12, Color("#e98ba4")); box.add_child(hp_label)
    xp_label = _label("XP", 12, Color("#bca5ff")); box.add_child(xp_label)
    stats_label = _label("", 11, Color("#a5aec9")); box.add_child(stats_label)

    var zone_panel := PanelContainer.new()
    zone_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    zone_panel.position = Vector2(-388, 16)
    zone_panel.size = Vector2(370, 94)
    zone_panel.add_theme_stylebox_override("panel", _panel(Color("#0b1020dd")))
    layer.add_child(zone_panel)
    var zone_box := VBoxContainer.new(); zone_panel.add_child(zone_box)
    zone_label = _label("", 18, Color("#f0f2ff")); zone_box.add_child(zone_label)
    combat_label = _label("Explore pour rencontrer des ennemis.", 11, Color("#55dfa0")); zone_box.add_child(combat_label)

    crosshair = _label("+", 22, Color("#ffffffbb"))
    crosshair.set_anchors_preset(Control.PRESET_CENTER)
    crosshair.position = Vector2(-8, -16)
    crosshair.size = Vector2(20, 32)
    layer.add_child(crosshair)

    hint_label = _label("WASD : se déplacer   •   Souris : caméra   •   Échap : libérer la souris", 11, Color("#c1c8df"))
    hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    hint_label.position = Vector2(18, -48)
    hint_label.size = Vector2(650, 30)
    layer.add_child(hint_label)

    message_label = _label("", 13, Color("#e7ddff"))
    message_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    message_label.position = Vector2(-300, -90)
    message_label.size = Vector2(600, 36)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    layer.add_child(message_label)

    reborn_button = Button.new()
    reborn_button.text = "REBORN"
    reborn_button.position = Vector2(18, 138)
    reborn_button.size = Vector2(140, 42)
    reborn_button.pressed.connect(_reborn)
    layer.add_child(reborn_button)

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label

func _panel(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color("#2d3858")
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 9
    style.content_margin_bottom = 9
    return style

func _refresh_hud() -> void:
    if not player:
        return
    level_label.text = "NIVEAU %d · REBORN %d" % [level, reborn]
    hp_label.text = "PV  %d / %d" % [max(0, int(hp)), int(max_hp)]
    xp_label.text = "XP  %d / %d" % [int(xp), int(XP_PER_LEVEL)]
    stats_label.text = "Puissance %d · Or %d · Kills %d" % [int(power), gold, kills]
    zone_label.text = "%s · %s" % [zone_names[zone_index], zone_biomes[zone_index]]
    reborn_button.disabled = level < REBORN_LEVEL

func _message(text: String) -> void:
    last_message = text
    if message_label:
        message_label.text = text

func _autosave(delta: float) -> void:
    autosave_timer += delta
    if autosave_timer >= 10.0:
        autosave_timer = 0
        _save()

func _save() -> void:
    var data := {
        "level": level,
        "xp": xp,
        "reborn": reborn,
        "power": power,
        "hp": hp,
        "max_hp": max_hp,
        "gold": gold,
        "kills": kills,
        "total_damage": total_damage
    }
    var file := FileAccess.open("user://infinite_ascension_save.json", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
        file.close()

func _load_save() -> void:
    if not FileAccess.file_exists("user://infinite_ascension_save.json"):
        return
    var file := FileAccess.open("user://infinite_ascension_save.json", FileAccess.READ)
    if not file:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    level = int(parsed.get("level", level))
    xp = float(parsed.get("xp", xp))
    reborn = int(parsed.get("reborn", reborn))
    power = float(parsed.get("power", power))
    hp = float(parsed.get("hp", hp))
    max_hp = float(parsed.get("max_hp", max_hp))
    gold = int(parsed.get("gold", gold))
    kills = int(parsed.get("kills", kills))
    total_damage = int(parsed.get("total_damage", total_damage))
