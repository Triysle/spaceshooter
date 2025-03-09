extends Node3D

signal asteroid_spawned(asteroid, size)

@export var small_asteroid_scene: PackedScene
@export var medium_asteroid_scene: PackedScene
@export var large_asteroid_scene: PackedScene
@export var huge_asteroid_scene: PackedScene
@export var spawn_radius: float = 1000.0
@export var min_distance_from_player: float = 10.0
@export var asteroid_counts: Dictionary = {
	"small": 10,
	"medium": 6,
	"large": 3,
	"huge": 1
}
@export var min_speed: float = 0.1
@export var max_speed: float = 0.3
@export var gradual_spawn: bool = false
@export var spawn_interval: float = 2.0
@export var max_spawn_attempts: int = 100

var asteroid_instances = []
var player_position: Vector3
var asteroid_sizes = {
	"small": 50.0,
	"medium": 200.0,
	"large": 1000.0,
	"huge": 25000.0
}
var spawn_queue = []
var spawn_timer: float = 0.0
var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	player_position = get_tree().get_first_node_in_group("player").global_transform.origin
	
	# Pre-calculate optimal spawn positions for larger asteroids
	if gradual_spawn:
		prepare_spawn_queue()
	else:
		spawn_all_asteroids()

func _process(delta):
	if gradual_spawn and not spawn_queue.empty():
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			var size = spawn_queue.pop_front()
			spawn_asteroid(size)

func prepare_spawn_queue():
	var sorted_sizes = ["huge", "large", "medium", "small"]
	for size in sorted_sizes:
		for i in range(asteroid_counts[size]):
			spawn_queue.append(size)

func spawn_all_asteroids():
	# First, create a distribution plan
	var sorted_sizes = ["huge", "large", "medium", "small"]
	var total_attempts = 0
	var success_count = 0
	
	for size in sorted_sizes:
		var target_count = asteroid_counts[size]
		var spawned_count = 0
		print("Attempting to spawn ", target_count, " ", size, " asteroids")
		
		while spawned_count < target_count and total_attempts < max_spawn_attempts * target_count:
			if spawn_asteroid(size):
				spawned_count += 1
				success_count += 1
			total_attempts += 1
		
		print("Successfully spawned ", spawned_count, " of ", target_count, " ", size, " asteroids")
	
	print("Spawn complete. Successfully placed ", success_count, " asteroids after ", total_attempts, " attempts")

func spawn_asteroid(size: String) -> bool:
	var asteroid_scene = get_asteroid_scene(size)
	if not asteroid_scene:
		push_warning("No asteroid scene found for size: " + size)
		return false
	
	var asteroid_radius = asteroid_sizes[size]
	var valid_position = false
	var spawn_position
	var max_attempts = int(max_spawn_attempts)
	var attempts = 0
	
	# For larger asteroids, try more positions and use a different strategy
	if size == "huge" or size == "large":
		while not valid_position and attempts < max_attempts:
			# For huge/large asteroids, spread them out more evenly
			spawn_position = get_strategic_position(asteroid_radius, size, attempts)
			valid_position = is_position_valid(spawn_position, asteroid_radius)
			attempts += 1
	else:
		while not valid_position and attempts < max_attempts:
			spawn_position = get_random_spherical_position(asteroid_radius)
			valid_position = is_position_valid(spawn_position, asteroid_radius)
			attempts += 1
	
	if not valid_position:
		push_warning("Failed to find valid position for " + size + " asteroid after " + str(attempts) + " attempts.")
		return false
	
	var asteroid = asteroid_scene.instantiate()
	add_child(asteroid)
	asteroid.global_transform.origin = spawn_position
	
	# Find the RigidBody3D component if it exists
	var rigid_body = null
	if asteroid is RigidBody3D:
		rigid_body = asteroid
	else:
		# Try to find a child that is a RigidBody3D
		for child in asteroid.get_children():
			if child is RigidBody3D:
				rigid_body = child
				break
	
	if rigid_body:
		# Random velocity
		var random_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(min_speed, max_speed)
		rigid_body.linear_velocity = random_velocity
		
		# Random rotation
		rigid_body.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	else:
		push_warning("No RigidBody3D found in asteroid. Cannot set velocity.")
	
	asteroid_instances.append({
		"position": spawn_position, 
		"radius": asteroid_radius, 
		"instance": asteroid,
		"size": size
	})
	
	emit_signal("asteroid_spawned", asteroid, size)
	return true

func get_strategic_position(asteroid_radius: float, size: String, attempt_number: int) -> Vector3:
	# For first few attempts at huge/large asteroids, try to place them in strategic locations
	if attempt_number < 8:
		# Create a set of "optimal" positions based on octants of the sphere
		var octant_directions = [
			Vector3(1, 1, 1),
			Vector3(1, 1, -1),
			Vector3(1, -1, 1),
			Vector3(1, -1, -1),
			Vector3(-1, 1, 1),
			Vector3(-1, 1, -1),
			Vector3(-1, -1, 1),
			Vector3(-1, -1, -1)
		]
		
		var octant = octant_directions[attempt_number % octant_directions.size()].normalized()
		var min_distance = min_distance_from_player + asteroid_radius * 2
		var max_distance = spawn_radius * 0.8  # Keep them slightly more centered
		var distance = lerp(min_distance, max_distance, 0.5)  # Middle of the range
		
		return octant * distance
	else:
		# After trying optimal positions, fall back to random positions
		return get_random_spherical_position(asteroid_radius)

func get_asteroid_scene(size: String) -> PackedScene:
	match size:
		"small": return small_asteroid_scene
		"medium": return medium_asteroid_scene
		"large": return large_asteroid_scene
		"huge": return huge_asteroid_scene
	return null

func get_random_spherical_position(asteroid_radius: float) -> Vector3:
	var scaled_radius = spawn_radius
	
	# Generate points on a sphere
	var theta = rng.randf() * TAU  # Azimuthal angle
	var phi = acos(2.0 * rng.randf() - 1.0)  # Polar angle for uniform distribution
	
	var x = sin(phi) * cos(theta)
	var y = sin(phi) * sin(theta)
	var z = cos(phi)
	
	var direction = Vector3(x, y, z).normalized()
	
	# For a hollow sphere distribution (on the surface)
	# return direction * scaled_radius
	
	# For a solid sphere distribution (anywhere inside)
	var distance_factor = pow(rng.randf(), 1.0/3.0)  # Cube root for uniform volume distribution
	var min_distance = min_distance_from_player + asteroid_radius * 1.5
	var distance = lerp(min_distance, scaled_radius, distance_factor)
	
	return direction * distance

func is_position_valid(pos: Vector3, radius: float) -> bool:
	var buffer = radius * 1.1  # Slightly increased buffer
	
	# Check distance from player
	if pos.distance_to(player_position) < (min_distance_from_player + buffer):
		return false
	
	# Check distance from other asteroids with size-based priority
	for asteroid in asteroid_instances:
		var combined_radius = asteroid["radius"] + radius
		var min_separation = combined_radius * 1.1  # Allow some overlap for smaller asteroids
		
		if pos.distance_to(asteroid["position"]) < min_separation:
			return false
	
	return true

func get_all_asteroids() -> Array:
	return asteroid_instances

func clear_all_asteroids():
	for asteroid_data in asteroid_instances:
		if asteroid_data.has("instance") and is_instance_valid(asteroid_data["instance"]):
			asteroid_data["instance"].queue_free()
	
	asteroid_instances.clear()

func get_asteroid_count(size: String = "") -> int:
	if size.is_empty():
		return asteroid_instances.size()
	
	var count = 0
	for asteroid in asteroid_instances:
		if asteroid["size"] == size:
			count += 1
	return count
