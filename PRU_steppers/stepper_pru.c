#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

// PRU driver headers
#include <prussdrv.h>
#include <pruss_intc_mapping.h>


#define WHICH_PRU  		 0

#define ADDR_PRU_DATA_0  0x01C30000

enum {
    CMD_GO = 0x0,
    CMD_SHUTDOWN = 0x1,
};

typedef struct {
    uint32_t x_period;
    uint32_t y_period;
    uint32_t z_period;
    uint32_t end_tick;
    uint8_t direction;
    uint8_t enable;
    uint8_t cmd;
    uint8_t reserved;
} __attribute__((packed)) Command;

uint8_t queue_idx = 0;
uint8_t cmds_outstanding = 0;
uint16_t cmds_processed = 0;

void wait_for_event() {
    unsigned int event = prussdrv_pru_wait_event(PRU_EVTOUT_0);
    printf("waited, event val %d\n", event);
    prussdrv_pru_clear_event(PRU0_ARM_INTERRUPT);
    cmds_outstanding--;
    cmds_processed++;
}

void enque(Command* cmd) {
    while (cmds_outstanding > 20) wait_for_event();
    if (queue_idx >= 16) { cmd->cmd |= 0x4; }
    printf("Writing command to offset %d\n", queue_idx*sizeof(Command));
    prussdrv_pru_write_memory(PRUSS0_PRU0_DATARAM, queue_idx * sizeof(Command)/4, (uint32_t*)cmd, sizeof(Command));
    if (queue_idx >= 16) { queue_idx = 0; } else { queue_idx++; }
    cmds_outstanding++;
}

int main(int argc, char** argv) {
    Command command;
    int argidx = 1;
    command.x_period = 10000;
    command.y_period = 21000;
    command.z_period = 32000;
    command.end_tick = 80000000;
    command.direction = 0x07;
    command.enable = 0x07;
    command.cmd = 0x00;

    while (argidx < argc) {
        if (strncmp(argv[argidx],"-d",2) == 0) {
            argidx++;
            if (argc == argidx) return -1;
            command.direction = atoi(argv[argidx++]);
        }
        else if (strncmp(argv[argidx],"-e",2) == 0) {
            argidx++;
            if (argc == argidx) return -1;
            command.enable = atoi(argv[argidx++]);
        } else {
            printf("Unrecognized argument %s\n",argv[argidx]);
            return -1;
        }
    }



    printf("Direction flags == %x\n",command.direction);
    printf("Enable flags == %x\n",command.enable);

    tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;
	
    prussdrv_init();		
    if (prussdrv_open(PRU_EVTOUT_0)) { 
        fprintf(stderr, "Could not open uio%d, aborting\n", PRU_EVTOUT_0);
        return -1;
    }
    // Initialize interrupts
    prussdrv_pruintc_init(&pruss_intc_initdata);
    // Set up test command
    enque(&command);
    command.direction = (~command.direction)&0x7;
    command.cmd = 0x01;
    enque(&command);
    // Run PRU program
    prussdrv_exec_program(WHICH_PRU, "./stepper_pru.bin");


    wait_for_event();

    printf("SUMMARY: oustanding events %d, processed events %d, queue offset %d\n",
            cmds_outstanding, cmds_processed, queue_idx);

    prussdrv_pru_disable(WHICH_PRU);
    prussdrv_exit ();
	
    return 0;
}

