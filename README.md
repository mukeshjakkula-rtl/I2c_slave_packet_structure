# Basic I2C Slave Packet Receiver FSM

A robust SystemVerilog implementation of an **I2C-style Slave Receiver**. This module utilizes a Finite State Machine (FSM) to decode serial data (SDL/SCL) into Address, Command, and Data packets, providing real-time status flags for ACKs and protocol errors.

---

## Overview

This design implements a slave device that monitors a serial bus. Unlike traditional I2C slaves that might use SCL as a clock, this module uses a high-frequency system `clk` to oversample the bus. This allows for reliable edge detection and prevents glitches from affecting the state transitions.

### Key Features
* **Synchronous Edge Detection:** Uses a high-speed system clock to sample `sdl` and `scl`.
* **8-Bit Packet Handling:** Processes 8-bit Address, 8-bit Command, and 8-bit Data segments.
* **Protocol Violation Detection:** The `error` flag triggers if a `STOP` condition occurs prematurely during the `DATA` phase.
* **Automatic Acknowledgment:** Logic automatically asserts `ack` during the `ADDR_ACK`, `CMD_ACK`, and `DATA_ACK` states.

---

## FSM Architecture

The receiver operates using a 7-state Finite State Machine:

1.  **IDLE**: Waiting for the `START` condition (`SCL` high, `SDL` falling).
2.  **ADDR**: Sampling 8 bits of Address on `SCL` rising edges.
3.  **ADDR_ACK**: Holding state for one clock cycle to acknowledge the address.
4.  **CMD**: Sampling 8 bits of Command/Instruction data.
5.  **CMD_ACK**: Acknowledging the command reception.
6.  **DATA**: Serializing data out via `data_out` on `SCL` rising edges.
7.  **DATA_ACK**: Final acknowledgment phase before returning to `IDLE` or `ADDR` (Repeated Start).

---

## Signal Interface

| Signal | Direction | Description |
| :--- | :--- | :--- |
| `clk` | Input | High-speed system clock (Oversampling). |
| `rst` | Input | Asynchronous active-low reset. |
| `sdl` | Input | Serial Data Line (SDA equivalent). |
| `scl` | Input | Serial Clock Line. |
| `ack` | Output | Active-high signal indicating an acknowledgment phase. |
| `error` | Output | High if a `STOP` occurs unexpectedly during a transfer. |
| `data_out` | Output | Serial data bit shifted out during the `DATA` state. |

---

## Implementation Details

### Edge Detection Logic
The module uses a helper `delay` module to create a 1-clock-cycle delayed version of the bus lines. This enables the following logic:
* **Start Condition:** `assign start = (scl && (~sdl & sdl_delay));`
* **Stop Condition:** `assign stop = (scl && (sdl & ~sdl_delay));`
* **SCL Rising:** `assign scl_rising_edge = (scl & ~scl_delay);`

### Error Handling
If a `STOP` condition is detected while the FSM is in the middle of the `DATA` state (before all 8 bits are received), the `error` register is latched high to notify the system of an incomplete packet.

---

## Note 
* This project is intended to demonstrate the conceptual logic and architectural idea of how an I2C slave receiver FSM operates. It is not a fully verified, production-grade I2C implementation (e.g., it does not include features like clock stretching, 10-bit addressing, or complex arbitration). Use this as a reference for learning or as a foundation for your own custom protocol receiver.
