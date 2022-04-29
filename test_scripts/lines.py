#!/usr/bin/python3
import math
import sys
from random import random

# radius in mm
r = 100
vt = 160
vd = 100
r_exclude = 50;

def ray_intersect_circle(x1,y1,x2,y2):
    pass

def line_on_circle():
    theta_a = random() * 2 * math.pi
    theta_b = theta_a + math.pi - (random() * 1.1 * math.pi);
    xa,ya = math.cos(theta_a) * r, math.sin(theta_a) * r
    xb,yb = math.cos(theta_b) * r, math.sin(theta_b) * r
    print("U")
    print("M{} {} {}".format(xa,ya,vt))
    print("D")
    print("M{} {} {}".format(xb,yb,vd))

print("Z")
for i in range(500):
    line_on_circle()
print("U")



