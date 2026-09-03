extends Control

const DEFAULT_PORT := 7777

var ip_edit: LineEdit
var port_edit: LineEdit
var status_label: Label
var connect_button: Button
var launch_button: Button
var stop_button: Button
var http: HTTPRequest
var host_url := ""

func _ready() -> void:
    _build_ui()
    _set_status("Entre l'adresse IPv4 du PC puis appuie sur CONNECTER.")

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
    box.add_theme_constant_override("separation", 14)
    margin.add_child(box)

    var title := Label.new()
    title.text = "INFINITE ASCENSION"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    title.add_theme_color_override("font_color", Color("#eef1ff"))
    box.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "ANDROID DEV CLIENT · PC LOCAL"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 13)
    subtitle.add_theme_color_override("font_color", Color("#b47aff"))
    box.add_child(subtitle)

    var info := Label.new()
    info.text = "Cette APK ne contient pas le jeu. Elle contrôle le jeu lancé sur le PC via le réseau local."
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_theme_font_size_override("font_size", 11)
    info.add_theme_color_override("font_color", Color("#9aa4c3"))
    box.add_child(info)

    var ip_label := Label.new()
    ip_label.text = "IP DU PC"
    box.add_child(ip_label)
    ip_edit = LineEdit.new()
    ip_edit.placeholder_text = "ex. 192.168.1.25"
    ip_edit.text = "192.168.1."
    ip_edit.custom_minimum_size.y = 48
    ip_edit.add_theme_font_size_override("font_size", 16)
    box.add_child(ip_edit)

    var port_label := Label.new()
    port_label.text = "PORT"
    box.add_child(port_label)
    port_edit = LineEdit.new()
    port_edit.text = str(DEFAULT_PORT)
    port_edit.input_filter = LineEdit.InputType.TYPE_INT
    port_edit.custom_minimum_size.y = 44
    box.add_child(port_edit)

    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.custom_minimum_size.y = 54
    box.add_child(status_label)

    connect_button = Button.new()
    connect_button.text = "◉  CONNECTER AU PC"
    connect_button.custom_minimum_size.y = 54
    connect_button.pressed.connect(_connect)
    box.add_child(connect_button)

    launch_button = Button.new()
    launch_button.text = "▶  LANCER LE JEU SUR LE PC"
    launch_button.custom_minimum_size.y = 54
    launch_button.disabled = true
    launch_button.pressed.connect(_launch)
    box.add_child(launch_button)

    stop_button = Button.new()
    stop_button.text = "■  ARRÊTER LE JEU SUR LE PC"
    stop_button.custom_minimum_size.y = 48
    stop_button.disabled = true
    stop_button.pressed.connect(_stop)
    box.add_child(stop_button)

    var note := Label.new()
    note.text = "PC et téléphone doivent être sur le même réseau Wi-Fi/LAN.\nLe port 7777 doit être autorisé dans le pare-feu Windows."
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_font_size_override("font_size", 10)
    note.add_theme_color_override("font_color", Color("#6f7896"))
    box.add_child(note)

    http = HTTPRequest.new()
    add_child(http)

func _url() -> String:
    var ip := ip_edit.text.strip_edges()
    var port := port_edit.text.strip_edges()
    if ip.is_empty():
        return ""
    if port.is_empty():
        port = str(DEFAULT_PORT)
    return "http://%s:%s" % [ip, port]

func _connect() -> void:
    host_url = _url()
    if host_url.is_empty():
        _set_status("Adresse IP invalide.")
        return
    connect_button.disabled = true
    _set_status("Connexion à %s…" % host_url)
    var err := http.request(host_url + "/status")
    if err != OK:
        connect_button.disabled = false
        _set_status("Impossible d'envoyer la requête réseau (%s)." % err)
        return
    var result = await http.request_completed
    connect_button.disabled = false
    if result[0] != HTTPRequest.RESULT_SUCCESS or int(result[1]) < 200 or int(result[1]) >= 300:
        launch_button.disabled = true
        stop_button.disabled = true
        _set_status("PC inaccessible. Vérifie l'IP, le port et le pare-feu Windows.")
        return
    var data: Variant = JSON.parse_string(result[3].get_string_from_utf8())
    if data is Dictionary and bool(data.get("ok", false)):
        launch_button.disabled = false
        stop_button.disabled = not bool(data.get("running", false))
        _set_status("PC connecté · jeu %s" % ("EN COURS" if bool(data.get("running", false)) else "ARRÊTÉ"))
    else:
        _set_status("Réponse du PC invalide.")

func _post(path: String) -> void:
    if host_url.is_empty():
        _connect()
        return
    _set_status("Commande %s…" % path)
    var err := http.request(host_url + path, ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")
    if err != OK:
        _set_status("Erreur réseau (%s)." % err)
        return
    var result = await http.request_completed
    if result[0] != HTTPRequest.RESULT_SUCCESS or int(result[1]) < 200 or int(result[1]) >= 300:
        _set_status("Le PC n'a pas répondu correctement.")
        return
    var data: Variant = JSON.parse_string(result[3].get_string_from_utf8())
    if data is Dictionary and bool(data.get("ok", false)):
        var running := bool(data.get("running", false))
        launch_button.disabled = running
        stop_button.disabled = not running
        _set_status("PC connecté · jeu %s" % ("EN COURS" if running else "ARRÊTÉ"))
    else:
        _set_status("Erreur PC : %s" % str(data.get("error", "inconnue")))

func _launch() -> void:
    _post("/launch")

func _stop() -> void:
    _post("/stop")

func _set_status(text: String) -> void:
    if status_label:
        status_label.text = text
