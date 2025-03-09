extends Node3D
class_name SpaceDustSystem

# Particle Configuration for Consistent Space Atmosphere
@export_category("Particle Settings")
@export var particle_count: int = 2000  # Total number of dust particles
@export var particle_size: float = 0.05  # Base size of dust particles
@export var box_size: float = 200.0  # Volume of dust field

@export_category("Movement Settings")
@export var reactivity_factor: float = 1.2  # Dust responsiveness to ship movement
@export var fade_distance: float = 20.0  # Distance at which particles start to fade
@export var fade_min_distance: float = 5.0  # Distance at which particles are fully transparent
@export var drift_intensity: float = 0.1  # Organic drift movement intensity

@export_category("Rendering")
@export var draw_behind_objects: bool = true  # Render particles behind other objects

@export_category("References")
@export var ship_node: Node3D
@export var camera_path: NodePath = "Camera3D"  # Path to camera within ship

# Private Variables for Dust Simulation
var _multimesh: MultiMesh
var _multimesh_instance: MultiMeshInstance3D
var _particles_pos: Array = []
var _particles_drift: Array = []
var _last_ship_position: Vector3
var _ship_velocity: Vector3 = Vector3.ZERO
var _half_box: float
var _camera_node: Camera3D
var _rng: RandomNumberGenerator

func _ready():
	# Initialize random number generator
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	
	# Cache the half box size for wrapping calculations
	_half_box = box_size / 2.0
	
	# Store the initial ship position
	if ship_node:
		_last_ship_position = ship_node.global_position
		_camera_node = ship_node.get_node(camera_path)
	
	# Set up the particle system
	_setup_multimesh()
	_create_particles()
	_update_multimesh()
	
	# Set a specific render layer for dust particles
	# We'll use layer 2 (the second layer)
	_multimesh_instance.layers = 2

# Create a soft, atmospheric dust texture
func _create_particle_texture() -> Texture2D:
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Create a soft, irregular dust-like shape
	for x in range(64):
		for y in range(64):
			var center = Vector2(32, 32)
			var dist = center.distance_to(Vector2(x, y))
			
			# Soft, organic edge with subtle noise
			var noise = sin(dist * 0.4) * 0.1
			var alpha = clamp(1.0 - (dist / 32.0) + noise, 0.0, 1.0)
			alpha = pow(alpha, 2.0)  # Softer, more diffuse edges
			
			if alpha > 0:
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	return ImageTexture.create_from_image(img)

# Enhanced MultiMesh setup for consistent atmospheric rendering
func _setup_multimesh():
	var quad = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	
	# Ensure particles respect scene geometry
	material.cull_mode = BaseMaterial3D.CULL_BACK  # Standard back-face culling
	
	# Emission for consistent visibility
	material.emission_enabled = true
	material.emission = Color(0.9, 0.95, 1.0, 0.2)
	material.emission_energy_multiplier = 0.8
	
	# Use our custom dust-like texture
	material.albedo_texture = _create_particle_texture()
	
	quad.material = material
	
	# MultiMesh setup remains the same
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = particle_count
	
	# Create the MultiMeshInstance3D
	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.multimesh = _multimesh
	
	# IMPORTANT: Set the render layer
	# We'll use layer 2 (bitwise, so 1 << 1)
	_multimesh_instance.layers = 2
	
	add_child(_multimesh_instance)

# Create particles with individual characteristics
func _create_particles():
	_particles_pos.clear()
	_particles_drift.clear()
	
	for _i in range(particle_count):
		# Random initial position within the dust box
		var pos = Vector3(
			_rng.randf_range(-_half_box, _half_box),
			_rng.randf_range(-_half_box, _half_box),
			_rng.randf_range(-_half_box, _half_box)
		)
		_particles_pos.append(pos)
		
		# Individual drift vector for each particle
		_particles_drift.append(Vector3(
			_rng.randf_range(-1, 1),
			_rng.randf_range(-1, 1),
			_rng.randf_range(-1, 1)
		).normalized() * drift_intensity)

# Update MultiMesh with consistent rendering
func _update_multimesh():
	for i in range(particle_count):
		# Create transform for this particle
		var transform = Transform3D()
		transform.origin = _particles_pos[i]
		
		# Consistent size with minimal variation
		transform.basis = Basis().scaled(Vector3(
			particle_size, 
			particle_size, 
			particle_size
		))
		
		# Add small z-offset to reduce z-fighting
		transform.origin.z += (i % 100) * 0.001
		
		_multimesh.set_instance_transform(i, transform)
		
		# Sophisticated opacity calculation
		var distance_to_ship = ship_node.global_position.distance_to(global_position + _particles_pos[i])
		var alpha = 1.0
		
		if distance_to_ship < fade_min_distance:
			alpha = 0.0
		elif distance_to_ship < fade_distance:
			# Smooth, non-linear fade
			alpha = pow(
				(distance_to_ship - fade_min_distance) / (fade_distance - fade_min_distance), 
				0.7
			)
		
		# Consistent white color with variable alpha
		_multimesh.set_instance_color(i, Color(1.0, 1.0, 1.0, alpha))

# Process method with organic movement
func _process(delta):
	if not ship_node:
		return
	
	# Try to get camera if we don't have it yet
	if _camera_node == null:
		_camera_node = ship_node.get_node_or_null(camera_path)
	
	# Calculate ship velocity
	var current_position = ship_node.global_position
	_ship_velocity = (current_position - _last_ship_position) / delta
	_last_ship_position = current_position
	
	# Update the MultiMeshInstance3D's position to stay with the ship
	global_position = ship_node.global_position
	
	# Update particle positions with organic movement
	for i in range(particle_count):
		# Move particles in the opposite direction of ship movement
		_particles_pos[i] -= _ship_velocity * reactivity_factor * delta
		
		# Add organic drift movement
		_particles_pos[i] += _particles_drift[i] * delta
		
		# Wrap particles that go outside the box
		if _particles_pos[i].x < -_half_box: _particles_pos[i].x += box_size
		if _particles_pos[i].x > _half_box: _particles_pos[i].x -= box_size
		
		if _particles_pos[i].y < -_half_box: _particles_pos[i].y += box_size
		if _particles_pos[i].y > _half_box: _particles_pos[i].y -= box_size
		
		if _particles_pos[i].z < -_half_box: _particles_pos[i].z += box_size
		if _particles_pos[i].z > _half_box: _particles_pos[i].z -= box_size
	
	# Update the multimesh with new positions
	_update_multimesh()

# Reset all particles to random positions
func reset_particles():
	for i in range(particle_count):
		_particles_pos[i] = Vector3(
			_rng.randf_range(-_half_box, _half_box),
			_rng.randf_range(-_half_box, _half_box),
			_rng.randf_range(-_half_box, _half_box)
		)
		# Optionally reset drift as well
		_particles_drift[i] = Vector3(
			_rng.randf_range(-1, 1),
			_rng.randf_range(-1, 1),
			_rng.randf_range(-1, 1)
		).normalized() * drift_intensity
	
	_update_multimesh()
