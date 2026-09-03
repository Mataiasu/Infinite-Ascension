extends Control

const RELEASE_URL := "https://github.com/Mataiasu/Infinite-Ascension/releases/tag/latest"
const MANIFEST_URL := "https://github.com/Mataiasu/Infinite-Ascension/releases/download/latest/manifest.json"

var status_label: Label
var build_label: Label
var update_button: Button
var http: HTTPRequest

func _ready() -> void:
    _build_ui()
    _check_latest_build()

func _build_ui() -> void:
    var background := ColorRect.new()
    background.color = Color("#070a16")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 28)
    margin.add_theme_constant_override("margin_right", 28)
    margin.add_theme_constant_override("margin_top", 32)
    margin.add_theme_constant_override("margin_bottom", 32)
    add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 18)
    margin.add_child(box)

    var title := Label.new()
    title.text = "INFINITE ASCENSION"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    title.add_theme_color_override("font_color", Color("#eef1ff"))
    box.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "ANDROID TEST LAUNCHER"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 13)
    subtitle.add_theme_color_override("font_color", Color("#b47aff"))
    box.add_child(subtitle)

    build_label = Label.new()
    build_label.text = "Build : vérification…"
    build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    build_label.add_theme_font_size_override("font_size", 13)
    build_label.add_theme_color_override("font_color", Color("#9aa4c3"))
    box.add_child(build_label)

    status_label = Label.new()
    status_label.text = "Connexion au dépôt…"
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size", 12)
    status_label.add_theme_color_override("font_color", Color("#bfc7df"))
    box.add_child(status_label)

    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(spacer)

    var play := Button.new()
    play.text = "▶  JOUER SUR ANDROID"
    play.custom_minimum_size.y = 58
    play.add_theme_font_size_override("font_size", 16)
    play.pressed.connect(_play)
    box.add_child(play)

    update_button = Button.new()
    update_button.text = "↻  VOIR LA MISE À JOUR"
    update_button.custom_minimum_size.y = 48
    update_button.pressed.connect(_open_release)
    box.add_child(update_button)

    var note := Label.new()
    note.text = "Cette APK teste le client Android du jeu.\nElle ne lance pas l'exécutable Windows à distance."
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_font_size_override("font_size", 10)
    note.add_theme_color_override("font_color", Color("#6f7896"))
    box.add_child(note)

    http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_manifest_completed)

func _check_latest_build() -> void:
    var error := http.request(MANIFEST_URL + "?t=" + str(Time.get_ticks_msec()))
    if error != OK:
        status_label.text = "Impossible de vérifier la dernière build."

func _manifest_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
        status_label.text = "Dépôt inaccessible · lancement local disponible."
        return
    var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
    if parsed is Dictionary:
        var build = parsed.get("build", "?")
        build_label.text = "Dernière build disponible : #%s" % str(build)
        status_label.text = "Build distante détectée. Prêt à tester."
    else:
        status_label.text = "Manifest invalide · lancement local disponible."

func _play() -> void:
    status_label.text = "Lancement du client Android…"
    get_tree().change_scene_to_file("res://Main.tscn")

func _open_release() -> void:
    OS.shell_open(RELEASE_URL)
