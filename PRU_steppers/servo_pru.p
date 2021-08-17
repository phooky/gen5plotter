//
// SERVO_PRU.P
//


//
// Command structure.
//
// Flags:
// 0x01 - halt until next signal
// 0x02 - reset command queue offset
// 0x04 - halt PRU
.struct Command
    .u32 x_period
    .u32 y_period
    .u32 z_period
    .u32 end_tick
    .u8  direction
    .u8  enable
    .u8  cmd
.ends

// servo pulse: 1-2ms out of 20ms
// ticks per servo cycle: 2e8 * 2e-2 = 4e6
// ticks per pulse: 2e8 * 1-2e-3 = 2-4e5
// 256 increments: 2e5 / 256 = 780 (rounded to speed up computation ;)
#define TICKS_PER_CYCLE 4000000
#define TICKS_PULSE_MIN 200000
#define TICKS_PULSE_INC 780

.origin 0
.entrypoint START

#include "gpio.hp"

#define TIME r18
#define REG_BASE r17
#define IO_BASE r16
#define PIN_MASK r15

#define DUTY_TICKS r5
#define CYCLE_TICKS r6
#define MIN_DUTY_TICKS r7
#define TOOL_VAL r8

#define ONE_SECOND_TICKS 0xbebc200
#define TWO_SECOND_TICKS 0x17d78400

// Which bank to use for pin 5,5

#define GPIO_BANK_BASE GPIO45_BASE
#define GPIO_PIN (16 + 5)

#include "tick_macros.hp"

.macro LDI32
.mparam dst, imm
    LDI     dst.w0, imm & 0xFFFF
    LDI     dst.w2, imm >> 16
.endm

START:
    // Test parameter
    LDI     TOOL_VAL, 128
    LDI32   MIN_DUTY_TICKS, TICKS_PULSE_MIN
    LDI32   CYCLE_TICKS, TICKS_PER_CYCLE
    LDI     REG_BASE, 0x7800
    LDI32   IO_BASE, (GPIO_BANK_BASE)
    LDI     PIN_MASK, 1
    LSL     PIN_MASK, PIN_MASK, GPIO_PIN
    // Set pin direction
    LBBO    &r0, IO_BASE, DIR_OFF, 4
    CLR     r0, r0, GPIO_PIN
    SBBO    &r0, IO_BASE, DIR_OFF, 4

    // Wait for a toolhead setting to begin
POLL_FOR_START:
    QBBC    POLL_FOR_START, r31, 31
CLEAR_INTERRUPT:
    //LDI     r1, 0x01
    //LDI     r2, 0x284
    //SBCO    r1, c0, r2, 4
    //LDI     r2, 0x384
    //SBCO    r1, c0, r2, 4
SET_PIN:
    reset_time
    // Set pin
    SBBO    &PIN_MASK, IO_BASE, SET_OFF, 4
    // Compute duty tick increment
    // 780 = 2^9 + 2^8 + 2^3 + 2^2
    LSL     DUTY_TICKS, TOOL_VAL, 2
    LSL     r0, TOOL_VAL, 3
    ADD     DUTY_TICKS, DUTY_TICKS, r0
    LSL     r0, TOOL_VAL, 8
    ADD     DUTY_TICKS, DUTY_TICKS, r0
    LSL     r0, TOOL_VAL, 9
    ADD     DUTY_TICKS, DUTY_TICKS, r0
    // Add minimum ticks
    ADD     DUTY_TICKS, MIN_DUTY_TICKS

WAIT_FOR_CLR:
    get_time
    QBGT    WAIT_FOR_CLR, TIME, DUTY_TICKS

    // Clear pin
    SBBO    &PIN_MASK, IO_BASE, CLR_OFF, 4
WAIT_FOR_SET:
    get_time
    QBGT    WAIT_FOR_SET, TIME, CYCLE_TICKS
    JMP     SET_PIN

