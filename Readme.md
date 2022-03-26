# g5plot

This software will allow you to control a generation 5 Makerbot Replicator and adapt it as a plotter.
It's adapted to my particular circumstances; ymmv. This is mostly to help myself remember when I come 
back to this project or find another junked G5.

## Initial setup

0. Disassemble the replicator until you have access to the main "birdwing" board.

1. Find the J5 connector on the birdwing board, right next to the speaker. The silkscreen will include the 
label "USB2TTL" and therevwill be an arrow pointing to Pin 1.  This is a 3.3V level serial console interface using a standard FTDI cable pinout. You can find a 3.3V FTDI USB-to-serial cable, or program an arduino or similar board with 3.3V I/O levels to act as a bridge. See the pinout section for details.

2. Open up your serial port in `tio`, `minicom`, or some other simple console. Be sure to set your baud rate to 115200. Next, turn on the PSU and push the "PowerOn" button on the birdwing board. After a few moments, you should see boot messages scrolling by. Eventually you will see a login prompt. Log in as "root"; no password should be necessary.

3. [TODO] connect ethernet

4. [TODO] set up wifi

5. Add your public key to the /var/ssh/authorized_keys file. Run "/etc/init.d/S50sshd restart".

6. [TODO] stop kaiten (it will get in the way)

## Building and installing g5plot

1. Install cross-platform toolchain for ARM Linux (arm-linux-gnueabi-gcc).

2. Build PASM and the app loader libraries with the "build_tools.sh" script.

3. cd g5plot && make

## Deploying and running

TODO

## TODOs

* Where is the speaker?
* document the servo hookup

## Pinouts

### J5 UART

To connect to the birdwing board you will need to wire up GND, TX, and RX only. It's safest to leave the other pins disconnected.

| Pin | Function |
|-----|----------|
|  1  | GND      |
|  2  | CTS (ignore) |
|  3  | VCC (ignore) |
|  4  | TX       |
|  5  | RX       |
|  6  | RTS (ignore) |
