extends CharacterBody2D
class_name Player

enum PlayerState {
	idle,
	running,
	braking,
	jumping,
	falling,
	sliding,
	crouching,
	crouching_idle,
	wall,
	attack
}

@onready var model : Stickman = $model

@onready var camera : Camera2D = $camera

@onready var jump_particle : CPUParticles2D = $jump_particle

@onready var left_wall_rays : Node2D = $left_wall_rays

@onready var right_wall_rays : Node2D = $right_wall_rays

@onready var no_fall_ray : RayCast2D = $no_fall_ray

@onready var ray_roof_uncrouch : RayCast2D = $ray_roof_uncrouch

@onready var speed_particles : CPUParticles2D = $speed_particle

@onready var ray_ledge_left : RayCast2D = $ledge_left

@onready var ray_ledge_right : RayCast2D = $ledge_right

@onready var col : CollisionShape2D = $col

@onready var col_shape : RectangleShape2D = $col.shape

@onready var close_floor_left_ray : RayCast2D = $no_fall_ray/close_left

@onready var close_floor_right_ray : RayCast2D = $no_fall_ray/close_right

@onready var sliding_particle : CPUParticles2D = $sliding_particle

#------------------------------------------

@export var acceleration : float = 800

@export var friction : float = 1000

@export var max_speed : float = 1000

@export var min_speed_run : float = 500

#---------------------------------------------

@export var jump_force : float = 1000

@export var gravity : float = 2000

@export var gravity_div_wall : float = 4

@export var min_speed_slide : float = 700

#--------------------------------------------

@export var max_camera_offset : float = 200

@export var camera_range : Vector2 = Vector2(375,375)

var state : PlayerState = PlayerState.idle

var last_state : PlayerState = state

var last_dir : float = 0

var is_sliding : bool = false

var is_crouching : bool = false

## Prevent uncrouching if roof is blocking it
var can_uncrouch : bool = true

## Make the fall faster and allows to ungrab ledges
var faster_fall_slide : bool = false

var sliding_off_edge : bool = false

var velocity_x_on_slide_off : float = 0

signal uncrouch

func is_children_ray_colliding(parent : Node) -> bool:
	var i : int = 0
	for ray in parent.get_children():
		# Second condition prevent the code from tinking it's on wall while transition to slide
		if ray.is_colliding() && (i < 2 || !(is_crouching || is_sliding)):
			return true
		i += 1
	return false

func _ready() -> void:
	for ray in left_wall_rays.get_children():
		ray.add_exception(self)
	for ray in right_wall_rays.get_children():
		ray.add_exception(self)

func is_sliding_off_edge() -> bool:
	return (
		!faster_fall_slide && 
		(is_sliding || is_crouching) && 
		!no_fall_ray.is_colliding() &&
		(close_floor_left_ray.is_colliding() || close_floor_right_ray.is_colliding()) &&
		!Input.is_action_pressed("jump")
	)

var was_on_floor : bool = false

func _physics_process(delta : float) -> void:
	# Bug velocity when jumping off wall with roofon head come from ray detecting wall but not roof while jumping
	var on_floor : bool = no_fall_ray.is_colliding()
	
	if on_floor != was_on_floor:
		was_on_floor = on_floor
		change_stance_height()
	
	if on_floor:
		sliding_off_edge = false
		faster_fall_slide = false
	
	var dir : float = Input.get_axis("left","right")
	
	if dir:
		last_dir = dir
	
	if is_sliding && abs(velocity.x) < 400:
		is_sliding = false
		is_crouching = true
		change_stance_height()
	
	if is_running(dir):
		run(dir,delta, on_floor)
	elif velocity.x != 0:
		apply_friction(dir,delta,on_floor)
	else:
		state = PlayerState.idle
	
	sliding_particle.emitting = false
	
	if on_floor:
		crouch_state(dir)
	elif is_sliding_off_edge() && velocity.y >= 0:
		if !sliding_off_edge:
			velocity_x_on_slide_off = velocity.x
		sliding_off_edge = true
		#Check if distance from ledge is greater than width, and if so, apply velocity to prevent flying off ledge
		if close_floor_right_ray.is_colliding():
			if (close_floor_right_ray.get_collision_point().x - global_position.x) > (col.shape.size.x / 2):
				velocity.x = 100
		elif (global_position.x - close_floor_left_ray.get_collision_point().x) > (col.shape.size.x / 2):
			velocity.x = -100
	
	if velocity.y < 0:
		sliding_off_edge = false
	
	var wall_right : bool = gravity_movement(delta, on_floor, dir)
	
	move_and_slide()
	
	if sliding_off_edge:
		state = PlayerState.wall
	elif PlayerState.idle == state && is_crouching:
		state = PlayerState.crouching_idle
	
	#print(PlayerState.keys()[state])
	
	model.play_animation(self,wall_right)
	
	last_state = state
	
	camera.offset = camera.offset.lerp(velocity.clamp(-camera_range,camera_range),delta)

func run(dir : float, delta : float, on_floor : bool) -> void:
	var mspeed : float = max_speed
	if is_crouching:
		mspeed /= 2
	if on_floor:
		state = PlayerState.running
	if abs(velocity.x) < mspeed:
		velocity.x += dir * acceleration * delta

func is_running(dir : float) -> bool:
	return (
		dir && !is_dir_against_velocity(dir) && 
		(last_state != PlayerState.wall || no_fall_ray.is_colliding())
	)

func is_dir_against_velocity(dir : float) -> bool:
	return !(velocity.x == 0 || (velocity.x > 0) == (dir > 0))

func crouch_state(dir : float) -> void:
	if is_sliding:
		state = PlayerState.sliding
		if !sliding_particle.emitting:
			sliding_particle.position = Vector2(0,64)
			sliding_particle.rotation_degrees = 90
			sliding_particle.emitting = true
	elif is_crouching:
		if dir:
			state = PlayerState.crouching
		
		if ray_roof_uncrouch.is_colliding():
			can_uncrouch = false
		elif !can_uncrouch:
			can_uncrouch = true
			uncrouch.emit()

func apply_friction(dir : float, delta : float, on_floor : bool) -> void:
	if on_floor:
		if abs(velocity.x) > min_speed_run:
			state = PlayerState.running
		else:
			state = PlayerState.idle
	var fric : float = friction + abs(dir * acceleration)
	if is_sliding && !is_dir_against_velocity(dir):
		fric /= 10
	velocity.x = move_toward(velocity.x,0,fric * delta)

func gravity_movement(delta : float, on_floor : bool, dir : float) -> bool:
	var wall_left : bool = is_children_ray_colliding(left_wall_rays)
	var wall_right : bool = is_children_ray_colliding(right_wall_rays)
	if (wall_left || wall_right) && !ray_roof_uncrouch.is_colliding():
		wall_movement(on_floor,wall_right, delta, dir)
	elif !on_floor:
		if (is_sliding || is_crouching) && faster_fall_slide:
			velocity.y += gravity * delta * 1.5
		else:
			velocity.y += gravity * delta
		if !no_fall_ray.is_colliding():
			if velocity.y > 0:
				state = PlayerState.falling
			else:
				state = PlayerState.jumping
	return wall_right

func wall_movement(on_floor : bool, wall_right : bool, delta : float, dir : float) -> void:
	if on_floor:
		return
	
	state = PlayerState.wall
	
	sliding_off_edge = false
	
	if velocity.y > 0 || (!dir && !velocity.x):
		if wall_right:
			velocity.x = 100
		else:
			velocity.x = -100
	
	# Prevent from launching of ledge when sliding
	if is_touching_ledge() && !faster_fall_slide && velocity.y >= 0:
		velocity.y = 0
		return
	
	# Reduce velocity when landing against wall
	if last_state != PlayerState.wall:
		velocity.y /= 2
	# Faster fall if pressing slide
	if faster_fall_slide:
		velocity.y += gravity / gravity_div_wall * delta * 1.5
	else:
		velocity.y += gravity / gravity_div_wall * delta
	
	# Wall particles
	if abs(velocity.y) >= 200:
		sliding_particle.rotation = 0
		sliding_particle.position.x = 10 if wall_right else -10
		sliding_particle.emitting = true
	return

func _input(event : InputEvent) -> void:
	if event.is_action_pressed("jump"):
		do_jump()
	elif event.is_action_pressed("attack"):
		pass
	elif event.is_action_pressed("slide") || event.is_action_released("slide"):
		do_slide(event.is_pressed())

func do_slide(slide : bool) -> void:
	if slide:
		faster_fall_slide = !is_on_floor()
		# If speed is above the min, slide instead of crouch
		if abs(velocity.x) > min_speed_slide:
			is_sliding = true
			is_crouching = false
		else:
			is_crouching = true
			is_sliding = false
	else:
		faster_fall_slide = false
		if !can_uncrouch:
			await uncrouch
			if Input.is_action_pressed("slide"):
				return
		is_sliding = false
		is_crouching = false
	change_stance_height()

## Make the change of collision for the stances(normal, crouch, slide)
func change_stance_height() -> void:
	if was_on_floor:
		if is_sliding:
			col_shape.size.y = 40
			col.position.y = 54
			return
		elif is_crouching:
			col_shape.size.y = 120
			col.position.y = 24
			return
	col_shape.size.y = 148
	col.position.y = 0

func do_jump() -> void:
	var on_floor : bool = is_on_floor()
	if !(on_floor || last_state == PlayerState.wall || no_fall_ray.is_colliding()):
			return
	
	# Give boost depending of direction pressed when jumping from wall
	if last_state == PlayerState.wall || state == PlayerState.wall:
		var wall_right : bool = is_children_ray_colliding(right_wall_rays)
		var mult : float = 1
		if !ray_ledge_left.is_colliding() && !ray_ledge_right.is_colliding():
			mult = 0.5
			if Input.is_action_pressed("right") && !wall_right:
				mult = 1
			elif Input.is_action_pressed("left") && wall_right:
				mult = 1
		velocity.x = (-1 if wall_right else 1) * acceleration * mult
		velocity.y = 0
	
	# Give boost to jump when sliding
	if (((is_sliding || is_crouching) && 
		[PlayerState.crouching,PlayerState.crouching_idle,PlayerState.sliding].has(state))) || sliding_off_edge:
		velocity.y = -jump_force * 1.5
	else:
		velocity.y = -jump_force
	
	if sliding_off_edge:
		velocity.x = velocity_x_on_slide_off
	
	sliding_off_edge = false
	
	# particles
	var particle : CPUParticles2D = jump_particle.duplicate()
	add_child(particle)
	particle.emitting = true
	await particle.finished
	particle.queue_free()

func is_touching_ledge() -> bool:
	if !ray_ledge_left.is_colliding() && left_wall_rays.get_child(0).is_colliding():
		return true
	elif !ray_ledge_right.is_colliding() && right_wall_rays.get_child(0).is_colliding():
		return true
	return false
