extends CharacterBody2D

# Basic Boss Logic

@export var patrol_points: Node
@export var speed: int = 1500
@export var wait_time: int = 3

@onready var sprite2D = $Sprite2D
@onready var timer = $Timer

const gravity = 1000

enum STATE { IDLE, ROAM, ENGAGED, DEAD }
var currState: STATE = STATE.IDLE
var direction: Vector2 = Vector2.LEFT

var number_of_points: int
var point_positions: Array[Vector2] = []
var currPoint: Vector2
var currPoint_position: int = 0

var can_roam: bool = true
var player = null


func _ready():
	if patrol_points != null:
		number_of_points = patrol_points.get_children().size()
		for point in patrol_points.get_children():
			point_positions.append(point.global_position)
		currPoint_position = 0
		currPoint = point_positions[currPoint_position]
	else:
		print("No Patrol Points Found.")
	
	timer.wait_time = wait_time


func _process(delta: float) -> void:
	if player != null and direction.x != 0:
		sprite2D.flip_h = direction.x > 0


func _physics_process(delta: float):
	enemy_gravity(delta)
	
	if player != null:
		var playerLOC = (player.global_position - global_position)
		if playerLOC.length() > 50.0:
			direction = playerLOC.normalized()
		else:
			direction = Vector2.ZERO
		
		engage_player(delta)
	else:
		enemy_idle(delta)
		enemy_roam(delta)
	
	move_and_slide()


func engage_player(delta: float):
	if direction != Vector2.ZERO:
		velocity = speed * direction
	else:
		velocity.x = move_toward(velocity.x, 0, speed)


func enemy_gravity(delta: float):
	velocity.y += gravity * delta


func enemy_idle(delta: float):
	if not can_roam:
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		currState = STATE.IDLE


func enemy_roam(delta: float):
	if not can_roam:
		return
	
	if abs(position.x - currPoint.x) > 0.5:
		velocity.x = direction.x * speed * delta
		currState = STATE.ROAM
	else:
		currPoint_position += 1
		if currPoint_position >= number_of_points:
			currPoint_position = 0
		
		currPoint = point_positions[currPoint_position]
		direction = (currPoint - position).normalized()
		
		can_roam = false
		timer.start()


func _on_timer_timeout() -> void:
	can_roam = true


func _on_attack_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		Player_data.life -= 1


func _on_player_detector_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		if player == null:
			player = body
			print(body.name + " found.")


func _on_player_detector_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		if player != null:
			player = null
			print(body.name + " lost.")
