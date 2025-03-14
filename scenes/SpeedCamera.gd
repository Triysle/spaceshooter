extends Camera3D

# Camera Dynamics Configuration
@export_group("Movement Dynamics")
@export var max_visual_pitch_angle: float = 10.0    # Maximum pitch for visual effect
@export var max_visual_roll_angle: float = 20.0     # Maximum roll for visual effect
@export var visual_smoothing: float = 5.0           # Smoothness of visual transitions
@export var fov_speed_sensitivity: float = 0.3      # How much speed affects FOV
@export var max_fov_change: float = 10.0            # Maximum FOV deviation
@export var base_fov: float = 75.0                  # Standard field of view
@export var fov_smoothing: float = 5.0              # FOV transition smoothness

# Crosshair Influence Parameters
@export_group("Crosshair Influence")
@export var crosshair_pitch_strength: float = 1.0   # Pitch influence from crosshair
@export var crosshair_roll_strength: float = 0.5    # Roll influence from crosshair

# Visual Offset Parameters
@export_group("Visual Offsets")
@export var max_visual_offset: float = 0.1          # Maximum visual displacement
@export var offset_smoothing: float = 5.0           # Smoothness of offset transitions

# Tracking Variables
var ship: Node3D
var aim_indicator: GimballedAimIndicator
var initial_transform: Transform3D
var visual_pitch: float = 0.0
var visual_roll: float = 0.0
var visual_offset: Vector3 = Vector3.ZERO
var target_visual_offset: Vector3 = Vector3.ZERO

func _ready():
	# Ensure camera is a child of the ship
	ship = get_parent()
	
	# Find aim indicator
	for child in ship.get_children():
		if child is GimballedAimIndicator:
			aim_indicator = child
			break
	
	# Store the initial camera transform
	initial_transform = transform
	
	# Start with base FOV
	fov = base_fov

func _process(delta):
	if not ship:
		return
	
	# Simulate camera movement based on ship's velocity and crosshair
	simulate_camera_movement(delta)

func simulate_camera_movement(delta):
	# Get ship's current velocity and orientation
	var velocity = ship.velocity
	var ship_forward = -ship.global_transform.basis.z
	var ship_right = ship.global_transform.basis.x
	var ship_up = ship.global_transform.basis.y
	
	# Calculate speed for FOV calculations
	var max_speed = ship.max_drift_speed if "max_drift_speed" in ship else 100.0
	var current_speed = velocity.length()
	var speed_ratio = clamp(current_speed / max_speed, 0.0, 1.0)
	
	# Calculate visual pitch based on vertical movement
	var ship_up_tilt = velocity.dot(ship_up) / max_speed
	var target_pitch = -ship_up_tilt * max_visual_pitch_angle
	
	# Crosshair influence on pitch and visual offset
	if aim_indicator:
		var aim_offset = aim_indicator.get_aim_offset()
		
		# Pitch from crosshair
		target_pitch += -aim_offset.y * max_visual_pitch_angle * crosshair_pitch_strength
		
		# Visual offset based on crosshair position
		target_visual_offset = Vector3(
			aim_offset.x * max_visual_offset,   # Horizontal offset
			-aim_offset.y * max_visual_offset,  # Vertical offset
			0  # No depth offset
		)
	
	# Calculate visual roll (banking effect without actual banking)
	var velocity_roll = velocity.dot(ship_right) / max_speed * max_visual_roll_angle
	var target_roll = velocity_roll
	
	# Smoothly interpolate visual elements
	visual_pitch = lerp(visual_pitch, target_pitch, visual_smoothing * delta)
	visual_roll = lerp(visual_roll, target_roll, visual_smoothing * delta)
	visual_offset = visual_offset.lerp(target_visual_offset, offset_smoothing * delta)
	
	# Calculate FOV adjustment based on speed
	var fov_adjustment = max_fov_change * speed_ratio * fov_speed_sensitivity
	var target_fov = base_fov + fov_adjustment
	
	# Smoothly adjust FOV
	fov = lerp(fov, target_fov, fov_smoothing * delta)
	
	# Apply the simulated camera movement
	# Reset to initial transform first, then apply visual transformations
	transform = initial_transform
	
	# Apply visual offsets
	translate(visual_offset)
	
	# Apply rotational visual effects
	rotate_x(deg_to_rad(visual_pitch))
	rotate_z(deg_to_rad(visual_roll))
