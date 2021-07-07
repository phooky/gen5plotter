== Basic outline of PRU stepper driver

* We'll be using Timer2, which appears to be available.
* PRU will have a queue in its own RAM
* PRU will just interpolate commands merrily until the queue is empty
* We should target straight-line movement. HP-GL specifies polygon approximation anyway.

What about acceleration?

What about zeroing?

What should a command look like?

DWELL -- special case of

At start of command, we have a current X Y Z

- REFACTOR: strip down code to bare minimum
- TECH TEST: send a buffer of commands to the PRU

