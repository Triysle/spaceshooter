extends CanvasLayer

# UI Element References
@onready var status_label = $Background/VBoxContainer/StatusLabel
@onready var speed_label = $Background/VBoxContainer/SpeedLabel
@onready var orientation_label = $Background/VBoxContainer/OrientationLabel
@onready var energy_bar = $Background/VBoxContainer/EnergyBar

# Ship Reference
var ship: Node3D = null

# Update Timing - reduced frequency to save performance
var update_interval: float = 0.1  # Update 10 times per second
var update_timer: float = 0.0

# State caching for performance
var last_boost_state = false
var last_dampers_state = false
var last_mode_state = false
var last_speed = 0.0
var last_pitch = 0.0
var last_yaw = 0.0
var last_energy = 0.0

func _ready():
	# Initial setup of labels
	status_label.text = "SYSTEM ONLINE"
	speed_label.text = "SPEED: 0 m/s"
	orientation_label.text = "ORIENTATION: 0°, 0°"
	
	# Set up energy bar (if it exists)
	if energy_bar:
		energy_bar.min_value = 0
		energy_bar.max_value = 100
		energy_bar.value = 100

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
	print("HUD Ship Reference Set: ", ship)
	
	# Connect to energy changed signal if available
	if ship.has_signal("energy_changed"):
		ship.connect("energy_changed", Callable(self, "_on_ship_energy_changed"))

func update_hud_elements():
	# Safety check for ship reference
	if not ship:
		print("Warning: No ship reference in HUD")
		return
	
	# Get current status - check for changes to avoid unnecessary updates
	var boost_state = ship.boost_active
	var dampers_state = ship.dampers_active
	var mode_state = ship.decoupled_mode
	
	# Only update the status label if something changed
	if (boost_state != last_boost_state or 
		dampers_state != last_dampers_state or 
		mode_state != last_mode_state
		):
		
		status_label.text = "BOOST: %s | DAMPERS: %s | MODE: %s" % [
			"ON" if boost_state else "OFF",
			"ON" if dampers_state else "OFF",
			"DECOUPLED" if mode_state else "COUPLED",
		]
		
		# Update cached states
		last_boost_state = boost_state
		last_dampers_state = dampers_state
		last_mode_state = mode_state
	
	# Calculate speed
	var current_speed = ship.velocity.length()
	
	# Only update speed if it changed significantly (threshold of 0.1)
	if abs(current_speed - last_speed) > 0.1:
		speed_label.text = "SPEED: %.1f m/s" % current_speed
		last_speed = current_speed
	
	# Calculate orientation
	var forward = -ship.global_transform.basis.z
	var pitch = rad_to_deg(asin(clamp(forward.y, -1.0, 1.0)))
	var yaw = rad_to_deg(atan2(forward.x, forward.z))
	
	# Only update orientation if pitch or yaw changed significantly (threshold of 0.5 degrees)
	if abs(pitch - last_pitch) > 0.5 or abs(yaw - last_yaw) > 0.5:
		orientation_label.text = "PITCH: %.1f° | YAW: %.1f°" % [pitch, yaw]
		last_pitch = pitch
		last_yaw = yaw
	
	# Update energy bar the standard way (as a fallback if signal not connected)
	if energy_bar and ship.has_method("get_energy_percentage"):
		var energy_percentage = ship.get_energy_percentage()
		if abs(energy_percentage - last_energy) > 0.5:
			energy_bar.value = energy_percentage
			last_energy = energy_percentage
			
			# Color the bar based on energy level
			if energy_percentage < 25:
				energy_bar.modulate = Color(1.0, 0.3, 0.3)  # Red when low
			elif energy_percentage < 50:
				energy_bar.modulate = Color(1.0, 0.8, 0.3)  # Yellow/orange when medium
			else:
				energy_bar.modulate = Color(0.3, 1.0, 0.3)  # Green when high

# Signal handler for ship energy changes
# More efficient than polling every frame
func _on_ship_energy_changed(current: float, maximum: float):
	if energy_bar:
		var energy_percentage = (current / maximum) * 100.0
		energy_bar.value = energy_percentage
		last_energy = energy_percentage
		
		# Color the bar based on energy level
		if energy_percentage < 25:
			energy_bar.modulate = Color(1.0, 0.3, 0.3)  # Red when low
		elif energy_percentage < 50:
			energy_bar.modulate = Color(1.0, 0.8, 0.3)  # Yellow/orange when medium
		else:
			energy_bar.modulate = Color(0.3, 1.0, 0.3)  # Green when high
