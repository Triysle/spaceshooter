extends Camera3D

@export var base_fov: float = 75.0
@export var max_fov_increase: float = 15.0
@export var fov_smoothing: float = 3.0
@export var decoupled_fov_factor: float = 0.5  # Reduces the effect in decoupled mode

# Optional settings for motion blur in decoupled mode
@export var use_motion_indicators: bool = true
@export var motion_indicator_strength: float = 1.0

@onready var ship = get_parent()

# For tracking movement direction relative to facing direction
var relative_movement_dot: float = 1.0

func _ready():
	base_fov = fov

func _process(delta):
	# Get the ship's current speed
	var current_speed = ship.velocity.length()
	
	# Get ship's max speed
	var max_speed = 20.0
	if "max_drift_speed" in ship:
		max_speed = ship.max_drift_speed
	
	# Calculate speed ratio
	var speed_ratio = clamp(current_speed / max_speed, 0.0, 1.0)
	
	# Calculate how aligned our movement is with our facing direction
	calculate_movement_alignment()
	
	# Adjust FOV based on alignment and decoupled mode
	var effective_fov_increase = max_fov_increase
	
	# Check if we're in decoupled mode
	var is_decoupled = false
	if "decoupled_mode" in ship:
		is_decoupled = ship.decoupled_mode
	
	# If we're in decoupled mode, adjust the FOV effect based on alignment
	if is_decoupled:
		# Reduce the FOV effect when moving perpendicular to facing direction
		effective_fov_increase *= decoupled_fov_factor * (0.5 + 0.5 * abs(relative_movement_dot))
	
	# Calculate target FOV
	var target_fov = base_fov + (effective_fov_increase * speed_ratio)
	
	# Smoothly transition to target FOV
	fov = lerp(fov, target_fov, fov_smoothing * delta)
	
	# Add additional visual cues for decoupled movement if enabled
	if use_motion_indicators and is_decoupled and speed_ratio > 0.2:
		update_motion_indicators(speed_ratio, delta)

func calculate_movement_alignment():
	# Get the direction the ship is facing (forward vector)
	var facing_direction = -ship.global_transform.basis.z.normalized()
	
	# Get the direction the ship is moving
	var velocity_direction = ship.velocity.normalized()
	
	# If we're barely moving, assume alignment is 1.0
	if ship.velocity.length() < 0.1:
		relative_movement_dot = 1.0
		return
	
	# Calculate the dot product to determine alignment
	# 1.0 = perfectly aligned (moving forward)
	# 0.0 = perpendicular (moving sideways)
	# -1.0 = opposite (moving backward)
	relative_movement_dot = facing_direction.dot(velocity_direction)

func update_motion_indicators(speed_ratio, delta):
	# This function would add visual indicators of movement direction
	# when in decoupled mode - like subtle vignette effects on screen edges
	
	# For now we'll leave this as a placeholder - we can implement
	# custom motion indicators later if the FOV adjustment isn't enough
	pass
