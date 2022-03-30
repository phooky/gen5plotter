CCTOOLS?=arm-linux-gnueabi-gcc
PRUDIR?=../pru_sw
PLOTTER?=gen5
DEPLOY_DIR?=/var/scratch/g5plot
DEPLOY_TO?=$(PLOTTER):$(DEPLOY_DIR)
SCP?=scp
SSH?=ssh

LIBDIR_APP_LOADER?=$(PRUDIR)/app_loader/lib
INCDIR_APP_LOADER?=$(PRUDIR)/app_loader/include
PASM=$(PRUDIR)/utils/pasm

CFLAGS+= -Wall -I$(INCDIR_APP_LOADER) -D__DEBUG -O2 -mtune=arm926ej-s -march=armv5te
LDFLAGS+=-L$(LIBDIR_APP_LOADER) -lprussdrv -lpthread -lm -static-libgcc -static
TARGET=g5plot

PRU_BINS = stepper_pru.bin servo_pru.bin
OBJS =g5plot.o 

SCRIPTS = g5p_start.sh g5p_stop.sh

.SUFFIXES: 

all: $(PRU_BINS) $(TARGET) 


%.bin: %.p
	$(PASM) -b $< $*

%.o: %.c 
	$(CCTOOLS) $(CFLAGS) -c -o $@ $< 

$(TARGET): $(OBJS) $(PRU_BINS) $(LIBDIR_APP_LOADER)/libprussdrv.a
	$(CCTOOLS) $(CFLAGS) -o $@ $(OBJS) $(LDFLAGS)

.PHONY: clean deploy

deploy: $(TARGET) $(PRU_BINS) $(SCRIPTS)
	$(SSH) $(PLOTTER) mkdir -p $(DEPLOY_DIR)
	$(SCP) $^ $(DEPLOY_TO)

start:
	$(SSH) $(PLOTTER) $(DEPLOY_DIR)/g5p_start.sh

stop:
	$(SSH) $(PLOTTER) $(DEPLOY_DIR)/g5p_stop.sh

deploy_and_run: stop deploy start
	echo "Done."


clean:
	rm -f $(PRU_BINS) $(OBJS) $(TARGET) 
