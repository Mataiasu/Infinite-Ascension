extends Control

const DEFAULT_PORT := 7777
const REQUEST_TIMEOUT := 2.0

var ip_edit: LineEdit
var port_edit: LineEdit
var status_label: Label
var connect_button: Button
var launch_button: Button
var stop_button: Button

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_ui()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color("090c15")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var box := VBoxContainer.new()
    box.custom_minimum_size = Vector2(560, 0)
    box.add_theme_constant_override("separation", 14)
    center.add_child(box)

    var title := Label.new()
    title.text = "INFINITE ASCENSION"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    box.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "ANDROID DEV CLIENT • PC LOCAL"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 16)
    box.add_child(subtitle)

    var ip_label := Label.new()
    ip_label.text = "IP DU PC"
    box.add_child(ip_label)
    ip_edit = LineEdit.new()
    ip_edit.placeholder_text = "Ex. 192.168.1.25"
    ip_edit.custom_minimum_size.y = 48
    ip_edit.add_theme_font_size_override("font_size", 16)
    box.add_child(ip_edit)

    var port_label := Label.new()
    port_label.text = "PORT"
    box.add_child(port_label)
    port_edit = LineEdit.new()
    port_edit.text = str(DEFAULT_PORT)
    port_edit.custom_minimum_size.y = 44
    box.add_child(port_edit)

    connect_button = Button.new()
    connect_button.text = "CONNECTER AU PC"
    connect_button.custom_minimum_size.y = 52
    connect_button.pressed.connect(_on_connect_pressed)
    box.add_child(connect_button)

    launch_button = Button.new()
    launch_button.text = "LANCER LE JEU SUR LE PC"
    launch_button.custom_minimum_size.y = 52
    launch_button.pressed.connect(_on_launch_pressed)
    box.add_child(launch_button)

    stop_button = Button.new()
    stop_button.text = "ARRÊTER LE JEU SUR LE PC"
    stop_button.custom_minimum_size.y = 52
    stop_button.pressed.connect(_on_stop_pressed)
    box.add_child(stop_button)

    status_label = Label.new()
    status_label.text = "Entrez l'adresse IP locale du PC."
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(status_label)

func _base_url() -> String:
    var ip := ip_edit.text.strip_edges()
    var port := port_edit.text.strip_edges()
    if ip.is_empty():
        return ""
    if port.is_empty():
        port = str(DEFAULT_PORT)
    return "http://%s:%s" % [ip, port]

func _request(path: String, method := HTTPClient.METHOD_GET) -> void:
    var base := _base_url()
    if base.is_empty():
        status_label.text = "IP du PC manquante."
        return
    var http := HTTPRequest.new()
    http.timeout = REQUEST_TIMEOUT
    add_child(http)
    http.request_completed.connect(_on_request_completed.bind(http))
    var err := http.request(base + path, [], method)
    if err != OK:
        status_label.text = "Impossible de contacter le PC (%s)." % err
        http.queue_free()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
    if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
        status_label.text = body.get_string_from_utf8()
    else:
        status_label.text = "Erreur PC : HTTP %s / résultat %s" % [response_code, result]
    http.queue_free()

func _on_connect_pressed() -> void:
    status_label.text = "Connexion au PC…"
    _request("/health")

func _on_launch_pressed() -> void:
    status_label.text = "Demande de lancement…"
    _request("/launch", HTTPClient.METHOD_POST)

func _on_stop_pressed() -> void:
    status_label.text = "Demande d'arrêt…"
    _request("/stop", HTTPClient.METHOD_POST)
