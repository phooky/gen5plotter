#!/bin/sh

PLOTTER=/var/run/plotter
PIDFILE=/var/run/plotter_pid
LOGFILE=/var/log/plotter.log

cd /var/scratch/g5plot
kill -9 `cat ${PIDFILE}`
rm ${PIDFILE}
rm ${PLOTTER}
# rotate log file here

