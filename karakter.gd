extends Node3D

@onready var mata_kiri: Sprite3D = $Object_4/Skeleton3D/BoneAttachment3D/Sprite3D
@onready var mata_kanan: Sprite3D = $Object_4/Skeleton3D/BoneAttachment3D/Sprite3D2

@export var gambar_terbuka: Texture2D
@export var gambar_tertutup: Texture2D
@export var jeda_kedip := 2.5
@export var lama_tertutup := 0.15

func _ready():
	kedip()

func kedip() -> void:
	await get_tree().create_timer(jeda_kedip).timeout
	mata_kiri.texture = gambar_tertutup
	mata_kanan.texture = gambar_tertutup
	await get_tree().create_timer(lama_tertutup).timeout
	mata_kiri.texture = gambar_terbuka
	mata_kanan.texture = gambar_terbuka
	kedip()
