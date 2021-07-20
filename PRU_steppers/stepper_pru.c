#include <stdio.h>
#include <stdint.h>

// PRU driver headers
#include <prussdrv.h>
#include <pruss_intc_mapping.h>


#define WHICH_PRU  		 0

#define ADDR_PRU_DATA_0  0x01C30000

typedef struct {
    uint32_t x_period;
    uint32_t y_period;
    uint32_t z_period;
    uint32_t end_tick;
    uint8_t direction;
    uint8_t enable;
    uint8_t flags;
} Command;

int main() {
    Command command;
    command.x_period = 10000;
    command.y_period = 21000;
    command.z_period = 32000;
    command.end_tick = 40000000;
    command.direction = 0x07;
    command.enable = 0x07;

    tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;
	
    prussdrv_init();		
    if (prussdrv_open(PRU_EVTOUT_0)) { 
        fprintf(stderr, "Could not open uio%d, aborting\n", PRU_EVTOUT_0);
        return -1;
    }
    // Set up test command
    prussdrv_pru_write_memory(PRUSS0_PRU0_DATARAM, 0, (uint32_t*)&command, sizeof(Command));  // spi code
    // Initialize interrupts
    prussdrv_pruintc_init(&pruss_intc_initdata);
    // Run PRU program
    prussdrv_exec_program(WHICH_PRU, "./stepper_pru.bin");

    // Just to be clear: the default interrupt setup here is a mystery that would benefit
    // from proper investigation.
    unsigned int event = prussdrv_pru_wait_event(PRU_EVTOUT_0);
    printf("Received event %d\n",event);
    prussdrv_pru_clear_event(PRU0_ARM_INTERRUPT);

    prussdrv_pru_disable(WHICH_PRU);
    prussdrv_exit ();
	
    return 0;
}

