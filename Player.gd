extends CharacterBody3D

signal health_changed(health_value)
signal death_count_changed(deaths)
signal kill_count_changed(kills)


@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $Camera3D/Pistol/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D
@onready var audio_player = $BulletSound 
@onready var setting_menu = $CanvasLayer/Settings
@onready var hit_sound = $HitSound
@onready var hud = $CanvasLayer/HUD
@onready var player_name = $CanvasLayer/HUD/PlayerName


@onready var mags = $CanvasLayer/HUD/mags
@onready var bullets = $CanvasLayer/HUD/bullet

var is_alive = false
var pistal_bullet := 7
var pistal_mags := 5
var health = 100
var deaths = 0
var kills = 0
var sensitivity = 1
var is_menu_open = false

const SPEED = 10.0
const JUMP_VELOCITY = 10.0

var gravity = 9.81 * 2.5

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	hud.show()


	if not is_multiplayer_authority(): return
	bullets.text = "bullet : " +str(pistal_bullet)
	mags.text = "mags"+ str(pistal_mags)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	var player = multiplayer.get_unique_id()
	player_name.text = str(player)
	
func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .002 * sensitivity)
		camera.rotate_x(-event.relative.y * .002 * sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if Input.is_action_just_pressed("shoot") and pistal_bullet >=1  \
			and anim_player.current_animation != "shoot":
		pistal_bullet -=1 
		bullets.text = "bullet : " +str(pistal_bullet)
		play_shoot_effects.rpc()
		if raycast.is_colliding():

			
			var hit_player = raycast.get_collider()
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())
			if hit_player.receive_damage() :
				update_kill()
	
	if Input.is_action_just_pressed("reload") and pistal_mags >= 1 :
		pistal_bullet = 7
		bullets.text = "bullet : " +str(pistal_bullet)
		pistal_mags -=1
		mags.text = "mags"+ str(pistal_mags)
				
				
	if event.is_action_pressed("quit"):
		if is_menu_open:
			setting_menu.hide()
			is_menu_open = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			setting_menu.show()
			is_menu_open = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			
			
func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if anim_player.current_animation == "shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play("move")
	else:
		anim_player.play("idle")

	move_and_slide()

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	# Play the shooting sound effect
	audio_player.play()

@rpc("any_peer")
func receive_damage():
	health -= 35
	hit_sound.play()
	print("Player hit: " + str(get_multiplayer_authority()) )
	health_changed.emit(health)
	if health <= 0:
		kill_player()
		deaths +=1
		death_count_changed.emit(deaths)
		print("Player down: " + str(get_multiplayer_authority()))
		return true
		

func update_kill():
	kills +=1
	kill_count_changed.emit(kills)
	

@rpc("any_peer")
func kill_player():
	toggle_alive_status()
	health = 100
	pistal_bullet = 7
	pistal_mags = 5
	if is_multiplayer_authority():
		bullets.text = "bullet : " +str(pistal_bullet)
		mags.text = "mags"+ str(pistal_mags)
	health_changed.emit(health)
	position = Vector3(randf_range(0, 18), 5, randf_range(0, 18))


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		anim_player.play("idle")

func _on_h_scroll_bar_value_changed(value):
	sensitivity = value

func _on_quit_button_pressed():
	get_tree().quit()

@rpc("any_peer", "reliable")
func toggle_alive_status():
	is_alive = not is_alive


