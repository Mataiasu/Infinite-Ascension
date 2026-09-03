extends Control

const RELEASE_URL := "https://github.com/Mataiasu/Infinite-Ascension/releases/tag/latest"
const MANIFEST_URL := "https://github.com/Mataiasu/Infinite-Ascension/releases/download/latest/manifest.json"
const APK_URL := "https://github.com/Mataiasu/Infinite-Ascension/releases/download/latest/Infinite-Ascension-Android.apk"
const CURRENT_BUILD := 41

var status_label: Label
var build_label: Label
var update_button: Button
var http: HTTPRequest
var auto_update := true
var latest_build := 0

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
    build_label.text = "Build installée : #%s" % CURRENT_BUILD
    build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    build_label.add_theme_font_size_override("font_size", 13)
    build_label.add_theme_color_override("font_color", Color("#9aa4c3"))
    box.add_child(build_label)

    status_label = Label.new()
    status_label.text = "Vérification de la dernière build…"
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
    update_button.text = "↻  METTRE À JOUR"
    update_button.custom_minimum_size.y = 48
    update_button.disabled = true
    update_button.pressed.connect(_start_update)
    box.add_child(update_button)

    var settings := Button.new()
    settings.text = "⚙  PARAMÈTRES"
    settings.custom_minimum_size.y = 44
    settings.pressed.connect(_show_settings)
    box.add_child(settings)

    var release := Button.new()
    release.text = "▣  OUVRIR LES RELEASES"
    release.custom_minimum_size.y = 42
    release.pressed.connect(_open_release)
    box.add_child(release)

    var note := Label.new()
    note.text = "Les mises à jour sont vérifiées au démarrage.\nAndroid peut demander l'autorisation d'installer des applications inconnues."
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
        update_button.disabled = true
        return
    var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
    if parsed is Dictionary:
        latest_build = int(parsed.get("build", 0))
        build_label.text = "Build installée : #%s · Disponible : #%s" % [CURRENT_BUILD, latest_build]
        if latest_build > CURRENT_BUILD:
            status_label.text = "Nouvelle mise à jour disponible : build #%s." % latest_build
            update_button.disabled = false
            if auto_update:
                call_deferred("_start_update")
        else:
            status_label.text = "Application à jour."
            update_button.disabled = false
    else:
        status_label.text = "Manifest invalide · lancement local disponible."

func _start_update() -> void:
    if latest_build <= CURRENT_BUILD:
        status_label.text = "Aucune mise à jour nécessaire."
        return
    status_label.text = "Téléchargement de la mise à jour…"
    update_button.disabled = true
    if OS.get_name() != "Android":
        OS.shell_open(APK_URL)
        return
    _download_apk_android()

func _download_apk_android() -> void:
    var android_runtime = Engine.get_singleton("AndroidRuntime")
    if android_runtime == null:
        status_label.text = "AndroidRuntime indisponible · ouverture du téléchargement."
        OS.shell_open(APK_URL)
        return

    var context = android_runtime.getApplicationContext()
    var DownloadManager = JavaClassWrapper.wrap("android.app.DownloadManager")
    var Request = JavaClassWrapper.wrap("android.app.DownloadManager$Request")
    var Uri = JavaClassWrapper.wrap("android.net.Uri")

    var request = Request.Request(Uri.parse(APK_URL))
    request.setTitle("Infinite Ascension — mise à jour")
    request.setDescription("Téléchargement de la build #%s" % latest_build)
    request.setNotificationVisibility(1)
    request.setMimeType("application/vnd.android.package-archive")
    request.setAllowedOverMetered(true)
    request.setAllowedOverRoaming(true)

    var manager = context.getSystemService("download")
    var download_id = manager.enqueue(request)
    status_label.text = "Téléchargement lancé. L'installation sera proposée à la fin."
    _poll_download(manager, download_id)

func _poll_download(manager, download_id) -> void:
    await get_tree().create_timer(1.0).timeout
    var DownloadManager = JavaClassWrapper.wrap("android.app.DownloadManager")
    var Query = JavaClassWrapper.wrap("android.app.DownloadManager$Query")
    var query = Query.Query()
    query.setFilterById(download_id)
    var cursor = manager.query(query)
    if cursor != null and cursor.moveToFirst():
        var status_col = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
        var status = cursor.getInt(status_col)
        if status == DownloadManager.STATUS_SUCCESSFUL:
            var uri = manager.getUriForDownloadedFile(download_id)
            cursor.close()
            _install_downloaded_apk(uri)
            return
        if status == DownloadManager.STATUS_FAILED:
            cursor.close()
            status_label.text = "Échec du téléchargement."
            update_button.disabled = false
            return
    if cursor != null:
        cursor.close()
    _poll_download(manager, download_id)

func _install_downloaded_apk(uri) -> void:
    if uri == null:
        status_label.text = "APK téléchargée mais URI d'installation introuvable."
        update_button.disabled = false
        return
    var android_runtime = Engine.get_singleton("AndroidRuntime")
    var activity = android_runtime.getActivity()
    var Intent = JavaClassWrapper.wrap("android.content.Intent")
    var intent = Intent.Intent(Intent.ACTION_VIEW)
    intent.setDataAndType(uri, "application/vnd.android.package-archive")
    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    activity.startActivity(intent)
    status_label.text = "Installation de la nouvelle version…"

func _show_settings() -> void:
    auto_update = not auto_update
    status_label.text = "Mise à jour automatique : %s" % ("ACTIVÉE" if auto_update else "DÉSACTIVÉE")

func _play() -> void:
    status_label.text = "Lancement du client Android…"
    get_tree().change_scene_to_file("res://Main.tscn")

func _open_release() -> void:
    OS.shell_open(RELEASE_URL)
