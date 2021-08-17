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

.origin 0
.entrypoint START

#include "gpio.hp"

#define TIME r18
#define REG_BASE r17
#define IO_BASE r16
#define PIN_MASK r15

#define DUTY_TICKS r5
#define PERIOD_TICKS r6

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
    // set up test params
    LDI32   DUTY_TICKS, ONE_SECOND_TICKS
    LDI32   PERIOD_TICKS, TWO_SECOND_TICKS
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
WAIT_FOR_CLR:
    get_time
    QBGT    WAIT_FOR_CLR, TIME, DUTY_TICKS

    // Clear pin
    SBBO    &PIN_MASK, IO_BASE, CLR_OFF, 4
WAIT_FOR_SET:
    get_time
    QBGT    WAIT_FOR_SET, TIME, PERIOD_TICKS
    JMP     SET_PIN

