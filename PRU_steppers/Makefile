CCTOOLS?=arm-linux-gnueabi-gcc
PRUDIR?=../pru_sw
DEPLOY_TO?=gen5:/var/scratch/PRU_steppers
SCP?=scp

LIBDIR_APP_LOADER?=$(PRUDIR)/app_loader/lib
INCDIR_APP_LOADER?=$(PRUDIR)/app_loader/include
PASM=$(PRUDIR)/utils/pasm

CFLAGS+= -Wall -I$(INCDIR_APP_LOADER) -D__DEBUG -O2 -mtune=arm926ej-s -march=armv5te
LDFLAGS+=-L$(LIBDIR_APP_LOADER) -lprussdrv -lpthread -lm -static-libgcc -static
TARGET=g5plot

PRU_BINS = stepper_pru.bin servo_pru.bin
OBJS =g5plot.o 

.SUFFIXES: 

all: $(PRU_BINS) $(TARGET) 


%.bin: %.p
	$(PASM) -b $< $*

%.o: %.c 
	$(CCTOOLS) $(CFLAGS) -c -o $@ $< 

$(TARGET): $(OBJS) $(PRU_BINS) $(LIBDIR_APP_LOADER)/libprussdrv.a
	$(CCTOOLS) $(CFLAGS) -o $@ $(OBJS) $(LDFLAGS)

.PHONY: clean deploy

deploy: $(TARGET) $(PRU_BINS)
	$(SCP) $^ $(DEPLOY_TO)

clean:
	rm -f $(PRU_BINS) $(OBJS) $(TARGET) 
