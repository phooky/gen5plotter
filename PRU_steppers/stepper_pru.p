//
// It is 2021 and I am writing PRU code to drive steppers. Again.
// This is like, what, the third time now?
//

// 
// Axis structure. Mask is static at start time,
// other fields are updated per-command.
// 12 bytes / 3 registers.
.struct Axis
    .u32 period
    .u32 next_tick
    .u32 mask
.ends

//
// Command structure.
//
.struct Command
    .u32 x_period
    .u32 y_period
    .u32 z_period
    .u32 end_tick
    .u8  direction
    .u8  enable
.ends

.origin 0
.entrypoint START

#include "stepper_pins.hp"

#define PRU0_ARM_INTERRUPT  34

// Not used at present
.macro clr_ccnt
    LBBO    &r0, r20, 0, 4
    CLR     r0, r0, 3  // disable counter
    SBBO    &r0, r20, 0, 4
    SBBO    &r21, r20, 0xc, 4
    SET     r0, r0, 3 // enable counter
    SBBO    &r0, r20, 0, 4
.endm

#define TIME r18
#define REG_BASE r17

#define END_TICK r5
.assign Axis, r6, *, xaxis
.assign Axis, r9, *, yaxis
.assign Axis, r12, *, zaxis

#define X_NEXT_TICK r6
#define X_TICK_PERIOD r7
#define X_MASK r8

.macro reset_time
    LBBO    &r0, REG_BASE, 0, 4
    CLR     r0, r0, 3
    SBBO    &r0, REG_BASE, 0, 4
    XOR     r1, r1, r1
    SBBO    &r1, REG_BASE, 0xc, 4
    SET     r0, r0, 3
    SBBO    &r0, REG_BASE, 0, 4
.endm

.macro get_time
    LBBO    &TIME, REG_BASE, 0xC, 4
.endm

START:
    LDI     REG_BASE, 0x7000
    // End move at 80M ticks
    LDI     END_TICK.w0, 46080
    LDI     END_TICK.w2, 1220
    // Prepare masks
    MOV     r1, 1
    LSL     xaxis.mask, r1, X_STEP
    LSL     yaxis.mask, r1, Y_STEP
    LSL     zaxis.mask, r1, Z_STEP
    // Enable X stepper
    CLR     r30, r30, X_ENABLE
    // Positive direction
    CLR     r30, r30, X_DIR
    // Test data
    MOV     xaxis.period, 10000
PROC_CMD:
    reset_time
    MOV     xaxis.next_tick, xaxis.period
STEP_LOOP:
    get_time
    QBGT    STEP_LOOP, TIME, xaxis.next_tick
    XOR     r30, r30, xaxis.mask
    ADD     xaxis.next_tick, xaxis.next_tick, xaxis.period
    QBGT    STEP_LOOP, TIME, END_TICK
// Turn off enable
    SET     r30, r30, X_ENABLE
    SET     r30, r30, Y_ENABLE
    SET     r30, r30, Z_ENABLE
DONE:
    // Let the host know we are done
    MOV R31.b0, #PRU0_ARM_INTERRUPT
    HALT
