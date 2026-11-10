# Closed-Loop Thermal Tuning Controller for Silicon Photonic Modulators

A multi-clock SystemVerilog hardware controller (IP subsystem) designed to dynamically regulate micro-heater power in silicon photonic modulators using a real-time peak-tracking hill-climbing algorithm. Built to demonstrate closed-loop digital control, Clock Domain Crossing (CDC) safety, and low-latency RTL design for optical transceiver ASICs.

---

## System Architecture

The controller bridges two asynchronous clock domains securely using an Asynchronous FIFO:

1. **Control FSM (Slow Domain - 50 MHz):** Implements a hill-climbing optimization algorithm. It evaluates 16-bit optical power feedback, tracks gradient changes, decides whether to step thermal tuning power up or down, and pushes 8-bit commands across clock domains.
2. **Asynchronous FIFO (CDC Bridge):** Utilizes 2-stage multi-flop synchronizers and Gray-coded pointers (`ADDR_WIDTH = 4`, 16 slots deep) to prevent metastability when passing multi-bit commands from the 50 MHz control domain to the 250 MHz driver domain.
3. **Sigma-Delta Modulator (Fast Domain - 250 MHz):** Converts 8-bit unsigned power commands into a high-speed, 1-bit Pulse-Density Modulated (PDM) hardware stream to drive the physical silicon micro-heater.

```text
 [ Optical Sensor ] 
         │ (16-bit Optical Power Feedback)
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

Before implementing the hardware FSM, the hill-climbing algorithm, optical Lorentzian resonance curve, and silicon thermal lag were modeled in Python using `NumPy` and `Matplotlib`.

<img width="1247" height="768" alt="Golden Model Dashboard" src="https://github.com/user-attachments/assets/5713ecd0-ecd6-4540-a31a-6fa18e4b2e0a" />

* **Design Insight:** The Python simulation revealed that an unfiltered hill-climbing algorithm is susceptible to high-frequency photodiode noise (false local maxima). In a production ASIC datapath, this motivates placing a digital low-pass filter (such as a parameterized Moving Average filter) upstream of the FSM.

---

## 📁 Repository Structure

* `rtl/` — SystemVerilog Hardware Description Language (HDL) modules
  * `fsm_controller.sv` — 4-state (`IDLE`, `MEASURE`, `ADJUST`, `WRITE_FIFO`) hill-climbing optimization FSM
  * `async_fifo.sv` — Dual-clock asynchronous FIFO with Gray-code pointer synchronization and **SystemVerilog Assertions (SVA)**
  * `sigma_delta.sv` — 1st-order accumulator-based 1-bit Pulse-Density Modulation (PDM) heater driver
  * `top_controller.sv` — Top-level hardware controller integration module
* `tb/` — Verification testbenches
  * `tb_sigma_delta.sv` — PDM duty-cycle and accumulator overflow verification testbench
  * `tb_async_fifo.sv` — Dual-clock CDC pointer synchronization and boundary testbench
  * `tb_fsm_controller.sv` — Directed optical peak-tracking verification testbench
  * `tb_top_controller.sv` — Full closed-loop multi-clock integration testbench
* `model/` — Software golden reference model
  * `golden_model.py` — Python physical plant and thermal lag simulator (`numpy`, `matplotlib`)
* `Makefile` — Automated compilation and simulation script for Icarus Verilog (`iverilog` / `vvp`)

---

##  Live Simulation & Verification

You can compile, simulate, and inspect the `.vcd` waveforms for this entire design directly in your browser using EDA Playground:
* **[Run Top-Level Simulation on EDA Playground](https://www.edaplayground.com/x/MxkB)**

### Verification Highlights
* **SystemVerilog Assertions (SVA):** Concurrent assertions embedded in `async_fifo.sv` continuously monitor write-domain boundaries (`@(posedge wclk) disable iff (!wrst_n) wfull |-> !winc`) to guarantee zero FIFO overflow across clock domains.
* **CDC Synchronization:** Verified clean pointer transitions across the asynchronous 50 MHz to 250 MHz boundary using Gray-code encoding (`(bin >> 1) ^ bin`) so at most 1 bit changes per clock edge.
* **Gradient Tracking:** EPWave waveform inspection confirms `u_fsm` steps `current_heater` upward as optical power increases (`1000 -> 1200 -> 1500`) and reverses `search_dir` within one state cycle when optical power drops (`1500 -> 1300`).

---

##  Tech Stack & Tools
* **Languages:** SystemVerilog (IEEE 1800-2012), Python 3 (`NumPy`, `Matplotlib`)
* **Simulators & Waveform Viewers:** Icarus Verilog, EPWave, Make
* **Core Concepts:** Finite State Machines (FSM), Clock Domain Crossing (CDC), Gray-Code FIFOs, Pulse-Density Modulation (PDM), SystemVerilog Assertions (SVA)
