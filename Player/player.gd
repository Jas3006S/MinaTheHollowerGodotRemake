## Written by Jas Sandhu

extends CharacterBody3D

@export_group("Movement")
@export var MAX_SPEED : float = 5.0
@export var ACCELERATION : float = 10.0
@export var FRICTION : float = 12.0

@export_group("Jumping")
# Regular jump force
@export var JUMP_FORCE : float = 9.0

# Higher jumping force after player leaves HOLLOWING state
@export var EMERGE_JUMP_FORCE : float = 11.0

## Sprites Z-axis offset
@export var SPRITE_JUMP_OFFSET : float = 0.5

@export_group("Gravity Multipliers")
@export var GRAVMULT_UP: float = 30.0    # lighter while rising
@export var GRAVMULT_DOWN: float = 80.0  # heavier while falling

@export var GRAVMULT_EMERGE_UP : float = 25.0    # floatier on the way up after emerging
@export var GRAVMULT_EMERGE_DOWN : float = 80.0

## On ready variables
@onready var state_label: Label3D = $StateLabel
@onready var shadow_sprite : Sprite3D = $ShadowSprite
@onready var coll_shape3d : CollisionShape3D = $CollisionShape3D
@onready var anim_sprite : AnimatedSprite3D = $AnimatedSprite3D
@onready var hollow_timer: Timer = $HollowTimer
@onready var sfx_player: Node3D = $AudioController
@onready var kick_dirt: AnimatedSprite3D = $KickDirt

var shake_tween : Tween
var last_anim : String = "walk_down"

## Player states
enum State{
	WALKING,
	JUMPING,
	HOLLOWING,
	EMERGING
}
var state : State = State.WALKING
var emerging : bool = false


func _ready() -> void:
	set_state(State.WALKING)
	anim_sprite.play("blink_down")
	kick_dirt.hide()


func set_state(next_state : State) -> void:
	# Only run if state has changed
	if next_state == state:
		return
	
	state = next_state
	
	# ENUM_NAME.keys()[enum_val] (https://forum.godotengine.org/t/translate-an-enum-into-a-string/20364/3)
	# Swap text to our current state, get string from State.keys()
	state_label.text = State.keys()[state]
	
	# reset active tweens
	if shake_tween:
		shake_tween.kill()
		anim_sprite.position.x = 0.0
	
	match state:
		State.JUMPING:
			sfx_player.play_jump()
		
		State.HOLLOWING:
			sfx_player.play_hollow_start()
			start_shake()
			
			# Kicking dirt animation
			kick_dirt.show()
			kick_dirt.play("dirtkick")
		
		State.EMERGING:
			sfx_player.play_hollow_jump()
		
		State.WALKING:
			pass


func start_shake() -> void:
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
		
	shake_tween = create_tween()
	shake_tween.set_loops()  # loop indefinitely
	
	shake_tween.tween_property(anim_sprite, "position:x", 0.04, 0.05)
	shake_tween.tween_property(anim_sprite, "position:x", -0.04, 0.05)
	shake_tween.tween_property(anim_sprite, "position:x", 0.0, 0.05)


func apply_gravity(delta : float) -> void:
	if is_on_floor():
		return
	
	# Is the player rising? (velocity.y is higher than 0)
	var rising_bool = velocity.y > 0
	
	# Applying gravity strenght depending on players current state
	if state == State.EMERGING:
		velocity.y -= (GRAVMULT_EMERGE_UP if rising_bool else GRAVMULT_EMERGE_DOWN) * delta
	else:
		velocity.y -= (GRAVMULT_UP if rising_bool else GRAVMULT_DOWN) * delta


# Built off of Mostly Mad Productions - https://www.youtube.com/watch?v=0mesDaDdVL4
func horizontal_movement(delta : float, speed_mult : float) -> void:
	## Horizontal movement — X and Z are the ground plane in 3D, Y hardcoded to 0 for walking
	# Build the direction vector for movement
	# normalized() stops the vector's length at 1 so diagonal movement isn't faster than cardinal
	var _input = Vector3(
		Input.get_axis("ui_left", "ui_right"),
		0,
		Input.get_axis("ui_up", "ui_down")
	).normalized()
	
	## Exponential lerping applied to X and Z values
	# If input is held -> lerp towards MAX_SPEED
	# If input released -> lerp towards 0, FRICTION makes this lerp faster for a smooth decelartion look
	var lerp_weight = 1.0 - exp(-delta * (ACCELERATION if _input else FRICTION))
	velocity.x = lerp(velocity.x, _input.x * MAX_SPEED * speed_mult, lerp_weight)
	velocity.z = lerp(velocity.z, _input.z * MAX_SPEED * speed_mult, lerp_weight)
	
	update_anim(_input)
	#if _input != Vector3.ZERO:
		#update_anim(_input)
	#else:
		#anim_sprite.stop()


func update_visuals() -> void:
	# body's y position in world
	var body_world_y : float = position.y
	
	## Shadows Movement
	shadow_sprite.position.y = -body_world_y  # inverse of player height so its stuck to the ground
	shadow_sprite.scale = Vector3(1.22, 0.62, 1.0) * clamp(1.0 - body_world_y * 0.1, 0.2, 1.0) # shift in scale
	
	## Character Sprite Jump offset on z axis
	anim_sprite.position.z = body_world_y * -SPRITE_JUMP_OFFSET


func update_anim(input : Vector3) -> void:
	if input == Vector3.ZERO:
		# Idle
		if last_anim == "walk_sideways":
			anim_sprite.play("blink_sideways")
		elif last_anim == "walk_down":
			anim_sprite.play("blink_down")
		else:
			anim_sprite.stop()
		return
	
	
	# Z axis is forward/back in 3D
	# X axis is left/right
	if abs(input.x) > abs(input.z):
		# Horizontal movement is dominant
		anim_sprite.play("walk_sideways")
		anim_sprite.flip_h = input.x < 0 # Flipping sprite
		last_anim = "walk_sideways"
	
	
	elif input.z < 0:
		# Moving up (away from camera)
		anim_sprite.play("walk_up")
		anim_sprite.flip_h = false
		last_anim = "walk_up"
	
	
	else:
		# Moving down
		anim_sprite.play("walk_down")
		anim_sprite.flip_h = false
		last_anim = "walk_down"


func _on_hollow_timer_timeout() -> void:
	if state == State.HOLLOWING:
		sfx_player.stop_hollowing()
		emerging = false
		
		velocity.y = EMERGE_JUMP_FORCE
		set_state(State.EMERGING)


func _physics_process(delta: float) -> void:
	# Add the gravity.
	apply_gravity(delta)
	
	# If player is HOLLOWING, movement is faster
	if state == State.HOLLOWING:
		horizontal_movement(delta, 1.5)
	else:
		horizontal_movement(delta, 1.0)
	
	match state:
		State.WALKING:
			if Input.is_action_just_pressed("Jump"):
				velocity.y = JUMP_FORCE
				set_state(State.JUMPING)
		
		# After JUMPING,
		State.JUMPING:
			anim_sprite.play("jumping")
			
			# If the player has landed
			if is_on_floor():
				# If they are still holding jump, shift to HOLLOWING state
				if Input.is_action_pressed("Jump"):
					set_state(State.HOLLOWING)
					hollow_timer.start()
				
				# Else shift to WALKING state
				else:
					set_state(State.WALKING)
					sfx_player.play_land()
					
					if last_anim == "walk_sideways":
						anim_sprite.play("blink_sideways")
					elif last_anim == "walk_down":
						anim_sprite.play("blink_down")
			
		# While HOLLOWING, player will ignore enemy collisions (future)
		State.HOLLOWING:
			anim_sprite.play("hollowing")
			
		# After EMERGING, we just set the player back to WALKING when they hit the floor
		# In the future we may have to check for "trinket" or side tool effects and apply those
		State.EMERGING:
			anim_sprite.play("jumping")
			
			if not is_on_floor():
				emerging = true
			
			if emerging and is_on_floor():
				set_state(State.WALKING)
				emerging = false
				anim_sprite.play("walk_down")
				sfx_player.play_land()
	
	move_and_slide()
	update_visuals()


func _on_kick_dirt_animation_finished() -> void:
	kick_dirt.hide()
