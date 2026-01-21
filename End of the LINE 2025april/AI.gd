extends CharacterBody3D


@export var on_train: bool
@export var speed: float
@export var attack_interval: float
@export var attack_range: float
@export var damage: int
@export var detection_area_radius: float
@export var must_see_to_aggro: bool
@export var model: Node3D

@export var print_shit: bool

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var detection_area_enter: Area3D = $DetectionAreaEnter
@onready var detection_area_exit: Area3D = $DetectionAreaExit
@onready var vision_ray: RayCast3D = $VisionRay
@onready var step_sound: AudioStreamPlayer3D = $Step

var target: CharacterBody3D
var base_position: Vector3
var state: STATES
var on_cooldown: bool
var target_in_sight: bool

var being_attacked: bool

var attack_node: Node3D

enum STATES {
	IDLE,
	RTB,
	APPROACH,
	ATTACK
}

func _ready() -> void:
	detection_area_enter.get_child(0).shape.radius = detection_area_radius
	detection_area_exit.get_child(0).shape.radius = detection_area_radius * 1.5
	base_position = global_position
	
	attack_node = find_child("Attack")
	if attack_node == null:
		printerr(str(self) + " Bro forgot to add the attack node💀")

func _physics_process(_delta: float) -> void:
	
	if !is_on_floor():
		velocity.y -= 5
		move_and_slide()
	
	state_manager()
	check_vision()
	check_detection_areas()
	
	#sound
	if is_on_floor():
		if (abs(velocity.x) > 0.1 or abs(velocity.z) > 0.1):
			if !step_sound.playing:
				step_sound.play()
		else:
			step_sound.stop()

func move_to_target_position() -> void:
	if is_instance_valid(target):
		nav_agent.target_position = target.global_position
	
	var current_location = global_position
	var next_location = nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * speed
	
	nav_agent.set_velocity(new_velocity)
	
	rotate_towards_player()
	move_and_slide()

func rotate_towards_player() -> void:
	if is_instance_valid(target):
		model.look_at(Vector3(target.global_position.x,model.global_position.y,target.global_position.z), Vector3.UP)
	else:
		var next_positon = nav_agent.get_next_path_position()
		model.look_at(Vector3(next_positon.x,model.global_position.y,next_positon.z), Vector3.UP)
func state_manager() -> void:
	match state:
		STATES.IDLE: idle()
		STATES.RTB: return_to_base()
		STATES.APPROACH: approach()
		STATES.ATTACK: attack()

func idle() -> void:
	if target != null:#target detected
		if nav_agent.is_target_reachable():#target is reachable
			if !on_train:
				state = STATES.APPROACH
		if target.global_position.distance_to(global_position) < attack_range:
			state = STATES.ATTACK
		if !nav_agent.is_target_reachable():#target is not reachable
			if !on_train:
				state = STATES.RTB
		
	
	#Behavior

func return_to_base() -> void:
	if base_position.distance_to(global_position) < 5:
		state = STATES.IDLE
	if target != null and nav_agent.is_target_reachable():
		if !on_train:
			state = STATES.APPROACH
	
	#Behavior
	nav_agent.target_position = base_position
	move_to_target_position()

func approach() -> void:
	if target == null or !nav_agent.is_target_reachable():#no target or cant reach target
		if !on_train:
			state = STATES.RTB
			return
	elif target.global_position.distance_to(global_position) < attack_range:#has target and can reach it and is in range of target
		state = STATES.ATTACK
	
	#Behavior
	if target_in_sight:
		nav_agent.target_position = target.global_position
		move_to_target_position()

func attack() -> void:
	if target != null and target.global_position.distance_to(global_position) > attack_range:#has target and target is outside attack range
		if !on_train:
			state = STATES.APPROACH
			return
	if !nav_agent.is_target_reachable():#cant reach target
		if !on_train:
			state = STATES.RTB
			return
	if on_train and is_instance_valid(target) and target.global_position.distance_to(global_position) > attack_range:
		state = STATES.IDLE
		return
	
	#Behavior
	rotate_towards_player()
	nav_agent.target_position = global_position
	if !on_cooldown and target_in_sight:
		if print_shit:
			print("123")
		attack_node.attack(target, damage)
		
		on_cooldown = true
		await get_tree().create_timer(attack_interval).timeout
		on_cooldown = false

func check_detection_areas() -> void:
	if !detection_area_enter.get_overlapping_bodies().is_empty():
		target = detection_area_enter.get_overlapping_bodies()[0]
		being_attacked = false
		if !must_see_to_aggro:
			target_in_sight = true
	
	elif detection_area_exit.get_overlapping_bodies().is_empty():
		if !being_attacked:
			target = null
			target_in_sight = false

func check_vision() -> void:
	if is_instance_valid(target):
		vision_ray.target_position = target.global_position - global_position
		if vision_ray.is_colliding() and vision_ray.get_collider() is CharacterBody3D and must_see_to_aggro:
			target_in_sight = true

func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
