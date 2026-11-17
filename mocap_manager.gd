extends Node

const SAVE_PATH := "user://rekaman_mocap.json"

var plugin
var frames: Array = []
var recording := false

func _ready() -> void:
	if Engine.has_singleton("MocapPlugin"):
		plugin = Engine.get_singleton("MocapPlugin")
		plugin.connect("pose_frame", Callable(self, "_on_pose_frame"))
		plugin.initPose()
	else:
		push_warning("Plugin MocapPlugin tidak ditemukan. Cek android/plugins dan centang di export preset.")

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
	print("Mulai rekam")

func selesai_rekam() -> void:
	recording = false
	plugin.stopRecording()

	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Gagal membuka file untuk menyimpan rekaman")
		return
	f.store_string(JSON.stringify(frames))
	f.close()

	print("Tersimpan ", frames.size(), " frame")
	print("Lokasi: ", ProjectSettings.globalize_path(SAVE_PATH))

func _on_pose_frame(data: String) -> void:
	if not recording:
		return
	var parsed = JSON.parse_string(data)
	if parsed != null:
		frames.append(parsed)
