# Modbus RTU Slave — Arduino Nano

Arduino Nano firmware implementing a Modbus RTU slave over RS-485 (MAX485
module), built against the official Modbus specifications:

- Modbus Application Protocol V1.1b3
- Modbus over Serial Line Specification & Implementation Guide V1.02

Sketch: [`ArduinoNanoModbusSlave/ArduinoNanoModbusSlave.ino`](ArduinoNanoModbusSlave/ArduinoNanoModbusSlave.ino)

## Dependency

Install **ModbusRTUSlave** (by CMB27) via the Arduino IDE Library Manager.
It implements function codes 01, 02, 03, 04, 05, 06, 15, 16 and handles
CRC16, RTU framing/timing, and Modbus exception responses.

## Wiring

| Nano pin | MAX485 pin |
|---|---|
| D0 (RX) | RO |
| D1 (TX) | DI |
| D2 | DE + RE (tied together) |
| 5V | VCC |
| GND | GND |

`A`/`B` go to the RS-485 bus, terminated with 120 ohm resistors at each end
of the bus. Disconnect the MAX485 from D0/D1 while uploading over USB,
since the hardware UART is shared.

| Signal | Nano pins |
|---|---|
| Digital inputs (active LOW, internal pull-up) | D3, D4, D5, D6 |
| Digital outputs | D7, D8, D9, D10 |
| Input registers (raw 10-bit ADC, 0-1023) | A0, A1, A2, A3 |
| Holding registers | RAM-backed, no physical pins |

## Serial settings

9600 baud, 8 data bits, no parity, 2 stop bits (8N2). Two stop bits are
used because the spec requires them when parity is disabled. Edit
`SLAVE_ID` / `BAUD_RATE` in the sketch to match your master.

## Register map (0-based, as sent on the wire)

| Data type | Function codes | Addresses | Classic notation |
|---|---|---|---|
| Coils (digital outputs) | 01, 05, 15 | 0-3 | 00001-00004 |
| Discrete inputs (digital inputs) | 02 | 0-3 | 10001-10004 |
| Input registers | 04 | 0-3 | 30001-30004 |
| Holding registers | 03, 06, 16 | 0-3 | 40001-40004 |

Default slave ID: `1`.
