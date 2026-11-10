# Closed-Loop Thermal Tuning Controller for Silicon Photonic Modulators

A robust, multi-clock SystemVerilog System-on-Chip (SoC) architecture designed to dynamically regulate micro-heater power in silicon photonic modulators using a real-time peak-tracking hill-climbing algorithm. Built to demonstrate high-reliability hardware control, Clock Domain Crossing (CDC) safety, and low-latency digital design for advanced ASIC applications.

---

##  System Architecture

The SoC bridges two asynchronous clock domains securely using an Asynchronous FIFO:
1. **Control FSM (Slow Domain - 50 MHz):** Implements a hill-climbing optimization algorithm. It evaluates optical power feedback, determines gradient changes, decides whether to step thermal tuning power up or down, and pushes safe commands across clock domains.
2. **Asynchronous FIFO (CDC Bridge):** Utilizes multi-flop synchronizers and Gray-coded pointers to prevent metastability when passing data from the slow FSM clock domain to the fast driver clock domain.
3. **Sigma-Delta Modulator (Fast Domain - 250 MHz):** Converts multi-bit 8-bit power commands into a high-speed, 1-bit pulse-density modulated (PWM) hardware stream to drive the silicon micro-heater.


[ Optical Sensor ]
│ (16-bit Optical Power Feedback)
▼
┌─────────────────────────┐     Async FIFO      ┌──────────────────────────┐
│   Control FSM (50MHz)   │ ──(Gray-Code CDC)──>│ Sigma-Delta Modulator    │
│  (Hill-Climbing Logic)  │                     │  (250MHz PWM Generator)  │
└─────────────────────────┘                     └──────────────────────────┘
│
▼
[ Silicon Micro-Heater ]


---

## 📁 Repository Structure

* `rtl/` — SystemVerilog Hardware Description Language (HDL) modules
  * `fsm_controller.sv` — Hill-climbing optimization finite state machine
  * `async_fifo.sv` — Dual-clock asynchronous FIFO with Gray-code pointer synchronization
  * `sigma_delta.sv` — 1-bit pulse-density modulation (PDM) heater driver
  * `top_controller.sv` — Top-level SoC integration module
* `tb/` — Self-checking testbenches and verification components
  * `tb_fsm_controller.sv` — FSM algorithmic verification testbench
  * `tb_async_fifo.sv` — Dual-clock CDC stress testbench
  * `tb_top_controller.sv` — Full top-level system integration testbench
* `model/` — Software golden reference models
  * `golden_model.py` — Python model validating optical resonance curves (`numpy`, `matplotlib`)

---

## 🚀 Live Simulation & Verification

You can compile, simulate, and inspect waveforms for this entire hardware design directly in your browser using EDA Playground (powered by Icarus Verilog):
* **[Run Top-Level Simulation on EDA Playground](https://www.edaplayground.com)** *(Load `top_controller.sv` and `tb_top_controller.sv`)*

### Verification Results & Waveforms
* **CDC Safety:** Verified zero data corruption across clock domain boundaries via Gray-code pointer synchronization.
* **Closed-Loop Tracking:** Waveform analysis confirms the FSM successfully detects optical power peaks, reverses search direction upon performance degradation, and adapts 8-bit power commands dynamically.

---

## 🛠️ Tech Stack & Tools
* **Languages:** SystemVerilog (IEEE 1800), Python 3 (`NumPy`, `Matplotlib`)
* **Simulators & Tools:** Icarus Verilog, EPWave, VS Code, Git/GitHub
* **Design Patterns:** Finite State Machines, Dual-Clock Synchronizers, Pulse-Density Modulation
