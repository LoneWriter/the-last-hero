extends CharacterBody2D

# TODO: Add Wall-Kicks aka Wall-Jumps

# Player State Machine
enum player_state { MOVE, ATTACK, SLAIN }
var curr_state = player_state.MOVE
var currPos: Vector2

# Movement
var input
@export var speed = 100.0
@export var gravity = 8
@export var max_fall_speed = 225
@export var jump_force = 300

# Jumping
var jump_count = 0
@export var max_jumps = 2
var coyote_timer = 0.0
@export var coyote_time = 0.15

# Animation
var transitioning = false
var was_on_floor = false
var death = 0

# Attack Combo
var attacking = false
var attack_index = 0
var combo_timer = 0.0
var combo_window = 0.5
var combo_failsafe_timer = 0.0
var queue_attack = false
var current_attack_anim = ""
var charge_time = 0.0
@export var max_charge_time = 2.0  # Max charge time for super attack
var charge_progress = 0.0  # Tracks the charge level
var movement_lock_timer = 0.0 # Movement lock after heavy attacks
@export var strike_three_lock_duration = 0.4 
var pending_strike_three_reset = false  # Flag to delay reset after StrikeThree until lock ends
var strike_three_timer = 0.0
@export var max_strike_three_duration = 1.0  # Max duration for the StrikeThree animation

func _ready():
	$Attack/CollisionShape2D.disabled = true


# Check *every* frame please
func _physics_process(delta):
	if Player_data.life <= 0:
		curr_state = player_state.SLAIN
	if Player_data.life >= 1:
		curr_state = player_state.MOVE
	
	# Prevent all movement and actions while locked
	if movement_lock_timer > 0:
		movement_lock_timer -= delta
		if movement_lock_timer <= 0 and pending_strike_three_reset:
			# Only reset state *after* lock ends
			pending_strike_three_reset = false
			attacking = false
			curr_state = player_state.MOVE
			reset_combo()
		return
	
	match curr_state:
		player_state.SLAIN:
			if death == 0:
				death += 1
				dead()
		player_state.MOVE:
			movement(delta)
			check_trans_animation_progress()
			
			# Base attack input
			if Input.is_action_just_pressed("ui_base_attack"):
				start_attack()
				curr_state = player_state.ATTACK
			
			# Power/Super attack input - hold to charge
			elif Input.is_action_pressed("ui_base_power"):
				charge_time += delta
				charge_progress = min(charge_time / max_charge_time, 1.0)  # Charge progress caps at 1 (100%)
			
			# Release the charge and perform Power attack when input is released
			elif Input.is_action_just_released("ui_base_power"):
				start_power_attack()
				curr_state = player_state.ATTACK
		
		player_state.ATTACK:
			movement(delta) # Allow movement during attack
			
			if current_attack_anim != "StrikeThree" and Input.is_action_just_pressed("ui_base_power"):
				start_power_attack()
				curr_state = player_state.ATTACK
			
			# Failsafe reset. Just in case too many inputs cause the logic to overflow and break
			combo_failsafe_timer -= delta
			if combo_failsafe_timer <= 0 and !attacking:
				curr_state = player_state.MOVE
				reset_combo()
			
			# Combo window
			if combo_timer > 0:
				combo_timer -= delta
			elif !attacking:
				curr_state = player_state.MOVE
				reset_combo()
			
			# Queue next combo input
			if Input.is_action_just_pressed("ui_base_attack") and attacking:
				queue_attack = true
			
			# Combo cancels except final hit. If you lock in then you *must* full commit
			if current_attack_anim != "StrikeThree" and current_attack_anim != "Super":
				if Input.is_action_just_pressed("ui_accept"):
					if is_on_floor() or jump_count < max_jumps:
						velocity.y = -jump_force
						jump_count += 1
						reset_combo()
						attacking = false
						curr_state = player_state.MOVE
				elif Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
					reset_combo()
					attacking = false
					curr_state = player_state.MOVE


# Debug only:
func restart_scene():
	if curr_state == player_state.SLAIN:
		get_tree().reload_current_scene()
		curr_state == player_state.MOVE
		
		# Debug:
		print("Player died.")


# Movement
func movement(delta):
	input = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	if is_on_floor():
		coyote_timer = coyote_time
		jump_count = 0
	else:
		coyote_timer -= delta
	
	# Jumping
	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor() or coyote_timer > 0:
			velocity.y = -jump_force
			jump_count += 1
			coyote_timer = 0
		elif jump_count < max_jumps: # Yes. You can double jump... for now >:D
			velocity.y = -jump_force
			jump_count += 1
	
	# I cast: "Fall faster. We don't have all day."
	if !is_on_floor() and Input.is_action_just_released("ui_accept") and velocity.y < 0:
		velocity.y *= 0.5
	
	# Movement inputs
	if input != 0:
		velocity.x = input * speed
		$Sprite2D.scale.x = sign(input) # 
		$Attack.position.x = abs($Attack.position.x) * sign(input)
	else:
		velocity.x = 0
	
	gravity_force() # Apply gravity
	
	if !attacking:
		handle_animation() # To Animation!
	
	move_and_slide() # Go move. This is a demand
	was_on_floor = is_on_floor() # This is so we can ref the players state on future frame updates


# I have mastered a fundamental core of the universe! Fear me!
func gravity_force():
	velocity.y += gravity
	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed


# Animation Handler
func handle_animation():
	if transitioning:
		return
	
	if !is_on_floor():
		if velocity.y < 0:
			$AnimPlayer.play("Jump")
		else:
			$AnimPlayer.play("Fall")
		return
	
	if !was_on_floor and input != 0:
		$AnimPlayer.play("transToRun")
		transitioning = true
		return
	
	if input == 0:
		if $AnimPlayer.current_animation != "Idle":
			$AnimPlayer.play("Idle")
		return
	
	if $AnimPlayer.current_animation != "Run":
		$AnimPlayer.play("transToRun")
		transitioning = true


# Calling for the completion of a animation can always be... *worrying*, so I'm skipping the middle man and going
# completely based on when I want it to switch instead of waiting for a signal.
func check_trans_animation_progress():
	if transitioning and $AnimPlayer.current_animation == "transToRun":
		var progress: float = $AnimPlayer.current_animation_position / $AnimPlayer.current_animation_length
		if progress >= 0.8:
			$AnimPlayer.play("Run")
			transitioning = false


# This is just for a cleaner animation from "Idle" -> "Run"
func _trans_animation(anim_name: String):
	if anim_name == "transToRun":
		$AnimPlayer.play("Run")
		transitioning = false


func dead():
	$AnimPlayer.play("death")
	velocity.x = 0


# Attack Handlers
func start_attack():
	attacking = true
	queue_attack = false
	combo_timer = combo_window
	combo_failsafe_timer = 1.0
	
	match attack_index:
		0:
			current_attack_anim = "StrikeOne"
			$AnimPlayer.play("StrikeOne")
		1:
			current_attack_anim = "StrikeTwo"
			$AnimPlayer.play("StrikeTwo")
		2:
			current_attack_anim = "StrikeThree"
			strike_three_timer = 0.0  # Reset on start
			$AnimPlayer.play("StrikeThree")
	
	$Attack/CollisionShape2D.disabled = false


# A Power/Super is a charged attack. The longer you hold it, the stronger it is.
func start_power_attack():
	attacking = true
	queue_attack = false
	
	if charge_progress >= 1.0:
		current_attack_anim = "SuperPower"
		$AnimPlayer.play("SuperPower")  # SuperPower is stronger and has its own animation
	else:
		current_attack_anim = "Super"
		$AnimPlayer.play("Super")  # Single animation regardless of charge level
	$Attack/CollisionShape2D.disabled = false
	
	reset_combo()


func reset_combo():
	attack_index = 0
	combo_timer = 0
	queue_attack = false
	charge_time = 0.0
	charge_progress = 0.0
	strike_three_timer = 0.0


# Animation Finished Signal
# This method is what resets the player's state to "MOVE" so they aren't locked forever in one of the strike animations
func _on_anim_player_animation_finished(anim_name):
	$Attack/CollisionShape2D.disabled = true
	
	if anim_name == "StrikeThree":
		movement_lock_timer = strike_three_lock_duration  # Lock movement briefly after final hit to make it feel weighty on impact
		if !queue_attack:
			pending_strike_three_reset = true  # Delay reset until after lock expires
			return
	
	if anim_name.begins_with("Strike"):
		if queue_attack and attack_index < 2:
			attack_index += 1
			start_attack()
			return
		else:
			attacking = false
			curr_state = player_state.MOVE
			reset_combo()

	elif anim_name == "Super" or anim_name == "SuperPower":
		attacking = false
		curr_state = player_state.MOVE
		reset_combo()
	
	current_attack_anim = ""  # Reset the variable to be used in a possible future combo
