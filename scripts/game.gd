extends Node3D

# Infinite Ascension v0.6
# Core vertical slice: movement, auto-combat, enemy stats, loot,
# adaptive frontier, zones, reborn progression and clearer HUD.

var level := 5
var xp := 0.0
var reborn := 0
var power := 120.0
var hp := 100.0
var max_hp := 100.0
var gold := 250
var world_tier := 1
var group_levels: Array[int] = [5, 4, 6]
var frontier_min := 5
var frontier_max := 10
var zone_index := 0
var preview_zone_index := 0
var total_kills := 0
var total_damage := 0
var combat_timer := 0.0
var spawn_timer := 0.0
var gold_accumulator := 0.0
var regen_accumulator := 0.0
var combat_streak := 0
var best_streak := 0
var last_enemy_level := 0
var last_loot := ""
var frontier_locked := false

const XP_PER_LEVEL := 100.0
const REBORN_LEVEL := 25
const MAX_ENEMIES := 10

var zone_names := [
    "Forêt des Brumes",
    "Vallée des Cendres",
    "Cité Fracturée",
    "Océan Céleste",
    "Royaume Mécanique",
    "Abysses Stellaires",
    "Frontière Infinie"
]
var zone_biomes := [
    "Sylvestre",
    "Volcanique",
    "Ruines",
    "Aérien",
    "Mécanique",
    "Cosmique",
    "Inconnu"
]
var zone_colors := [
    Color("#24412f"),
    Color("#4b2921"),
    Color("#29263d"),
    Color("#283b52"),
    Color("#29383a"),
    Color("#302348"),
    Color("#211934")
]

var enemies: Array[Node3D] = []
var player: CharacterBody3D
var camera: Camera3D
var ui: CanvasLayer
var xp_bar: ProgressBar
var hp_bar: ProgressBar
var level_label: Label
var avg_label: Label
var power_label: Label
var gold_label: Label
var zone_label: Label
var frontier_label: Label
var reborn_label: Label
var tier_label: Label
var combat_label: Label
var ai_label: Label
var combat_stats_label: Label
var toast: Label
var log_box: RichTextLabel
var reborn_button: Button
var generate_button: Button

func _ready() -> void:
    randomize()
    _setup_world()
    _setup_player()
    _setup_camera()
    _setup_ui()
    _update_frontier()
    _apply_zone_visuals()
    _log("Bienvenue dans Infinite Ascension.")
    _log("La frontière du monde suit le niveau moyen du groupe.")
    _log("v0.6 : auto-combat, HP, loot, zones et Reborn.")
    _spawn_wave()
    _refresh()

func _setup_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#070a16")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#8090c0")
    environment.ambient_light_energy = 0.55
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.2
    sun.shadow_enabled = true
    add_child(sun)

    var floor := MeshInstance3D.new()
    floor.name = "Arena"
    var plane := PlaneMesh.new()
    plane.size = Vector2(120, 120)
    floor.mesh = plane
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#10182a")
    mat.roughness = 0.94
    floor.material_override = mat
    add_child(floor)

    for i in range(70):
        var prop := MeshInstance3D.new()
        var box := BoxMesh.new()
        var s := randf_range(0.25, 1.2)
        box.size = Vector3(s, randf_range(0.2, 1.4), s)
        prop.mesh = box
        prop.position = Vector3(randf_range(-42, 42), box.size.y / 2.0, randf_range(-42, 42))
        var prop_mat := StandardMaterial3D.new()
        prop_mat.albedo_color = Color("#1b2440") if i % 3 else Color("#252047")
        prop.material_override = prop_mat
        add_child(prop)

func _setup_player() -> void:
    player = CharacterBody3D.new()
    player.position = Vector3(0, 1, 0)
    add_child(player)

    var mesh := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.height = 1.7
    capsule.radius = 0.42
    mesh.mesh = capsule
    var pm := StandardMaterial3D.new()
    pm.albedo_color = Color("#a66cff")
    pm.emission_enabled = true
    pm.emission = Color("#6c37b8")
    pm.emission_energy_multiplier = 1.6
    mesh.material_override = pm
    player.add_child(mesh)

func _setup_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 18, 14)
    camera.rotation_degrees = Vector3(-48, 0, 0)
    camera.current = true
    player.add_child(camera)

func _panel_style(bg: Color, radius := 14) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = Color("#2d3858")
    s.set_border_width_all(1)
    s.set_corner_radius_all(radius)
    s.content_margin_left = 14
    s.content_margin_right = 14
    s.content_margin_top = 10
    s.content_margin_bottom = 10
    return s

func _label(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l

func _setup_ui() -> void:
    ui = CanvasLayer.new()
    add_child(ui)

    var root := MarginContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("margin_left", 18)
    root.add_theme_constant_override("margin_right", 18)
    root.add_theme_constant_override("margin_top", 16)
    root.add_theme_constant_override("margin_bottom", 16)
    ui.add_child(root)

    var cols := HBoxContainer.new()
    cols.add_theme_constant_override("separation", 12)
    root.add_child(cols)

    var left := VBoxContainer.new()
    left.custom_minimum_size.x = 270
    left.add_theme_constant_override("separation", 10)
    cols.add_child(left)

    var title_panel := PanelContainer.new()
    title_panel.add_theme_stylebox_override("panel", _panel_style(Color("#101426cc")))
    left.add_child(title_panel)
    var title_box := VBoxContainer.new()
    title_panel.add_child(title_box)
    title_box.add_child(_label("INFINITE", 22, Color("#eef1ff")))
    title_box.add_child(_label("ASCENSION", 12, Color("#b47aff")))
    title_box.add_child(_label("Incremental RPG · Vertical Slice", 10, Color("#8f99b8")))

    var stats := PanelContainer.new()
    stats.add_theme_stylebox_override("panel", _panel_style(Color("#111725dd")))
    left.add_child(stats)
    var sv := VBoxContainer.new()
    stats.add_child(sv)
    level_label = _label("", 18, Color("#f0f2ff")); sv.add_child(level_label)
    hp_bar = ProgressBar.new(); hp_bar.show_percentage = false; hp_bar.custom_minimum_size.y = 10; sv.add_child(hp_bar)
    xp_bar = ProgressBar.new(); xp_bar.show_percentage = false; xp_bar.custom_minimum_size.y = 10; sv.add_child(xp_bar)
    avg_label = _label("", 11, Color("#8f99b8")); sv.add_child(avg_label)
    power_label = _label("", 11, Color("#8f99b8")); sv.add_child(power_label)
    gold_label = _label("", 11, Color("#ffd166")); sv.add_child(gold_label)
    tier_label = _label("", 11, Color("#b9a4ff")); sv.add_child(tier_label)

    var reb := PanelContainer.new()
    reb.add_theme_stylebox_override("panel", _panel_style(Color("#171125dd")))
    left.add_child(reb)
    var rv := VBoxContainer.new()
    reb.add_child(rv)
    rv.add_child(_label("REBORN", 12, Color("#dfe4ff")))
    reborn_label = _label("", 11, Color("#a9b0c9")); rv.add_child(reborn_label)
    reborn_button = Button.new()
    reborn_button.text = "↻ Reborn — niveau 25"
    reborn_button.custom_minimum_size.y = 46
    reborn_button.pressed.connect(_reborn)
    rv.add_child(reborn_button)

    var center := VBoxContainer.new()
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.add_theme_constant_override("separation", 10)
    cols.add_child(center)

    var worldp := PanelContainer.new()
    worldp.add_theme_stylebox_override("panel", _panel_style(Color("#101525dd")))
    center.add_child(worldp)
    var wv := VBoxContainer.new()
    worldp.add_child(wv)
    zone_label = _label("", 20, Color("#eef1ff")); wv.add_child(zone_label)
    frontier_label = _label("", 11, Color("#8f99b8")); wv.add_child(frontier_label)
    combat_label = _label("", 11, Color("#49df9a")); wv.add_child(combat_label)
    combat_stats_label = _label("", 10, Color("#9aa4c3")); wv.add_child(combat_stats_label)

    var aip := PanelContainer.new()
    aip.add_theme_stylebox_override("panel", _panel_style(Color("#1a1230e8")))
    center.add_child(aip)
    var av := VBoxContainer.new()
    aip.add_child(av)
    av.add_child(_label("DIRECTEUR IA", 11, Color("#49df9a")))
    ai_label = _label("Simulation locale : le directeur prépare la prochaine frontière.", 11, Color("#bcb7d4")); av.add_child(ai_label)
    generate_button = Button.new()
    generate_button.text = "✦ Prévisualiser la prochaine frontière"
    generate_button.custom_minimum_size.y = 46
    generate_button.pressed.connect(_generate_frontier)
    av.add_child(generate_button)

    var logp := PanelContainer.new()
    logp.size_flags_vertical = Control.SIZE_EXPAND_FILL
    logp.add_theme_stylebox_override("panel", _panel_style(Color("#0c101de8")))
    center.add_child(logp)
    log_box = RichTextLabel.new()
    log_box.bbcode_enabled = true
    log_box.scroll_active = true
    log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    logp.add_child(log_box)

    var right := VBoxContainer.new()
    right.custom_minimum_size.x = 250
    right.add_theme_constant_override("separation", 10)
    cols.add_child(right)

    var help := PanelContainer.new()
    help.add_theme_stylebox_override("panel", _panel_style(Color("#111725dd")))
    right.add_child(help)
    var hv := VBoxContainer.new(); help.add_child(hv)
    hv.add_child(_label("MONDE VIVANT", 12, Color("#dfe4ff")))
    hv.add_child(_label("Déplacement : WASD / flèches\n\nLe personnage combat automatiquement.\nLes ennemis attaquent aussi.\n\nLes récompenses et niveaux suivent la frontière.\n\nAtteins le niveau 25 pour Reborn.", 11, Color("#8f99b8")))

    var prog := PanelContainer.new()
    prog.add_theme_stylebox_override("panel", _panel_style(Color("#101525dd")))
    right.add_child(prog)
    var pv := VBoxContainer.new(); prog.add_child(pv)
    pv.add_child(_label("PROGRESSION", 12, Color("#dfe4ff")))
    var progress_text := _label("", 11, Color("#8f99b8"))
    progress_text.name = "ProgressText"
    pv.add_child(progress_text)

    toast = _label("", 14, Color("#eef1ff"))
    toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
    toast.position = Vector2(-160, 18)
    toast.size = Vector2(320, 48)
    toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
    toast.modulate.a = 0.0
    ui.add_child(toast)

func _process(delta: float) -> void:
    _move_player(delta)
    _auto_combat(delta)
    _enemy_attacks(delta)

    spawn_timer += delta
    if spawn_timer >= 3.5 and enemies.size() < MAX_ENEMIES:
        spawn_timer = 0.0
        _spawn_enemy()

    gold_accumulator += delta
    if gold_accumulator >= 1.0:
        var whole := int(floor(gold_accumulator))
        gold += whole * max(1, 1 + reborn)
        gold_accumulator -= whole

    regen_accumulator += delta
    if regen_accumulator >= 1.0:
        hp = min(max_hp, hp + 3.0 + reborn)
        regen_accumulator = 0.0

    _refresh()

func _move_player(_delta: float) -> void:
    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var dir := Vector3(input.x, 0, input.y)
    if dir.length() > 1.0:
        dir = dir.normalized()
    player.velocity = dir * 7.0
    player.move_and_slide()
    player.position.x = clamp(player.position.x, -50.0, 50.0)
    player.position.z = clamp(player.position.z, -50.0, 50.0)

func _spawn_wave() -> void:
    for i in range(6):
        _spawn_enemy(i)

func _enemy_profile(enemy_level: int, index: int) -> Dictionary:
    var types := [
        {"name":"Brumeux", "hp":1.0, "damage":0.8, "gold":1.2, "color":Color("#6f82e8")},
        {"name":"Cendreux", "hp":1.25, "damage":1.0, "gold":1.35, "color":Color("#d85a79")},
        {"name":"Ravager", "hp":1.5, "damage":1.25, "gold":1.6, "color":Color("#cc8d45")}
    ]
    return types[index % types.size()]

func _spawn_enemy(index := 0) -> void:
    var enemy := MeshInstance3D.new()
    var enemy_level := randi_range(frontier_min, max(frontier_min, frontier_max))
    var profile := _enemy_profile(enemy_level, index)
    var mesh := CapsuleMesh.new()
    mesh.height = 1.5
    mesh.radius = 0.45
    enemy.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = profile["color"]
    mat.emission_enabled = true
    mat.emission = mat.albedo_color * 0.18
    enemy.material_override = mat
    enemy.position = Vector3(randf_range(-18, 18), 0.9, randf_range(-18, 18))
    enemy.set_meta("level", enemy_level)
    enemy.set_meta("type", profile["name"])
    enemy.set_meta("max_hp", enemy_level * 18.0 * float(profile["hp"]))
    enemy.set_meta("hp", enemy.get_meta("max_hp"))
    enemy.set_meta("damage", enemy_level * 1.7 * float(profile["damage"]))
    enemy.set_meta("gold", int(enemy_level * 3.0 * float(profile["gold"])))
    enemy.set_meta("xp", 10 + enemy_level * 3 + reborn * 2)
    enemy.set_meta("attack_timer", randf_range(0.0, 1.0))
    add_child(enemy)
    enemies.append(enemy)

func _nearest_enemy(max_distance := 24.0) -> Node3D:
    var nearest: Node3D = null
    var best := max_distance
    for e in enemies:
        if not is_instance_valid(e):
            continue
        var d := player.global_position.distance_to(e.global_position)
        if d < best:
            best = d
            nearest = e
    return nearest

func _auto_combat(delta: float) -> void:
    combat_timer += delta
    if combat_timer < 1.1:
        return
    combat_timer = 0.0

    var target := _nearest_enemy()
    if target == null:
        combat_label.text = "⚔ Auto-combat · aucune cible à portée"
        return

    var enemy_level := int(target.get_meta("level"))
    var damage := max(1, int(power * 0.35 + level * 1.8 + reborn * 5.0))
    var enemy_hp := float(target.get_meta("hp"))
    enemy_hp -= damage
    target.set_meta("hp", enemy_hp)
    total_damage += damage
    last_enemy_level = enemy_level
    combat_label.text = "⚔ Attaque · %s niveau %d · -%d PV" % [target.get_meta("type"), enemy_level, damage]

    if enemy_hp <= 0.0:
        _defeat_enemy(target)

func _enemy_attacks(delta: float) -> void:
    for e in enemies:
        if not is_instance_valid(e):
            continue
        var timer := float(e.get_meta("attack_timer")) + delta
        if timer < 2.2:
            e.set_meta("attack_timer", timer)
            continue
        e.set_meta("attack_timer", 0.0)
        if player.global_position.distance_to(e.global_position) > 16.0:
            continue
        var damage := max(1.0, float(e.get_meta("damage")) * (1.0 - reborn * 0.04))
        hp -= damage
        combat_label.text = "🛡 %s riposte · -%d PV" % [e.get_meta("type"), int(damage)]
        if hp <= 0.0:
            _player_defeated()

func _defeat_enemy(target: Node3D) -> void:
    var enemy_level := int(target.get_meta("level"))
    var reward_xp := int(target.get_meta("xp"))
    var reward_gold := int(target.get_meta("gold"))
    var loot_roll := randi_range(1, 100)

    xp += reward_xp
    gold += reward_gold
    power += 1.0 + enemy_level * 0.08
    total_kills += 1
    combat_streak += 1
    best_streak = max(best_streak, combat_streak)

    if loot_roll <= 8:
        var shard := 1 + int(enemy_level / 10.0)
        last_loot = "Éclat d'Ascension x%d" % shard
        power += shard * 2
        _log("[color=#ffd166]Butin rare : %s[/color]" % last_loot)
    elif loot_roll <= 28:
        var essence := 1 + int(enemy_level / 8.0)
        last_loot = "Essence x%d" % essence
        max_hp += essence * 2
        hp = min(max_hp, hp + essence * 2)
    else:
        last_loot = "Or +%d" % reward_gold

    _log("Victoire contre %s niveau %d · +%d XP · +%d or" % [target.get_meta("type"), enemy_level, reward_xp, reward_gold])
    target.queue_free()
    enemies.erase(target)

    while xp >= XP_PER_LEVEL:
        xp -= XP_PER_LEVEL
        level += 1
        group_levels[0] = level
        max_hp += 8 + reborn * 2
        hp = max_hp
        power += 10 + reborn * 2
        _log("[color=#bca5ff]Niveau %d atteint.[/color]" % level)
        _show_toast("NIVEAU %d" % level)
        if level % 5 == 0:
            _update_frontier()

func _player_defeated() -> void:
    hp = max_hp * 0.55
    gold = max(0, gold - 15)
    combat_streak = 0
    player.position = Vector3(0, 1, 0)
    _log("[color=#d85a79]Défaite.[/color] Retour au point de départ · -15 or.")
    _show_toast("DÉFAITE")

func _average() -> float:
    var total := 0.0
    for l in group_levels:
        total += float(l)
    return total / float(group_levels.size())

func _update_frontier() -> void:
    var avg_level := _average()
    frontier_min = max(1, int(floor(avg_level / 5.0)) * 5)
    frontier_max = frontier_min + 5
    var next_zone := min(zone_names.size() - 1, int(floor(avg_level / 15.0)))
    if next_zone != zone_index:
        zone_index = next_zone
        preview_zone_index = zone_index
        _apply_zone_visuals()
        _log("[color=#8fd8ff]Nouvelle zone débloquée : %s.[/color]" % zone_names[zone_index])
    world_tier = max(1, 1 + int(floor(avg_level / 30.0)))
    frontier_locked = avg_level < float((zone_index + 1) * 15)
    ai_label.text = "Analyse : niveau moyen %.1f → frontière %d–%d. Zone suivante : %s." % [avg_level, frontier_min, frontier_max, zone_names[min(zone_names.size() - 1, zone_index + 1)]]

func _generate_frontier() -> void:
    _update_frontier()
    preview_zone_index = min(zone_names.size() - 1, zone_index + 1)
    var preview_min := frontier_min + 5
    var preview_max := frontier_max + 5
    ai_label.text = "Prévisualisation : %s · %s · niveaux %d–%d · boss suggéré." % [zone_names[preview_zone_index], zone_biomes[preview_zone_index], preview_min, preview_max]
    _log("Directeur IA : prévisualisation de %s (%s)." % [zone_names[preview_zone_index], zone_biomes[preview_zone_index]])
    _show_toast("FRONTIÈRE PRÉVISUALISÉE")

func _apply_zone_visuals() -> void:
    var arena := get_node_or_null("Arena") as MeshInstance3D
    if arena != null:
        var mat := arena.material_override as StandardMaterial3D
        if mat != null:
            var base := zone_colors[zone_index]
            mat.albedo_color = base.lerp(Color("#10182a"), 0.45)

func _reborn() -> void:
    if level < REBORN_LEVEL:
        reborn_button.disabled = true
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
    combat_streak = 0
    _update_frontier()
    _log("[color=#d8b4ff]Reborn %d.[/color] Bonus permanent : puissance +%d, survie +%d%%." % [reborn, reborn * 25, reborn * 4])
    _show_toast("REBORN %d" % reborn)

func _refresh() -> void:
    var avg_level := _average()
    level_label.text = "NIVEAU %d" % level
    hp_bar.max_value = max_hp
    hp_bar.value = hp
    xp_bar.max_value = XP_PER_LEVEL
    xp_bar.value = xp
    avg_label.text = "Niveau moyen du groupe : %.1f" % avg_level
    power_label.text = "Puissance : %d · Dégâts totaux : %d" % [int(power), total_damage]
    gold_label.text = "Or : %d · Kills : %d" % [gold, total_kills]
    tier_label.text = "Palier monde : %d · Reborn : %d" % [world_tier, reborn]
    reborn_label.text = "Cycle %d · Prochain reset au niveau %d\nMeilleur streak : %d" % [reborn, REBORN_LEVEL, best_streak]
    zone_label.text = "%s · %s" % [zone_names[zone_index], zone_biomes[zone_index]]
    frontier_label.text = "Frontière active : niveaux %d–%d · Ennemis : %d/%d" % [frontier_min, frontier_max, enemies.size(), MAX_ENEMIES]
    combat_stats_label.text = "Dernière cible : niveau %d · Dernier butin : %s" % [last_enemy_level, last_loot if last_loot != "" else "—"]
    reborn_button.disabled = level < REBORN_LEVEL

    var progress_text := right_progress_label()
    if progress_text != null:
        progress_text.text = "Progression vers Reborn : %.0f%%\nZone : %s\nPalier : %d" % [min(100.0, level * 100.0 / REBORN_LEVEL), zone_names[zone_index], world_tier]

func right_progress_label() -> Label:
    var node := ui.get_child(0)
    if node == null:
        return null
    return _find_label(node, "ProgressText")

func _find_label(node: Node, target_name: String) -> Label:
    if node is Label and node.name == target_name:
        return node as Label
    for child in node.get_children():
        var found := _find_label(child, target_name)
        if found != null:
            return found
    return null

func _log(message: String) -> void:
    if log_box == null:
        return
    log_box.append_text(message + "\n")
    log_box.scroll_to_line(log_box.get_line_count())

func _show_toast(message: String) -> void:
    toast.text = message
    toast.modulate.a = 1.0
    var tween := create_tween()
    tween.tween_interval(0.65)
    tween.tween_property(toast, "modulate:a", 0.0, 0.45)
