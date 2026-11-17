extends Label

const JS_SETUP := """
window.mp_status = 'mulai';
(async () => {
  try {
    window.mp_status = 'memuat library';
    const { FilesetResolver, PoseLandmarker } = await import('https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/vision_bundle.mjs');
    window.mp_status = 'library ok, memuat wasm';
    const vision = await FilesetResolver.forVisionTasks('https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm');
    window.mp_status = 'wasm ok, memuat model full';
    const landmarker = await PoseLandmarker.createFromOptions(vision, {
      baseOptions: { modelAssetPath: 'pose_landmarker_full.task' },
      runningMode: 'VIDEO',
      numPoses: 1
    });
    window.mp_status = 'model ok, minta kamera';
    const video = document.createElement('video');
    video.setAttribute('playsinline', '');
    video.muted = true;
    video.style.display = 'none';
    document.body.appendChild(video);
    const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' } });
    video.srcObject = stream;
    await video.play();
    window.mp_status = 'kamera aktif';
    let last = -1;
    function loop() {
      if (video.readyState >= 2 && video.currentTime !== last) {
        last = video.currentTime;
        const r = landmarker.detectForVideo(video, performance.now());
        window.pose_data = (r.landmarks && r.landmarks.length) ? r.landmarks[0] : [];
      }
      requestAnimationFrame(loop);
    }
    loop();
  } catch (e) {
    window.mp_status = 'ERROR: ' + (e.name || '') + ' ' + e.message;
  }
})();
"""

# Saklar lengan (sudah terbukti benar)
const FLIP_X_LENGAN := true
const FLIP_Y_LENGAN := true

# Gerak samping dan naik turun dari pinggul
const FLIP_X_GERAK := true
const FLIP_Y_GERAK := false
const GERAK := Vector2(2.0, 2.0)

# Gerak maju dari langkah di tempat
# Ubah MAJU_ARAH ke 1.0 kalau karakter bergerak mundur, bukan maju
const MAJU_ARAH := -1.0
const KECEPATAN_MAJU := 0.8
const AMBANG_LANGKAH := 0.004
const MAJU_MAKS := 4.0

# [bahu, siku MediaPipe, nama tulang lengan, nama tulang lengan bawah]
const PAIR := {
	"lengan_kiri": [11, 13, "mixamorig_LeftArm", "mixamorig_LeftForeArm"],
	"lengan_kanan": [12, 14, "mixamorig_RightArm", "mixamorig_RightForeArm"],
}

var _t := 0.0
var skel: Skeleton3D = null
var root: Node3D = null
var root_awal := Vector3.ZERO
var idx := {}
var pinggul_awal := Vector2.ZERO
var pinggul_siap := false
var geser := Vector2.ZERO
var maju := 0.0
var _mata_kaki_prev := 0.0
var _kecepatan_langkah := 0.0

func _ready():
	if not OS.has_feature("web"):
		text = "Bukan web"
		return
	JavaScriptBridge.eval(JS_SETUP)
	skel = get_tree().current_scene.find_child("Skeleton3D", true, false) as Skeleton3D
	root = get_tree().current_scene as Node3D
	if root:
		root_awal = root.position
	if skel:
		for k in PAIR.keys():
			idx[k] = [skel.find_bone(PAIR[k][2]), skel.find_bone(PAIR[k][3])]

func _titik(pose: Array, i: int) -> Vector2:
	return Vector2(pose[i]["x"], pose[i]["y"])

func _putar(bi: int, ci: int, target: Vector3) -> void:
	var rest_b := skel.get_bone_global_rest(bi)
	var rest_c := skel.get_bone_global_rest(ci)
	var arah_rest := (rest_c.origin - rest_b.origin).normalized()
	if arah_rest.length() < 0.001:
		return

	var rot_rest := rest_b.basis.orthonormalized().get_rotation_quaternion()
	var target_skel := Quaternion(arah_rest, target) * rot_rest

	var induk: int = skel.get_bone_parent(bi)
	var induk_rot := Quaternion()
	if induk >= 0:
		induk_rot = skel.get_bone_global_rest(induk).basis.orthonormalized().get_rotation_quaternion()
	var pose_rot := rot_rest.inverse() * (induk_rot.inverse() * target_skel)

	var sekarang := skel.get_bone_pose_rotation(bi)
	skel.set_bone_pose_rotation(bi, sekarang.slerp(pose_rot, 0.4))

func _kembali_rest() -> void:
	for k in idx.keys():
		for b in idx[k]:
			if b >= 0:
				var sekarang := skel.get_bone_pose_rotation(b)
				skel.set_bone_pose_rotation(b, sekarang.slerp(Quaternion(), 0.2))

func _process(delta):
	if not OS.has_feature("web"):
		return
	_t += delta
	if _t < 0.05:
		return
	var dt := _t
	_t = 0.0

	var status = JavaScriptBridge.eval("window.mp_status || 'belum mulai'")
	var data = JavaScriptBridge.eval("JSON.stringify(window.pose_data || [])")
	var pose = JSON.parse_string(str(data))

	if not (pose is Array and pose.size() > 0):
		pinggul_siap = false
		if skel:
			_kembali_rest()
		if root:
			geser = geser.lerp(Vector2.ZERO, 0.1)
			root.position = root_awal + Vector3(geser.x, geser.y, maju * MAJU_ARAH)
		text = str(status)
		return

	if skel == null:
		text = "Skeleton tidak ditemukan"
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		text = "Kamera 3D tidak ditemukan"
		return
	var basis_kamera := cam.global_transform.basis
	var skel_balik := skel.global_transform.basis.inverse()

	# Lengan
	for k in PAIR.keys():
		var p: Array = PAIR[k]
		var b: int = idx[k][0]
		var fore: int = idx[k][1]
		if b < 0 or fore < 0:
			continue

		var dx: float = pose[p[1]]["x"] - pose[p[0]]["x"]
		var dy: float = pose[p[1]]["y"] - pose[p[0]]["y"]
		if FLIP_X_LENGAN:
			dx = -dx
		var layar := Vector3(dx, -dy, 0.0)
		if FLIP_Y_LENGAN:
			layar.y = -layar.y
		if layar.length() < 0.01:
			continue
		var target := (skel_balik * (basis_kamera * layar.normalized())).normalized()
		_putar(b, fore, target)

	# Gerak samping dan naik turun dari pinggul
	var pinggul := (_titik(pose, 23) + _titik(pose, 24)) * 0.5
	if not pinggul_siap:
		pinggul_awal = pinggul
		pinggul_siap = true
	var d := pinggul - pinggul_awal
	var gx := d.x
	if FLIP_X_GERAK:
		gx = -gx
	var gy := -d.y
	if FLIP_Y_GERAK:
		gy = -gy
	geser = geser.lerp(Vector2(gx, gy) * GERAK, 0.3)

	# Gerak maju dari langkah di tempat: selisih tinggi pergelangan kaki berubah saat kaki bergantian
	var mata_kaki := _titik(pose, 27).y - _titik(pose, 28).y
	var selisih_kaki := absf(mata_kaki - _mata_kaki_prev)
	_mata_kaki_prev = mata_kaki
	_kecepatan_langkah = lerpf(_kecepatan_langkah, selisih_kaki, 0.3)
	if _kecepatan_langkah > AMBANG_LANGKAH:
		maju = clampf(maju + KECEPATAN_MAJU * dt, 0.0, MAJU_MAKS)

	if root:
		root.position = root_awal + Vector3(geser.x, geser.y, maju * MAJU_ARAH)

	text = "langkah: %.3f  maju: %.2f" % [_kecepatan_langkah, maju]
