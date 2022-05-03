#!/usr/bin/python3

from gi import require_version;
require_version('Gtk','3.0')
from gi.repository import Gtk, GLib
import cairo
import math

dim_mm = (160, 160)
scale = 3.

class Emulator(Gtk.Window):
    def __init__(self):
        super(Emulator,self).__init__()
        self.init_ui()
        self.cmds = None

    def init_ui(self):
        area = Gtk.DrawingArea()
        area.connect("draw", self.on_draw)
        self.add(area)
        self.set_title("Plotter emulator")
        self.resize(dim_mm[0] * scale,dim_mm[1] * scale)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.connect("delete-event", Gtk.main_quit)
        self.show_all()

    def on_draw(self, wid, cr):
        # draw background
        cr.save()
        cr.set_source_rgb(0.9,0.95,0.9)
        cr.paint()
        cr.restore()
        # iterate through commands
        position = (0.,0.)
        penup = True
        if self.cmds:
            for line in self.cmds:
                if len(line) < 1:
                    continue
                cmd,params = line[0],list(map(float,line[1:].split()))
                if cmd == 'D':
                    penup = False
                if cmd == 'U':
                    penup = True
                    cr.stroke()
                if cmd == 'M':
                    if penup:
                        cr.move_to(params[0]*scale,params[1]*scale)
                    else:
                        cr.line_to(params[0]*scale,params[1]*scale)
        cr.stroke()


from sys import argv

if __name__ == "__main__":
    app = Emulator()
    if len(argv) > 1:
        app.cmds = open(argv[1]).readlines()
    Gtk.main()

