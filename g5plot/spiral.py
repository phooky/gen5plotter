#!/usr/bin/python
import math
import sys

v=150
r = 2
max_r = 40
factor = 0.35
theta = 0

if len(sys.argv) > 1:
    max_r = float(sys.argv[1])

print("U")
print("M0 0 100")
print("D")
# estimated seg length = theta_d * r
# we want to keep seglens to about 1.5
while r < max_r:
    theta_d = 1.5/r
    theta = theta + theta_d
    r = theta * factor
    x = math.sin(theta) * r
    y = math.cos(theta) * r
    print("M{} {} {}".format(x,y,v))

print("M0 0 150")

print("U")
