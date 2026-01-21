extends CharacterBody3D
class_name Agent

const AGENT_SHADOW = preload("res://scenes/agents/agent_shadow.tscn")
const ANIMATIONHANDLER_SCRIPT = preload("res://scripts/animation_handler.gd")

const GRAVITY = 1
const HUMAN = 0
const INFECTED = 1
const default_infected = preload("res://scenes/agents/dev_agent_infected.tscn")

# Used when marked "dead" and globals is searching new zombie to control
var despawn_flag : bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export_category("Base Stats")
@export var unit_radius : float = 0.7
@export var speed: float
@export var max_health: int
@export var exp_gain: int
##Put all states for agent to use here. Default state is first in list
@export var states: Array[Script]
@export_category("Combat")
@export var detection_radius: float
@export var aggressive: bool
@export var damage: int
@export var min_attack_range: float = 0.0
@export var attack_range: float 
@export var attack_speed: float
@export var death_wait_time: float = 5
@export_enum("Human", "Infected") var team: int
@export var weapon: Weapon
@export var infected_version: PackedScene
@export_enum("no", "spitter", "bomber", "tank") var special_infected : String = "no"
@export_category("misc")
@export var has_animations: bool
@export_category("Debug")
@export var debug: bool
@export var player_controlled: bool:
	set(val):
		player_controlled = val
		if !val and is_instance_valid(current_state) and current_state.name == "PlayerControl":
			change_state("Idle")

#Automatically clamp health
var health: int:
	set(val):
		if debug:
			print(name + "got damaged for: " + str(val))
		health = clampi(val, 0, max_health)

var target: Agent
#Target and target_position are different so we can move to specific nodes and to Vec3:s
var target_position: Vector3

var current_state: State
var current_speed: float
var update_tick: int
var upgrades: Array[Upgrade]
var has_been_infected: bool

var nav_agent: NavigationAgent3D
var detection_area: Area3D
var visibility_checker: VisibleOnScreenNotifier3D
var animation_handler: AnimationHandler

func _ready() -> void:
	
	#Setup agent
	collision_layer = 2
	collision_mask = 1
	health = max_health
	current_speed = speed
	match team:
		HUMAN:		add_to_group("Human")
		INFECTED:	add_to_group("Infected")
	
	#Agent shadow
	var ins = AGENT_SHADOW.instantiate()
	add_child(ins)
	
	#pathfinding update tick assigning
	update_tick = Globals.path_finding_id % Globals.path_finding_spilt_rate
	Globals.path_finding_id += 1
	
	#Setup state machine
	var default_set: bool = false
	for state in states:
		var state_node: Node = Node.new()
		state_node.set_script(state)
		add_child(state_node)
		state_node.name = state.get_global_name()
		#Default state is first in list
		if !default_set:
			default_set = true
			change_state(state_node.name)
	
	#Setup detection area
	detection_area = Area3D.new()
	var detection_collision_area: CollisionShape3D = CollisionShape3D.new()
	var detection_shape: CylinderShape3D = CylinderShape3D.new()
	add_child(detection_area)
	detection_area.add_child(detection_collision_area)
	detection_collision_area.shape = detection_shape
	detection_shape.radius = detection_radius
	detection_shape.height = 10
	
	detection_area.collision_layer = 0
	detection_area.collision_mask = 2
	
	detection_area.body_exited.connect(detection_area_exited)
	detection_area.body_entered.connect(detection_area_entered)
	
	#Setup navigation agent
	nav_agent = NavigationAgent3D.new()
	add_child(nav_agent)
	
	#Setup visibility checker
	visibility_checker = VisibleOnScreenNotifier3D.new()
	add_child(visibility_checker)
	
	#Setup gun raycast
	if is_instance_valid(weapon):
		var ray = RayCast3D.new()
		add_child(ray)
		ray.collision_mask = 3
		ray.name = "GunRayCast"
		ray.position.y = 1.4
	
	#Setup animationhandler
	var temp = Node.new()
	temp.set_script(ANIMATIONHANDLER_SCRIPT)
	animation_handler = temp
	add_child(animation_handler)
	
	if debug:
		nav_agent.debug_enabled = true

func _physics_process(delta: float) -> void:
	apply_gravity()
	run_continous_upgrades()
	
	#State machine
	if current_state and !despawn_flag:
		current_state.run(delta)
	#Player override
	if player_controlled and is_instance_valid(current_state) and current_state.name != "PlayerControl":
		print("aaa")
		change_state("PlayerControl")
	
	if health == 0 and despawn_flag == false:
		die()

func change_state(state_name: String) -> void:
	if current_state:
		current_state.exit_state()
	current_state = get_node(state_name)
	if current_state:
		current_state.enter_state(self)
		if debug:
			print(name + "enters: " + current_state.name)
	else:
		printerr(state_name + " not found")

func apply_gravity() -> void:
	if !is_on_floor():
		velocity.y -= GRAVITY
	else:
		velocity.y = 0

##Use target position to move to Vec3 instead of Node3D
func update_target_position(use_target_node_position: bool) -> void:
	if use_target_node_position and is_instance_valid(target):
		nav_agent.target_position = target.global_position
	else:
		nav_agent.target_position = target_position

#Call every frame to move towards target position
func move_toward_nav_target_position(delta: float, update_asap: bool = false) -> void:
	#Only run if the global path finding tick is on the same one as agents
	if Globals.path_finding_update_tick % Globals.path_finding_spilt_rate == update_tick or update_asap:
		tick_nav_agent_update(delta)
		if visibility_checker.is_on_screen() and !global_position.is_equal_approx(global_position + velocity):
			look_at(global_position + velocity)
	move_and_slide()

func tick_nav_agent_update(delta: float) -> void:
	var next_position: Vector3 = nav_agent.get_next_path_position()
	#remove y component
	next_position.y = 0
	var next_velocity: Vector3 = (next_position - global_position).normalized()
	velocity = next_velocity * current_speed * delta
	#remove it again idk man shits fucked
	velocity.y = 0


# Melee attack
func attack() -> void:
	if team == 0:
		animation_handler.play_animation("Attack Human")
	else:
		animation_handler.play_animation("Attack Infected")
	if target != null and target is Agent:
		target.has_been_infected = true
		target.health -= damage


func become_infected() -> void:
	change_state("Idle")
	# Infected animation
	if has_animations:
		animation_handler.play_animation("Infect")
		await animation_player.animation_finished
	# If special unit get chanse to become special unit, else become default infected
	var spawn_chanse : float = 0.0
	if special_infected != "no":
		match special_infected:
			"spitter" : spawn_chanse = Globals.spitter_unlocked
			"bomber" : spawn_chanse = Globals.suicide_unlocked
			"tank" : spawn_chanse = Globals.tank_unlocked
		var rng = randf_range(0, 1)
		if rng > spawn_chanse:
			print("default infected")
			infected_version = default_infected
	# Change to infected
	AgentFactory.create_agent(infected_version, global_position, global_rotation)
	UpgradeManager.gain_experience(exp_gain)
	queue_free()


func die() -> void:
	change_state("Idle")
	animation_handler.stop_animation() # Force stop animations to prevent immortality
	if team == HUMAN:
		# Despawn logic
		if despawn_flag == false:
			despawn_flag = true
			if has_been_infected:
				become_infected()
				Globals.update_unit_count(-1, 1) # -1 infected
				
			else:
				Globals.update_unit_count(-1, 0) # -1 infected
				dead()
			
	else:
		# Despawn logic
		if despawn_flag == false:
			despawn_flag = true
			# Find new infected and remove this one
			if player_controlled:
				Globals.find_new_zombie()
			Globals.update_unit_count(0, -1) # -1 infected
			dead()

func dead():
	animation_handler.play_animation("Die")
	await get_tree().create_timer(death_wait_time).timeout
	queue_free()


func aquire_target(body: Node3D) -> void:
	if is_instance_valid(body):
		if team == HUMAN and body.is_in_group("Infected"):
			target = body
		if team == INFECTED and body.is_in_group("Human"):
			target = body

func detection_area_entered(body: Node3D) -> void:
	if team == HUMAN and !is_instance_valid(target) and body.team == INFECTED:
		target = body

func detection_area_exited(body: Node3D) -> void:
	if is_instance_valid(body) and body == target:
		target = null
		#Get new target if any exists in detection area
		if detection_area.has_overlapping_bodies():
			aquire_target(Globals.get_closest_agent_in_array(self, detection_area.get_overlapping_bodies()))



func run_continous_upgrades() -> void:
	for upgrade in upgrades:
		upgrade.continous_upgrade()

func add_upgrade(upgrade: Upgrade) -> void:
	upgrade.upgrade(self)
	upgrades.append(upgrade)
