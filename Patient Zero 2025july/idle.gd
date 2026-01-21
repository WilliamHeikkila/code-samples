extends State
class_name Idle

var started_wander_timer: bool

func enter_state(agent_node: Agent) -> void:
	super.enter_state(agent_node)

func exit_state() -> void:
	pass

func run(_delta: float) -> void:
	agent.animation_handler.play_animation("Idle")
	#Get new target if has no target
	if !is_instance_valid(agent.target) and agent.detection_area.has_overlapping_bodies():
		agent.aquire_target(Globals.get_closest_agent_in_array(agent, agent.detection_area.get_overlapping_bodies()))
	
	
	if is_instance_valid(agent.target):
		if agent.aggressive:
			agent.change_state("Approach")
		else:
			agent.change_state("Flee")
	elif !started_wander_timer:
		started_wander_timer = true
		await get_tree().create_timer(randf_range(1,4)).timeout
		started_wander_timer = false
		if agent.current_state == self:
			agent.change_state("Wander")
