#!/usr/bin/python3

from more_itertools import peekable

is_pen_down = False
v_travel = 100
v_draw = 100
velocity = v_travel

def do_pendown(draw = True):
    global is_pen_down
    global v
    if is_pen_down != draw:
        if draw:
            velocity = v_draw
            yield "D"
        else:
            velocity = v_travel
            yield "U"
        is_pen_down = draw

def consume_wsp(d_iter):
    while d_iter.peek().isspace():
        next(d_iter)

def consume_wsp_comma(d_iter):
    while d_iter.peek().isspace() or d_iter.peek() == ',':
        next(d_iter)

def read_float(d_iter):
    check = d_iter.peek()
    if not (check.isdigit() or check == '-'):
        return None
    if check == '-':
        sign = -1
        next(d_iter)
    else:
        sign = 1
    val = 0
    dp = 1
    while True:
        nc = next(d_iter,' ')
        if nc == '.':
            break
        if not nc.isdigit():
            d_iter.prepend(nc)
            return val * sign
        else:
            val = val * 10 + int(nc)
    while True:
        nc = next(d_iter,' ')
        if not nc.isdigit():
            d_iter.prepend(nc)
            return val * sign
        val += float(nc) * (10**-dp)
        dp += 1
        
        
    
def handle_move(d_iter, absolute, draw = False):
    yield from do_pendown(draw)
    if absolute:
        c = 'M'
    else:
        c = 'R'
    # read X and Y
    while True:
        consume_wsp(d_iter)
        x = read_float(d_iter)
        if x == None:
            break
        consume_wsp_comma(d_iter)
        y = read_float(d_iter)
        if y == None:
            break
        yield '{}{} {} {}'.format(c,x,y,velocity)

def handle_line(d_iter, absolute):
    yield from handle_move(d_iter, absolute, True)

handle_code = {
    'M' : handle_move,
    #'Z' : handle_closepath,
    'L' : handle_line,
    #'H' : handle_horiz,
    #'V' : handle_vert,
    # we'll handle arcs and beziers later
   }

class FormatError(Exception):
    pass

def path_d_to_plot(d_iter):
    'Generates a set of plotter commands from an iterator over a path "d" code.'
    d_iter = peekable(d_iter)
    while True:
        consume_wsp(d_iter)
        code = next(d_iter)
        if not code.isalpha():
            raise FormatError
        yield from handle_code[code.upper()](d_iter,code.isupper())


for l in path_d_to_plot(iter('M1,2 3 4 5, 6 7 ,8L 9 10M200 200l20 20')):

        print(l)
        
        
