extends CharacterBody3D

class_name Controllable

@export_group("Debug")
@export var print_damage_taken: bool
@export var print_visible_by: bool
@export var is_invincible: bool

@export_group("Defense")
@export var health: int = 1
@export var armour: int = 0

enum types {LIGHT, HEAVY, STRUCTURE, NONE}
@export var type: types

@export_group("Offense")
@export var damage: int = 1

enum damage_types {LIGHT, HEAVY, STRUCTURE, NONE}
@export var damage_type: damage_types

@export var attack_speed: float

@export var detection_range: float
@export var attack_range: float

@export_group("General")
@export var name_: String
@export var is_building: bool

enum teams {NEUTRAL, HUMAN, ALIEN}
@export var team: teams

enum sizes {SMALL, MEDIUM, LARGE, HUGE, VEHICLE_DEPOT, FACTORY, BIOMECHPRINTER}
@export var size: sizes
@export var radius_meters: float
@export var sight_range: float
@export var energy_usage: int

@export_group("Build info")
@export var icon: CompressedTexture2D
@export var price: int
@export var build_time: int

enum production_buildings {NONE, VEHICLE_DEPOT, FACTORY, BIOMECHANICAL_PRINTER}
@export var production_location: production_buildings
@export var unlock_requirements: Array[String]

const SELECTION_HUGE = preload("res://UI/3D/Selection Circles/Huge.tscn")
const SELECTION_LARGE = preload("res://UI/3D/Selection Circles/Large.tscn")
const SELECTION_MEDIUM = preload("res://UI/3D/Selection Circles/Medium.tscn")
const SELECTION_SMALL = preload("res://UI/3D/Selection Circles/Small.tscn")

const MOVEMENT_POINTER = preload("res://UI/3D/Movement pointer/MovementPointer.tscn")

const MINIMAP_BLIP = preload("res://UI/2D/Minimap_Blip.tscn")

var selection_circle: MeshInstance3D
var is_selected: bool

var movement_pointer: Node3D

var minimap_blip: Sprite3D

var max_health: int

var kills: int

var visible_by: Array[CharacterBody3D]
var turn_visible: bool

var sight_area: Area3D
var sight_collider: GPUParticlesCollisionSphere3D

func _ready() -> void:
	
	max_health = health
	
	match team:
		0:	add_to_group("Team0")
		1:	add_to_group("Team1")
		2:	add_to_group("Team2")
	
	GeneralVars.getTeamVarList(getTeam()).addToAllUnits(self)
	
	match size:
		0:	selection_circle = SELECTION_SMALL.instantiate()
		1:	selection_circle = SELECTION_MEDIUM.instantiate()
		2:	selection_circle = SELECTION_LARGE.instantiate()
		3:	selection_circle = SELECTION_HUGE.instantiate()
		#vehicle depot and factory special thing
		4:	selection_circle = SELECTION_MEDIUM.instantiate()
		5:	selection_circle = SELECTION_LARGE.instantiate()
		6:	selection_circle = SELECTION_LARGE.instantiate()
	add_child(selection_circle)
	
	#add sight area if not neutral controllable
	if getTeam() != 0:
		sight_area = Area3D.new()
		var shape = CollisionShape3D.new()
		shape.shape = CylinderShape3D.new()
		add_child(sight_area)
		sight_area.add_child(shape)
		sight_area.collision_mask = 28
		sight_area.collision_layer = 0
		sight_area.get_child(0).shape.radius = sight_range
		sight_area.get_child(0).shape.height = 10
		sight_area.body_entered.connect(sightAreaEntered)
		sight_area.area_entered.connect(sightAreaEntered)
		sight_area.body_exited.connect(sightAreaExited)
		sight_area.area_exited.connect(sightAreaExited)
		
		if getTeam() == 1:
			sight_collider = GPUParticlesCollisionSphere3D.new()
			add_child(sight_collider)
			sight_collider.radius = sight_range
			sight_collider.layers = 2
			sight_collider.cull_mask = 2
	
	#if enemy turn invisible on creation
	if getTeam() == 2:
		turn_visible = false
		visible = false
	
	#movement pointer
	movement_pointer = MOVEMENT_POINTER.instantiate()
	movement_pointer.initialize(self)
	await get_tree().create_timer(0.05).timeout
	get_tree().root.add_child(movement_pointer)
	
	#Minimap Blip
	if getTeam() != 0:
		minimap_blip = MINIMAP_BLIP.instantiate()
		add_child(minimap_blip)
		minimap_blip.position.y += 400
		
		if getTeam() == 1:
			minimap_blip.modulate = Color.LAWN_GREEN
		elif getTeam() == 2:
			minimap_blip.modulate = Color.CRIMSON
	
	#Energy usage
	GeneralVars.getTeamVarList(getTeam()).changeCurrentEnergyUsage(energy_usage)

func _process(_delta: float) -> void:
	if !GeneralVars.getPaused():
		if selection_circle != null:
			if is_selected:
				selection_circle.set_visible(true)
			else:
				selection_circle.set_visible(false)
		
		#visibility
		if getTeam() == 2:
			if getVisibleBy().is_empty() and turn_visible == true:
				turn_visible = false
				visible = false
			elif !getVisibleBy().is_empty():
				turn_visible = true
				visible = true
		
		if health <= 0:
			die()
		
		if print_visible_by:
			print(getVisibleBy())

func smoothTurn(look_pos: Vector3, target_node: Node, rot_speed: float = 0.1) -> void:
	if look_pos.distance_to(target_node.global_position) > 0.01:
		var rot = target_node.global_transform
		var rot_quat = Quaternion(target_node.global_transform.basis.orthonormalized())
		target_node.look_at(look_pos, Vector3.UP)
		var target_rot = Quaternion(target_node.global_transform.basis.orthonormalized())
		target_node.global_transform = rot
		var final_rot = rot_quat.slerp(target_rot, rot_speed)
		
		target_node.global_transform.basis = Basis(final_rot)

func sightAreaEntered(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_method("getTeam") and body.getTeam() != getTeam():
		body.appendVisibleBy(self)
		
func sightAreaExited(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_method("getTeam") and body.getTeam() != getTeam():
		body.eraseVisibleBy(self)

func setIsSelected(b: bool) -> void:	is_selected = b
func getIsSelected() -> bool:	return is_selected

func setName(i: String):	name_ = i
func getName() -> String:	return name_

func setHealth(i: int) -> void:	health = i
func getHealth() -> int:	return health
func setMaxHealth(i: int) -> void:	max_health = i
func getMaxHealth() -> int:	return max_health
func reduceHealth(damage_: int, damage_type_: int, _shooter_: CharacterBody3D) -> bool:
	#flat damage reduction
	damage_ -= armour
	damage_ = clamp(damage_, 0, 9999)
	
	#1.5x damage if damage type matches unit type
	#0 = LIGHT, 1 = HEAVY, 2 = STRUCTURE, 3 = NONE
	if damage_type_ == type:
		damage_ *= 1.5
	
	if is_invincible:
		damage_ = 0
	
	health -= damage_
	
	if print_damage_taken:
		print("\nHit " + str(self) + " for " + str(damage_) + "\n")
	
	#Return true if attack did damage
	if damage_ > 0:
		return true
	return false

func die() -> void:
	GeneralVars.getTeamVarList(getTeam()).removeFromAllUnits(self)
	GeneralVars.getTeamVarList(getTeam()).removeFromSelectedUnits(self)
	GeneralVars.getTeamVarList(getTeam()).changeCurrentEnergyUsage(-energy_usage)
	queue_free()

func getVisibleBy() -> Array: return visible_by
func appendVisibleBy(i: CharacterBody3D) -> void: visible_by.append(i)
func eraseVisibleBy(i: CharacterBody3D) -> void: if visible_by.has(i): visible_by.erase(i)
func getDamage() -> int:	return damage
func setDamage(i: int) -> void:	damage = i
func getKills() -> int:	return kills
func setKills(i: int) -> void:	kills = i
func getArmour() -> int:	return armour
func setArmour(i: int) -> void:	armour = i
func getType() -> int:	return type
func setType(i: int) -> void:	type = i as types
func getDamageType() -> int:	return damage_type
func setDamageType(i: int) -> void:	damage_type = i as damage_types
func getIsBuilding() -> bool:	return is_building
func setIsBuilding(i: bool) -> void:	is_building = i
func getIsInvincible() -> int:	return is_invincible
func setIsInvincible(i: bool) -> void:	is_invincible = i
func getTeam() -> int:	return team
func setTeam(i: int) -> void:	team = i as teams
func getSize() -> int:	return size
func setSize(i: int) -> void:	size = i as sizes
func getRadius() -> float:	return radius_meters
func setRadius(i: int) -> void:	radius_meters = i
func getIcon() -> CompressedTexture2D: return icon
func getPrice() -> int:	return price
func setPrice(i: int) -> void:	price = i
func getBuildTime() -> int:	return build_time
func setBuildTime(i: int) -> void:	build_time = i
func getProductionLocation() -> int:	return production_location
func setProductionLocation(i: int) -> void:	production_location = i as production_buildings
func getUnlockRequirements() -> Array[String]:	return unlock_requirements
func setUnlockRequirements(i: Array[String]) -> void:	unlock_requirements = i
func getMovementPointer() -> Node3D:	return movement_pointer
func setMovementPointer(i: Node3D):	movement_pointer = i
func getEnergyUsage() -> int: return energy_usage
func setEnergyUsage(i: int) -> void: energy_usage = i
