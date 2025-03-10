extends Node3D
class_name SimpleMovementIndicator

# References
var ship: Node3D
var camera: Camera3D

# Crosshair settings
@export var crosshair_size: int = 15
@export var crosshair_thickness: int = 2
@export var crosshair_gap: int = 5
@export var crosshair_color: Color = Color(0.3, 0.3, 0.3, 0.7)

# UI elements
var _canvas_layer: CanvasLayer
var _crosshair: Control

func _ready():
	# Get references
	ship = get_parent()
	
	# Find camera (assuming it's a direct child of the ship)
	for child in ship.get_children():
		if child is Camera3D:
			camera = child
			break
	
	# Create UI layer with delay to ensure everything is initialized
	call_deferred("_setup_ui")

func _setup_ui():
	# Create canvas layer
	_canvas_layer = CanvasLayer.new()
	add_child(_canvas_layer)
	
	# Setup crosshair
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_crosshair)
	_crosshair.connect("draw", Callable(self, "_draw_crosshair"))
	
	# Force initial redraw
	_crosshair.queue_redraw()

func _process(_delta):
	# Update the crosshair every frame
	if _crosshair:
		_crosshair.queue_redraw()

func _draw_crosshair():
	if not _crosshair:
		return
		
	var viewport_size = _crosshair.get_viewport_rect().size
	var center = viewport_size / 2
	var color = crosshair_color
	
	# Calculate positions with float values
	var half_thickness = crosshair_thickness / 2.0
	
	# Draw horizontal lines
	_crosshair.draw_rect(Rect2(
		center.x - crosshair_size, 
		center.y - half_thickness,
		crosshair_size - crosshair_gap, 
		crosshair_thickness
	), color)
	
	_crosshair.draw_rect(Rect2(
		center.x + crosshair_gap, 
		center.y - half_thickness,
		crosshair_size - crosshair_gap, 
		crosshair_thickness
	), color)
	
	# Draw vertical lines
	_crosshair.draw_rect(Rect2(
		center.x - half_thickness, 
		center.y - crosshair_size,
		crosshair_thickness, 
		crosshair_size - crosshair_gap
	), color)
	
	_crosshair.draw_rect(Rect2(
		center.x - half_thickness, 
		center.y + crosshair_gap,
		crosshair_thickness, 
		crosshair_size - crosshair_gap
	), color)
