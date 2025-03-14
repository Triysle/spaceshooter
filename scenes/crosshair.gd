extends Node3D
class_name GimballedAimIndicator

# References
var ship: Node3D

# Crosshair settings
@export var crosshair_size: int = 15
@export var crosshair_thickness: int = 2
@export var crosshair_gap: int = 5
@export var crosshair_color: Color = Color(0.3, 0.3, 0.3, 0.7)

# Gimbal settings
@export var max_gimbal_angle: float = 25.0  # Maximum angle the crosshair can move from center
@export var gimbal_smooth_factor: float = 5.0  # How smoothly the crosshair follows mouse
@export var mouse_sensitivity: float = 0.3  # How fast the crosshair moves with mouse input
@export var dead_zone_radius: float = 0.15  # Percentage of max radius where no rotation occurs (0.0-1.0)
@export var invert_y_axis: bool = false  # Whether to invert the vertical control axis
@export var invert_x_axis: bool = false  # Whether to invert the horizontal control axis

# UI elements
var _canvas_layer: CanvasLayer
var _crosshair: Control

# Tracking variables
var viewport_center: Vector2 = Vector2.ZERO
var crosshair_position: Vector2 = Vector2.ZERO
var target_crosshair_position: Vector2 = Vector2.ZERO
var normalized_aim_offset: Vector2 = Vector2.ZERO  # -1.0 to 1.0 range

func _ready():
	# Get references
	ship = get_parent()
	
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
	
	# Get the viewport size and set initial positions
	viewport_center = _crosshair.get_viewport_rect().size / 2
	crosshair_position = viewport_center
	target_crosshair_position = viewport_center

func _process(delta):
	# Update viewport center in case window was resized
	if _crosshair:
		viewport_center = _crosshair.get_viewport_rect().size / 2
		
	# Calculate max offset based on gimbal angle
	var max_offset = viewport_center.y * tan(deg_to_rad(max_gimbal_angle))
	
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Smoothly interpolate current position toward target
		crosshair_position = crosshair_position.lerp(target_crosshair_position, gimbal_smooth_factor * delta)
		
		# Calculate normalized aim offset (-1 to 1 range)
		normalized_aim_offset = Vector2.ZERO
		if max_offset > 0:  # Prevent division by zero
			normalized_aim_offset = (crosshair_position - viewport_center) / max_offset
	else:
		# When mouse is not captured, smoothly reset crosshair to center
		target_crosshair_position = viewport_center
		crosshair_position = crosshair_position.lerp(viewport_center, gimbal_smooth_factor * delta)
		normalized_aim_offset = Vector2.ZERO
	
	# Update the crosshair every frame
	if _crosshair:
		_crosshair.queue_redraw()
		
# Method that can be called to reset the aim position
func reset_aim_position():
	target_crosshair_position = viewport_center
	crosshair_position = viewport_center
	normalized_aim_offset = Vector2.ZERO
		
func _input(event):
	# Only handle mouse motion when mouse is captured
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		# Calculate max offset based on gimbal angle
		var max_offset = viewport_center.y * tan(deg_to_rad(max_gimbal_angle))
		
		# Apply inversion if enabled
		var motion = event.relative
		if invert_x_axis:
			motion.x = -motion.x
		if invert_y_axis:
			motion.y = -motion.y
		
		# Update target position with mouse movement
		target_crosshair_position += motion * mouse_sensitivity
		
		# Enforce circular boundary instead of square
		var offset_from_center = target_crosshair_position - viewport_center
		var distance_from_center = offset_from_center.length()
		
		# If outside the circular boundary, scale back to the boundary
		if distance_from_center > max_offset:
			offset_from_center = offset_from_center.normalized() * max_offset
			target_crosshair_position = viewport_center + offset_from_center

func _draw_crosshair():
	if not _crosshair:
		return
	
	# Update viewport center in case window was resized
	viewport_center = _crosshair.get_viewport_rect().size / 2
	
	var color = crosshair_color
	
	# Calculate positions with float values
	var half_thickness = crosshair_thickness / 2.0
	
	# Calculate max offset for visual reference
	var max_offset = viewport_center.y * tan(deg_to_rad(max_gimbal_angle))
	var dead_zone_size = max_offset * dead_zone_radius
	
	# Draw dead zone indicator (subtle circle) using arc approximation with multiple line segments
	if dead_zone_radius > 0.0:
		var dead_zone_color = Color(crosshair_color.r, crosshair_color.g, crosshair_color.b, crosshair_color.a * 0.3)
		draw_circle_approximation(_crosshair, viewport_center, dead_zone_size, dead_zone_color, false)
	
	# Horizontal lines
	_crosshair.draw_rect(Rect2(
		crosshair_position.x - crosshair_size, 
		crosshair_position.y - half_thickness,
		crosshair_size - crosshair_gap, 
		crosshair_thickness
	), color)
	
	_crosshair.draw_rect(Rect2(
		crosshair_position.x + crosshair_gap, 
		crosshair_position.y - half_thickness,
		crosshair_size - crosshair_gap, 
		crosshair_thickness
	), color)
	
	# Vertical lines
	_crosshair.draw_rect(Rect2(
		crosshair_position.x - half_thickness, 
		crosshair_position.y - crosshair_size,
		crosshair_thickness, 
		crosshair_size - crosshair_gap
	), color)
	
	_crosshair.draw_rect(Rect2(
		crosshair_position.x - half_thickness, 
		crosshair_position.y + crosshair_gap,
		crosshair_thickness, 
		crosshair_size - crosshair_gap
	), color)
	
	# Center cross outline
	var center_outline_color = Color(color.r, color.g, color.b, color.a * 0.5)
	var center_outline_thickness = crosshair_thickness / 2
	
	# Horizontal center line
	_crosshair.draw_rect(Rect2(
		crosshair_position.x - crosshair_gap, 
		crosshair_position.y - center_outline_thickness / 2,
		crosshair_gap * 2, 
		center_outline_thickness
	), center_outline_color)
	
	# Vertical center line
	_crosshair.draw_rect(Rect2(
		crosshair_position.x - center_outline_thickness / 2, 
		crosshair_position.y - crosshair_gap,
		center_outline_thickness, 
		crosshair_gap * 2
	), center_outline_color)
	
	# Draw a subtle boundary indicator showing maximum range
	var boundary_color = Color(crosshair_color.r, crosshair_color.g, crosshair_color.b, crosshair_color.a * 0.2)
	draw_circle_approximation(_crosshair, viewport_center, max_offset, boundary_color, false)
	
	# Draw a dot at the center as a reference point
	draw_circle_approximation(_crosshair, viewport_center, 2, Color(crosshair_color.r, crosshair_color.g, crosshair_color.b, 0.5), true)
	
# Helper function to draw a circle using line segments
func draw_circle_approximation(control, center: Vector2, radius: float, color: Color, filled: bool = true):
	# Number of segments (more segments = smoother circle)
	var segments = 32
	
	if filled:
		# For filled circles, create a polygon
		var points = PackedVector2Array()
		for i in range(segments + 1):
			var angle = i * TAU / segments
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		control.draw_polygon(points, [color])
	else:
		# For outlines, draw line segments
		var prev_point = center + Vector2(radius, 0)
		for i in range(1, segments + 1):
			var angle = i * TAU / segments
			var point = center + Vector2(cos(angle), sin(angle)) * radius
			control.draw_line(prev_point, point, color)
			prev_point = point

# Public methods to get aim data for the ship
func get_aim_offset() -> Vector2:
	return normalized_aim_offset

func reset_aim():
	crosshair_position = viewport_center
	target_crosshair_position = viewport_center
	normalized_aim_offset = Vector2.ZERO
