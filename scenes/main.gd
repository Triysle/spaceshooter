extends Node3D

func _ready():
	# Find the ship (assuming it's a direct child named "Ship")
	var ship = $Ship
	
	# Find the HUD Layer
	var hud_layer = $HUDLayer
	
	# Set the ship reference
	hud_layer.set_ship(ship)
