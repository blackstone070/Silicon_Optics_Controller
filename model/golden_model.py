import numpy as np
import matplotlib.pyplot as plt

# --- 1. THE PHYSICS ENGINE (PLANT MODEL) ---
def simulate_optical_resonance(temperature, optimal_temp=50.0):
    # Gaussian curve: Light intensity peaks perfectly at optimal_temp
    # Output ranges from 0.0 (no light) to 1.0 (perfect lock)
    return np.exp(-((temperature - optimal_temp) ** 2) / 20.0)

# --- 2. THE SIMULATION SETUP ---
time_steps = 200
heater_power = 20.0       # FSM starting guess (way off target)
actual_temperature = 20.0 # Silicon starts cold
thermal_inertia = 0.2     # How fast the silicon heats up (0.0 to 1.0)

# FSM Memory variables
prev_intensity = 0.0
step_direction = 1.0      # +1 for hotter, -1 for cooler
step_size = 1.5           # How aggressively the FSM turns the knob

# Data arrays for the dashboard
history_temp = []
history_intensity = []
history_heater = []

# --- 3. THE CONTROL LOOP (FSM + THERMAL LAG) ---
for t in range(time_steps):
    # A. Thermal Physics: Temperature slowly catches up to heater power
    actual_temperature += (heater_power - actual_temperature) * thermal_inertia
    
    # B. Read the Photodiode (with a tiny bit of random sensor noise)
    noise = np.random.normal(0, 0.01)
    current_intensity = simulate_optical_resonance(actual_temperature) + noise
    
    # C. The FSM Hill-Climbing Logic (The Brain)
    if current_intensity < prev_intensity:
        # We stepped the wrong way and lost light! Reverse direction.
        step_direction *= -1.0 
    
    # Apply the new heater step for the next cycle
    heater_power += (step_direction * step_size)
    
    # Save current state for the next cycle's comparison
    prev_intensity = current_intensity
    
    # Log data for the plot
    history_temp.append(actual_temperature)
    history_intensity.append(current_intensity)
    history_heater.append(heater_power)

# --- 4. PLOTTING THE DASHBOARD ---
plt.figure(figsize=(10, 6))

# Top Plot: The Light Signal
plt.subplot(2, 1, 1)
plt.plot(history_intensity, label="Optical Intensity (Lock)", color='purple', linewidth=2)
plt.title("Photodiode Output (Seeking Maximum Light)")
plt.ylabel("Light Intensity")
plt.grid(True)
plt.legend(loc="lower right")

# Bottom Plot: The Heater and Temperature
plt.subplot(2, 1, 2)
plt.plot(history_heater, label="Heater Power Command (FSM Output)", color='red', linestyle='--')
plt.plot(history_temp, label="Actual Silicon Temp (Thermal Lag)", color='orange', linewidth=2)
plt.axhline(y=50.0, color='green', linestyle=':', label="Target Optimal Temp")
plt.title("Controller & Thermal Physics")
plt.xlabel("Time Steps (Simulation Cycles)")
plt.ylabel("Temperature / Power Level")
plt.grid(True)
plt.legend(loc="lower right")

plt.tight_layout()
plt.show()