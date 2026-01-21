extends CharacterBody3D


var current_speed: float

var train_rotation_delta: float = 0
var prev_frame_train_rotation: float = 0
var curr_frame_train_rotation: float = 0

var on_train: bool = false
var train: Node3D

var player_rotation: float = 0
var oxygen: float = 100
var oxygen_max: float = 100
var player_speed = Vector2.ZERO

var hypoxia_timer: int = 0

@export var walk_speed: float = 2
@export var sprint_speed: float = 5
@export var sensitivity: float = 0.2
@export var respawn_point: Marker3D

@onready var camera: Camera3D = $Camera3D
@onready var main: Node = $".."
@onready var ray_cast: RayCast3D = $RayCast3D
@onready var ray_cast_interact: RayCast3D = $Camera3D/RayCastInteract
@onready var step_sound: AudioStreamPlayer3D = $Step
@onready var health: Node = $Health
@onready var hitbox = $CollisionShape3D
@onready var footsteps = $Step
@onready var choke_sound = $Choke

func _ready() -> void:
	Globals.player = self
	current_speed = walk_speed

func _physics_process(delta: float) -> void:
	handle_movement(delta)
	handle_interact()
	
	if oxygen < 1:
		if choke_sound.playing == false:
			choke_sound.play()
		if hypoxia_timer > 10:
			health.health -= 1
			hypoxia_timer = 0
		else:
			hypoxia_timer += 1
	else:
		if choke_sound.playing == true:
			choke_sound.stop()
	
	if health.health < 1:
		respawn()
	
	#raycast train check
	if ray_cast.get_collider() != null: # on train
		train = ray_cast.get_collider()
		on_train = true
		rotation_degrees.y = player_rotation - train_rotation_delta
	else: # off train
		if on_train:
			on_train = false
			player_rotation -= train_rotation_delta
		
		rotation_degrees.y = player_rotation
		train_rotation_delta = 0
	
	if is_instance_valid(train):
		curr_frame_train_rotation = train.rotation_degrees.y
		train_rotation_delta += prev_frame_train_rotation - curr_frame_train_rotation
		prev_frame_train_rotation = curr_frame_train_rotation
	
	#sound
	if is_on_floor():
		if (abs(velocity.x) > 0.1 or abs(velocity.z) > 0.1):
			if !step_sound.playing:
				step_sound.play()
		else:
			step_sound.stop()

func respawn() -> void:
	health.health = health.max_health
	oxygen = oxygen_max
	global_position = respawn_point.global_position
	Globals.remove_inventory(999, 0)
	Globals.remove_inventory(999, 1)
	Globals.remove_inventory(999, 2)
	Globals.remove_inventory(999, 3)
	Globals.remove_inventory(999, 4)

func handle_movement(delta: float) -> void:
	
	if !is_on_floor():
		velocity.x = player_speed.x
		velocity.z = player_speed.y
		velocity.y -= 0.8
		velocity.x *= 0.95
		velocity.z *= 0.95
		#jump
	else:
		velocity.y = 0
		player_speed.x = velocity.x + get_platform_velocity().x
		player_speed.y = velocity.z + get_platform_velocity().z
		velocity.x *= 0.55
		velocity.z *= 0.55
		if Input.is_action_just_pressed("Jump"):
			velocity.y += 12
	
	if Input.is_action_pressed("Sprint"):
		current_speed = sprint_speed
		footsteps.pitch_scale = 1.2
	else:
		current_speed = walk_speed
		footsteps.pitch_scale = 0.9
	
	if Input.is_action_pressed("Crouch"):
		var tween_hitbox = create_tween()
		tween_hitbox.tween_property(hitbox.shape, "height", 1.2, 0.2)
	elif camera.position.y:
		var tween_hitbox = create_tween()
		tween_hitbox.tween_property(hitbox.shape, "height", 1.8, 0.2)
	
	var input_dir: Vector2 = Input.get_vector("A", "D", "W", "S")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
			velocity.x = direction.x * current_speed * delta * 100
			velocity.z = direction.z * current_speed * delta * 100
	
	move_and_slide()

func handle_interact() -> void:
	# LMB button pressed
	if Input.is_action_just_pressed("Interact"):
		if ray_cast_interact.is_colliding():
			ray_cast_interact.get_collider().interact(true, false)
	
	# RMB button pressed
	elif Input.is_action_just_pressed("interact 2"):
		if ray_cast_interact.is_colliding():
			ray_cast_interact.get_collider().interact(false, true)
	
	# No button pressed
	elif ray_cast_interact.is_colliding() and ray_cast_interact.get_collider() != null:
		ray_cast_interact.get_collider().interact(false, false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera.rotation_degrees.x -= event.relative.y * sensitivity
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -70.0, 50.0)
		
		player_rotation -= event.relative.x * sensitivity
