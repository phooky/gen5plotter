#include <stdio.h>

// PRU driver headers
#include <prussdrv.h>
#include <pruss_intc_mapping.h>


#define WHICH_PRU  		 0

int main() {
    tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;
	
    prussdrv_init ();		
    if (prussdrv_open(PRU_EVTOUT_0)) { 
        fprintf(stderr, "Could not open uio%d, aborting\n", PRU_EVTOUT_0);
        return -1;
    }
    // Initialize interrupts
    prussdrv_pruintc_init(&pruss_intc_initdata);
    // Run PRU program
    prussdrv_exec_program(WHICH_PRU, "./stepper_pru.bin");

    // Just to be clear: the default interrupt setup here is a mystery that would benefit
    // from proper investigation.
    unsigned int event = prussdrv_pru_wait_event(PRU_EVTOUT_0);
    printf("Received event %d\n",event);
    prussdrv_pru_clear_event(PRU0_ARM_INTERRUPT);

    prussdrv_pru_disable (WHICH_PRU);
    prussdrv_exit ();
	
    return 0;
}

