import schemdraw
import schemdraw.elements as elm
import os

selfdir = os.path.dirname(__file__)


with schemdraw.Drawing() as d:

    Ibias = elm.SourceI().up().label(r'$i_{bias}$')
    M3 = elm.PFet(bulk=True).anchor('drain').theta(0).label("M3", loc="top", ofst=-0.15)
    # elm.Line().at(M3.bulk).left().length(0.5)
    # elm.Line().up().
    
    # to(M3.source)
    elm.Dot().at(M3.gate)
    elm.Line().at(M3.gate).down().toy(M3.drain)
    elm.Line().tox(M3.drain).dot()
    
    elm.Line().at(M3.gate).right().length(0.25)
    M2 = elm.PFet(bulk=True).anchor('gate').theta(0).reverse().label("M2", loc="top", ofst=-0.15)
    elm.Line().at(M2.drain).down().length(0.5)

    M1 = elm.NFet(bulk=True).anchor('drain').theta(0).reverse().label("M1", loc="top", ofst=-0.15)
    elm.Line().at(M1.gate).left().length(0.25)

    d.config(unit=2.0)
    elm.SourceSin().down().reverse().label(r'$V_{in}$')
    elm.Dot()
    Vss = elm.Line().right().tox(M1.source)
    elm.Line().up().toy(M1.source)
    elm.Line().at(Vss.start).tox(Ibias.start)
    elm.Line().up().toy(Ibias.start)

    elm.Line().at(M1.bulk).right().length(0.5)
    elm.Line().down().toy(Vss.end).dot()

    elm.Dot().at((M1.drain + M2.drain) / 2)
    elm.Line().right().length(2.0)
    elm.Line().down().length(0.7)
    elm.Capacitor().down().label('7 pF', loc="top").label(['+',r'$v_{out}$','-'],loc='bot')
    elm.Line().down().toy(Vss.end)
    elm.Line().left().tox(Vss.end).dot()

    elm.Line().at(M2.bulk).right().length(0.5)
    elm.Line().up().toy(M2.source)
    elm.Line().up().length(0.6)
    Vdd = elm.Line().left().tox(M2.source).dot()
    elm.Line().down().toy(M2.source)
    Vdd = elm.Line().at(Vdd.end).left().tox(M3.source).dot()
    elm.Line().down().toy(M3.source)
    elm.Line().at(Vdd.end).left().tox(M3.bulk)
    Vdd = elm.Line().left().length(0.5).dot()
    elm.Line().down().toy(M3.bulk)
    elm.Line().right().tox(M3.bulk)

    elm.Line().at(Vdd.end).left().length(1.25)
    elm.Line().down().length(1.5)
    elm.SourceV().down().reverse().label('3.3V')
    elm.Line().down().toy(Vss.end)
    elm.Line().right().tox(Ibias.start).dot()
    
    gnd = elm.Ground()

    # This last push/pop forces the
    # drawing to be fully flushed (otherwise
    # the last element is often missing)
    d.push()
    d.pop()

    d.save(fname=os.path.join(selfdir, "amplifier.png"),
           transparent=False,
           dpi=300)
