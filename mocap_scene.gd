extends Node

const SAVE_NAME := "rekaman_mocap.json"
const PLUGIN_NAME := "MocapPlugin"
const COL_BG := Color("#0d1117")
const COL_CARD := Color("#161b22")
const COL_ACCENT := Color("#2ee6c5")
const COL_REC := Color("#ff4d6d")
const COL_TEXT := Color("#e6edf3")
const COL_MUTED := Color("#8b949e")

var plugin
var frames: Array = []
var recording := false

var lbl_title: Label
var lbl_status: Label
var lbl_count: Label
var lbl_hint: Label
var btn_rec: Button

func _ready() -> void:
	_build_ui()
	if Engine.has_singleton(PLUGIN_NAME):
		plugin = Engine.get_singleton(PLUGIN_NAME)
		plugin.connect("pose_frame", Callable(self, "_on_pose_frame"))
		plugin.initPose()
		_set_status("Siap merekam", "Tekan tombol di bawah untuk mulai")
	else:
		_set_status("Plugin tidak ditemukan", "Cek export preset dan folder plugin")
		btn_rec.disabled = true

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_bottom", 60)
	layer.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	lbl_title = _label("MOCAP STUDIO", 22, COL_ACCENT)
	box.add_child(lbl_title)

	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COL_CARD
	card_style.set_corner_radius_all(24)
	card_style.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", card_style)
	box.add_child(card)

	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 12)
	card.add_child(card_box)

	lbl_status = _label("", 36, COL_TEXT)
	card_box.add_child(lbl_status)
	lbl_count = _label("0 frame", 28, COL_MUTED)
	card_box.add_child(lbl_count)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	lbl_hint = _label("", 22, COL_MUTED)
	box.add_child(lbl_hint)

	btn_rec = Button.new()
	btn_rec.custom_minimum_size = Vector2(0, 130)
	btn_rec.add_theme_font_size_override("font_size", 30)
	btn_rec.add_theme_color_override("font_color", COL_BG)
	btn_rec.add_theme_color_override("font_disabled_color", COL_MUTED)
	btn_rec.pressed.connect(_on_button_pressed)
	box.add_child(btn_rec)

	_style_button(COL_ACCENT)
	btn_rec.text = "MULAI MEREKAM"

func _label(teks: String, ukuran: int, warna: Color) -> Label:
	var l := Label.new()
	l.text = teks
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", ukuran)
	l.add_theme_color_override("font_color", warna)
	return l

func _style_button(warna: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = warna
		sb.set_corner_radius_all(32)
		btn_rec.add_theme_stylebox_override(state, sb)

func _on_button_pressed() -> void:
	if recording:
		selesai_rekam()
	else:
		mulai_rekam()

func mulai_rekam() -> void:
	frames.clear()
	recording = true
	plugin.startRecording()
	btn_rec.text = "BERHENTI & SIMPAN"
	_style_button(COL_REC)
	lbl_count.text = "0 frame"
	_set_status("Merekam", "Berdiri dengan seluruh tubuh terlihat")

func selesai_rekam() -> void:
	recording = false
	plugin.stopRecording()
	var path := _simpan()
	btn_rec.text = "MULAI MEREKAM"
	_style_button(COL_ACCENT)
	_set_status("Tersimpan: %d frame" % frames.size(), path)

func _simpan() -> String:
	var dl := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if dl != "":
		var dl_path := dl.path_join(SAVE_NAME)
		var f := FileAccess.open(dl_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(frames))
			f.close()
			return dl_path
	var path := "user://" + SAVE_NAME
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	if f2 == null:
		return "GAGAL MENYIMPAN"
	f2.store_string(JSON.stringify(frames))
	f2.close()
	return path

func _on_pose_frame(data: String) -> void:
	if not recording:
		return
	var parsed = JSON.parse_string(data)
	if parsed != null:
		frames.append(parsed)
		lbl_count.text = "%d frame" % frames.size()

func _set_status(judul: String, detail: String) -> void:
	lbl_status.text = judul
	lbl_hint.text = detail
	print(judul, " | ", detail)
