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

#include "stepper_pins.hp"

#define PRU0_ARM_INTERRUPT  34

#define CMD_OFF r16.b0 
#define TIME r18
#define REG_BASE r17
#define EN_MASK (1 << X_ENABLE) | (1 << Y_ENABLE) | (1 << Z_ENABLE)
#define DIR_MASK (1 << X_DIR) | (1 << Y_DIR) | (1 << Z_DIR)
#define DIR_EN_MASK (0xffffffff ^ (DIR_MASK | EN_MASK))

#define END_TICK r5
.assign Axis, r6, *, xaxis
.assign Axis, r9, *, yaxis
.assign Axis, r12, *, zaxis

.assign Command, r20, *, command

// Disable counter, store zero, and restart counter
.macro reset_time
    LBBO    &r0, REG_BASE, 0, 4
    CLR     r0, r0, 3
    SBBO    &r0, REG_BASE, 0, 4
    LDI     r1, 0
    SBBO    &r1, REG_BASE, 0xc, 4
    SET     r0, r0, 3
    SBBO    &r0, REG_BASE, 0, 4
.endm

.macro get_time
    LBBO    &TIME, REG_BASE, 0xC, 4
.endm

.macro copy_bit 
.mparam from_reg, from_bit, to_reg, to_bit
    QBBC    END_COPY_BIT, from_reg, from_bit
    SET     to_reg, to_bit
END_COPY_BIT:
.endm

START:
    LDI     REG_BASE, 0x7000
    LDI     CMD_OFF, 0
    // Prepare masks
    MOV     r1, 1
    LSL     xaxis.mask, r1, X_STEP
    LSL     yaxis.mask, r1, Y_STEP
    LSL     zaxis.mask, r1, Z_STEP
PROC_CMD:
    reset_time
    LBCO    &command, c3, CMD_OFF, 19
    MOV     xaxis.period, command.x_period
    LSR     xaxis.next_tick, xaxis.period, 1
    MOV     yaxis.period, command.y_period
    LSR     yaxis.next_tick, yaxis.period, 1
    MOV     zaxis.period, command.z_period
    LSR     zaxis.next_tick, zaxis.period, 1
    MOV     END_TICK, command.end_tick
    // set direction and enable flags
    MOV     r1.w0, (DIR_EN_MASK) & 0xffff
    MOV     r1.w2, (DIR_EN_MASK) >> 16
    AND     r1, r30, r1
    copy_bit command.direction, 0, r1, X_DIR
    copy_bit command.direction, 1, r1, Y_DIR
    copy_bit command.direction, 2, r1, Z_DIR
    copy_bit command.enable, 0, r1, X_ENABLE
    copy_bit command.enable, 1, r1, Y_ENABLE
    copy_bit command.enable, 2, r1, Z_ENABLE
    SET     r1, X_VREF
    SET     r1, Y_VREF
    MOV     r30, r1
STEP_LOOP:
    get_time
XCHK:
    QBGT    YCHK, TIME, xaxis.next_tick
    XOR     r30, r30, xaxis.mask
    ADD     xaxis.next_tick, xaxis.next_tick, xaxis.period
YCHK:
    QBGT    ZCHK, TIME, yaxis.next_tick
    XOR     r30, r30, yaxis.mask
    ADD     yaxis.next_tick, yaxis.next_tick, yaxis.period
ZCHK:
    QBGT    ENDCHK, TIME, zaxis.next_tick
    XOR     r30, r30, zaxis.mask
    ADD     zaxis.next_tick, zaxis.next_tick, zaxis.period
ENDCHK:
    QBGT    STEP_LOOP, TIME, END_TICK
    ADD     CMD_OFF, CMD_OFF, 20
    // Let the host know we are done
    MOV R31.b0, #PRU0_ARM_INTERRUPT
    QBBC    SKIP_IDX_RST, command.cmd, 0x2 
    LDI     CMD_OFF, 0
SKIP_IDX_RST:
    QBNE    PROC_CMD, command.cmd, 0x1
// Turn off enable
    SET     r30, r30, X_ENABLE
    SET     r30, r30, Y_ENABLE
    SET     r30, r30, Z_ENABLE
DONE:
    HALT
