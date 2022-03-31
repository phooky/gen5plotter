#!/bin/sh

PLOTTER=/var/run/plotter
PIDFILE=/var/run/plotter_pid
LOGFILE=/var/log/plotter.log

cd /var/scratch/g5plot
mkfifo ${PLOTTER}
nohup ./g5plot <${PLOTTER} >${LOGFILE} &
echo $! > ${PIDFILE}

