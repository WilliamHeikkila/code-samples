extends Controllable

class_name Unit

@export_group("Debug")
@export var print_state: bool
@export var print_attack_override: bool
@export var print_detected_targets: bool
@export var print_current_target: bool

@export_group("Movement")
@export var move_speed: float
@export var rotation_speed: float

var current_target: CharacterBody3D
var target_position: Vector3
var saved_target_position: Vector3
var detected_targets: Array[CharacterBody3D]
var can_move: bool = false

enum {IDLE, MOVE, ATTACKMOVE}
var state: int
var attack_moving: bool

var detection_area: Area3D
var nav_agent: NavigationAgent3D
var update_interval: int = 5
var update_interval_curr: int = 0

const GRAVITY: int = 10

func _ready() -> void:
	super._ready()
	SignalManager.update_pathing.connect(makePath)
	
	detection_area = Area3D.new()
	var shape = CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	add_child(detection_area)
	detection_area.add_child(shape)
	detection_area.collision_mask = 12
	detection_area.collision_layer = 0
	detection_area.get_child(0).shape.radius = detection_range
	detection_area.get_child(0).shape.height = 10
	detection_area.body_entered.connect(detectionAreaEntered)
	detection_area.body_exited.connect(detectionAreaExited)
	
	nav_agent = get_node("NavigationAgent3D")
	if nav_agent == null:
		print("nav agent not found in " + str(self))
	else:
		nav_agent.velocity_computed.connect(safeMoveUnit)
	
	target_position = global_position

func _physics_process(delta: float) -> void:
	if !GeneralVars.getPaused():
		super._process(delta)
		can_move = false
		
		if current_target != null:
			target_position = current_target.global_position
		
		update_interval_curr += 1
		if Settings.low_end_cpu:
			update_interval = 10
		else:
			update_interval = 5
		
		stateMachine()
		
		if print_state:
			print(getState())
		if print_current_target:
			print(getCurrentTarget())

func stateMachine() -> void:
	match state:
		IDLE:
			idleState()
		MOVE:
			moveState()
		ATTACKMOVE:
			attackMoveState()

func idleState() -> void:
	velocity = Vector3.ZERO
	target_position = global_position
	attack_moving = false
	if print_detected_targets:
		print(detected_targets)
	
	if !detected_targets.is_empty():
		setCurrentTarget(detected_targets[0])
		setState(ATTACKMOVE)
		
func moveState() -> void:
	moveUnit()
	attack_moving = false
	if global_position.distance_to(target_position) < 1.1:
		setState(IDLE)

func attackMoveState() -> void:
	if getCurrentTarget() != null or attack_moving:
		#out of range
		if getCurrentTarget() != null and global_position.distance_to(target_position) - getCurrentTarget().getRadius() - getRadius() > attack_range:
			moveUnit()
		#no target
		elif getCurrentTarget() == null:
			if !detected_targets.is_empty():
				setCurrentTarget(detected_targets[0])
				
				#save original target pos for later reference
				saved_target_position = target_position
			
			#put it back?
			elif global_position.distance_to(target_position) < 1.1:
				
				if target_position != saved_target_position:
					target_position = saved_target_position
			
			if global_position.distance_to(target_position) < 1.1:
				setState(IDLE)
			else:
				moveUnit()
		#in range
		else:
			attack(current_target)
	else:
		setState(IDLE)

func attack(_unit: CharacterBody3D) -> void:
	if print_attack_override:
		print("Attack should be overwritten")
		print(self)

func reduceHealth(damage_: int, damage_type_: int, origin_: CharacterBody3D) -> bool:
	var result: bool = super.reduceHealth(damage_, damage_type_, origin_)
	#return fire 
	if getState() == IDLE and global_position.distance_to(origin_.global_position) <= sight_range:
		forceSetCurrentTarget(origin_)
		setState(ATTACKMOVE)
	return result

func detectionAreaEntered(body: Node3D) -> void:
	#check if body is a enemy
	if body is CharacterBody3D and body.has_method("getTeam") and body.getTeam() != getTeam() and body.getTeam() != 0:
		detected_targets.append(body)

func detectionAreaExited(body: Node3D) -> void:
	#check if body is a enemy
	if body is CharacterBody3D and body.has_method("getTeam") and body.getTeam() != getTeam() and body.getTeam() != 0:
		detected_targets.erase(body)
		if current_target == body:
			current_target = null

func moveUnit() -> void:
	can_move = true
	var current_location = global_transform.origin
	var next_location: Vector3 = Vector3.ZERO
	if update_interval_curr >= update_interval:
		update_interval_curr = 0
		next_location = nav_agent.get_next_path_position()
	
	var new_velocity: Vector3 = Vector3.ZERO
	if next_location != Vector3.ZERO:
		new_velocity = (next_location - current_location)
	
	#nav_agent.set_avoidance_enabled(true)
	if new_velocity != Vector3.ZERO:
		nav_agent.set_velocity(new_velocity)

func safeMoveUnit(safe_velocity: Vector3) -> void:
	if can_move and !GeneralVars.getPaused():
		var global_vel = global_position + safe_velocity
		smoothTurn(Vector3(global_vel.x, global_position.y, global_vel.z), self, rotation_speed)
		#velocity = Vector3(safe_velocity.normalized().x, 0, safe_velocity.normalized().z) * move_speed
		
		#slow down if no power and player team
		var actual_move_speed := move_speed
		if GeneralVars.getTeamVarList(getTeam()).getCurrentEnergyUsage() > GeneralVars.getTeamVarList(getTeam()).getMaxEnergyUsage() and getTeam() == 1:
			actual_move_speed *= 0.5
		
		velocity = global_position - to_global(Vector3.FORWARD * -actual_move_speed)
		
		#keep unit on floor
		if !is_on_floor():
			velocity.y -= GRAVITY
		else:
			velocity.y = 0
		
		if global_position.y < -0.5:
			global_position.y = 1
		
		move_and_slide()

func makePath() -> void:
	nav_agent.set_target_position(target_position)

func setTargetPosition(pos: Vector3) -> void: target_position = pos
func getTargetPosition() -> Vector3: return target_position
func setSavedTargetPosition(pos: Vector3) -> void: saved_target_position = pos
func getSavedTargetPosition() -> Vector3: return saved_target_position
func setCurrentTarget(unit: CharacterBody3D) -> void: 
	if unit != null and !unit.getVisibleBy().is_empty():
		current_target = unit
func forceSetCurrentTarget(unit: CharacterBody3D) -> void: current_target = unit
func getCurrentTarget() -> CharacterBody3D: return current_target
func addToDetectedTarget(unit: CharacterBody3D) -> void: detected_targets.append(unit)
func RemoveFromDetectedTarget(unit: CharacterBody3D) -> void: detected_targets.erase(unit)
func getDetectedTargets() -> Array[CharacterBody3D]: return detected_targets
func clearDetectedTargets() -> void: detected_targets.clear()
func setState(i: int) -> void: state = i
func getState() -> int: return state
func setAttackMoving(i: bool) -> void: attack_moving = i
func getAttackMoving() -> bool: return attack_moving
