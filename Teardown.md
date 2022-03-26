# Controlling a Gen 5 Replicator

## Introduction and motivation

A while back I was gifted a busted-up Makerbot Replicator Generation 5 (henceforth just "gen5"). It
was too mechanically damaged to serve as a printer again, but I figured I could pull out the gantry 
and use it as a pen plotter. Unfortunately the existing software on the gen5 was unsuitable for
my purposes, and I ended up having to write a new stepper driver from scratch.

## Anatomy

This is a quick breakdown of the major parts of the gen5. This is all based on my teardown, comments
in the software, and silkscreens on the PCBs; Makerbot may use other terminology.

* Birdwing - the mainboard. Carries the AM1808 processor and the X/Y/Z stepper drivers, along with
    ethernet, wifi, and a six-pin serial console connection.
* Hoboken - the interface PCB. Hoboken includes the knob and buttons, the screen, the thumbdrive USB port,
    the camera, and the chamber lighting LED. Hoboken is connected to Birdwing via an HDMI cable and standard
    connectors. The cable does not actually carry HDMI signals. The video is routed over a single
    signal pair. There is a USB hub on board that routes signals from the camera and thumbdrive.
* Bronx - the toolhead PCB. This is the PCB inside the toolhead, not the one inside the extruder. It has a
    stepper driver and probably some mosfets. It connect via a large flexible flat cable.
* PSU - a small ATX power supply
* H-bot - the XY gantry is in a so-called "h-bot" configuration, with one continuous belt.

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


The easiest way is to use a 115200
 
I'll just refer to the Replicator as the "gen5" going forward.

## TODOs

* Where is the speaker?
