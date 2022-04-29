# g5plot

This software will allow you to control a generation 5 Makerbot Replicator and adapt it as a plotter.
It's adapted to my particular circumstances; ymmv. This is mostly to help myself remember when I come 
back to this project or find another junked G5.

## Initial setup

0. Disassemble the replicator until you have access to the main "birdwing" board.

1. Find the J5 connector on the birdwing board, right next to the speaker. The silkscreen will include the 
label "USB2TTL" and therevwill be an arrow pointing to Pin 1.  This is a 3.3V level serial console interface using a standard FTDI cable pinout. You can find a 3.3V FTDI USB-to-serial cable, or program an arduino or similar board with 3.3V I/O levels to act as a bridge. See the pinout section for details.

2. Open up your serial port in `tio`, `minicom`, or some other simple console. Be sure to set your baud rate to 115200. Next, turn on the PSU and push the "PowerOn" button on the birdwing board. After a few moments, you should see boot messages scrolling by. Eventually you will see a login prompt. Log in as "root"; no password should be necessary.

3. Remount the root partition as read/write: `mount -o remount,rw /`

4. Change the hostname. For convenience, I've named mine 'gen5'. If you use something else you'll need to edit the hostname in the Makefile if you want the 'deploy' and other remote targets to work. You can change the hostname by editing the `/etc/hostname` file and rebooting (or in theory running the 'hostname' utility).

5. Plug in the wired ethernet, or set up the wifi. I'm not going to document the wifi configuration here, but you can probably set it up with the 'nmcli' utility.

5. Add your public key to the /var/ssh/authorized_keys file. Run "/etc/init.d/S50sshd restart".

6. Stop the 'kaiten' process. Remove the 'kaiten' from the /etc/init.d directory (or better yet move it somewhere safe) to stop it from launching on boot. Reboot.

## Building and installing g5plot

1. Install cross-platform toolchain for ARM Linux (arm-linux-gnueabi-gcc).

2. Build PASM and the app loader libraries with the "build_tools.sh" script.

3. #`(cd g5plot && make)`

## Deploying and running

You can deploy g5plot by running `make deploy` from the g5plot directory. It relies on the hostname being `gen5`; you can either change the default in the Makefile or set the `PLOTTER` environment variable to the plotter's name.

By default g5plot is deployed to `/var/scratch/g5plot`. If you want to deploy it outside of the `/var` tree you'll need to remount the root partition as read/write.

You can use the `g5p_start.sh` and `g5p_stop.sh` scripts to start and stop the plotter process. Commands should be piped to `/var/run/plotter`.

## TODOs

* Start using the speaker for alerts

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

### Servo hookup

TODO
