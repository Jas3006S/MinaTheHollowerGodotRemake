extends Node3D

@onready var jump_sfx: AudioStreamPlayer3D = $JumpSFX
@onready var hollowing_sfx: AudioStreamPlayer3D = $HollowingSFX
@onready var hollow_jump_sfx: AudioStreamPlayer3D = $HollowJumpSFX
@onready var hollow_start_sfx: AudioStreamPlayer3D = $HollowStartSFX
@onready var land_sfx: AudioStreamPlayer3D = $LandSFX


func play_jump() -> void:
	#print("playing jump")
	jump_sfx.play()

func play_hollowing() -> void:
	hollowing_sfx.play()

func stop_hollowing() -> void:
	hollowing_sfx.stop()

func play_hollow_jump() -> void:
	hollow_jump_sfx.play()

func play_hollow_start() -> void:
	hollow_start_sfx.play()

func play_land() -> void:
	land_sfx.play()

func _on_hollow_start_sfx_finished() -> void:
	play_hollowing()
