#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <stdbool.h>

// PRU driver headers
#include <prussdrv.h>
#include <pruss_intc_mapping.h>


#define WHICH_PRU  		 0

const uint8_t ZERO_QUEUE_BIT = 0x4;

typedef struct {
    uint32_t x_period;
    uint32_t y_period;
    uint32_t z_period;
    uint32_t end_tick;
    uint8_t direction;
    uint8_t enable;
    uint8_t cmd;
    uint8_t reserved;
} __attribute__((packed,aligned(4))) Command;

const uint32_t NO_EVT_CODE = 0xffffffff;
uint8_t cmds_outstanding = 0;
uint16_t cmds_processed = 0;
uint32_t last_evt_code = NO_EVT_CODE;

// Queue management
uint8_t queue_idx = 0; // next empty queue slot
const uint8_t queue_len = 20; // total number of Command entries in queue

// Wait for next event and update oustanding/processed command counts
void wait_for_event() {
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
    last_evt_code = event;
}

void enqueue(Command* cmd) {
    while (cmds_outstanding > 8) wait_for_event();
    cmd->cmd &= ~ZERO_QUEUE_BIT;
    bool zero_queue = (queue_idx >= queue_len - 2);
    if (zero_queue) {
        printf("(zero queue) ");
        cmd->cmd |= ZERO_QUEUE_BIT;
    } 
    const unsigned int CommandSzInWords = 5;
    int written = prussdrv_pru_write_memory(PRUSS0_PRU0_DATARAM, queue_idx * CommandSzInWords,
        (uint32_t*)cmd, sizeof(Command));
    printf("command queued at %d (%d words)\n",queue_idx,written);
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
    cmd.cmd = 0x01;
    cmd.end_tick = 200;
    enqueue(&cmd);
}

/**
 * Wait until current queue is completely processed.
 */
void wait_for_completion();
    

int main(int argc, char** argv) {
    int argidx = 1;
    while (argidx < argc) {
        if (strncmp(argv[argidx],"-d",2) == 0) {
            argidx++;
            if (argc == argidx) return -1;
            //command.direction = atoi(argv[argidx++]);
        }
        else if (strncmp(argv[argidx],"-e",2) == 0) {
            argidx++;
            if (argc == argidx) return -1;
            //command.enable = atoi(argv[argidx++]);
        } else {
            printf("Unrecognized argument %s\n",argv[argidx]);
            return -1;
        }
    }

    tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;
	
    prussdrv_init();		
    if (prussdrv_open(PRU_EVTOUT_0)) { 
        fprintf(stderr, "Could not open uio%d, aborting\n", PRU_EVTOUT_0);
        return -1;
    }
    // Initialize interrupts
    prussdrv_pruintc_init(&pruss_intc_initdata);

    // Run PRU program
    prussdrv_exec_program(WHICH_PRU, "./stepper_pru.bin");

    move_rel_xy_time( 0, -4000, 80000000 );
    move_rel_xy_time( -4000, 0, 80000000 );
    prussdrv_pru_send_event (ARM_PRU0_INTERRUPT);
    for (int i = 0; i < 12; i++) {
        printf("*** SQUARE START ***\n");
        move_rel_xy_time( 0, 4000, 80000000 );
        move_rel_xy_time( 4000, 0, 80000000 );
        move_rel_xy_time( 0, -4000, 80000000 );
        move_rel_xy_time( -4000, 0, 80000000 );
    }
    stop();

    while (cmds_outstanding > 0) {
        wait_for_event();
        printf("event; oustanding events %d, processed events %d, queue offset %d\n",
                cmds_outstanding, cmds_processed, queue_idx);
    }

    printf("SUMMARY: oustanding events %d, processed events %d, queue offset %d\n",
            cmds_outstanding, cmds_processed, queue_idx);

    prussdrv_pru_disable(WHICH_PRU);
    prussdrv_exit ();
	
    return 0;
}

