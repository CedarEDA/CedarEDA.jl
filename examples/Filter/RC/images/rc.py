import schemdraw
import schemdraw.elements as elm
import os

selfdir = os.path.dirname(__file__)

with schemdraw.Drawing() as d:
    d.config(unit=2.5)
    first_line = elm.Line().right().length(0.3)
    d += elm.Resistor().right().label("0.2 Ω")
    d += elm.Line().right().length(0.3)
    d += elm.Capacitor().down().label('500 mF').label(['+',r'$v_{out}$','-'], loc='bot')
    d += elm.Line().left().tox(first_line.start)
    elm.Dot()
    elm.Ground()
    d += elm.SourceSquare().up().label(r'$V_{in}$', loc="bot")

    d.save(fname=os.path.join(selfdir, "rc.png"),
           transparent=False,
           dpi=300)
