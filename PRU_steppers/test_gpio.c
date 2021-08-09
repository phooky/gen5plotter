#include <stdio.h>
#include <unistd.h>

// from arch/arm/mach-davinci/include/mach/gpio-davinci.h
#define GPIO_TO_PIN(bank, gpio)	(16 * (bank) + (gpio))
#define GPIO5_5 GPIO_TO_PIN(5,5)
#define GPIO2_5 GPIO_TO_PIN(2,5)
// PIN 14 on GOWANUS connector
#define CH_RSV0 GPIO5_5
#define CH_RSV1 GPIO2_5

void setpin(int pinno, int value) {
    FILE *ioval;
    char buf[1024];
    sprintf(buf,"/sys/class/gpio/gpio%d/value",pinno);
    printf("opening %s for %d\n",buf,value);
    ioval = fopen(buf, "w");
    fseek(ioval,0,SEEK_SET);
    fprintf(ioval,"%d",value);
    fclose(ioval);
}

int main(int argc, char** argv) {
    FILE *io,*iodir;
    char buf[1024];
    int outpin = CH_RSV0;

    fprintf(stdout,"start\n");
    return 0;
    io = fopen("/sys/class/gpio/export", "w");
    fseek(io,0,SEEK_SET);
    fprintf(io,"%d",outpin);
    fflush(io);

    printf("did export\n");
    sprintf(buf,"/sys/class/gpio/gpio%d/direction",outpin);
    iodir = fopen(buf, "w");
    fseek(iodir,0,SEEK_SET);
    fprintf(iodir,"out");
    fflush(iodir);
    printf("did dir\n");

    while(1)
    {
        setpin(outpin,1);
        sleep(1);
        setpin(outpin,0);
        sleep(1);
    }

    fclose(io);
    fclose(iodir);
    return 0;
}

