import schemdraw
import schemdraw.elements as elm
import os

selfdir = os.path.dirname(__file__)


with schemdraw.Drawing() as d:

    d.config(unit=2)

    elm.Dot()
    elm.Ground()
    Vin = elm.SourceSin().up().label(r'$V_{in}$')
    L1 = elm.Inductor().right().label(r'$L_1$')
    elm.Dot()
    C2 = elm.Capacitor().down().label(r'$C_2$')
    elm.Inductor().at(C2.start).right().label(r'$L_3$')
    elm.Resistor().down().reverse().label(r'$R_4$').label(['+',r'$v_{out}$','-'], loc='bot')
    elm.Line().left().tox(C2.end).dot()
    elm.Line().left().tox(Vin.start)

    # This last push/pop forces the
    # drawing to be fully flushed (otherwise
    # the last element is often missing)
    d.push()
    d.pop()

    d.save(fname=os.path.join(selfdir, "butterworth.png"),
           transparent=False,
           dpi=300)
