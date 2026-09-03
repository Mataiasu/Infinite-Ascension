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
    process_mode = Node.PROCESS_MODE_ALWAYS
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
    var ground := StaticBody3D.new()
    ground.name = "WorldGround"
    ground.collision_layer = 1
    ground.collision_mask = 1
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

    for i in range(95):
        var p := Vector3(randf_range(-WORLD_SIZE * 0.47, WORLD_SIZE * 0.47), 0, randf_range(-WORLD_SIZE * 0.47, WORLD_SIZE * 0.47))
        if p.length() < 8.0:
            continue
        if i % 3 != 0:
            _create_tree(p, randf_range(0.8, 1.35))
        else:
            _create_rock(p)

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
    var sphere := SphereMesh.new()
    sphere.height = 3.8
    sphere.radius = 1.5
    crown.mesh = sphere
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
    player.collision_layer = 1
    player.collision_mask = 1
    player.position = Vector3(0, 1.0, 0)
    player.floor_snap_length = 0.2
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
    # Camera rig is a sibling of Player, so rotating the player can never rotate the camera.
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

func _update_camera() -> void:
    if camera == null or player == null:
        return
    camera_pivot.global_position = camera_pivot.global_position.lerp(player.global_position + Vector3(0, 1.5, 0), 0.2)
    camera.position = camera.position.lerp(Vector3(0, 4.0, 8.5), 0.12)

func _move_player(delta: float) -> void:
    if player == null or not is_instance_valid(player) or camera_pivot == null:
        return

    # Standard Godot InputMap movement: keyboard actions only affect the player.
    # The mouse is handled separately in _input() and only rotates the camera rig.
    var direction := Vector3.ZERO
    if Input.is_action_pressed("move_right"):
        direction.x += 1.0
    if Input.is_action_pressed("move_left"):
        direction.x -= 1.0
    if Input.is_action_pressed("move_back"):
        direction.z += 1.0
    if Input.is_action_pressed("move_forward"):
        direction.z -= 1.0
    if direction != Vector3.ZERO:
        direction = direction.normalized()

    # Keep movement camera-relative, but never rotate the Player or CameraPivot from keyboard input.
    var forward := -camera_pivot.global_transform.basis.z
    var right := camera_pivot.global_transform.basis.x
    forward.y = 0.0
    right.y = 0.0
    if forward.length_squared() > 0.001:
        forward = forward.normalized()
    if right.length_squared() > 0.001:
        right = right.normalized()

    var world_direction := right * direction.x + forward * direction.z
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

func _spawn_initial_enemies() -> void:
    for i in range(8):
        _spawn_enemy()

func _spawn_enemy() -> void:
    if enemies.size() >= MAX_ENEMIES:
        return

    var enemy := CharacterBody3D.new()
    enemy.name = "Enemy"
    enemy.collision_layer = 2
    enemy.collision_mask = 2

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
            var direction := player.global_position - enemy.global_position
            direction.y = 0
            if direction.length_squared() > 0.001:
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

func _enemy_attacks(delta: float) -> void:
    enemy_attack_timer -= delta
    if enemy_attack_timer > 0.0:
        return
    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        if enemy.global_position.distance_to(player.global_position) <= ENEMY_ATTACK_RANGE:
            hp = max(0.0, hp - float(enemy.get_meta("damage")))
            enemy_attack_timer = 1.0
            _message("%s vous attaque (-%d PV)" % [enemy.get_meta("name"), int(enemy.get_meta("damage"))])
            if hp <= 0.0:
                hp = max_hp
                player.position = Vector3.ZERO
                _message("Vous êtes tombé. Retour au point de départ.")
            break

func _spawn_loop(delta: float) -> void:
    spawn_timer += delta
    if spawn_timer >= 3.0:
        spawn_timer = 0.0
        _spawn_enemy()

func _autosave(delta: float) -> void:
    autosave_timer += delta
    if autosave_timer >= 15.0:
        autosave_timer = 0.0
        _save_game()

func _gain_xp(amount: float) -> void:
    xp += amount
    while xp >= XP_PER_LEVEL:
        xp -= XP_PER_LEVEL
        level += 1
        power += 3.0
        max_hp += 8.0
        hp = max_hp
        _message("Niveau %d atteint !" % level)
        if level >= REBORN_LEVEL:
            reborn_button.disabled = false

func _update_frontier() -> void:
    frontier_min = max(1, 1 + zone_index * 5 + reborn * 2)
    frontier_max = frontier_min + 4

func _apply_zone_visuals() -> void:
    var ground := get_node_or_null("WorldGround/MeshInstance3D") as MeshInstance3D
    if ground != null:
        var mat := ground.material_override as StandardMaterial3D
        if mat != null:
            mat.albedo_color = zone_colors[clamp(zone_index, 0, zone_colors.size() - 1)]

func _refresh_hud() -> void:
    if level_label != null:
        level_label.text = "Niveau %d  •  Reborn %d" % [level, reborn]
    if hp_label != null:
        hp_label.text = "PV : %d / %d" % [int(hp), int(max_hp)]
    if xp_label != null:
        xp_label.text = "XP : %d / %d" % [int(xp), int(XP_PER_LEVEL)]
    if zone_label != null:
        zone_label.text = "%s  •  %s  •  Niveaux %d–%d" % [zone_names[zone_index], zone_biomes[zone_index], frontier_min, frontier_max]
    if stats_label != null:
        stats_label.text = "Puissance %d  •  Or %d  •  Kills %d  •  Dégâts %d" % [int(power), gold, kills, total_damage]
    if hint_label != null:
        hint_label.text = "WASD : déplacer  •  Souris : caméra  •  Espace / clic gauche : attaque  •  Échap : libérer la souris"
    if reborn_button != null:
        reborn_button.visible = level >= REBORN_LEVEL
        reborn_button.disabled = level < REBORN_LEVEL
    if crosshair != null:
        crosshair.text = "+"

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)

    level_label = Label.new()
    level_label.position = Vector2(24, 20)
    level_label.add_theme_font_size_override("font_size", 22)
    layer.add_child(level_label)

    hp_label = Label.new()
    hp_label.position = Vector2(24, 55)
    layer.add_child(hp_label)

    xp_label = Label.new()
    xp_label.position = Vector2(24, 82)
    layer.add_child(xp_label)

    zone_label = Label.new()
    zone_label.position = Vector2(24, 112)
    layer.add_child(zone_label)

    stats_label = Label.new()
    stats_label.position = Vector2(24, 142)
    layer.add_child(stats_label)

    combat_label = Label.new()
    combat_label.position = Vector2(24, 175)
    layer.add_child(combat_label)

    hint_label = Label.new()
    hint_label.position = Vector2(24, 650)
    layer.add_child(hint_label)

    message_label = Label.new()
    message_label.position = Vector2(24, 610)
    message_label.add_theme_font_size_override("font_size", 18)
    layer.add_child(message_label)

    crosshair = Label.new()
    crosshair.position = Vector2(638, 350)
    crosshair.add_theme_font_size_override("font_size", 28)
    layer.add_child(crosshair)

    reborn_button = Button.new()
    reborn_button.text = "REBORN"
    reborn_button.position = Vector2(1080, 24)
    reborn_button.size = Vector2(160, 48)
    reborn_button.pressed.connect(_do_reborn)
    layer.add_child(reborn_button)

func _message(text: String) -> void:
    last_message = text
    if message_label != null:
        message_label.text = text

func _do_reborn() -> void:
    if level < REBORN_LEVEL:
        return
    reborn += 1
    level = 1
    xp = 0.0
    power = 25.0 + reborn * 8.0
    max_hp = 100.0 + reborn * 20.0
    hp = max_hp
    gold += 250 * reborn
    zone_index = min(zone_index + 1, zone_names.size() - 1)
    _update_frontier()
    _apply_zone_visuals()
    _message("REBORN %d — progression améliorée." % reborn)
    _save_game()

func _save_game() -> void:
    if SaveManager != null and SaveManager.has_method("save_game"):
        SaveManager.call("save_game", {
            "level": level,
            "xp": xp,
            "reborn": reborn,
            "power": power,
            "hp": hp,
            "max_hp": max_hp,
            "gold": gold,
            "kills": kills,
            "total_damage": total_damage,
            "zone_index": zone_index
        })

func _load_save() -> void:
    if SaveManager == null or not SaveManager.has_method("load_game"):
        return
    var data = SaveManager.call("load_game")
    if not data is Dictionary:
        return
    level = int(data.get("level", level))
    xp = float(data.get("xp", xp))
    reborn = int(data.get("reborn", reborn))
    power = float(data.get("power", power))
    hp = float(data.get("hp", hp))
    max_hp = float(data.get("max_hp", max_hp))
    gold = int(data.get("gold", gold))
    kills = int(data.get("kills", kills))
    total_damage = int(data.get("total_damage", total_damage))
    zone_index = clamp(int(data.get("zone_index", zone_index)), 0, zone_names.size() - 1)
