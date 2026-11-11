# Closed-Loop Thermal Tuning Controller for Silicon Photonic Modulators

A multi-clock SystemVerilog hardware controller (IP subsystem) designed to dynamically regulate micro-heater power in silicon photonic modulators using a real-time peak-tracking hill-climbing algorithm. Built to demonstrate closed-loop digital control, Clock Domain Crossing (CDC) safety, hardware noise filtering, and self-checking verification for optical transceiver ASICs.

---

##  System Architecture

The controller bridges two asynchronous clock domains securely using an Asynchronous FIFO and includes an upstream digital low-pass filter to mitigate photodiode noise:

1. **Moving Average Filter (Slow Domain - 50 MHz):** A parameterized 4-tap (`WINDOW_LOG2 = 2`) digital low-pass filter that strips high-frequency photodiode noise in $O(1)$ hardware time using zero-gate-delay bit-shifting (`sum >> 2`).
2. **Control FSM (Slow Domain - 50 MHz):** Implements a 4-state (`IDLE`, `MEASURE`, `ADJUST`, `WRITE_FIFO`) hill-climbing optimization algorithm with pipeline settling control. Evaluates filtered 16-bit optical power feedback, tracks gradient reversals, and pushes 8-bit heater commands across clock domains.
3. **Asynchronous FIFO (CDC Bridge):** Utilizes 2-stage multi-flop synchronizers and registered Gray-coded pointers (`ADDR_WIDTH = 4`, 16 slots deep) to prevent metastability and combinational feedback loops when crossing from the 50 MHz control domain to the 250 MHz driver domain.
4. **Sigma-Delta Modulator (Fast Domain - 250 MHz):** Converts 8-bit unsigned power commands into a high-speed, 1-bit Pulse-Density Modulated (PDM) hardware stream to drive the physical silicon micro-heater.

```text
 [ Optical Sensor ] 
         │ (Noisy 16-bit Optical Power Feedback)
         ▼
┌─────────────────────────┐
│  Moving Average Filter  │ (4-Tap Digital Low-Pass Filter, 50MHz)
└─────────────────────────┘
         │ (Filtered 16-bit Optical Power)
         ▼
┌─────────────────────────┐     Async FIFO      ┌──────────────────────────┐
│   Control FSM (50MHz)   │ ──(Gray-Code CDC)──>│ Sigma-Delta Modulator    │
│  (Hill-Climbing Logic)  │                     │  (250MHz PDM Generator)  │
└─────────────────────────┘                     └──────────────────────────┘
                                                             │
                                                             ▼
                                                    [ Silicon Micro-Heater ]
```

---

## Software Golden Model (Algorithm Proof)

Before implementing the hardware RTL, the hill-climbing algorithm, optical Lorentzian resonance curve, and silicon thermal lag were modeled in Python using `NumPy` and `Matplotlib`.

<img width="1247" height="768" alt="Golden Model Dashboard" src="https://github.com/user-attachments/assets/5713ecd0-ecd6-4540-a31a-6fa18e4b2e0a" />

* **Design Insight:** The Python simulation revealed that an unfiltered hill-climbing algorithm is vulnerable to high-frequency photodiode noise (false local maxima). This directly motivated the architectural addition of `moving_average.sv` upstream of the FSM in the RTL datapath.

---

## 📁 Repository Structure

* `rtl/` — SystemVerilog Hardware Description Language (HDL) modules
  * `moving_average.sv` — Parameterized 4-tap digital low-pass filter (`O(1)` running sum + right-shift divide)
  * `fsm_controller.sv` — Hill-climbing optimization finite state machine with pipeline settling counter
  * `async_fifo.sv` — Dual-clock asynchronous FIFO with Gray-code pointers and embedded overflow/underflow SVA checks
  * `sigma_delta.sv` — 1st-order accumulator-based 1-bit Pulse-Density Modulation (PDM) heater driver
  * `top_controller.sv` — Top-level hardware controller integration module
* `tb/` — Self-checking verification testbenches
  * `tb_top_controller.sv` — Closed-loop SystemVerilog `real` physical plant model, automated CDC queue scoreboard, assertions, and functional coverage collector
  * `tb_fsm_controller.sv` — Directed FSM peak-tracking testbench
  * `tb_async_fifo.sv` — Dual-clock CDC pointer synchronization testbench
  * `tb_sigma_delta.sv` — PDM duty-cycle verification testbench
* `model/` — Software golden reference model
  * `golden_model.py` — Python physical plant and thermal lag simulator (`numpy`, `matplotlib`)
* `Makefile` — Automated compilation and simulation regression script (`iverilog` / `vvp`)

---

## 🚀 Live Simulation & Verification Results

You can run the closed-loop verification environment and inspect the `.vcd` waveforms directly in your browser on EDA Playground:
* **[Run Closed-Loop Simulation on EDA Playground](https://www.edaplayground.com/x/MxkB)**

### Closed-Loop Verification & Coverage Log
`tb_top_controller.sv` closes the loop in SystemVerilog using `real` data types to model Newton's law of thermal lag, a Lorentzian optical resonance curve, and $\pm 450$ units of high-frequency photodiode noise across dynamic temperature step changes (`55.0 °C` $\rightarrow$ `72.0 °C`):

```text
================================================================
 STARTING CLOSED-LOOP VERIFICATION (SV REAL PLANT + SCOREBOARD)
================================================================
[TEST 1] Target Temp: 55.0 C | Reached Temp: 55.1 C | Filtered Power: 49971 / 50000
[TEST 2] Target Temp: 72.0 C | Reached Temp: 72.1 C | Filtered Power: 49992 / 50000
================================================================
                 VERIFICATION & COVERAGE SUMMARY                
================================================================
 CDC Transactions Verified : 200 words (0 corruption)
 FSM State Coverage        : 100.0% (1111)
 Gradient Reversal Covered : YES (100%)
 Resonance Lock Achieved   : YES (>90% Peak)
 Total Assertion Errors    : 0
 FINAL RESULT              : PASS
================================================================
```

### Verification Highlights
* **Real-Number Plant Modeling (`real`):** Models continuous silicon thermal lag (`thermal_alpha = 0.85`) and Lorentzian optical intensity dynamically on every clock edge.
* **Self-Checking CDC Scoreboard:** A queue-based scoreboard (`cdc_scoreboard[$]`) monitors every write in the 50 MHz domain and verifies bit-accurate readout in the 250 MHz domain across **200 transactions with 0 data corruption**.
* **SystemVerilog Assertions (SVA):** Continuous boundary checks verify zero FIFO overflow (`wfull && winc`) and zero FIFO underflow (`rempty && rinc`).
* **Real-World Bug Caught During Verification:** The scoreboard caught a zero-time combinational feedback loop between `assign rinc = ~rempty` and `rptr_gray_next` in `async_fifo.sv`, which was resolved by comparing registered Gray pointers (`rptr_gray == rq2_wptr`).

---

##  Tech Stack & Tools
* **Languages:** SystemVerilog (IEEE 1800-2012), Python 3 (`NumPy`, `Matplotlib`)
* **Simulators & Waveform Viewers:** Icarus Verilog 12.0, EPWave, GNU Make
* **Core Concepts:** Closed-Loop Control, Real-Number Modeling, Clock Domain Crossing (CDC), Gray-Code FIFOs, Pulse-Density Modulation (PDM), Scoreboards, SystemVerilog Assertions (SVA), Functional Coverage
