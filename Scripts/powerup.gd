extends Area2D

# Item pick up logic


func _ready():
	$anim.play("Idle")


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		Player_data.pickUps += 1
		
		# Debug:
		print("Item Picked Up! Count: ", Player_data.pickUps)
		
		$CollisionShape2D.disabled = true
		queue_free()
