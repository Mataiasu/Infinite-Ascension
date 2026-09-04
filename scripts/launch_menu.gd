extends CanvasLayer

const BG_COLOR := Color("#070b18f2")
const PANEL_COLOR := Color("#0d1428f5")
const BORDER_COLOR := Color("#6f4cff")
const TEXT_COLOR := Color("#f2efff")
const MUTED_COLOR := Color("#9ea8c7")

var menu_root: Control
var continue_button: Button
var new_game_button: Button
var quit_button: Button
var runtime: Node

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    layer = 100
    runtime = get_parent()
    _build_menu()
    _lock_runtime_while_menu_is_open()
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _lock_runtime_while_menu_is_open() -> void:
    if runtime != null and is_instance_valid(runtime):
        # The gameplay runtime previously used PROCESS_MODE_ALWAYS. Force it
        # completely disabled while the launch menu is visible so keyboard,
        # mouse input, physics, enemies and timers cannot run behind the menu.
        runtime.process_mode = Node.PROCESS_MODE_DISABLED

func _build_menu() -> void:
    menu_root = Control.new()
    menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(menu_root)

    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = BG_COLOR
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu_root.add_child(background)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu_root.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(460, 500)
    panel.add_theme_stylebox_override("panel", _panel_style())
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 38)
    margin.add_theme_constant_override("margin_right", 38)
    margin.add_theme_constant_override("margin_top", 34)
    margin.add_theme_constant_override("margin_bottom", 34)
    panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    margin.add_child(box)

    var title := Label.new()
    title.text = "INFINITE ASCENSION"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 32)
    title.add_theme_color_override("font_color", TEXT_COLOR)
    box.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "ASCENSION • REBORN • FRONTIÈRE INFINIE"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 11)
    subtitle.add_theme_color_override("font_color", Color("#a66cff"))
    box.add_child(subtitle)

    var separator := HSeparator.new()
    box.add_child(separator)

    var status := Label.new()
    status.text = "Prêt à commencer votre ascension."
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_theme_font_size_override("font_size", 13)
    status.add_theme_color_override("font_color", MUTED_COLOR)
    box.add_child(status)

    continue_button = _button("CONTINUER LA PARTIE")
    continue_button.tooltip_text = "Reprendre la progression sauvegardée"
    continue_button.pressed.connect(_continue_game)
    box.add_child(continue_button)

    new_game_button = _button("NOUVELLE PARTIE")
    new_game_button.tooltip_text = "Effacer la progression locale et recommencer"
    new_game_button.pressed.connect(_new_game)
    box.add_child(new_game_button)

    var controls := Label.new()
    controls.text = "ZQSD / WASD  •  Souris : caméra  •  Espace / clic : attaque"
    controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    controls.add_theme_font_size_override("font_size", 10)
    controls.add_theme_color_override("font_color", MUTED_COLOR)
    box.add_child(controls)

    quit_button = _button("QUITTER")
    quit_button.pressed.connect(_quit_game)
    box.add_child(quit_button)

    var version := Label.new()
    version.text = "Build de test"
    version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    version.add_theme_font_size_override("font_size", 9)
    version.add_theme_color_override("font_color", Color("#68718c"))
    box.add_child(version)

func _button(text_value: String) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 52)
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", TEXT_COLOR)
    button.add_theme_stylebox_override("normal", _button_style(Color("#151d36")))
    button.add_theme_stylebox_override("hover", _button_style(Color("#202b4d")))
    button.add_theme_stylebox_override("pressed", _button_style(Color("#30245f")))
    button.add_theme_stylebox_override("focus", _button_style(Color("#202b4d")))
    return button

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL_COLOR
    style.border_color = BORDER_COLOR
    style.set_border_width_all(1)
    style.set_corner_radius_all(18)
    style.shadow_color = Color("#000000aa")
    style.shadow_size = 24
    return style

func _button_style(background: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = Color("#38466d")
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    return style

func _continue_game() -> void:
    if runtime != null and is_instance_valid(runtime):
        runtime.process_mode = Node.PROCESS_MODE_PAUSABLE
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    menu_root.queue_free()

func _new_game() -> void:
    var save_path := "user://infinite_ascension_save.json"
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(save_path)
    get_tree().paused = false
    get_tree().reload_current_scene()

func _quit_game() -> void:
    get_tree().paused = false
    get_tree().quit()

func _close_menu() -> void:
    _continue_game()
