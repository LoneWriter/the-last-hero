extends CanvasLayer

# GUI logic

const life_max = 8
const life_offset = 28


func _ready():
	for i in range(Player_data.life):
		var new_life = Sprite2D.new()
		new_life.texture = $Life.texture
		new_life.hframes = $Life.hframes
		$Life.add_child(new_life)


func _process(delta):
	display_life()


# Basic logic for life GUI
func display_life():
	for life in $Life.get_children():
		var index = life.get_index()
		var x = (index % life_max) * life_offset
		var y = int(index / life_max) * life_offset
		life.position = Vector2(x, y)
		
		# Set all to frame 1 if player is dead
		if Player_data.life <= 0:
			life.frame = 1
		else:
			# Show life frame (0 = active, 1 = lost)
			life.frame = 0 if index < Player_data.life else 1
