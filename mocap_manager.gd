extends Node

const SAVE_NAME := "rekaman_mocap.json"

var plugin
var frames: Array = []
var recording := false
var label: Label

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 36)
	layer.add_child(label)

	if Engine.has_singleton("MocapPlugin"):
		plugin = Engine.get_singleton("MocapPlugin")
		plugin.connect("pose_frame", Callable(self, "_on_pose_frame"))
		plugin.initPose()
		_set_status("Sentuh layar untuk mulai merekam")
	else:
		_set_status("PLUGIN TIDAK DITEMUKAN\n" + str(Engine.get_singleton_list()))

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
	var dl := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var path := dl.path_join(SAVE_NAME) if dl != "" else "user://" + SAVE_NAME
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		# Android versi baru bisa menolak tulis ke Download, jadi simpan di folder aplikasi
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
