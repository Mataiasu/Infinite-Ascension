extends Node3D

# Infinite Ascension runtime v0.7
# Clean replacement for the previous monolithic runtime while it is repaired.

const XP_PER_LEVEL: float = 100.0
const REBORN_LEVEL: int = 25
const MAX_ENEMIES: int = 8

var level: int = 5
var xp: float = 0.0
var reborn: int = 0
var power: float = 120.0
var hp: float = 100.0
var max_hp: float = 100.0
var gold: int = 250
var kills: int = 0
var total_damage: int = 0
var group_levels: Array[int] = [5, 4, 6]
var frontier_min: int = 5
var frontier_max: int = 10
var world_tier: int = 1
var zone_index: int = 0
var combat_timer: float = 0.0
var spawn_timer: float = 0.0
var enemy_attack_timer: float = 0.0
var autosave_timer: float = 0.0
var last_loot: String = "—"
var last_target: String = "—"

var zone_names: Array[String] = [
    "Forêt des Brumes", "Vallée des Cendres", "Cité Fracturée",
    "Océan Céleste", "Royaume Mécanique", "Abysses Stellaires", "Frontière Infinie"
]
var zone_biomes: Array[String] = [
    "Sylvestre", "Volcanique", "Ruines", "Aérien", "Mécanique", "Cosmique", "Inconnu"
]
var zone_colors: Array[Color] = [
    Color("#24412f"), Color("#4b2921"), Color("#29263d"),
    Color("#283b52"), Color("#29383a"), Color("#302348"), Color("#211934")
]

var player: CharacterBody3D
var camera: Camera3D
var ui: CanvasLayer
var level_label: Label
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var stats_label: Label
var zone_label: Label
var frontier_label: Label
var combat_label: Label
var loot_label: Label
var ai_label: Label
var save_label: Label
var log_box: RichTextLabel
var reborn_button: Button

var save_path: String:
    get: return "user://infinite_ascension_save.json"

func _ready() -> void:
    randomize()
    _build_player()
    _build_camera()
    _build_hud()
    _load_save()
    _update_frontier()
    _apply_zone_visuals()
    _spawn_wave()
    _log("Infinite Ascension v0.7 lancé.")
    _log("Journal de diagnostic actif côté launcher.")
    _log("Monde : %s · niveaux %d–%d." % [zone_names[zone_index], frontier_min, frontier_max])
    _refresh_hud()

func _process(delta: float) -> void:
    _move_player(delta)
    _auto_combat(delta)
    _enemy_attacks(delta)
    _spawn_loop(delta)
    _passive_income(delta)
    _autosave(delta)
    _refresh_hud()

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 1, 0)
    add_child(player)

    var mesh := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.height = 1.8
    capsule.radius = 0.42
    mesh.mesh = capsule
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#a66cff")
    material.emission_enabled = true
    material.emission = Color("#6c37b8")
    material.emission_energy_multiplier = 1.5
    mesh.material_override = material
    player.add_child(mesh)

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 16, 16)
    camera.rotation_degrees = Vector3(-45, 0, 0)
    camera.current = true
    player.add_child(camera)

func _panel_style(bg: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = Color("#2d3858")
    style.set_border_width_all(1)
    style.set_corner_radius_all(14)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style

func _make_label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _build_hud() -> void:
    ui = CanvasLayer.new()
    add_child(ui)

    var root := MarginContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("margin_left", 18)
    root.add_theme_constant_override("margin_right", 18)
    root.add_theme_constant_override("margin_top", 16)
    root.add_theme_constant_override("margin_bottom", 16)
    ui.add_child(root)

    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 12)
    root.add_child(columns)

    var left := VBoxContainer.new()
    left.custom_minimum_size.x = 270
    left.add_theme_constant_override("separation", 10)
    columns.add_child(left)

    var title := PanelContainer.new()
    title.add_theme_stylebox_override("panel", _panel_style(Color("#101426dd")))
    left.add_child(title)
    var title_box := VBoxContainer.new(); title.add_child(title_box)
    title_box.add_child(_make_label("INFINITE", 22, Color("#eef1ff")))
    title_box.add_child(_make_label("ASCENSION", 12, Color("#b47aff")))
    title_box.add_child(_make_label("Vertical Slice · v0.7", 10, Color("#8f99b8")))

    var stats := PanelContainer.new()
    stats.add_theme_stylebox_override("panel", _panel_style(Color("#111725dd")))
    left.add_child(stats)
    var stat_box := VBoxContainer.new(); stats.add_child(stat_box)
    level_label = _make_label("", 18, Color("#f0f2ff")); stat_box.add_child(level_label)
    hp_bar = ProgressBar.new(); hp_bar.show_percentage = false; hp_bar.custom_minimum_size.y = 10; stat_box.add_child(hp_bar)
    xp_bar = ProgressBar.new(); xp_bar.show_percentage = false; xp_bar.custom_minimum_size.y = 10; stat_box.add_child(xp_bar)
    stats_label = _make_label("", 11, Color("#9aa4c3")); stat_box.add_child(stats_label)

    var reborn := PanelContainer.new()
    reborn.add_theme_stylebox_override("panel", _panel_style(Color("#171125dd")))
    left.add_child(reborn)
    var rb := VBoxContainer.new(); reborn.add_child(rb)
    rb.add_child(_make_label("REBORN", 12, Color("#dfe4ff")))
    loot_label = _make_label("", 11, Color("#a9b0c9")); rb.add_child(loot_label)
    reborn_button = Button.new()
    reborn_button.text = "↻ Reborn — niveau 25"
    reborn_button.custom_minimum_size.y = 48
    reborn_button.pressed.connect(_reborn)
    rb.add_child(reborn_button)

    var center := VBoxContainer.new()
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.add_theme_constant_override("separation", 10)
    columns.add_child(center)

    var world := PanelContainer.new()
    world.add_theme_stylebox_override("panel", _panel_style(Color("#101525dd")))
    center.add_child(world)
    var wb := VBoxContainer.new(); world.add_child(wb)
    zone_label = _make_label("", 20, Color("#eef1ff")); wb.add_child(zone_label)
    frontier_label = _make_label("", 11, Color("#8f99b8")); wb.add_child(frontier_label)
    combat_label = _make_label("", 11, Color("#49df9a")); wb.add_child(combat_label)
    var controls := _make_label("WASD / flèches · combat automatique", 10, Color("#6f7896")); wb.add_child(controls)

    var director := PanelContainer.new()
    director.add_theme_stylebox_override("panel", _panel_style(Color("#1a1230e8")))
    center.add_child(director)
    var db := VBoxContainer.new(); director.add_child(db)
    db.add_child(_make_label("DIRECTEUR IA", 11, Color("#49df9a")))
    ai_label = _make_label("Le gameplay reste autoritaire côté moteur.", 11, Color("#c7c0df")); db.add_child(ai_label)

    var log_panel := PanelContainer.new()
    log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log_panel.add_theme_stylebox_override("panel", _panel_style(Color("#0c101de8")))
    center.add_child(log_panel)
    log_box = RichTextLabel.new()
    log_box.bbcode_enabled = true
    log_box.scroll_active = true
    log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log_panel.add_child(log_box)

    var right := VBoxContainer.new()
    right.custom_minimum_size.x = 250
    right.add_theme_constant_override("separation", 10)
    columns.add_child(right)

    var group := PanelContainer.new()
    group.add_theme_stylebox_override("panel", _panel_style(Color("#111725dd")))
    right.add_child(group)
    var gb := VBoxContainer.new(); group.add_child(gb)
    gb.add_child(_make_label("GROUPE", 12, Color("#dfe4ff")))
    gb.add_child(_make_label("Toi · Niv. 5", 11, Color("#bfc7df")))
    gb.add_child(_make_label("Ami_01 · Niv. 4", 11, Color("#bfc7df")))
    gb.add_child(_make_label("Ami_02 · Niv. 6", 11, Color("#bfc7df")))
    gb.add_child(_make_label("Moyenne = niveau directeur", 10, Color("#6f7896")))

    var progress := PanelContainer.new()
    progress.add_theme_stylebox_override("panel", _panel_style(Color("#111725dd")))
    right.add_child(progress)
    var pb := VBoxContainer.new(); progress.add_child(pb)
    pb.add_child(_make_label("PROGRESSION", 12, Color("#dfe4ff")))
    save_label = _make_label("", 11, Color("#8f99b8")); pb.add_child(save_label)

func _move_player(_delta: float) -> void:
    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := Vector3(input.x, 0, input.y)
    if direction.length() > 1.0:
        direction = direction.normalized()
    player.velocity = direction * 7.0
    player.move_and_slide()
    player.position.x = clamp(player.position.x, -50.0, 50.0)
    player.position.z = clamp(player.position.z, -50.0, 50.0)

func _spawn_wave() -> void:
    for i in range(6):
        _spawn_enemy(i)

func _spawn_enemy(index: int = 0) -> void:
    var enemy := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.height = 1.5
    mesh.radius = 0.45
    enemy.mesh = mesh
    var level_enemy: int = randi_range(frontier_min, frontier_max)
    var color := Color("#6f82e8") if index % 2 == 0 else Color("#d85a79")
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color * 0.18
    enemy.material_override = material
    enemy.position = Vector3(randf_range(-18, 18), 0.9, randf_range(-18, 18))
    enemy.set_meta("level", level_enemy)
    enemy.set_meta("type", ["Brumeux", "Cendreux", "Ravager"][index % 3])
    enemy.set_meta("hp", float(level_enemy * 18))
    enemy.set_meta("max_hp", float(level_enemy * 18))
    enemy.set_meta("damage", float(level_enemy) * 1.6)
    enemy.set_meta("attack", 0.0)
    add_child(enemy)
    enemies.push_back(enemy)

var enemies: Array[Node3D] = []

func _nearest_enemy(max_distance: float = 24.0) -> Node3D:
    var nearest: Node3D = null
    var best: float = max_distance
    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        var distance: float = player.global_position.distance_to(enemy.global_position)
        if distance < best:
            best = distance
            nearest = enemy
    return nearest

func _auto_combat(delta: float) -> void:
    combat_timer += delta
    if combat_timer < 1.15:
        return
    combat_timer = 0.0
    var target := _nearest_enemy()
    if target == null:
        combat_label.text = "⚔ Recherche de cible…"
        return
    var damage: int = max(1, int(power * 0.32 + level * 1.7 + reborn * 5))
    var current_hp: float = float(target.get_meta("hp")) - damage
    target.set_meta("hp", current_hp)
    total_damage += damage
    last_target = "%s Niv.%d" % [target.get_meta("type"), int(target.get_meta("level"))]
    combat_label.text = "⚔ %s · -%d PV" % [last_target, damage]
    if current_hp <= 0.0:
        _defeat_enemy(target)

func _enemy_attacks(delta: float) -> void:
    enemy_attack_timer += delta
    if enemy_attack_timer < 1.8:
        return
    enemy_attack_timer = 0.0
    var target := _nearest_enemy(18.0)
    if target == null:
        return
    var incoming: float = float(target.get_meta("damage"))
    hp -= max(1.0, incoming * (1.0 - reborn * 0.03))
    combat_label.text = "🛡 Riposte · -%d PV" % int(incoming)
    if hp <= 0.0:
        _player_defeated()

func _defeat_enemy(enemy: Node3D) -> void:
    var enemy_level: int = int(enemy.get_meta("level"))
    var reward_xp: int = 10 + enemy_level * 3 + reborn * 2
    var reward_gold: int = 3 + enemy_level * 2
    xp += reward_xp
    gold += reward_gold
    power += 1.0 + enemy_level * 0.06
    kills += 1
    if randi_range(1, 100) <= 10:
        last_loot = "Éclat d'Ascension"
        power += 3
    else:
        last_loot = "+%d or" % reward_gold
    _log("Victoire : %s · +%d XP · %s" % [enemy.get_meta("type"), reward_xp, last_loot])
    enemy.queue_free()
    enemies.erase(enemy)
    while xp >= XP_PER_LEVEL:
        xp -= XP_PER_LEVEL
        level += 1
        group_levels[0] = level
        max_hp += 8 + reborn * 2
        hp = max_hp
        power += 10 + reborn * 2
        _log("[color=#bca5ff]Niveau %d atteint[/color]." % level)
        if level % 5 == 0:
            _update_frontier()

func _player_defeated() -> void:
    hp = max_hp * 0.55
    gold = max(0, gold - 15)
    player.position = Vector3(0, 1, 0)
    _log("[color=#d85a79]Défaite[/color] · retour au point de départ · -15 or.")

func _spawn_loop(delta: float) -> void:
    spawn_timer += delta
    if spawn_timer >= 3.5 and enemies.size() < MAX_ENEMIES:
        spawn_timer = 0.0
        _spawn_enemy(enemies.size())

func _passive_income(delta: float) -> void:
    gold += int(floor(delta * float(1 + reborn) * 0.7))
    hp = min(max_hp, hp + delta * (2.0 + reborn))

func _average() -> float:
    var total: float = 0.0
    for value in group_levels:
        total += float(value)
    return total / float(group_levels.size())

func _update_frontier() -> void:
    var average: float = _average()
    frontier_min = max(1, int(floor(average / 5.0)) * 5)
    frontier_max = frontier_min + 5
    zone_index = min(zone_names.size() - 1, int(floor(average / 15.0)))
    world_tier = max(1, 1 + int(floor(average / 30.0)))
    ai_label.text = "Moyenne %.1f → frontière %d–%d · prochaine zone : %s." % [average, frontier_min, frontier_max, zone_names[min(zone_names.size() - 1, zone_index + 1)]]

func _apply_zone_visuals() -> void:
    var arena := get_node_or_null("Arena") as MeshInstance3D
    if arena == null:
        return
    var material := arena.material_override as StandardMaterial3D
    if material == null:
        return
    var base_color: Color = zone_colors[zone_index]
    material.albedo_color = base_color.lerp(Color("#10182a"), 0.45)

func _reborn() -> void:
    if level < REBORN_LEVEL:
        _show_toast("NIVEAU 25 REQUIS")
        return
    reborn += 1
    level = 1
    xp = 0.0
    group_levels[0] = 1
    power = 100.0 + reborn * 25.0
    max_hp = 100.0 + reborn * 15.0
    hp = max_hp
    gold = 100 + reborn * 50
    _update_frontier()
    _log("[color=#d8b4ff]REBORN %d[/color] · bonus permanent acquis." % reborn)
    _show_toast("REBORN %d" % reborn)
    _save()

func _refresh_hud() -> void:
    var average := _average()
    level_label.text = "NIVEAU %d · REBORN %d" % [level, reborn]
    hp_bar.max_value = max_hp
    hp_bar.value = hp
    xp_bar.max_value = XP_PER_LEVEL
    xp_bar.value = xp
    stats_label.text = "HP %.0f/%.0f · Puissance %d · Or %d · Kills %d\nMoyenne groupe %.1f · Palier %d" % [hp, max_hp, int(power), gold, kills, average, world_tier]
    loot_label.text = "Dernier butin : %s" % last_loot
    zone_label.text = "%s · %s" % [zone_names[zone_index], zone_biomes[zone_index]]
    frontier_label.text = "Frontière : niveaux %d–%d · Ennemis %d/%d" % [frontier_min, frontier_max, enemies.size(), MAX_ENEMIES]
    reborn_button.disabled = level < REBORN_LEVEL
    save_label.text = "Sauvegarde automatique : active\nTotal dégâts : %d\nDernière cible : %s" % [total_damage, last_target]

func _autosave(delta: float) -> void:
    autosave_timer += delta
    if autosave_timer >= 30.0:
        autosave_timer = 0.0
        _save()

func _save() -> void:
    var data := {
        "level": level, "xp": xp, "reborn": reborn, "power": power,
        "hp": hp, "max_hp": max_hp, "gold": gold, "kills": kills,
        "total_damage": total_damage, "group_levels": group_levels,
        "world_tier": world_tier, "frontier_min": frontier_min,
        "frontier_max": frontier_max, "zone_index": zone_index
    }
    var file := FileAccess.open(save_path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data))
        file.close()

func _load_save() -> void:
    if not FileAccess.file_exists(save_path):
        return
    var file := FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not parsed is Dictionary:
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
    var saved_group: Variant = parsed.get("group_levels", group_levels)
    if saved_group is Array:
        group_levels = []
        for value in saved_group:
            group_levels.append(int(value))
    world_tier = int(parsed.get("world_tier", world_tier))
    frontier_min = int(parsed.get("frontier_min", frontier_min))
    frontier_max = int(parsed.get("frontier_max", frontier_max))
    zone_index = clampi(int(parsed.get("zone_index", zone_index)), 0, zone_names.size() - 1)
    _log("Sauvegarde chargée.")

func _log(message: String) -> void:
    if log_box != null:
        log_box.append_text(message + "\n")
        log_box.scroll_to_line(log_box.get_line_count())

func _show_toast(message: String) -> void:
    # Minimal notification while the full HUD is being developed.
    if ui == null:
        return
    var label := _make_label(message, 14, Color("#eef1ff"))
    label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    label.position = Vector2(-140, 18)
    label.size = Vector2(280, 48)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.modulate.a = 1.0
    ui.add_child(label)
    var tween := create_tween()
    tween.tween_interval(0.6)
    tween.tween_property(label, "modulate:a", 0.0, 0.5)
    tween.tween_callback(label.queue_free)
