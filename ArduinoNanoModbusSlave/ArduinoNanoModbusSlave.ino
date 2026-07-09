/*
  Arduino Nano - Modbus RTU Slave (MAX485 / RS-485)
  ---------------------------------------------------
  Implements a Modbus RTU slave per the official Modbus specifications:
    - Modbus Application Protocol V1.1b3
    - Modbus over Serial Line Specification & Implementation Guide V1.02

  Library: ModbusRTUSlave by CMB27
    Install via Arduino IDE Library Manager -> search "ModbusRTUSlave"
    https://github.com/CMB27/ModbusRTUSlave
  Supported function codes: 01, 02, 03, 04, 05, 06, 15, 16

  Wiring (Arduino Nano <-> MAX485 module):
    Nano D0 (RX) <- MAX485 RO
    Nano D1 (TX) -> MAX485 DI
    Nano D2      -> MAX485 DE + RE (tied together)
    Nano 5V      -> MAX485 VCC
    Nano GND     -> MAX485 GND
    MAX485 A/B   -> RS-485 bus (twisted pair, 120 ohm termination at each bus end)

  Since the hardware UART (D0/D1) is dedicated to RS-485, disconnect the
  MAX485 TX/RX lines while uploading sketches over USB.

  Digital inputs (dry contacts / sensors), pulled up internally, active LOW:
    D3, D4, D5, D6

  Digital outputs (relays / LEDs / actuators):
    D7, D8, D9, D10

  Input registers (read-only, 0-1023 raw ADC counts):
    A0, A1, A2, A3

  Holding registers (read/write, RAM-backed test values, no physical pins)

  Comm parameters (slave ID, baud rate, parity/stop bits) are set in the
  "USER CONFIGURATION" block below - edit those to match your master.
  The spec requires 2 stop bits when no parity is used, which is why
  SERIAL_8N2 is the default instead of SERIAL_8N1.

  Modbus data model addressing used by this slave (0-based, as sent on the
  wire). Add the conventional offset if your master/HMI uses the classic
  5-digit notation:
    Coils              (FC 01/05/15): 0-3  -> 00001-00004
    Discrete Inputs    (FC 02)      : 0-3  -> 10001-10004
    Input Registers    (FC 04)      : 0-3  -> 30001-30004
    Holding Registers  (FC 03/06/16): 0-3  -> 40001-40004
*/

#include <ModbusRTUSlave.h>

// ==================== USER CONFIGURATION ====================
// Modbus slave address. Must be unique on the RS-485 bus (1-247).
const uint8_t SLAVE_ID = 1;

// Serial baud rate. Must match the Modbus master.
const unsigned long BAUD_RATE = 9600;

// Serial frame format. Must match the Modbus master. Options:
//   SERIAL_8N1, SERIAL_8N2 (8 data bits, no parity, 1 or 2 stop bits)
//   SERIAL_8E1, SERIAL_8E2 (even parity)
//   SERIAL_8O1, SERIAL_8O2 (odd parity)
// Per the Modbus spec, use 2 stop bits when parity is set to none.
const uint16_t SERIAL_CONFIG = SERIAL_8N2;
// ==============================================================

const uint8_t DE_RE_PIN = 2;

const uint8_t NUM_DIGITAL_INPUTS = 4;
const uint8_t NUM_DIGITAL_OUTPUTS = 4;
const uint8_t NUM_HOLDING_REGISTERS = 4;
const uint8_t NUM_INPUT_REGISTERS = 4;

const uint8_t digitalInputPins[NUM_DIGITAL_INPUTS] = {3, 4, 5, 6};
const uint8_t digitalOutputPins[NUM_DIGITAL_OUTPUTS] = {7, 8, 9, 10};
const uint8_t analogInputPins[NUM_INPUT_REGISTERS] = {A0, A1, A2, A3};

bool discreteInputs[NUM_DIGITAL_INPUTS];
bool coils[NUM_DIGITAL_OUTPUTS];
uint16_t holdingRegisters[NUM_HOLDING_REGISTERS];
uint16_t inputRegisters[NUM_INPUT_REGISTERS];

ModbusRTUSlave modbus(Serial, DE_RE_PIN);

void setup() {
  for (uint8_t i = 0; i < NUM_DIGITAL_INPUTS; i++) {
    pinMode(digitalInputPins[i], INPUT_PULLUP);
  }
  for (uint8_t i = 0; i < NUM_DIGITAL_OUTPUTS; i++) {
    pinMode(digitalOutputPins[i], OUTPUT);
    digitalWrite(digitalOutputPins[i], LOW);
  }

  for (uint8_t i = 0; i < NUM_HOLDING_REGISTERS; i++) {
    holdingRegisters[i] = 0;
  }

  modbus.configureCoils(coils, NUM_DIGITAL_OUTPUTS);
  modbus.configureDiscreteInputs(discreteInputs, NUM_DIGITAL_INPUTS);
  modbus.configureHoldingRegisters(holdingRegisters, NUM_HOLDING_REGISTERS);
  modbus.configureInputRegisters(inputRegisters, NUM_INPUT_REGISTERS);

  Serial.begin(BAUD_RATE, SERIAL_CONFIG);
  modbus.begin(SLAVE_ID, BAUD_RATE, SERIAL_CONFIG);
}

void loop() {
  for (uint8_t i = 0; i < NUM_DIGITAL_INPUTS; i++) {
    discreteInputs[i] = !digitalRead(digitalInputPins[i]);
  }
  for (uint8_t i = 0; i < NUM_INPUT_REGISTERS; i++) {
    inputRegisters[i] = analogRead(analogInputPins[i]);
  }

  modbus.poll();

  for (uint8_t i = 0; i < NUM_DIGITAL_OUTPUTS; i++) {
    digitalWrite(digitalOutputPins[i], coils[i]);
  }
}
