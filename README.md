# Digital Lock with Status Display

A digital lock system implemented using **Verilog HDL** and deployed on the **DE2-115 FPGA development board**. The project demonstrates RTL design, simulation, synthesis, and hardware implementation of a simple password-based digital locking system.

## Overview

The system allows a predefined password to be entered using the available inputs on the DE2-115 board. The entered combination is compared with the stored password, and the system indicates whether the lock is successfully unlocked or remains locked.

The project was developed as a practical application of **digital logic design and FPGA-based system implementation**.

## Features

* Password-based digital locking mechanism
* Lock and unlock state control
* Status indication for the current lock state
* Verilog HDL-based RTL implementation
* Functional simulation and verification
* FPGA synthesis and hardware implementation

## Hardware

* **DE2-115 Development Board**
* Intel/Altera **Cyclone IV E FPGA**
* On-board switches/buttons for user input
* On-board LEDs/display for status indication

## Software & Tools

* **Verilog HDL**
* **Intel Quartus Prime**
* **ModelSim**

## System Workflow

```text
User Input
    ↓
Input Processing
    ↓
Password Comparison
    ↓
Lock Control Logic
    ↓
┌───────────────┐
│               │
Locked      Unlocked
│               │
└───────┬───────┘
        ↓
  Status Display
```

## Design

The system is implemented using synchronous digital logic. User inputs are processed by the control logic and compared against the predefined password. Based on the comparison result, the system transitions between the locked and unlocked states and updates the corresponding status outputs.

The design was first simulated to verify the functionality of the RTL modules before being synthesized and programmed onto the DE2-115 FPGA.

## Verification

The design was verified using simulation in **ModelSim** to test the different input combinations and lock states.

The implementation was then synthesized using **Quartus Prime** and deployed on the DE2-115 board for hardware-level testing.

## Results

The digital lock was successfully synthesized and implemented on the DE2-115 FPGA. The lock state and corresponding status outputs were validated using the board's available input and output peripherals.

## Skills Demonstrated

* RTL Design
* Verilog HDL
* Digital Logic Design
* FPGA Design
* Testbench Development
* Functional Simulation
* RTL Verification
* FPGA Synthesis
* Quartus Prime
* ModelSim

