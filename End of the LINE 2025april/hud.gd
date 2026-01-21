extends Control

const MAIN_MENU = preload("res://main_menu.tscn")

@onready var texture_progress_bar_health: TextureProgressBar = %TextureProgressBarHealth
@onready var texture_progress_bar_oxygen: TextureProgressBar = %TextureProgressBarOxygen

@onready var pause_main: Panel = %PauseMain
@onready var pause_menu: HBoxContainer = %PauseMenu
@onready var options_menu: HBoxContainer = %OptionsMenu

@onready var slot_1: TextureRect = %TextureRect1
@onready var slot_2: TextureRect = %TextureRect2
@onready var slot_3: TextureRect = %TextureRect3
@onready var slot_4: TextureRect = %TextureRect4
@onready var slot_5: TextureRect = %TextureRect5
@onready var money : Label = %Money
@onready var hurt : TextureRect = $Hurt

@onready var slider_sensitivity: HSlider = %HSliderSensitivity
@onready var slider_sound_master: HSlider = %HSliderSoundMaster
@onready var slider_sound_sfx: HSlider = %HSliderSoundSFX
@onready var slider_sound_music: HSlider = %HSliderSoundMusic

var ray_cast_interact: RayCast3D


func _ready() -> void:
	Globals.inventory_changed.connect(inventory_update)
	Globals.player_hurt.connect(hurt_effect)
	await get_tree().create_timer(0.1).timeout
	ray_cast_interact = Globals.player.ray_cast_interact
	inventory_update()
	unpause_game()

func _physics_process(_delta: float) -> void:
	if is_instance_valid(Globals.player):
		texture_progress_bar_health.value = Globals.player.find_child("Health").health
		texture_progress_bar_oxygen.value = Globals.player.oxygen / Globals.player.oxygen_max
	money.text = str(Globals.money)+"$"
	
	if Input.is_action_just_pressed("Pause"):
		if !pause_main.visible:
			pause_game()
		else:
			unpause_game()

# :)
func inventory_update() -> void:
	slot_1.get_child(1).text = ""
	slot_2.get_child(1).text = ""
	slot_3.get_child(1).text = ""
	slot_4.get_child(1).text = ""
	slot_5.get_child(1).text = ""
	
	slot_1.get_child(0).texture = Globals.get_inventory_slot(0).texture
	if Globals.get_inventory_slot(0).amount > 0:
		slot_1.get_child(1).text = str(Globals.get_inventory_slot(0).amount)
	slot_2.get_child(0).texture = Globals.get_inventory_slot(1).texture
	if Globals.get_inventory_slot(1).amount > 0:
		slot_2.get_child(1).text = str(Globals.get_inventory_slot(1).amount)
	slot_3.get_child(0).texture = Globals.get_inventory_slot(2).texture
	if Globals.get_inventory_slot(2).amount > 0:
		slot_3.get_child(1).text = str(Globals.get_inventory_slot(2).amount)
	slot_4.get_child(0).texture = Globals.get_inventory_slot(3).texture
	if Globals.get_inventory_slot(3).amount > 0:
		slot_4.get_child(1).text = str(Globals.get_inventory_slot(3).amount)
	slot_5.get_child(0).texture = Globals.get_inventory_slot(4).texture
	if Globals.get_inventory_slot(4).amount > 0:
		slot_5.get_child(1).text = str(Globals.get_inventory_slot(4).amount)

func pause_game() -> void:
	get_tree().paused = true
	hide_all_pause_menu()
	pause_main.visible = true
	pause_menu.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func unpause_game() -> void:
	get_tree().paused = false
	pause_main.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func hide_all_pause_menu() -> void:
	pause_menu.visible = false
	options_menu.visible = false

##PAUSE MAIN
func resume_button() -> void:
	unpause_game()

func options_button() -> void:
	hide_all_pause_menu()
	options_menu.visible = true
	update_sliders()

func back_to_menu() -> void:
	var ins = MAIN_MENU.instantiate()
	
	get_tree().root.get_node("Main").add_child(ins)
	get_tree().root.get_node("Main").get_node("World").queue_free()

##PAUSE OPTIONS
func change_sensitivity(val: float) -> void:
	Globals.sensitivity = val

func change_sound_master(val: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(val))

func change_sound_sfx(val: float) -> void:
	AudioServer.set_bus_volume_db(1, linear_to_db(val))

func change_sound_music(val: float) -> void:
	AudioServer.set_bus_volume_db(2, linear_to_db(val))

func update_sliders() -> void:
	slider_sensitivity.value = Globals.sensitivity
	slider_sound_master.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	slider_sound_sfx.value = db_to_linear(AudioServer.get_bus_volume_db(1))
	slider_sound_music.value = db_to_linear(AudioServer.get_bus_volume_db(2))

func options_back() -> void:
	hide_all_pause_menu()
	pause_menu.visible = true
func hurt_effect() -> void:
	print("HURT")
	hurt.get_child(0).play("play")
