//
// STEPPER_PRU.P
//
// This code controls the stepper motion and communicates with
// the toolhead. It runs on PRU0.
//
// At startup, this code waits for an interrupt from the ARM.
// The ARM fills the command buffer, wholly or partially, and
// fires off an interrupt to the PRU to initiate processing.
// As each command is read (not executed), the PRU sends an 
// interrupt back to the ARM to let it know that command has
// been received and that futher commands can be buffered.
//
// The command buffer is located in PRU Data RAM, which is just
// 512 bytes; at 20B/command, that gives us about 25 commands
// total. In practice our buffer need not even be that big. Even
// the smallest motion control commands will run for a millisecond
// or more.
//
// Most commands are motion commands; these consist of enable
// and direction flags for the steppers, the length of time
// that the motion command should execute for, and the period
// between toggles of the step pin for each axis, along with
// a command field.
//
// All timing is in terms of PRU ticks. The AM1808 PRU runs
// at 200 MHz.
//
// The command field includes a flag that indicates that the
// next available command is at the beginning of the command
// buffer. The controlling ARM is responsible for setting
// this flag before the command queue overflows.
//


// Axis structure.
// 12 bytes / 3 registers.
.struct Axis
    .u32 period       // The number of ticks between pin toggles
    .u32 next_tick    // The tick of the next pin toggle
    .u32 mask         // The bit to toggle in R30; generated at startup
.ends

// Command structure.
// 20 bytes / 5 registers. 
// Command flags:
// bit 0 - halt motion and wait for next interrupt
// bit 2 - reset queue offset
// bit 3 - send toolhead command byte and interrupt
.struct Command
    .u32 x_period    // The number of ticks between X step pin toggles
    .u32 y_period    // The number of ticks between Y step pin toggles
    .u32 z_period    // The number of ticks between Z step pin toggles
    .u32 end_tick    // The number of ticks before the command is complete
    .u8  direction   // Direction bit for each axis (bit 0 = X, bit 1 = Y, bit 2 = Z)
    .u8  enable      // Enable bit for each axis (bit 0 = X, bit 1 = Y, bit 2 = Z)
    .u8  cmd         // The type of command to execute, see table
    .u8  toolhead    // Toolhead command information
.ends

#define CFL_WAIT        0
#define CFL_RST_QUEUE   2
#define CFL_TOOLHEAD    3

#define CmdSz 20

#include "stepper_pins.hp"

#define PRU0_ARM_INTERRUPT  34
#define PRU0_PRU1_INTERRUPT 32

#define EN_MASK (1 << X_ENABLE) | (1 << Y_ENABLE) | (1 << Z_ENABLE)
#define DIR_MASK (1 << X_DIR) | (1 << Y_DIR) | (1 << Z_DIR)
#define DIR_EN_MASK (0xffffffff ^ (DIR_MASK | EN_MASK))

// Register layout
#define END_TICK r5
.assign Axis, r6, *, xaxis
.assign Axis, r9, *, yaxis
.assign Axis, r12, *, zaxis
#define CMD_OFF r16.w0 
#define REG_BASE r17
#define TIME r18
.assign Command, r20, *, command

#include "tick_macros.hp"

// Macro for setting a to_bit in to_reg if from_bit is set in from_reg
// (Terrible name; it does not "copy" a zero bit)
.macro copy_bit 
.mparam from_reg, from_bit, to_reg, to_bit
    QBBC    END_COPY_BIT, from_reg, from_bit
    SET     to_reg, to_bit
END_COPY_BIT:
.endm

// Start instructions at location 0 and indicate that code begins at START label
.origin 0
.entrypoint START

START:
    // 0x7000 is the base location of the PRU0 registers; we set this
    // for use by the tick macros
    LDI     REG_BASE, 0x7000
    // Initialize command buffer offset
    LDI     CMD_OFF, 0
    // Prepare masks
    MOV     r1, 1
    LSL     xaxis.mask, r1, X_STEP
    LSL     yaxis.mask, r1, Y_STEP
    LSL     zaxis.mask, r1, Z_STEP
POLL_FOR_START:
    QBBC    POLL_FOR_START, r31, 30
    // Clear the interrupt
    LDI     r1, 0x01
    LDI     r2, 0x284
    SBCO    r1, c0, r2, 4
    //LDI     r2, 0x384
    //SBCO    r1, c0, r2, 4
    
PROC_CMD:
    reset_time
    LBCO    &command, c3, CMD_OFF, CmdSz
    // Let host know that command has been read
    MOV     R31.b0, #PRU0_ARM_INTERRUPT
    // Update CMD_OFF
    ADD     CMD_OFF, CMD_OFF, CmdSz
    QBBC    SKIP_ZERO_OFF, command.cmd, CFL_RST_QUEUE // Check zero queue bit
    LDI     CMD_OFF, 0
SKIP_ZERO_OFF:
    QBBC    SKIP_TOOLHEAD, command.cmd, CFL_TOOLHEAD // Check toolhead cmd bit
    // toolhead code here
    MOV     r31.b0, #PRU0_PRU1_INTERRUPT
SKIP_TOOLHEAD:
    // Check for end state
    QBBS    DONE, command.cmd, CFL_WAIT
    // Load command
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
    JMP     PROC_CMD
DONE:
    SET     r30, r30, X_ENABLE
    SET     r30, r30, Y_ENABLE
    SET     r30, r30, Z_ENABLE
    JMP     POLL_FOR_START
