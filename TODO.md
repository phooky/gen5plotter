
* TODO Proper check for whether a command has been executed; we need a bit to indicate that this
  command has not yet been handled. This will allow us to have proper pipeline stalls, instead
  of the mess I'm currently grappling with.


* [DONE] find penup/pendown solenoid breakout (gowanus connector?)
* look into homing
* [DONE] check gpio pins:
	DA850_GPIO5_5,	//Chamber heater reserved 0
	DA850_GPIO2_5,	//Chamber heater reserved 1
* [DONE] test basic GPIO toggling from PRU1
* DONE servo test from PRU1
  CLOSED: [2022-03-30 Wed 11:27]
* DONE pru0->pru1 servo command
  CLOSED: [2022-03-30 Wed 11:27]


