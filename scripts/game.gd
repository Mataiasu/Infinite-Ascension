extends Node3D

var level := 5
var xp := 0.0
var reborn := 0
var power := 120.0
var gold := 250
var world_tier := 1
var group_levels := [5,4,6]
var frontier_min := 5
var frontier_max := 10
var zone_index := 0
var zone_names := ["Forêt des Brumes","Vallée des Cendres","Cité Fracturée","Océan Céleste","Royaume Mécanique","Abysses Stellaires","Frontière Infinie"]
var zone_biomes := ["Sylvestre","Volcanique","Ruines","Aérien","Mécanique","Cosmique","Inconnu"]
var enemies: Array[Node3D] = []
var spawn_timer := 0.0
var combat_timer := 0.0
var gold_per_second := 1.0

var player: CharacterBody3D
var camera: Camera3D
var ui: CanvasLayer
var xp_bar: ProgressBar
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
var toast: Label
var log_box: RichTextLabel
var reborn_button: Button
var generate_button: Button

func _ready() -> void:
    _setup_world()
    _setup_player()
    _setup_camera()
    _setup_ui()
    _update_frontier()
    _log("Bienvenue dans Infinite Ascension.")
    _log("Le monde s'adapte à la progression du groupe.")
    _spawn_wave()

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
    sun.rotation_degrees = Vector3(-55,-25,0)
    sun.light_energy = 1.2
    sun.shadow_enabled = true
    add_child(sun)

    var floor := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(120,120)
    floor.mesh = plane
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#10182a")
    mat.roughness = 0.94
    floor.material_override = mat
    add_child(floor)

    for i in range(80):
        var rock := MeshInstance3D.new()
        var box := BoxMesh.new()
        var s := randf_range(0.25, 1.2)
        box.size = Vector3(s, randf_range(0.2,1.4), s)
        rock.mesh = box
        rock.position = Vector3(randf_range(-42,42), box.size.y/2.0, randf_range(-42,42))
        var rm := StandardMaterial3D.new()
        rm.albedo_color = Color("#1b2440") if i % 3 else Color("#252047")
        rock.material_override = rm
        add_child(rock)

func _setup_player() -> void:
    player = CharacterBody3D.new()
    player.position = Vector3(0,1,0)
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
    camera.position = Vector3(0,18,14)
    camera.rotation_degrees = Vector3(-48,0,0)
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
    left.custom_minimum_size.x = 265
    left.add_theme_constant_override("separation", 10)
    cols.add_child(left)

    var title := PanelContainer.new()
    title.add_theme_stylebox_override("panel", _panel_style(Color("#101426cc")))
    left.add_child(title)
    var tv := VBoxContainer.new()
    title.add_child(tv)
    tv.add_child(_label("INFINITE", 22, Color("#eef1ff")))
    tv.add_child(_label("ASCENSION", 12, Color("#b47aff")))
    tv.add_child(_label("Incremental RPG · Prototype", 10, Color("#8f99b8")))

    var stats := PanelContainer.new()
    stats.add_theme_stylebox_override("panel", _panel_style(Color("#111725dd")))
    left.add_child(stats)
    var sv := VBoxContainer.new()
    stats.add_child(sv)
    level_label = _label("", 18, Color("#f0f2ff")); sv.add_child(level_label)
    xp_bar = ProgressBar.new(); xp_bar.show_percentage = false; xp_bar.custom_minimum_size.y = 12; sv.add_child(xp_bar)
    avg_label = _label("",12,Color("#8f99b8")); sv.add_child(avg_label)
    power_label = _label("",12,Color("#8f99b8")); sv.add_child(power_label)
    gold_label = _label("",12,Color("#ffd166")); sv.add_child(gold_label)
    tier_label = _label("",12,Color("#b9a4ff")); sv.add_child(tier_label)

    var reb := PanelContainer.new()
    reb.add_theme_stylebox_override("panel", _panel_style(Color("#171125dd")))
    left.add_child(reb)
    var rv := VBoxContainer.new(); reb.add_child(rv)
    rv.add_child(_label("REBORN",12,Color("#dfe4ff")))
    reborn_label = _label("",11,Color("#a9b0c9")); rv.add_child(reborn_label)
    reborn_button = Button.new()
    reborn_button.text = "↻ Reborn — niveau 25"
    reborn_button.custom_minimum_size.y = 50
    reborn_button.pressed.connect(_reborn)
    rv.add_child(reborn_button)

    var center := VBoxContainer.new()
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.add_theme_constant_override("separation", 10)
    cols.add_child(center)

    var worldp := PanelContainer.new()
    worldp.add_theme_stylebox_override("panel", _panel_style(Color("#101525dd")))
    center.add_child(worldp)
    var wv := VBoxContainer.new(); worldp.add_child(wv)
    zone_label = _label("",20,Color("#eef1ff")); wv.add_child(zone_label)
    frontier_label = _label("",11,Color("#8f99b8")); wv.add_child(frontier_label)
    combat_label = _label("",11,Color("#49df9a")); wv.add_child(combat_label)

    var aip := PanelContainer.new()
    aip.add_theme_stylebox_override("panel", _panel_style(Color("#1a1230e8")))
    center.add_child(aip)
    var av := VBoxContainer.new(); aip.add_child(av)
    av.add_child(_label("DIRECTEUR IA",11,Color("#49df9a")))
    ai_label = _label("Simulation locale active. L'IA sera branchée après validation du gameplay.",11,Color("#bcb7d4")); av.add_child(ai_label)
    generate_button = Button.new()
    generate_button.text = "✦ Générer la prochaine frontière"
    generate_button.custom_minimum_size.y = 48
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
    hv.add_child(_label("MONDE VIVANT",12,Color("#dfe4ff")))
    hv.add_child(_label("Déplacement : WASD / flèches\nLe personnage combat automatiquement.\n\nLes monstres et récompenses suivent la zone actuelle.\n\nAtteins le niveau 25 pour Reborn.",11,Color("#8f99b8")))

    toast = _label("",14,Color("#eef1ff"))
    toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
    toast.position = Vector2(-160, 18)
    toast.size = Vector2(320,48)
    toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
    toast.modulate.a = 0.0
    ui.add_child(toast)

func _process(delta: float) -> void:
    _move_player(delta)
    _auto_combat(delta)
    spawn_timer += delta
    combat_timer += delta
    gold += int(floor(gold_per_second * delta))
    if spawn_timer > 4.0 and enemies.size() < 8:
        spawn_timer = 0.0
        _spawn_enemy()
    _refresh()

func _move_player(delta: float) -> void:
    var input := Input.get_vector("move_left","move_right","move_forward","move_back")
    var dir := Vector3(input.x,0,input.y)
    player.velocity = dir * 7.0
    player.move_and_slide()
    player.position.x = clamp(player.position.x,-50.0,50.0)
    player.position.z = clamp(player.position.z,-50.0,50.0)

func _spawn_wave() -> void:
    for i in range(6):
        _spawn_enemy(i)

func _spawn_enemy(index := 0) -> void:
    var enemy := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.height = 1.5
    mesh.radius = 0.45
    enemy.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#d85a79") if index % 2 else Color("#6f82e8")
    enemy.material_override = mat
    enemy.position = Vector3(randf_range(-18,18),0.9,randf_range(-18,18))
    add_child(enemy)
    enemies.append(enemy)

func _auto_combat(delta: float) -> void:
    if combat_timer < 1.5:
        return
    combat_timer = 0.0
    if enemies.is_empty():
        combat_label.text = "Aucun ennemi à portée · recherche..."
        return
    var target: Node3D = enemies[0]
    var best := player.global_position.distance_to(target.global_position)
    for e in enemies:
        if is_instance_valid(e):
            var d := player.global_position.distance_to(e.global_position)
            if d < best:
                target = e; best = d
    if best > 22.0:
        combat_label.text = "Auto-combat · cible trop éloignée"
        return
    var enemy_level := randi_range(max(1,frontier_min), max(frontier_min+1,frontier_max))
    var reward_xp := 8 + enemy_level * 2 + reborn
    xp += reward_xp
    gold += enemy_level * 3
    power += 1
    combat_label.text = "⚔ Victoire · ennemi niveau %d · +%d XP · +%d or" % [enemy_level,reward_xp,enemy_level*3]
    _log("Victoire contre un monstre niveau %d." % enemy_level)
    target.queue_free()
    enemies.erase(target)
    while xp >= 100.0:
        xp -= 100.0
        level += 1
        group_levels[0] = level
        power += 10 + reborn * 2
        _log("[color=#bca5ff]Niveau %d[/color] atteint." % level)
        if level % 5 == 0:
            _update_frontier()

func _average() -> float:
    var total := 0.0
    for l in group_levels:
        total += float(l)
    return total / float(group_levels.size())

func _update_frontier() -> void:
    avg_level = _average()
    frontier_min = max(1, int(floor(avg_level / 5.0)) * 5)
    frontier_max = frontier_min + 5
    zone_index = min(zone_names.size()-1, int(floor(avg_level / 15.0)))
    ai_label.text = "Analyse : niveau moyen %.1f → prochaine zone niveau %d–%d." % [avg_level,frontier_min,frontier_max]

func _generate_frontier() -> void:
    _update_frontier()
    world_tier = max(world_tier, 1 + int(floor(avg_level / 30.0)))
    var future_index := min(zone_names.size()-1, zone_index + 1)
    zone_label.text = zone_names[future_index]
    ai_label.text = "Frontière générée : %s · %s · niveaux %d–%d · boss prévu." % [zone_names[future_index],zone_biomes[future_index],frontier_min,frontier_max]
    _log("[color=#49df9a]Directeur IA[/color] : nouvelle frontière validée → %s." % zone_names[future_index])
    _show_toast("Nouvelle frontière ajoutée")

func _reborn() -> void:
    if level < 25:
        _show_toast("Reborn disponible au niveau 25")
        return
    reborn += 1
    level = 1
    group_levels[0] = 1
    xp = 0
    power += 25 + reborn * 10
    world_tier = max(world_tier, 1 + int(floor(reborn / 2.0)))
    _log("[color=#d7bcff]REBORN #%d[/color] : progression temporaire réinitialisée, monde conservé." % reborn)
    _show_toast("REBORN #%d — bonus permanent acquis" % reborn)
    _update_frontier()

func _refresh() -> void:
    var avg := _average()
    level_label.text = "Niveau %d · Reborn %d" % [level,reborn]
    avg_label.text = "Niveau moyen du groupe : %.1f" % avg
    power_label.text = "Puissance effective : %d" % int(power)
    gold_label.text = "Or : %d  ·  +%.1f/s" % [gold,gold_per_second]
    tier_label.text = "World Tier : %d" % world_tier
    xp_bar.value = xp
    reborn_label.text = "Reborn permanents : %d\nBonus puissance : +%d" % [reborn,int(max(0, power-120))]
    reborn_button.disabled = level < 25
    zone_label.text = "%s · %s" % [zone_names[zone_index],zone_biomes[zone_index]]
    frontier_label.text = "Frontière active : niveaux %d–%d · niveau moyen %.1f" % [frontier_min,frontier_max,avg]

func _log(text: String) -> void:
    if log_box:
        log_box.append_text("[color=#6f7896][%s][/color] %s\n" % [Time.get_time_string_from_system(),text])

func _show_toast(text: String) -> void:
    toast.text = text
    toast.modulate.a = 1.0
    var tween := create_tween()
    tween.tween_interval(1.6)
    tween.tween_property(toast,"modulate:a",0.0,0.4)
