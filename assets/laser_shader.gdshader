shader_type canvas_item; // Use spatial for 3D

// Parameters that you can adjust in the Inspector
uniform vec4 laser_color : source_color = vec4(1.0, 0.2, 0.2, 1.0); // Red laser by default
uniform float laser_speed : hint_range(0.1, 10.0) = 1.0;
uniform float laser_intensity : hint_range(1.0, 5.0) = 1.5;
uniform float laser_width : hint_range(0.1, 1.0) = 0.7;

void fragment() {
    // Create the base laser beam
    // We'll use UV.y to determine the width of the beam
    float beam_mask = smoothstep(laser_width, 0.0, abs(UV.y - 0.5) * 2.0);
    
    // Add some movement along the beam for that energy flow effect
    float time_offset = TIME * laser_speed;
    float energy_pulse = sin(UV.x * 20.0 + time_offset) * 0.5 + 0.5;
    
    // Small random variations in the beam intensity
    float noise_effect = fract(sin(dot(UV, vec2(12.9898, 78.233) + time_offset)) * 43758.5453);
    
    // Combine effects for the final beam
    float final_intensity = beam_mask * (1.0 + energy_pulse * 0.3 + noise_effect * 0.1);
    
    // Apply color and intensity
    COLOR = laser_color * final_intensity * laser_intensity;
    
    // Add glow effect at the center
    float glow = smoothstep(0.4, 0.0, abs(UV.y - 0.5) * 2.0);
    COLOR += laser_color * glow * 0.5;
}