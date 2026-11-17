extends Node

const SAVE_NAME := "rekaman_mocap.json"
const PLUGIN_NAME := "MocapPlugin"

var plugin
var frames: Array = []
var recording := false
var label: Label

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	label = Label.new()
	label.position = Vector2(20, 20)
	label.custom_minimum_size = Vector2(1000, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 32)
	layer.add_child(label)

	if Engine.has_singleton(PLUGIN_NAME):
		plugin = Engine.get_singleton(PLUGIN_NAME)
		plugin.connect("pose_frame", Callable(self, "_on_pose_frame"))
		plugin.initPose()
		_set_status("Sentuh layar untuk mulai merekam")
	else:
		_set_status("PLUGIN TIDAK DITEMUKAN\nSingleton terdaftar:\n" + ", ".join(Engine.get_singleton_list()))

func _input(event: InputEvent) -> void:
	if plugin == null:
		return
	if event is InputEventScreenTouch and event.pressed:
		if recording:
			selesai_rekam()
		else:
			mulai_rekam()

func mulai_rekam() -> void:
	frames.clear()
	recording = true
	plugin.startRecording()
	_set_status("Merekam... 0 frame\nBerdiri dengan seluruh tubuh terlihat")

func selesai_rekam() -> void:
	recording = false
	plugin.stopRecording()
	var path := _simpan()
	_set_status("Selesai: %d frame\nTersimpan di:\n%s" % [frames.size(), path])

func _simpan() -> String:
	var path := ""
	var dl := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if dl != "":
		path = dl.path_join(SAVE_NAME)

	var f: FileAccess = null
	if path != "":
		f = FileAccess.open(path, FileAccess.WRITE)

	# Android versi baru bisa menolak tulis ke Download, jadi pakai folder aplikasi sebagai cadangan
	if f == null:
		path = "user://" + SAVE_NAME
		f = FileAccess.open(path, FileAccess.WRITE)

	if f == null:
		return "GAGAL MENYIMPAN"

	f.store_string(JSON.stringify(frames))
	f.close()
	return path

func _on_pose_frame(data: String) -> void:
	if not recording:
		return
	var parsed = JSON.parse_string(data)
	if parsed != null:
		frames.append(parsed)
		_set_status("Merekam... %d frame" % frames.size())

func _set_status(teks: String) -> void:
	label.text = teks
	print(teks)
