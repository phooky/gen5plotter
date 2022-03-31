#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <stdbool.h>

// PRU driver headers
#include <prussdrv.h>
#include <pruss_intc_mapping.h>


#define STEPPER_PRU     0
#define TOOLHEAD_PRU    1

// Command structure that is sent to the PRU.
typedef struct {
    uint32_t x_period;
    uint32_t y_period;
    uint32_t z_period;
    uint32_t end_tick;
    uint8_t direction;
    uint8_t enable;
    uint8_t cmd;
    uint8_t toolhead;
} __attribute__((packed,aligned(4))) Command;

const unsigned int CommandSzInWords = 5;

enum {
    CFL_WAIT = 0,        // Tells PRU to wait for an interrupt before continuing.
    CFL_CMD_READY = 1,   // Indicates that this command is ready for processing.
                         // If this bit is not set, the PRU will busy wait until it is.
    CFL_RST_QUEUE = 2,   // Indicates that after this command is executed, the PRU should go
                         // back to the head of the buffer.
    CFL_TOOLHEAD = 3,    // Indicates that this command is for the toolhead.
};

const uint32_t NO_EVT_CODE = 0xffffffff;
uint8_t cmds_outstanding = 0;
uint16_t cmds_processed = 0;
uint32_t last_evt_code = NO_EVT_CODE;

// Queue management
uint8_t queue_idx = 0; // next empty queue slot
const uint8_t queue_len = 20; // total number of Command entries in queue

// Check if we're running or not
bool is_running = false;

// Wait for next event and update oustanding/processed command counts
void wait_for_event() {
    if (!is_running) {
        prussdrv_pru_send_event (ARM_PRU0_INTERRUPT);
        is_running = true;
    }
    unsigned int event = prussdrv_pru_wait_event(PRU_EVTOUT_0);
    prussdrv_pru_clear_event(PRU_EVTOUT_0, PRU0_ARM_INTERRUPT);
    if (last_evt_code == NO_EVT_CODE) {
        printf("Starting event is %d\n",event);
        cmds_outstanding--;
        cmds_processed++;
    } else {
        int diff = event - last_evt_code;
        cmds_outstanding -= diff;
        cmds_processed += diff;
        if (diff != 1) {
            printf("### %d events missed\n",diff);
        }
    }
    if (cmds_outstanding == 0) {
        is_running = false;
    }
    last_evt_code = event;
}

void enqueue(Command* cmd) {
    while (cmds_outstanding > 8) wait_for_event();
    cmd->cmd &= ~(1 << CFL_RST_QUEUE);
    bool zero_queue = (queue_idx >= queue_len - 2);
    if (zero_queue) {
        cmd->cmd |= 1 << CFL_RST_QUEUE;
    } 
    int written = prussdrv_pru_write_memory(PRUSS0_PRU0_DATARAM, queue_idx * CommandSzInWords,
        (uint32_t*)cmd, sizeof(Command));
    if (written != sizeof(Command)/4) {
      printf("Unexpected write size %d (expected %d)",written,sizeof(Command)/4);
    }
    // Set ready bit
    cmd->cmd |= 1 << CFL_CMD_READY;
    written = prussdrv_pru_write_memory(PRUSS0_PRU0_DATARAM, queue_idx * CommandSzInWords,
					(uint32_t*)cmd, 1);
    queue_idx = zero_queue?0:queue_idx+1;
    cmds_outstanding++;
}

typedef struct { int32_t a; int32_t b; } AB;
/*
 * Convert X/Y coordinates, in steps, to A/B hbot coordinates
 */
AB xy_to_ab(int32_t x, int32_t y) {
    AB r = { .a = y+x, .b = y-x };
    return r;
}

/*
 * Enqueue a relative X/Y move, in steps and timer ticks
 */
void move_rel_xy_time(int32_t x_delta, int32_t y_delta, uint32_t ticks) {
    Command cmd;
    cmd.end_tick = ticks;
    cmd.enable = 0x4;
    cmd.direction = 0x1;
    AB ab = xy_to_ab(x_delta,y_delta);
    int32_t a = ab.a; int32_t b = ab.b;
    if (a < 0) { cmd.direction ^= 0x1; a = -a; }
    if (b < 0) { cmd.direction ^= 0x2; b = -b; }
    cmd.cmd = 0x00;
    cmd.z_period = ticks + 1;
    //printf("X %d Y %d A %d B %d\n",x_delta,y_delta,a,b);
    cmd.x_period = (a==0)?0x7fffffff:(ticks / (a * 2));
    cmd.y_period = (b==0)?0x7fffffff:(ticks / (b * 2));
    //printf("X_P %d Y_P %d\n",cmd.x_period, cmd.y_period);
    enqueue(&cmd);
}

/*
 * Machine state
 */
float current_x =0.0, current_y =0.0;

/*
 * Machine configuration
 */
const float steps_per_mm = 100.0;
// Maximum X coordinate in millimeters
const float max_x = 252.0;
// Maximum Y coordinate in millimeters
const float max_y = 199.0;
// Maximum velocity in mm/s
const float max_v = 150.0;
// Steps per mm, XY
const float steps_per_mm_xy = 88.573186;
// Steps per mm, Z
const float steps_per_mm_z = 400.0;
// Internal PRU ticks per second (200 MHz)
const float ticks_per_second = 200 * 1000 * 1000;


/**
 * Move in XY coordinates relative to the current position.
 * Ignores commands that try to move at exceptionally low speeds.
 * TODO: check for overlong moves (max: 10s)
 * @param dx the delta x coordinate in millimeters (mm).
 * @param dy the delta y coordinate in millimeters (mm).
 * @param v the velocity of the move, in millimeters per second (mm/s).
 */
void move_relative_xy(float dx, float dy, float v) {
    if (fabsf(v) <= 0.1) {
        fprintf(stderr, "Refusing to move at less that 0.1mm/s\n");
        return;
    }
    int32_t steps_x = (int32_t)(dx * steps_per_mm_xy);
    int32_t steps_y = (int32_t)(dy * steps_per_mm_xy);
    float len = sqrt(dx*dx + dy*dy);
    uint32_t time_in_ticks = (uint32_t)(ticks_per_second * (len / v));
    move_rel_xy_time(steps_x,steps_y,time_in_ticks);
    current_x += dx;
    current_y += dy;
}

/**
 * Move to the specified XY coordinates from current position.
 * @param x the x coordinate in millimeters (mm).
 * @param y the y coordinate in millimeters (mm).
 * @param v the velocity of the move, in millimeters per second (mm/s).
 */
void move_xy(float x, float y, float v) {
    float dx = x - current_x;
    float dy = y - current_y;
    move_relative_xy(dx, dy, v);
}

/**
 * Dwell at given location for a specified time.
 * TODO: check for overlong dwells (max: 10s)
 * @param t the time to dwell, in seconds
 */
void dwell(float time) {
    uint32_t time_in_ticks = (uint32_t)(ticks_per_second * time);
    move_rel_xy_time(0,0,time_in_ticks);
}

void toolhead(int parameter) {
    Command cmd;
    cmd.cmd = 1 << CFL_TOOLHEAD;
    cmd.toolhead = parameter & 0xff;
    cmd.end_tick = 500;
    cmd.enable = 0x4;
    cmd.direction = 0x1;
    cmd.z_period = 0x7fffffff;
    cmd.x_period = 0x7fffffff;
    cmd.y_period = 0x7fffffff;
    enqueue(&cmd);
}


/**
 * Set bot's idea of home (0,0).
 */
void set_here_as_home() {
    current_x = 0.0;
    current_y = 0.0;
}

/**
 * Enqueue a stop command.
 */
void stop() {
    Command cmd;
    cmd.enable = 0x0;
    cmd.cmd = 1 << CFL_WAIT;
    cmd.end_tick = 200;
    enqueue(&cmd);
}

/**
 * Wait until current queue is completely processed.
 */
void wait_for_completion() {
    while (cmds_outstanding > 0) {
        wait_for_event();
    }
}


tpruss_intc_initdata interrupt_controller_setup = {
    // System events to be enabled. 
    .sysevts_enabled = {
        PRU0_PRU1_INTERRUPT, // Inter-PRU
        PRU1_PRU0_INTERRUPT, 
        PRU0_ARM_INTERRUPT,  // PRU-to-ARM
        PRU1_ARM_INTERRUPT, 
        ARM_PRU0_INTERRUPT,  // ARM-to-PRU
        ARM_PRU1_INTERRUPT,
        -1, },
    // Map system events to each channel in the INTC.
    .sysevt_to_channel_map = {
        { PRU0_PRU1_INTERRUPT, 1 },
        { PRU1_PRU0_INTERRUPT, 0 },
        { PRU0_ARM_INTERRUPT,  2 },
        { PRU1_ARM_INTERRUPT,  3 },
        { ARM_PRU0_INTERRUPT,  0 },
        { ARM_PRU1_INTERRUPT,  1 },
        { -1, -1 }, },
    // Mapping from channels to host interrupts.
    .channel_to_host_map = {
        { 0, PRU0 },
        { 1, PRU1 },
        { 2, PRU_EVTOUT0 },
        { 3, PRU_EVTOUT1 },
        { -1, -1 }, },
    // Host interrupts to enable
    .host_enable_bitmask = 
        PRU0_HOSTEN_MASK | PRU1_HOSTEN_MASK | PRU_EVTOUT0_HOSTEN_MASK | PRU_EVTOUT1_HOSTEN_MASK,
};


int main(int argc, char** argv) {
    tpruss_intc_initdata pruss_intc_initdata = interrupt_controller_setup;
	
    prussdrv_init();		
    if (prussdrv_open(PRU_EVTOUT_0)) { 
        fprintf(stderr, "Could not open uio%d, aborting\n", PRU_EVTOUT_0);
        return -1;
    }
    // Initialize interrupts
    prussdrv_pruintc_init(&pruss_intc_initdata);

    // Clear out command buffer to ensure no accidental commands are run
    {
	Command empty_cmd = { 0 };
	for (int i = 0; i < queue_len; i++) {
	    prussdrv_pru_write_memory(PRUSS0_PRU0_DATARAM, i * CommandSzInWords,
				      (uint32_t*)&empty_cmd, sizeof(Command));
	}
    }

    // Run PRU programs
    prussdrv_exec_program(TOOLHEAD_PRU, "./servo_pru.bin");
    prussdrv_exec_program(STEPPER_PRU, "./stepper_pru.bin");

    int cmd;
    bool stopped = true;
    while (1) {
	cmd = getchar();
	if (cmd == EOF) {
	    if (!stopped) {
		stop();
		printf("Sent stop.\n");
		stopped = true;
	    }
	    clearerr(stdin);
	    continue;
	}
        if (cmd == 'M') {
            float x_in, y_in, v_in;
	    stopped = false;
            if (scanf("%f %f %f\n",&x_in,&y_in,&v_in) != EOF) {
                move_xy(x_in,y_in,v_in);
                printf("Move to X %f Y %f - V %f\n",x_in,y_in,v_in);
            }
        } else if (cmd == 'T') {
            int th;
	    stopped = false;
            if (scanf("%d\n",&th) != EOF) {
                toolhead(th);
                printf("Sending %d to toolhead\n",th);
            }
        }
    }
    stop();

    wait_for_completion();

    printf("SUMMARY: oustanding events %d, processed events %d, queue offset %d\n",
            cmds_outstanding, cmds_processed, queue_idx);

    prussdrv_pru_disable(STEPPER_PRU);
    prussdrv_pru_disable(TOOLHEAD_PRU);
    prussdrv_exit ();
	
    return 0;
}

