extends CharacterBody3D

@export_group("Movement Parameters")
@export var speed: float = 10.0
@export var acceleration: float = 5.0
@export var turn_smoothness: float = 5.0
@export var mouse_sensitivity: float = 0.2
@export var boost_factor: float = 2.0

@export_group("Physics Settings")
@export var damper_strength: float = 0.9  # How strongly dampers slow the ship
@export var max_drift_speed: float = 20.0  # Maximum speed with dampers off
@export var inertia_factor: float = 0.01  # Small amount of space friction for playability

var velocity_vector := Vector3.ZERO
var last_input_direction := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var target_yaw := 0.0
var target_pitch := 0.0

# Ship systems status
var mouse_captured := true
var boost_active := false
var dampers_active := true
var decoupled_mode := false

func _ready():
	velocity = Vector3.ZERO
	capture_mouse()

func _physics_process(delta):
	# Process all inputs first
	process_inputs(delta)
	
	# Handle physics movement
	handle_ship_physics(delta)
	
	# Apply rotation with smoothing
	apply_rotation(delta)

func process_inputs(_delta):
	# Check for boost (continuous press)
	boost_active = Input.is_action_pressed("boost")
	
	# Check for toggles (just pressed)
	if Input.is_action_just_pressed("toggle_dampers"):
		dampers_active = !dampers_active
		# Play sound effect here if available
		print("Inertial Dampers: " + ("ON" if dampers_active else "OFF"))
	
	if Input.is_action_just_pressed("toggle_decoupled"):
		decoupled_mode = !decoupled_mode
		# Play sound effect here if available
		print("Flight Mode: " + ("COUPLED" if !decoupled_mode else "DECOUPLED"))
		
	# Toggle mouse capture
	if Input.is_action_just_pressed("ui_cancel"):
		mouse_captured = !mouse_captured
		if mouse_captured:
			capture_mouse()
		else:
			release_mouse()

func _input(event):
	# Mouse rotation input handling
	if mouse_captured and event is InputEventMouseMotion:
		handle_mouse_rotation(event.relative)

func handle_ship_physics(delta):
	var input_dir = get_input_direction()
	var current_max_speed = speed * (boost_factor if boost_active else 1.0)
	
	# Apply different physics behavior based on dampers state
	if dampers_active:
		# With dampers: smooth acceleration and deceleration
		velocity_vector = velocity_vector.lerp(input_dir * current_max_speed, acceleration * delta)
	else:
		# Without dampers: continuous acceleration with minimal drag
		if input_dir != Vector3.ZERO:
			velocity_vector += input_dir * acceleration * delta
			
			# Apply very slight drag for playability (not realistic but helps with control)
			# Using a consistent formula based on velocity magnitude
			var drag_factor = inertia_factor * velocity_vector.length() * delta
			velocity_vector = velocity_vector * (1.0 - clamp(drag_factor, 0.0, 0.1))
			
			# Limit max speed with a soft cap for better feel
			var speed_ratio = velocity_vector.length() / max_drift_speed
			if speed_ratio > 1.0:
				var soft_cap_factor = 1.0 / (1.0 + (speed_ratio - 1.0) * 0.5)
				velocity_vector *= soft_cap_factor
	
	# Apply final velocity to the physics engine
	velocity = velocity_vector
	var collision = move_and_slide()
	
	# Handle collision response for more realistic bouncing
	if collision:
		handle_collision_response()

func get_input_direction() -> Vector3:
	var input_dir = Vector3.ZERO
	
	# Get raw directional input
	if Input.is_action_pressed("move_forward"): input_dir.z -= 1
	if Input.is_action_pressed("move_backward"): input_dir.z += 1
	if Input.is_action_pressed("move_left"): input_dir.x -= 1
	if Input.is_action_pressed("move_right"): input_dir.x += 1
	if Input.is_action_pressed("move_up"): input_dir.y += 1
	if Input.is_action_pressed("move_down"): input_dir.y -= 1
	
	# Normalize if we have movement
	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()
		last_input_direction = input_dir
		
	# Transform global input to local movement based on flight mode
	if !decoupled_mode:
		# Traditional flight - transform to ship's local space
		return transform.basis * input_dir
	else:
		# Decoupled flight - input is independent of ship orientation
		return input_dir

func apply_rotation(delta):
	# Smoothly interpolate to target values
	yaw = lerp(yaw, target_yaw, turn_smoothness * delta)
	pitch = lerp(pitch, target_pitch, turn_smoothness * delta)
	
	# Apply rotation to the ship
	rotation_degrees = Vector3(pitch, yaw, 0)

func handle_mouse_rotation(delta_mouse: Vector2):
	target_yaw -= delta_mouse.x * mouse_sensitivity
	target_pitch -= delta_mouse.y * mouse_sensitivity  
	target_pitch = clamp(target_pitch, -80, 80)

func handle_collision_response():
	# If we implement proper collision response, it would go here
	# This would handle bouncing off asteroids, etc.
	pass

func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
