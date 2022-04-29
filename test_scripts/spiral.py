#!/usr/bin/python
import math
import sys

v=150
max_r = 40
factor = 0.35

def spiral(max_r):
    print("U")
    print("M0 0 100")
    print("D")
    # estimated seg length = theta_d * r
    # we want to keep seglens to about 1.5
    r = 2
    theta = 0
    while r < max_r:
        theta_d = 1.5/r
        theta = theta + theta_d
        r = theta * factor
        x = math.sin(theta) * r
        y = math.cos(theta) * r
        print("M{} {} {}".format(x,y,v))
    print("U")


if len(sys.argv) > 1:
    max_r = float(sys.argv[1])

if len(sys.argv) > 2:
    gx = int(sys.argv[2])
    gy = int(sys.argv[3])
    ux = -(gx-1)*max_r
    uy = -(gy-1)*max_r
    print("U")
    print("M{} {} {}".format(ux,uy,v))
    print("Z")
    for x in range(gx):
        for y in range(gy):
            spiral(max_r)
            print("M0 {} {}".format(max_r*2,v))
            print("Z")
        print("M0 {} {}".format(-max_r*2*gy,v))
        print("Z")
        print("M{} 0 {}".format(max_r*2,v))
        print("Z")

        
else:
    spiral(max_r)


