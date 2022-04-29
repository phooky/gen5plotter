#!/bin/sh

PLOTTER=gen5
PIPE=/var/run/plotter
DEPLOY_DIR=/var/scratch/g5plot

case $1 in
    start)
	ssh ${PLOTTER} ${DEPLOY_DIR}/g5p_start.sh
	;;
    stop)
	ssh ${PLOTTER} ${DEPLOY_DIR}/g5p_stop.sh
	;;
    penup)
	ssh ${PLOTTER} echo T0 ">${PIPE}"
	;;
    pendown)
	ssh ${PLOTTER} echo T200 ">${PIPE}"
	;;
    *)
	scp $1 ${PLOTTER}:/var/scratch/g5plot/plot.temp
	ssh ${PLOTTER} cat /var/scratch/g5plot/plot.temp ">${PIPE}"
	;;
esac


	


