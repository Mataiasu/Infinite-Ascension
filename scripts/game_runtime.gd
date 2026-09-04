extends Node3D

# Infinite Ascension — playable vertical slice
# Third-person exploration, Godot InputMap movement, mouse-only camera,
# manual combat, enemies, XP/levels, Reborn progression, procedural scenery and local save.

const XP_PER_LEVEL := 100.0
const REBORN_LEVEL := 25
const PLAYER_SPEED := 7.0
const PLAYER_ACCEL := 30.0
const GRAVITY := 22.0
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
    process_mode = Node.PROCESS_MODE_PAUSABLE
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
    _move_enemies(delta)
    _enemy_attacks(delta)
    _spawn_loop(delta)
    _autosave(delta)
    _update_camera()
    _refresh_hud()

func _physics_process(delta: float) -> void:
    _move_player(delta)

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key := event as InputEventKey
        if key.echo:
            return
        if key.keycode == KEY_ESCAPE and key.pressed:
            mouse_captured = not mouse_captured
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseMotion and mouse_captured:
        if camera_pivot != null and camera != null:
            camera_pivot.rotate_y(-event.relative.x * 0.004)
            camera.rotation.x = clamp(camera.rotation.x - event.relative.y * 0.003, deg_to_rad(-65), deg_to_rad(20))
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not mouse_captured:
        mouse_captured = true
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_world() -> void:
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#07101a")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#6677aa")
    env.ambient_light_energy = 0.65
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.environment = env
    add_child(environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -30, 0)
    sun.light_energy = 1.0
    sun.shadow_enabled = true
    add_child(sun)

    var ground := StaticBody3D.new()
    ground.name = "Ground"
    add_child(ground)

    var mesh_instance := MeshInstance3D.new()
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(WORLD_SIZE, WORLD_SIZE)
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#18231e")
    material.roughness = 0.95
    mesh_instance.material_override = material
    ground.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(WORLD_SIZE, 0.2, WORLD_SIZE)
    collision.shape = shape
    collision.position.y = -0.1
    ground.add_child(collision)

    for i in range(70):
        _spawn_scenery(i)

func _spawn_scenery(index: int) -> void:
    var root := Node3D.new()
    root.name = "Scenery_%d" % index
    var angle := randf() * TAU
    var distance := randf_range(5.0, WORLD_SIZE * 0.44)
    root.position = Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
    add_child(root)

    if index % 3 == 0:
        var trunk := MeshInstance3D.new()
        var cylinder := CylinderMesh.new()
        cylinder.top_radius = 0.22
        cylinder.bottom_radius = 0.32
        cylinder.height = randf_range(2.0, 3.8)
        trunk.mesh = cylinder
        var bark := StandardMaterial3D.new()
        bark.albedo_color = Color("#3a2a20")
        bark.roughness = 1.0
        trunk.material_override = bark
        trunk.position.y = cylinder.height * 0.5
        root.add_child(trunk)

        var crown := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = randf_range(1.0, 1.5)
        sphere.height = sphere.radius * 2.0
        crown.mesh = sphere
        var leaves := StandardMaterial3D.new()
        leaves.albedo_color = Color("#214b35")
        leaves.roughness = 0.9
        crown.material_override = leaves
        crown.position.y = cylinder.height + sphere.radius * 0.55
        root.add_child(crown)
    else:
        var rock := MeshInstance3D.new()
        var box := BoxMesh.new()
        var scale := randf_range(0.4, 1.2)
        box.size = Vector3(scale, scale * randf_range(0.5, 1.1), scale * randf_range(0.7, 1.3))
        rock.mesh = box
        var stone := StandardMaterial3D.new()
        stone.albedo_color = Color("#36404b")
        stone.roughness = 1.0
        rock.material_override = stone
        rock.position.y = box.size.y * 0.5
        rock.rotation.y = randf() * TAU
        root.add_child(rock)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 1.0, 0)
    add_child(player)

    var capsule := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.45
    shape.height = 1.8
    capsule.shape = shape
    capsule.position.y = 0.9
    player.add_child(capsule)

    var body := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.45
    mesh.height = 1.8
    body.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#9b7cff")
    material.metallic = 0.15
    material.roughness = 0.55
    body.material_override = material
    body.position.y = 0.9
    player.add_child(body)

func _build_camera() -> void:
    camera_pivot = Node3D.new()
    camera_pivot.name = "CameraPivot"
    add_child(camera_pivot)
    camera_pivot.global_position = player.global_position + Vector3(0, 1.5, 0)

    camera = Camera3D.new()
    camera.position = Vector3(0, 4.0, 8.5)
    camera.rotation_degrees.x = -14.0
    camera.current = true
    camera.fov = 72.0
    camera_pivot.add_child(camera)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    layer.layer = 10
    add_child(layer)

    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)

    level_label = Label.new()
    level_label.position = Vector2(24, 18)
    level_label.add_theme_font_size_override("font_size", 20)
    root.add_child(level_label)

    hp_label = Label.new()
    hp_label.position = Vector2(24, 48)
    root.add_child(hp_label)

    xp_label = Label.new()
    xp_label.position = Vector2(24, 72)
    root.add_child(xp_label)

    stats_label = Label.new()
    stats_label.position = Vector2(24, 105)
    root.add_child(stats_label)

    zone_label = Label.new()
    zone_label.position = Vector2(24, 145)
    zone_label.add_theme_font_size_override("font_size", 16)
    root.add_child(zone_label)

    combat_label = Label.new()
    combat_label.position = Vector2(24, 175)
    root.add_child(combat_label)

    hint_label = Label.new()
    hint_label.position = Vector2(24, 205)
    hint_label.text = "ZQSD / WASD : déplacer  •  Souris : caméra  •  Espace / clic : attaque  •  Échap : pause"
    root.add_child(hint_label)

    message_label = Label.new()
    message_label.position = Vector2(0, 650)
    message_label.size = Vector2(1152, 40)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_font_size_override("font_size", 18)
    root.add_child(message_label)

    crosshair = Label.new()
    crosshair.text = "+"
    crosshair.position = Vector2(571, 335)
    crosshair.add_theme_font_size_override("font_size", 24)
    root.add_child(crosshair)

    reborn_button = Button.new()
    reborn_button.text = "REBORN"
    reborn_button.position = Vector2(1000, 20)
    reborn_button.size = Vector2(130, 48)
    reborn_button.pressed.connect(_do_reborn)
    root.add_child(reborn_button)

func _refresh_hud() -> void:
    if level_label == null:
        return
    level_label.text = "Niveau %d  •  Reborn %d" % [level, reborn]
    hp_label.text = "HP %d / %d" % [round(hp), round(max_hp)]
    xp_label.text = "XP %d / %d" % [round(xp), round(XP_PER_LEVEL)]
    stats_label.text = "Puissance %d  •  Or %d  •  Kills %d" % [round(power), gold, kills]
    zone_label.text = "%s  •  %s  •  Frontière %d–%d" % [zone_names[zone_index], zone_biomes[zone_index], frontier_min, frontier_max]
    combat_label.text = "Dégâts totaux : %d" % total_damage
    reborn_button.visible = level >= REBORN_LEVEL

func _message(text_value: String) -> void:
    last_message = text_value
    if message_label != null:
        message_label.text = text_value

func _move_player(delta: float) -> void:
    if player == null or not is_instance_valid(player) or camera_pivot == null:
        return

    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var forward := -camera_pivot.global_transform.basis.z
    var right := camera_pivot.global_transform.basis.x
    forward.y = 0.0
    right.y = 0.0
    if forward.length_squared() > 0.001:
        forward = forward.normalized()
    if right.length_squared() > 0.001:
        right = right.normalized()

    var world_direction := right * input_vector.x + forward * input_vector.y
    if world_direction.length_squared() > 1.0:
        world_direction = world_direction.normalized()

    var target_velocity := world_direction * PLAYER_SPEED
    player.velocity.x = move_toward(player.velocity.x, target_velocity.x, PLAYER_ACCEL * delta)
    player.velocity.z = move_toward(player.velocity.z, target_velocity.z, PLAYER_ACCEL * delta)

    if player.is_on_floor():
        player.velocity.y = -0.2
    else:
        player.velocity.y -= GRAVITY * delta

    player.move_and_slide()
    player.position.x = clamp(player.position.x, -WORLD_SIZE * 0.48, WORLD_SIZE * 0.48)
    player.position.z = clamp(player.position.z, -WORLD_SIZE * 0.48, WORLD_SIZE * 0.48)

func _move_enemies(delta: float) -> void:
    if player == null:
        return
    for enemy in enemies:
        if enemy == null or not is_instance_valid(enemy):
            continue
        var to_player := player.global_position - enemy.global_position
        to_player.y = 0.0
        var distance := to_player.length()
        if distance > ENEMY_ATTACK_RANGE and distance > 0.01:
            enemy.global_position += to_player.normalized() * min(2.4 + level * 0.08, 4.0) * delta
            enemy.look_at(Vector3(player.global_position.x, enemy.global_position.y, player.global_position.z), Vector3.UP)

func _enemy_attacks(delta: float) -> void:
    enemy_attack_timer -= delta
    if enemy_attack_timer > 0.0 or player == null:
        return
    enemy_attack_timer = 1.3
    var total := 0
    for enemy in enemies:
        if enemy == null or not is_instance_valid(enemy):
            continue
        if enemy.global_position.distance_to(player.global_position) <= ENEMY_ATTACK_RANGE:
            total += int(enemy.get_meta("damage", 5))
    if total > 0:
        hp -= total
        _message("Tu subis %d dégâts." % total)
        if hp <= 0.0:
            hp = 0.0
            _handle_defeat()

func _spawn_loop(delta: float) -> void:
    spawn_timer -= delta
    if spawn_timer <= 0.0 and enemies.size() < MAX_ENEMIES:
        spawn_timer = 4.0
        _spawn_enemy()

func _spawn_initial_enemies() -> void:
    for i in range(6):
        _spawn_enemy()

func _spawn_enemy() -> void:
    if player == null or enemies.size() >= MAX_ENEMIES:
        return
    var enemy := CharacterBody3D.new()
    enemy.name = "Enemy_%d" % enemies.size()
    var angle := randf() * TAU
    var distance := randf_range(14.0, 34.0)
    enemy.position = player.position + Vector3(cos(angle) * distance, 1.0, sin(angle) * distance)
    enemy.position.x = clamp(enemy.position.x, -WORLD_SIZE * 0.45, WORLD_SIZE * 0.45)
    enemy.position.z = clamp(enemy.position.z, -WORLD_SIZE * 0.45, WORLD_SIZE * 0.45)
    add_child(enemy)

    var level_value := randi_range(frontier_min, frontier_max)
    var enemy_hp := level_value * 30 + 30
    var enemy_damage := level_value * 2 + 3
    enemy.set_meta("level", level_value)
    enemy.set_meta("hp", enemy_hp)
    enemy.set_meta("max_hp", enemy_hp)
    enemy.set_meta("damage", enemy_damage)

    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.5
    shape.height = 1.8
    collision.shape = shape
    collision.position.y = 0.9
    enemy.add_child(collision)

    var body := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.8
    body.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#b64cff") if randi() % 2 == 0 else Color("#ff4c7a")
    material.emission_enabled = true
    material.emission = material.albedo_color * 0.15
    body.material_override = material
    body.position.y = 0.9
    body.scale = Vector3.ONE * (1.0 + level_value * 0.02)
    enemy.add_child(body)

    var label := Label3D.new()
    label.text = "Niv. %d" % level_value
    label.position.y = 2.2
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 32
    enemy.add_child(label)

    enemies.append(enemy)

func _attack() -> void:
    var closest: Node3D = null
    var closest_distance := ATTACK_RANGE
    for enemy in enemies:
        if enemy == null or not is_instance_valid(enemy):
            continue
        var distance := enemy.global_position.distance_to(player.global_position)
        if distance <= closest_distance:
            closest = enemy
            closest_distance = distance
    if closest == null:
        _message("Aucune cible à portée.")
        return
    var critical := randf() < 0.15
    var damage := int(round(power * randf_range(0.85, 1.15) * (1.75 if critical else 1.0)))
    var current_hp := int(closest.get_meta("hp", 1)) - damage
    closest.set_meta("hp", current_hp)
    total_damage += damage
    _message("Coup critique ! %d dégâts" % damage if critical else "%d dégâts" % damage)
    if current_hp <= 0:
        _defeat_enemy(closest)

func _input_attack(event: InputEvent) -> void:
    if event.is_action_pressed("attack"):
        _attack()

func _defeat_enemy(enemy: Node3D) -> void:
    var enemy_level := int(enemy.get_meta("level", 1))
    xp += 18 + enemy_level * 7
    gold += 5 + enemy_level * 3
    power += 1.5 + enemy_level * 0.12
    kills += 1
    enemies.erase(enemy)
    enemy.queue_free()
    _check_level_up()
    _update_frontier()

func _check_level_up() -> void:
    while xp >= XP_PER_LEVEL:
        xp -= XP_PER_LEVEL
        level += 1
        max_hp += 12 + reborn * 2
        hp = max_hp
        power += 8 + reborn * 2
        _message("Niveau %d ! Puissance augmentée." % level)

func _handle_defeat() -> void:
    for enemy in enemies:
        if enemy != null and is_instance_valid(enemy):
            enemy.queue_free()
    enemies.clear()
    level = 1
    xp = 0.0
    power = 25 + reborn * 12
    max_hp = 100 + reborn * 15
    hp = max_hp
    player.position = Vector3(0, 1.0, 0)
    _update_frontier()
    _spawn_initial_enemies()
    _message("Tu as été vaincu. Nouvelle tentative.")
    _save_game()

func _do_reborn() -> void:
    if level < REBORN_LEVEL:
        return
    reborn += 1
    level = 1
    xp = 0.0
    power = 25 + reborn * 12
    max_hp = 100 + reborn * 15
    hp = max_hp
    gold += 100 + reborn * 50
    _update_frontier()
    for enemy in enemies:
        if enemy != null and is_instance_valid(enemy):
            enemy.queue_free()
    enemies.clear()
    _spawn_initial_enemies()
    _message("REBORN %d ! La frontière s'étend." % reborn)
    _save_game()

func _update_frontier() -> void:
    var group_average: float = (level + max(1, level - 1) + level + 1) / 3.0
    var average: float = (level + group_average) / 2.0
    frontier_min = max(1, int(floor(average)))
    frontier_max = frontier_min + 4
    zone_index = min(max(int(floor(level / 10.0)), 0), zone_names.size() - 1)

func _apply_zone_visuals() -> void:
    var env_node := get_node_or_null("WorldEnvironment")
    if env_node is WorldEnvironment and env_node.environment != null:
        env_node.environment.background_color = zone_colors[zone_index]

func _update_camera() -> void:
    if camera_pivot == null or player == null:
        return
    camera_pivot.global_position = player.global_position + Vector3(0, 1.5, 0)

func _autosave(delta: float) -> void:
    autosave_timer -= delta
    if autosave_timer <= 0.0:
        autosave_timer = 10.0
        _save_game()

func _save_game() -> void:
    var save_path := "user://infinite_ascension_save.json"
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
    var file := FileAccess.open(save_path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data))
        file.close()

func _load_save() -> void:
    var save_path := "user://infinite_ascension_save.json"
    if not FileAccess.file_exists(save_path):
        return
    var file := FileAccess.open(save_path, FileAccess.READ)
    if file == null:
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
