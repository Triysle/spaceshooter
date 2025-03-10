extends CharacterBody3D

# Movement Configuration
# Exported variables for flexible ship handling
@export_group("Movement Parameters")
@export var base_speed: float = 50.0           # Standard maximum speed
@export var base_acceleration: float = 15.0    # Base rate of velocity change
@export var boost_acceleration_factor: float = 2.0  # Acceleration multiplier during boost
@export var turn_smoothness: float = 10.0      # Rotation responsiveness
@export var mouse_sensitivity: float = 0.3     # Precision of aiming controls

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
	
	# Emit initial energy level
	emit_signal("energy_changed", current_energy, max_energy)

# Physics Update Cycle
# Handles all physics-related updates each frame
func _physics_process(delta):
	# Process player inputs
	process_inputs(delta)
	
	# Handle energy regeneration and consumption
	handle_energy(delta)
	
	# Calculate and apply ship movement physics
	handle_ship_physics(delta)
	
	# Smoothly interpolate and apply ship rotation
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
		else:
			release_mouse()

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

# Rotation Application
# Smoothly interpolates and applies ship rotation
func apply_rotation(delta):
	# Smoothly move current rotation towards target rotation
	yaw = lerp(yaw, target_yaw, turn_smoothness * delta)
	pitch = lerp(pitch, target_pitch, turn_smoothness * delta)
	
	# Apply final rotation to ship
	rotation_degrees = Vector3(pitch, yaw, 0)

# Input Event Handling
# Specifically manages mouse look input
func _input(event):
	# Only process mouse rotation when mouse is captured
	if mouse_captured and event is InputEventMouseMotion:
		handle_mouse_rotation(event.relative)

# Mouse Rotation Handling
# Calculates rotation targets based on mouse movement
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
