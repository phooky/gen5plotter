//
// Poking around with PRU code
//

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

#define STEPS r5
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
    LDI     STEPS, 8000 // start with 8000 steps
    reset_time
    // about 1kHz
    LDI     X_TICK_PERIOD.w2, 3
    LDI     X_TICK_PERIOD.w0, 3392
    MOV     X_MASK, 1
    LSL     X_MASK, X_MASK, X_STEP
    MOV     X_NEXT_TICK, X_TICK_PERIOD

    // Positive direction
    SET     r30, r30, X_DIR
    // Enable X stepper
    CLR     r30, r30, X_ENABLE
STEP_LOOP:
    get_time
    QBGT    STEP_LOOP, TIME, X_NEXT_TICK
    XOR     r30, r30, X_MASK
    ADD     X_NEXT_TICK, X_NEXT_TICK, X_TICK_PERIOD
    SUB     STEPS, STEPS, 1
    QBNE    STEP_LOOP, STEPS, 0
// Turn off enable
    SET     r30, r30, X_ENABLE
    SET     r30, r30, Y_ENABLE
    SET     r30, r30, Z_ENABLE
DONE:
    // Let the host know we are done
    MOV R31.b0, #PRU0_ARM_INTERRUPT
    HALT
