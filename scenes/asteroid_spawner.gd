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

# Precomputed values
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

# Cache references to asteroid scenes
var asteroid_scenes = {}

func _ready():
	rng.randomize()
	player_position = get_tree().get_first_node_in_group("player").global_transform.origin
	
	# Cache all asteroid scenes in a dictionary for faster lookup
	asteroid_scenes = {
		"small": small_asteroid_scene,
		"medium": medium_asteroid_scene,
		"large": large_asteroid_scene,
		"huge": huge_asteroid_scene
	}
	
	# Normalize octant directions once
	for i in range(octant_directions.size()):
		octant_directions[i] = octant_directions[i].normalized()
	
	# Pre-calculate spawn queue or spawn all asteroids
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
	var sorted_sizes = ["huge", "large", "medium", "small"]
	var total_attempts = 0
	var success_count = 0
	
	for size in sorted_sizes:
		var target_count = asteroid_counts[size]
		var spawned_count = 0
		print("Attempting to spawn ", target_count, " ", size, " asteroids")
		
		var size_max_attempts = max_spawn_attempts * target_count
		while spawned_count < target_count and total_attempts < size_max_attempts:
			if spawn_asteroid(size):
				spawned_count += 1
				success_count += 1
			total_attempts += 1
		
		print("Successfully spawned ", spawned_count, " of ", target_count, " ", size, " asteroids")
	
	print("Spawn complete. Successfully placed ", success_count, " asteroids after ", total_attempts, " attempts")

func spawn_asteroid(size: String) -> bool:
	var asteroid_scene = asteroid_scenes[size]
	if not asteroid_scene:
		push_warning("No asteroid scene found for size: " + size)
		return false
	
	var asteroid_radius = asteroid_sizes[size]
	var valid_position = false
	var spawn_position
	var attempt_limit = int(max_spawn_attempts)
	var attempts = 0
	
	# Optimize position finding based on asteroid size
	if size == "huge" or size == "large":
		while not valid_position and attempts < attempt_limit:
			spawn_position = get_strategic_position(asteroid_radius, attempts)
			valid_position = is_position_valid(spawn_position, asteroid_radius)
			attempts += 1
	else:
		while not valid_position and attempts < attempt_limit:
			spawn_position = get_random_spherical_position(asteroid_radius)
			valid_position = is_position_valid(spawn_position, asteroid_radius)
			attempts += 1
	
	if not valid_position:
		push_warning("Failed to find valid position for " + size + " asteroid after " + str(attempts) + " attempts.")
		return false
	
	var asteroid = asteroid_scene.instantiate()
	add_child(asteroid)
	asteroid.global_transform.origin = spawn_position
	
	# Find the RigidBody3D component
	var rigid_body
	if asteroid is RigidBody3D:
		rigid_body = asteroid
	else:
		# More efficient child scanning using explicit type checking
		for child in asteroid.get_children():
			if child is RigidBody3D:
				rigid_body = child
				break
	
	if rigid_body:
		# Random velocity - reuse calculations where possible
		var random_dir = Vector3(
			randf_range(-1, 1), 
			randf_range(-1, 1), 
			randf_range(-1, 1)
		).normalized()
		
		rigid_body.linear_velocity = random_dir * randf_range(min_speed, max_speed)
		rigid_body.angular_velocity = Vector3(
			randf_range(-1, 1), 
			randf_range(-1, 1), 
			randf_range(-1, 1)
		)
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

func get_strategic_position(asteroid_radius: float, attempt_number: int) -> Vector3:
	# Use precomputed octant directions for first attempts
	if attempt_number < 8:
		var octant = octant_directions[attempt_number]
		var min_distance = min_distance_from_player + asteroid_radius * 2
		var max_distance = spawn_radius * 0.8
		var distance = (min_distance + max_distance) * 0.5  # Simplified lerp calculation
		
		return octant * distance
	else:
		# After trying optimal positions, fall back to random positions
		return get_random_spherical_position(asteroid_radius)

func get_asteroid_scene(size: String) -> PackedScene:
	return asteroid_scenes[size]

func get_random_spherical_position(asteroid_radius: float) -> Vector3:
	# Generate points on a sphere using more efficient calculation
	var theta = rng.randf() * TAU
	var phi = acos(2.0 * rng.randf() - 1.0)
	
	var sin_phi = sin(phi)
	var x = sin_phi * cos(theta)
	var y = sin_phi * sin(theta)
	var z = cos(phi)
	
	var direction = Vector3(x, y, z)  # Already normalized by the math
	
	# Calculate distance with uniform volume distribution
	var distance_factor = pow(rng.randf(), 1.0/3.0)
	var min_distance = min_distance_from_player + asteroid_radius * 1.5
	var distance = min_distance + (spawn_radius - min_distance) * distance_factor
	
	return direction * distance

func is_position_valid(pos: Vector3, radius: float) -> bool:
	var buffer = radius * 1.1
	
	# Check distance from player
	if pos.distance_to(player_position) < (min_distance_from_player + buffer):
		return false
	
	# Check distance from other asteroids with early termination on failure
	var min_separation
	for asteroid in asteroid_instances:
		min_separation = (asteroid["radius"] + radius) * 1.1
		
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
