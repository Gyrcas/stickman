extends Node2D
class_name Stickman

@onready var anim_player : AnimationPlayer = $anim_player

@onready var dust : CPUParticles2D = $left_leg/leg/dust

@onready var blend_timer : Timer = $blend_timer

func _on_anim_player_current_animation_changed(anim_name : String) -> void:
	blend_timer.timeout.emit()
	if anim_name.contains("brake"):
		blend_timer.start(0.2)
		await blend_timer.timeout
		dust.emitting = true
	else:
		dust.emitting = false

func play_animation(player : Player,wall_right : bool) -> void:
	var str_dir : String
	if player.velocity.x:
		str_dir = "right" if player.velocity.x > 0 else "left"
	else:
		str_dir = "right" if player.last_dir > 0 else "left"
	
	if player.sliding_off_edge:
		wall_right = player.close_floor_right_ray.is_colliding()
	
	match player.state:
		player.PlayerState.idle:
			# Blend time is first float on second line
			anim_player.play("idle",
			0.2)
		player.PlayerState.running:
			anim_player.play(str("run_",str_dir),
			0.4, player.velocity.x / player.acceleration * 1.5)
		player.PlayerState.braking:
			anim_player.play(str("brake_",str_dir),
			0.2)
		player.PlayerState.jumping:
			anim_player.play(str("jump_",str_dir),
			0.1)
		player.PlayerState.wall:
			anim_player.play(str("wall_","right" if wall_right else "left"),
			0.2)
		player.PlayerState.falling:
			anim_player.play(str("jump_",str_dir),
			0.2)
		player.PlayerState.sliding:
			anim_player.play(str("slide_",str_dir),
			0.1)
		player.PlayerState.crouching:
			anim_player.play(str("crouch_",str_dir),
			0.2, 2)
		player.PlayerState.crouching_idle:
			anim_player.play(str("crouch_",str_dir,"_idle"),
			0.2, 2)
