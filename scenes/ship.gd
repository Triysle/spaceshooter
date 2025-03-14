extends CharacterBody3D

# Movement Configuration
# Exported variables for flexible ship handling
@export_group("Movement Parameters")
@export var base_speed: float = 50.0           # Standard maximum speed
@export var base_acceleration: float = 15.0    # Base rate of velocity change
@export var boost_acceleration_factor: float = 2.0  # Acceleration multiplier during boost
@export var turn_smoothness: float = 10.0      # Rotation responsiveness
@export var mouse_sensitivity: float = 0.3     # Precision of aiming controls

# Gimbal aiming system parameters
@export_group("Gimbal System")
@export var aim_follow_speed: float = 100.0      # Maximum rotation speed (degrees per second)
@export var aim_acceleration: float = 5.0      # How quickly rotation builds up when moving cursor

@export_group("Physics Settings")
@export var max_drift_speed: float = 50.0      # Consistent maximum velocity
@export var inertia_factor: float = 0.002      # Natural velocity decay rate

@export_group("Energy System")
@export var max_energy: float = 100.0          # Maximum energy capacity
@export var energy_regen_rate: float = 15.0    # Energy regeneration per second
@export var boost_energy_cost: float = 25.0    # Energy consumption per second while boosting
@export var min_boost_energy: float = 10.0     # Minimum energy required to activate boost

# Movement State Tracking
# Manages ship's movement and orientation
var velocity_vector := Vector3.ZERO        # Actual movement vector
var last_input_direction := Vector3.ZERO   # Stores the last non-zero input direction
var yaw := 0.0                             # Current horizontal rotation
var pitch := 0.0                           # Current vertical rotation
var target_yaw := 0.0                      # Target horizontal rotation
var target_pitch := 0.0                    # Target vertical rotation

# Ship Systems Status
# Tracks current ship configuration and mode
var mouse_captured := true                 # Is mouse look active?
var boost_active := false                  # Is boost mode currently on?
var dampers_active := true                 # Are inertial dampeners active?
var decoupled_mode := false                # Is the ship in decoupled flight mode?
var current_energy: float = max_energy     # Current energy level
var energy_depleted: bool = false          # Flag for energy depletion

# Gimbal system references
var aim_indicator: GimballedAimIndicator   # Reference to the aim indicator

# Energy status information
signal energy_changed(current, maximum)    # Signal to notify UI of energy changes

# Optimization Caches
# Performance-related precalculations
var current_acceleration: float            # Dynamic acceleration rate
var input_dir := Vector3.ZERO
var transform_basis: Basis

# Initialization
# Set up initial ship state
func _ready():
	# Start with zero velocity and base acceleration
	velocity = Vector3.ZERO
	current_acceleration = base_acceleration
	current_energy = max_energy
	
	# Capture mouse input by default
	capture_mouse()
	
	# Find aim indicator (assuming it's a direct child)
	for child in get_children():
		if child is GimballedAimIndicator:
			aim_indicator = child
			break
	
	# If no aim indicator was found, print a warning
	if not aim_indicator:
		push_warning("No GimballedAimIndicator found as a child of the ship!")
	
	# Emit initial energy level
	emit_signal("energy_changed", current_energy, max_energy)

# Physics Update Cycle
# Handles all physics-related updates each frame
# Physics Update Cycle
# Handles all physics-related updates each frame
func _physics_process(delta):
	# Process player inputs
	process_inputs(delta)
	
	# Handle energy regeneration and consumption
	handle_energy(delta)
	
	# Calculate and apply ship movement physics
	handle_ship_physics(delta)
	
	# Apply gimballed aim rotation if available
	if aim_indicator:
		# First, apply aim rotation (this was missing!)
		apply_aim_rotation(delta)
		
		# Then add visual banking effect
		var aim_offset = aim_indicator.get_aim_offset()
		
		# Create a gentle banking effect
		var bank_angle = -aim_offset.x * 5.0  # Adjust multiplier to control intensity
		
		# Smoothly interpolate the visual bank to prevent jarring movements
		$MeshInstance3D.rotation.z = lerp_angle($MeshInstance3D.rotation.z, deg_to_rad(bank_angle), 10.0 * delta)
	else:
		# Fall back to old rotation method if no aim indicator
		apply_rotation(delta)

# Input Processing
# Manages all input-based ship control actions
func process_inputs(_delta):
	# Boost Mechanics
	# Modify acceleration rate during boost
	var boost_input_pressed = Input.is_action_pressed("boost")
	
	# Only allow boost if we have enough energy
	if boost_input_pressed and current_energy >= min_boost_energy:
		if !boost_active:
			boost_active = true
			current_acceleration = base_acceleration * boost_acceleration_factor
	elif boost_active:
		# Deactivate boost if released or energy depleted
		boost_active = false
		current_acceleration = base_acceleration
	
	# System Toggles
	# Handle various ship system toggle inputs
	if Input.is_action_just_pressed("toggle_dampers"):
		dampers_active = !dampers_active
		print("Inertial Dampers: " + ("ON" if dampers_active else "OFF"))
	
	if Input.is_action_just_pressed("toggle_decoupled"):
		decoupled_mode = !decoupled_mode
		print("Flight Mode: " + ("COUPLED" if !decoupled_mode else "DECOUPLED"))
	
	# Mouse Capture Toggle
	# Allow escaping mouse capture during gameplay
	if Input.is_action_just_pressed("ui_cancel"):
		mouse_captured = !mouse_captured
		if mouse_captured:
			capture_mouse()
			# Reset aim indicator when recapturing mouse
			if aim_indicator:
				aim_indicator.reset_aim_position()
		else:
			release_mouse()
	
	# Control Inversion Toggles
	# Toggle Y-axis inversion
	if Input.is_action_just_pressed("toggle_invert_y") and aim_indicator:
		aim_indicator.invert_y_axis = !aim_indicator.invert_y_axis
		print("Y-Axis Inversion: " + ("ON" if aim_indicator.invert_y_axis else "OFF"))
	
	# Toggle X-axis inversion
	if Input.is_action_just_pressed("toggle_invert_x") and aim_indicator:
		aim_indicator.invert_x_axis = !aim_indicator.invert_x_axis
		print("X-Axis Inversion: " + ("ON" if aim_indicator.invert_x_axis else "OFF"))

# Energy Management System
# Handles energy regeneration and consumption
func handle_energy(delta):
	var previous_energy = current_energy
	
	# Consume energy while boosting
	if boost_active:
		current_energy = max(current_energy - boost_energy_cost * delta, 0.0)
		
		# Disable boost if energy depleted
		if current_energy < min_boost_energy:
			boost_active = false
			energy_depleted = true
			current_acceleration = base_acceleration
	else:
		# Regenerate energy when not boosting
		current_energy = min(current_energy + energy_regen_rate * delta, max_energy)
		
		# Reset energy depleted flag when we have enough energy to boost again
		if energy_depleted and current_energy >= min_boost_energy:
			energy_depleted = false
	
	# Notify UI of energy changes (only if changed significantly to reduce overhead)
	if abs(previous_energy - current_energy) > 0.01:
		emit_signal("energy_changed", current_energy, max_energy)

# Ship Physics Simulation
# Advanced movement physics with nuanced damper behaviors
func handle_ship_physics(delta):
	# Get current input direction
	input_dir = get_input_direction()
	
	# Cache transform basis for performance
	transform_basis = transform.basis
	
	# Consistent maximum speed across all modes
	var target_speed = max_drift_speed
	
	if dampers_active:
		# Dampers On: Smooth, precise velocity control
		var target_velocity = input_dir * target_speed
		
		# Gradual, controlled velocity adjustment
		velocity_vector = velocity_vector.move_toward(
			target_velocity, 
			current_acceleration * delta
		)
	else:
		# Dampers Off: More direct, physics-based approach
		if input_dir != Vector3.ZERO:
			# Direct velocity addition respecting input direction
			velocity_vector += input_dir * current_acceleration * delta
			
			# Maintain maximum speed while preserving direction
			if velocity_vector.length() > target_speed:
				velocity_vector = velocity_vector.normalized() * target_speed
	
	# Apply calculated velocity to physics engine
	velocity = velocity_vector
	move_and_slide()

# Input Direction Calculation
# Determines movement direction based on input and flight mode
func get_input_direction() -> Vector3:
	# Reset input direction
	input_dir = Vector3.ZERO
	
	# Gather raw directional inputs
	input_dir.z -= float(Input.is_action_pressed("move_forward"))
	input_dir.z += float(Input.is_action_pressed("move_backward"))
	input_dir.x -= float(Input.is_action_pressed("move_left"))
	input_dir.x += float(Input.is_action_pressed("move_right"))
	input_dir.y += float(Input.is_action_pressed("move_up"))
	input_dir.y -= float(Input.is_action_pressed("move_down"))
	
	# Normalize input if it has magnitude
	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()
		last_input_direction = input_dir
	
	# Transform input based on flight mode
	if !decoupled_mode:
		# Coupled Mode: Input transformed to ship's local space
		return transform_basis * input_dir
	else:
		# Decoupled Mode: Input independent of ship orientation
		return input_dir

# Gimballed Aim Rotation - Controller-like approach
# Uses the crosshair position to determine rotation rate, like a joystick
func apply_aim_rotation(delta):
	# Get the normalized aim offset from the indicator (-1 to 1 range)
	var aim_offset = aim_indicator.get_aim_offset()
	
	# Calculate the offset length (distance from center)
	var offset_length = aim_offset.length()
	
	# Apply dead zone - no rotation if within dead zone
	if offset_length < aim_indicator.dead_zone_radius:
		# Within dead zone, no rotation
		pass
	else:
		# Calculate rotation rate based on distance from dead zone edge
		# Remap from (deadzone-1) range to (0-1) range for smoother control
		var normalized_distance = (offset_length - aim_indicator.dead_zone_radius) / (1.0 - aim_indicator.dead_zone_radius)
		normalized_distance = clamp(normalized_distance, 0.0, 1.0)
		
		# Apply a curve to the normalized distance for better control
		# Squaring gives finer control near the dead zone and faster rotation at the edges
		normalized_distance = normalized_distance * normalized_distance
		
		# Calculate rotation speed (increases as crosshair moves further from center)
		# Base the rotation speed on degrees per second for more intuitive tuning
		var rotation_rate = normalized_distance * aim_follow_speed
		
		# Apply rotation based on direction
		if offset_length > 0.01:  # Prevent division by zero
			# Normalize the aim vector for direction
			var normalized_aim = aim_offset / offset_length
			
			# Calculate rotation amounts - INVERT the direction to make ship turn TOWARD the crosshair
			# We need to invert the direction because positive yaw/pitch values rotate in the opposite
			# direction of what we want when trying to follow the crosshair
			var yaw_change = -normalized_aim.x * rotation_rate * delta
			var pitch_change = -normalized_aim.y * rotation_rate * delta
			
			# Apply rotation
			yaw += yaw_change
			pitch += pitch_change
			
			# Clamp pitch to prevent flipping
			pitch = clamp(pitch, -80, 80)
	
	# Apply final rotation to ship
	rotation_degrees = Vector3(pitch, yaw, 0)

# Legacy Rotation Application
# Used only if no aim indicator is available
func apply_rotation(delta):
	# Smoothly move current rotation towards target rotation
	yaw = lerp(yaw, target_yaw, turn_smoothness * delta)
	pitch = lerp(pitch, target_pitch, turn_smoothness * delta)
	
	# Apply final rotation to ship
	rotation_degrees = Vector3(pitch, yaw, 0)

# Input Event Handling
# Now only used for direct mouse look if no aim indicator is available
func _input(event):
	# Only process direct mouse rotation when mouse is captured AND no aim indicator exists
	if mouse_captured and event is InputEventMouseMotion and not aim_indicator:
		handle_mouse_rotation(event.relative)

# Mouse Rotation Handling
# Legacy method for direct ship rotation
func handle_mouse_rotation(delta_mouse: Vector2):
	# Update rotation targets
	target_yaw -= delta_mouse.x * mouse_sensitivity
	target_pitch -= delta_mouse.y * mouse_sensitivity
	
	# Clamp vertical rotation to prevent over-rotation
	target_pitch = clamp(target_pitch, -80, 80)

# Mouse Capture Utilities
# Manage mouse input capture state
func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Public API for energy system
# Returns current energy percentage (0-100)
func get_energy_percentage() -> float:
	return (current_energy / max_energy) * 100.0
