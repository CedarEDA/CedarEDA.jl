import schemdraw
import schemdraw.elements as elm
import os

selfdir = os.path.dirname(__file__)


with schemdraw.Drawing() as d:

    d.config(unit=1.0)

    gnd = elm.Ground()
    elm.Dot()
    start = elm.Line().up().length(1.5)
    Vdd = elm.SourceV().up().label('5V')
    elm.Line().at(start.start).right().length(1.75)

    source_base = elm.Line().up().length(0.75)
    elm.SourceSquare().up().label(r'$V_1$')
    elm.Line().up().length(0.25)
    elm.SourceSin().up().label(r'$V_2$')
    elm.Line().up().length(0.25)
    elm.Line().right().length(0.25)
    v_in = elm.Resistor().right().label(r"100$\Omega$")

    elm.Dot().at(source_base.start)
    Vss = elm.Line().right().length(3.0)

    elm.Line().up().length(0.5)
    Xneg = elm.NFet(bulk=True).anchor('source').theta(0).reverse().label("Xneg", loc="top", ofst=-0.25)
    elm.Line().at(Xneg.bulk).right().length(0.5)
    elm.Line().down().toy(Vss.end).dot()
    Xpos = elm.PFet(bulk=True).at(Xneg.drain).anchor('drain').theta(0).reverse().label("Xpos", loc="top", ofst=-0.25)

    elm.Line().at(Xneg.gate).to(Xpos.gate).dot()
    elm.Line().up().toy(v_in.end)
    elm.Line().left().tox(v_in.end)

    elm.Line().at(Xpos.source).up().length(0.75)
    top_net = elm.Line().left().tox(Vdd.end)
    elm.Line().down().toy(Vdd.end)

    elm.Line().at(Xpos.bulk).right().length(0.5)
    elm.Line().up().toy(top_net.end)
    elm.Line().left().tox(Xpos.source).dot()

    elm.Dot().at((Xneg.drain + Xpos.drain)/2)
    vout_plus = elm.Line().right().length(1.5).dot(open=True).label("+",loc="rgt")
    
    elm.Dot().at(Vss.end)
    vout_minus = elm.Line().right().tox(vout_plus.end).dot(open=True).label("-", loc="rgt")

    elm.Label().at((vout_plus.end + vout_minus.end) / 2).label(r"$v_{out}$")

    # This last push/pop forces the
    # drawing to be fully flushed (otherwise
    # the last element is often missing)
    d.push()
    d.pop()

    d.save(fname=os.path.join(selfdir, "inverter.png"),
           transparent=False,
           dpi=300)
