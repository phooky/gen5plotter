== Current design

Our current design does not support acceleration.

Command queue is in PRU0 data RAM, which is 0x1ff bytes long.
A command is five 32-bit words (16 bytes): a velocity for each axis,
a total length in PRU ticks, and four bytes for axis direciton/enable
and top-level commands.

The PRU will send an interrupt to the ARM upon completion of each
command and, presuming the command does not involve halting or
pausing the stepper progress, automatically continue on to the
next command.

We should assume that the minimum command length is around 5uS, or
1000 PRU ticks. This will ensure that we don't miss any interrupts.

== Command Queue

The command queue should be about 32 commands long. The command queue
offset should be reset manually by the sender.


TODO: the PRU can indicate the last processed command by writing it to
a fixed location in PRU0 data RAM.

== Commands

The command byte looks like this:

* bits 0-2: command
* bit 3: zero queue position after this command
* bits 4-7: unused

=== Command values

* 0 - perform move
* 1 - shutdown
* 2 - wait for start signal

== TODO

What about acceleration?

What about zeroing?

At start of command, we have a current X Y Z

- TECH TEST: send a buffer of commands to the PRU

