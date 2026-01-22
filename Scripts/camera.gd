extends Camera2D

# Camera Movement
@onready var player = $"../Player"


func _ready():
	pass


func _process(delta):
	camera_follow()


func camera_follow():
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position = player.position
