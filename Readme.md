# Controlling a Gen 5 Replicator

## Getting in

### Step one: console

Find the J5 connector on the birdwing board, right next to the speaker. The silkscreen will include the 
label "USB2TTL" and there
will be an arrow pointing to Pin 1.  This is a 3.3V level serial console interface using a standard FTDI cable
pinout. You can find a 3.3V FTDI USB-to-serial cable, or program an arduino or similar board with 3.3V I/O levels
to act as a bridge.

Open up your serial port in `tio`, `minicom`, or some other simple console. Be sure to set your baud rate to 115200.
Next, turn on the PSU and push the "PowerOn" button on the birdwing board. After a few moments, you should see boot
messages scrolling by. Eventually you will see a login prompt. Log in as "root"; no password should be necessary.

### Step two: ethernet and ssh

add pub key to /var/ssh/authorized_keys 
`# /etc/init.d/S50sshd restart`

### Step three: stop kaiten

## Build instructions

build pasm
get arm tools
build entire thing

## TODOs

* Where is the speaker?
