#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <stdbool.h>

// PRU driver headers
#include <prussdrv.h>

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

uint16_t cmds_processed = 0;

uint8_t* prumem = NULL;

static volatile int not_interrupted = 1;

// Queue management
uint8_t queue_idx = 0; // next empty queue slot
const uint8_t queue_len = 20; // total number of Command entries in queue

// Check if we're running or not
bool is_running = false;

void enqueue(Command* cmd) {
    int byteoff = queue_idx * sizeof(Command);
    Command* prucmd = (Command*)(prumem + byteoff);
    // clear reset flag and ready flag on existing command, just in case
    cmd->cmd &= ~((1 << CFL_RST_QUEUE) | (1 << CFL_CMD_READY));
    // zero the queue after this entry if near the end
    bool zero_queue = (queue_idx >= queue_len - 2);
    if (zero_queue) {
        cmd->cmd |= 1 << CFL_RST_QUEUE;
    }
    // wait for empty command space
    uint32_t attempts = 0;
    printf("Full buffer %d",prucmd->cmd & (1<<CFL_CMD_READY));
    while ((prucmd->cmd & (1<<CFL_CMD_READY)) && not_interrupted) {
	// pass and busy wait, we should check for timeouts at some point
	if (attempts == 0xffff) { printf("Busy waiting"); fflush(stdout); }
	attempts++;
    }
    *prucmd = *cmd;
    // Set ready bit
    cmd->cmd |= 1 << CFL_CMD_READY;
    *prucmd = *cmd;
    queue_idx = zero_queue?0:queue_idx+1;
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

#include <signal.h>

void handle_sigint(int dummy) {
    not_interrupted = 0;
    printf("Interrupted; shutting down.\n");
}

int main(int argc, char** argv) {
    //tpruss_intc_initdata pruss_intc_initdata = interrupt_controller_setup;
    prussdrv_init();	
    if (prussdrv_open(PRU_EVTOUT_0)) { 
        fprintf(stderr, "Could not open uio%d, aborting\n", PRU_EVTOUT_0);
        return -1;
    }
    fprintf(stderr,"Opened PRU.\n");
    
    // Initialize interrupts
    //prussdrv_pruintc_init(&pruss_intc_initdata);

    if (prussdrv_map_prumem(PRUSS0_PRU0_DATARAM, (void**) &prumem) != 0) {
	fprintf(stderr, "Could not map PRU0 data ram! Aborting.\n");
	return -1;
    }
    
    // Clear out command buffer to ensure no accidental commands are run
    {
	const int wordsz = sizeof(Command)*queue_len / 4;
	for (int i = 0; i < wordsz; i++) {
	    *((uint32_t*)prumem + i) = 0;
	}
    }

    // Run PRU programs
    prussdrv_exec_program(TOOLHEAD_PRU, "./servo_pru.bin");
    prussdrv_exec_program(STEPPER_PRU, "./stepper_pru.bin");

    int cmd;
    struct sigaction sa = { .sa_handler = handle_sigint, .sa_flags = 0 };
    sigaction(SIGINT, &sa, NULL);

    while (not_interrupted) {
	cmd = getchar();
	if (cmd == EOF) {
	    clearerr(stdin);
	    continue;
	}
	if (cmd == 'Z') {
	    printf("Now at 0,0\n");
	    set_here_as_home();
	}
	if (cmd == 'Q') {
	    printf("Explicit shutdown.\n");
	    not_interrupted = false;
	}
        if (cmd == 'M') {
            float x_in, y_in, v_in;
            if (scanf("%f %f %f\n",&x_in,&y_in,&v_in) != EOF) {
                move_xy(x_in,y_in,v_in);
                printf("Move to X %f Y %f - V %f\n",x_in,y_in,v_in);
            }
        } else if (cmd == 'T') {
            int th;
            if (scanf("%d\n",&th) != EOF) {
                toolhead(th);
                printf("Sending %d to toolhead\n",th);
            }
        }
    }
    printf("Out of main loop.\n");

    printf("SUMMARY: oustanding events %d, processed events %d, queue offset %d\n",
	   0, cmds_processed, queue_idx);

    prussdrv_pru_disable(STEPPER_PRU);
    prussdrv_pru_disable(TOOLHEAD_PRU);
    prussdrv_exit ();

    return 0;
}

