== Overview

The plotter is controlled by the `g5plot` process, which takes simpled
commands from standard input and uses them to control the plotter. It
terminates and shuts down the plotter cleanly when it receives a SIGINT
signal. SIGSTOP/SIGTSTP and SIGCONT can be use to pause and continue
execution, but be aware that the currently queued commands will
continue to be executed if SIGSTOP is sent. SIGTSTP will immediately
halt the PRUs and reenable them on continuation.

== Interface

=== g5plot interface

Commands are seperated by newlines. All parameters are floats if not
otherwise specified.

| command code | parameters | explanation |
|--------------|------------|-------------|
| U | - | toolhead up (to preset value) |
| D | - | toolhead down (to preset value) |
| M | X Y V | move toolhead. X and Y are in mm, V is in mm/sec. |
| R | X Y V | move toolhead relative to last position. X and Y are in mm, V is in mm/sec. |
| T | V | move toolhead to velue. Toolhead value is a one-byte unsigned integer. |
| Z | - | set current position as zero/home. |
| Q | - | shut down plotter. |
| W | - | wait for user intervention (NOT YET IMPLEMENTED) |

While g5plot can be driven directly from the command line, the
intended use is to have it receive commands from a fifo, generally
`/var/run/plotter`.

=== Plotter queue management

* dropping and launching prepared files
* modules for handling gcode and svg
* simulator

== Internals

Command queue is in PRU0 data RAM, which is 0x1ff bytes long.
A command is five 32-bit words (16 bytes): a velocity for each axis,
a total length in PRU ticks, and four bytes for axis direciton/enable
and top-level commands.

We do not use interrupts; instead we busy-wait on a ready bit in each
command. That means that to reliably perform a command, it needs to be
written twice: once without the ready bit set, and again with it set.

It's possible that this is unnecessary, as we could put the flag in 
the last byte to be written, but it's not worth the effort to find out
for a useless optimization.

=== Command Queue

The command queue is 20 commands long. The command queue
offset should is reset manually by the sender. Ordinarily it
resets it after 18 commands, but this could be changed easily.

=== Command byte

The command byte is a bitfield. Every command is a "move toolhead"
command, so if the command is only for the toolhead or is a dwell, the
[xyz]_period fields should be set to 0xffffffff.

The bits on the command flag are:

| bit | name | explanation |
|-----|------|-------------|
| 0 | WAIT | 'WAIT' is deprecated. |
| 1 | READY | The READY flag is set when a command is ready to be executed, and cleared by the PRU once execution has started. |
| 2 | RESET | After this command is executed, the PRU should begin reading the next command from the start of the command buffer. |
| 3 | TOOLHEAD | This command contains a toolhead payload byte which should be sent to the toolhead PRU. |

== TODO

What about acceleration?

What about zeroing?

At start of command, we have a current X Y Z

