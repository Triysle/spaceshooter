extends Node3D

@onready var ship = $Ship
@onready var hud_layer = $HUDLayer

func _ready():
	# Connect HUD to ship directly with deferred setup to ensure all nodes are ready
	call_deferred("setup_hud")

func setup_hud():
	if hud_layer and ship:
		hud_layer.set_ship(ship)
