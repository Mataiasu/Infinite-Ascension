extends CanvasLayer

# In-game pause menu. Works independently from game_runtime so it remains available
# even while the gameplay tree is paused.

var overlay: ColorRect
var menu: PanelContainer
var options_panel: PanelContainer
var fullscreen_check: CheckButton
var volume_slider: HSlider
var menu_cursor: Control
var is_open := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 100
    _build_ui()
    _set_open(false)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        _toggle()
        get_viewport().set_input_as_handled()

func _toggle() -> void:
    _set_open(not is_open)

func _set_open(value: bool) -> void:
    is_open = value
    if overlay:
        overlay.visible = value
    if options_panel:
        options_panel.visible = value and options_panel.visible
    if menu_cursor:
        menu_cursor.visible = value
    get_tree().paused = value
    if value:
        Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
    else:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_ui() -> void:
    overlay = ColorRect.new()
    overlay.color = Color(0.015, 0.02, 0.04, 0.82)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)

    menu = PanelContainer.new()
    menu.position = Vector2(440, 150)
    menu.size = Vector2(400, 420)
    overlay.add_child(menu)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    menu.add_child(box)

    var title := Label.new()
    title.text = "INFINITE ASCENSION"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    box.add_child(title)

    var paused := Label.new()
    paused.text = "JEU EN PAUSE"
    paused.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    paused.add_theme_font_size_override("font_size", 18)
    box.add_child(paused)

    var resume := Button.new()
    resume.text = "REPRENDRE"
    resume.custom_minimum_size.y = 52
    resume.pressed.connect(func(): _set_open(false))
    box.add_child(resume)

    var options := Button.new()
    options.text = "OPTIONS"
    options.custom_minimum_size.y = 52
    options.pressed.connect(_show_options)
    box.add_child(options)

    var quit := Button.new()
    quit.text = "QUITTER LE JEU"
    quit.custom_minimum_size.y = 52
    quit.pressed.connect(_quit_game)
    box.add_child(quit)

    var hint := Label.new()
    hint.text = "Échap : fermer le menu"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(hint)

    _build_options()

    var cursor_script := load("res://scripts/menu_cursor.gd")
    if cursor_script != null:
        menu_cursor = Control.new()
        menu_cursor.set_script(cursor_script)
        menu_cursor.visible = false
        add_child(menu_cursor)

func _build_options() -> void:
    options_panel = PanelContainer.new()
    options_panel.position = Vector2(470, 175)
    options_panel.size = Vector2(340, 370)
    overlay.add_child(options_panel)
    options_panel.visible = false

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    options_panel.add_child(box)

    var title := Label.new()
    title.text = "OPTIONS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 24)
    box.add_child(title)

    fullscreen_check = CheckButton.new()
    fullscreen_check.text = "Plein écran"
    fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
    fullscreen_check.toggled.connect(_set_fullscreen)
    box.add_child(fullscreen_check)

    var volume_label := Label.new()
    volume_label.text = "Volume général"
    box.add_child(volume_label)

    volume_slider = HSlider.new()
    volume_slider.min_value = 0.0
    volume_slider.max_value = 1.0
    volume_slider.step = 0.05
    volume_slider.value = 1.0
    volume_slider.value_changed.connect(_set_volume)
    box.add_child(volume_slider)

    var back := Button.new()
    back.text = "RETOUR"
    back.custom_minimum_size.y = 48
    back.pressed.connect(_hide_options)
    box.add_child(back)

func _show_options() -> void:
    menu.visible = false
    options_panel.visible = true

func _hide_options() -> void:
    options_panel.visible = false
    menu.visible = true

func _set_fullscreen(enabled: bool) -> void:
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _set_volume(value: float) -> void:
    AudioServer.set_bus_volume_db(0, linear_to_db(max(value, 0.001)))

func _quit_game() -> void:
    get_tree().paused = false
    _log("GAME_QUIT_FROM_MENU", {})
    get_tree().quit()

func _log(event_name: String, data: Dictionary = {}) -> void:
    var logger := get_node_or_null("/root/GameLogger")
    if logger != null and logger.has_method("log_event"):
        logger.call("log_event", event_name, data)
