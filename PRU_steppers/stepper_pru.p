//
// Poking around with PRU code
//

.origin 0
.entrypoint START

#include "stepper_pins.hp"

#define PRU0_ARM_INTERRUPT  34

.macro delay
    MOV     r21, r20
DELAY_LOOP:
    SUB     r21, r21, 1
    QBNE    DELAY_LOOP, r21, 0
.endm

// Not used at present
.macro clr_ccnt
    LBBO    &r0, r20, 0, 4
    CLR     r0, r0, 3  // disable counter
    SBBO    &r0, r20, 0, 4
    SBBO    &r21, r20, 0xc, 4
    SET     r0, r0, 3 // enable counter
    SBBO    &r0, r20, 0, 4
.endm

START:
    LDI     r20.b0, 16960
    LDI     r20.b2, 1
    LDI     r5, 8000 // 200 iterations
// Turn on enable
// dir pos
    SET     r30, r30, X_DIR
    CLR     r30, r30, X_ENABLE
    SET     r30, r30, X_STEP
STEP_LOOP:
    // step high
    SET     r30, r30, X_STEP
    MOV     r21, 0x3fff
D1:
    SUB     r21, r21, 1
    QBNE    D1, r21, 0
    // step low
    CLR     r30, r30, X_STEP
    MOV     r21, 0x3fff
D2:
    SUB     r21, r21, 1
    QBNE    D2, r21, 0
    SUB     r5, r5, 1
    QBNE    STEP_LOOP, r5, 0
// Turn off enable
    SET     r30, r30, X_ENABLE
    SET     r30, r30, Y_ENABLE
    SET     r30, r30, Z_ENABLE
DONE:
    // Let the host know we're done
    MOV R31.b0, #PRU0_ARM_INTERRUPT
    HALT
