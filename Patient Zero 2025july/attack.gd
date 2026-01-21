extends State
class_name Attack

var attacked: bool = false

func enter_state(agent_node: Agent) -> void:
	super.enter_state(agent_node)
	agent.animation_player.speed_scale = agent.attack_speed

func exit_state() -> void:
	agent.animation_player.speed_scale = 1

func run(_delta: float) -> void:
	if agent.weapon:
		has_weapon()
	else:
		no_weapon()

func state_change() -> void:
	if agent is MilitaryAgent:
		match agent.behaviour:
			0:	
				agent.change_state("Guard")
			1:	agent.change_state("Patrol")
	else:
		agent.change_state("Approach")

func no_weapon() -> void:
	if is_instance_valid(agent.target) and !attacked:
		attacked = true
		agent.attack()
		await agent.animation_player.animation_finished
		attacked = false
		state_change()
	if !attacked:
		state_change()

func has_weapon() -> void:
	if is_instance_valid(agent.target) and agent.weapon.ready_to_fire:
		agent.look_at(agent.target.global_position)
		agent.weapon.shoot()
		if agent.has_animations:
			await agent.animation_player.animation_finished
		if !agent.weapon.ready_to_fire:
			state_change()
