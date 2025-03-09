extends CanvasLayer

# UI Element References
@onready var status_label = $VBoxContainer/StatusLabel
@onready var speed_label = $VBoxContainer/SpeedLabel
@onready var orientation_label = $VBoxContainer/OrientationLabel

# Ship Reference
var ship: Node3D = null

# Update Timing
var update_interval: float = 0.1  # Update 10 times per second
var update_timer: float = 0.0

func _ready():
	# Initial setup of labels
	status_label.text = "SYSTEM ONLINE"
	speed_label.text = "SPEED: 0 m/s"
	orientation_label.text = "ORIENTATION: 0°, 0°"

func _process(delta):
	# Reduce update frequency for performance
	update_timer += delta
	if update_timer < update_interval:
		return
	
	update_timer = 0.0
	
	# Only update if ship is set
	if ship:
		update_hud_elements()

func set_ship(target_ship: Node3D):
	ship = target_ship
	
	# Optional: Verify ship has expected properties
	if not ship.has_method("get_velocity"):
		push_warning("Ship does not have expected methods!")

func update_hud_elements():
	# Update status text
	status_label.text = "BOOST: {boost} | DAMPERS: {dampers} | MODE: {mode}".format({
		"boost": "ON" if ship.boost_active else "OFF",
		"dampers": "ON" if ship.dampers_active else "OFF",
		"mode": "COUPLED" if not ship.decoupled_mode else "DECOUPLED"
	})
	
	# Calculate speed
	var current_speed = ship.velocity.length()
	
	# Calculate orientation
	var forward = -ship.global_transform.basis.z
	var pitch = rad_to_deg(asin(clamp(forward.y, -1.0, 1.0)))
	var yaw = rad_to_deg(atan2(forward.x, forward.z))
	
	# Update labels with precise formatting
	speed_label.text = "SPEED: %.1f m/s" % current_speed
	orientation_label.text = "PITCH: %.1f° | YAW: %.1f°" % [pitch, yaw]

# Optional: Color coding for different states
func get_speed_color(speed: float) -> Color:
	var max_speed = ship.max_drift_speed if ship else 20.0
	var speed_ratio = speed / max_speed
	
	if speed_ratio < 0.3:
		return Color.GREEN
	elif speed_ratio < 0.7:
		return Color.YELLOW
	else:
		return Color.RED

# Optional: Add warning or alert methods
func show_warning(message: String, duration: float = 2.0):
	# Temporary warning display logic
	pass
