import schemdraw
import schemdraw.elements as elm
import os

selfdir = os.path.dirname(__file__)

with schemdraw.Drawing() as d:

    elm.Dot()
    elm.Ground()
    Vss_origin = elm.Line().right().length(0.0)

    Vss = elm.Line().right().length(1.0).dot()
    RBias = elm.Resistor().up().label(r'$100\Omega$').label("Rbias", loc="bot")
    elm.Line().up().length(1.5)
    P1B = elm.PFet(bulk=True).anchor('drain').theta(0).label("MP1B", loc="bot")
    elm.Line().at(P1B.gate).down().toy(P1B.drain)
    elm.Line().left().tox(P1B.drain).dot()

    Vss = elm.Line().at(RBias.start).right().length(2.0).dot()

    elm.Line().up().length(0.5)
    N4 = elm.NFet(bulk=True).anchor('source').theta(0).label("MN4", loc="bot")
    elm.Line().at(N4.bulk).left().length(0.5)
    elm.Line().down().toy(Vss.start).dot()

    Vss = elm.Line().at(Vss.end).right().length(2.5).dot()
    elm.Line().up().length(0.5)
    N3 = elm.NFet(bulk=True).anchor('source').theta(0).reverse().label("MN3", loc="bot")
    elm.Line().at(N3.bulk).right().length(0.5)
    elm.Line().down().toy(Vss.start).dot()
    
    Vss = elm.Line().at(Vss.end).right().length(1.5).dot()
    elm.Line().up().length(0.5)
    N1 = elm.NFet(bulk=True).anchor('source').theta(0).label("MN1", loc="bot")
    elm.Line().at(N1.bulk).left().length(0.5)
    elm.Line().down().toy(Vss.start).dot()
    
    elm.Line().at(Vss.end).right().length(2.5).dot()
    elm.Line().up().length(0.5)
    N2 = elm.NFet(bulk=True).anchor('source').theta(0).reverse().label("MN2", loc="bot")
    elm.Line().at(N2.bulk).right().length(0.5)
    Vss = elm.Line().down().toy(Vss.start).dot()
    elm.Line().left().tox(N2.source)

    elm.Dot().at((N1.gate + N2.gate) / 2)
    elm.Line().at((N1.gate + N2.gate) / 2).up().toy(N1.drain)
    elm.Line().left().tox(N1.drain).dot()
    
    elm.Dot().at((N3.gate + N4.gate) / 2)
    elm.Line().at((N3.gate + N4.gate) / 2).up().toy(N1.drain)
    elm.Line().right().tox(N3.drain).dot()

    elm.Line().at(N4.drain).up().length(4.0)
    P4 = elm.PFet(bulk=True).anchor('drain').theta(0).label("MP4", loc="bot")
    elm.Line().at(P4.gate).down().toy(P4.drain)
    elm.Line().left().tox(P4.drain).dot()

    elm.Line().at(N2.drain).up().length(4.0)
    P5 = elm.PFet(bulk=True).anchor('drain').theta(0).reverse().label("MP5", loc="bot")
    elm.Line().at(P5.gate).left().tox(P4.gate).dot()
    elm.Line().at(P5.bulk).right().length(0.5)
    elm.Line().up().length(1.0)
    Vdd = elm.Line().left().tox(P1B.source)
    Vdd = elm.Line().left().length(1.0)

    elm.Line().at(N3.drain).up().length(0.5)
    P2 = elm.PFet(bulk=True).anchor('drain').theta(0).reverse().label("MP2", loc="bot")

    elm.Line().at(N1.drain).up().toy(P2.drain)
    P3 = elm.PFet(bulk=True).anchor('drain').theta(0).label("MP3", loc="bot")

    elm.Line().at(P3.bulk).to(P2.bulk)
    elm.Line().at(P3.source).to(P2.source)

    elm.Dot().at(P1B.gate)    
    elm.Line().at(P1B.gate).right().tox(P2.gate)
    P1 = elm.PFet(bulk=True).anchor('gate').theta(0).reverse().label("MP1", loc="bot")
    elm.Line().at(P1.drain).down().toy(P2.source).dot()

    elm.Line().at(P1B.source).up().toy(Vdd.start).dot()
    elm.Line().at(P1B.bulk).left().length(0.5)
    elm.Line().toy(Vdd.start).dot()

    elm.Line().at(P5.source).up().toy(Vdd.start).dot()

    elm.Line().at(P4.source).up().toy(Vdd.start).dot()
    elm.Line().at(P4.bulk).left().length(0.5)
    elm.Line().up().toy(Vdd.start).dot()

    elm.Line().at(P1.source).toy(Vdd.start).dot()
    p1bulk_net = elm.Line().at(P1.bulk).right().length(0.5).dot()
    elm.Line().up().toy(Vdd.start).dot()
    elm.Line().at(p1bulk_net.end).down().toy(P2.bulk).dot()

    elm.Line().at(Vss.end).right().length(2.25)

    d.config(unit=1) # shorter leads

    elm.Line().up().length(0.25)
    Vmid = elm.SourceV().up().label('1.65V')
    elm.Line().up().length(0.5)
    V1 = elm.SourceSin().up().flip().label('V1')
    elm.Line().up().toy(P3.gate)
    elm.Line().left().length(1.0)
    Rin = elm.Resistor().left().label(r'1 k$\Omega$')
    elm.Line().tox(P3.gate)

    d.config(unit=3)
    elm.Line().at(P2.gate).up().length(1.25)
    elm.Line().right().tox(P5.drain).dot()
    elm.Line().right().tox(Vmid.end)
    elm.Line().right().length(1.5).dot()
    Rl = elm.Resistor().down().label(r'$R_{load}$')
    elm.Line().down().toy((Vmid.end + V1.start) / 2)
    elm.Line().left().tox((Vmid.end + V1.start) / 2).dot()
    elm.Line().at(Rl.start).right().length(1.5)
    
    # Do we want to label nout and ninp?
    # elm.Tag().right().label(r'$n_{out}$')

    Cl = elm.Capacitor().down().label(r'$C_{load}$')
    elm.Line().left().tox(Rl.end).dot()

    elm.Line().at(Vss_origin.end).left().length(0.5)
    elm.Line().up().length(2.0)
    elm.SourceV().up().label('3.3V')
    elm.Line().up().toy(Vdd.end)
    elm.Line().right().tox(Vdd.end)

    # This last push/pop forces the
    # drawing to be fully flushed (otherwise
    # the last element is often missing)
    d.push()
    d.pop()

    d.save(fname=os.path.join(selfdir, "ota.png"),
           transparent=False,
           dpi=300)
