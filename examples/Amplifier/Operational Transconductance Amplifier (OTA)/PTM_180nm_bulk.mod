* Edited by Glen on 2016/11/15:
* - Changed model from BSIM3 to BSIM4 v4.8.2 (ngspice LEVEL=54)

* Predictive Technology Model Beta Version
* 180nm NMOS SPICE Parametersv (normal one)
*  changed: from original one:
* +lmin=1.8e-7 lmax=1.8e-7 wmin=1.8e-7 wmax=1.0e-4 Tref=27.0 version =3.1
* to: +lmin=1.8e-7 lmax=1e-5 wmin=1.8e-7 wmax=1.0e-3 Tref=27.0 version =4.8.2
*
.model NMOS NMOS
+Level = 54 version=4.8
+Lint = 4.e-08
*+Tox = 4.e-09
+Vth0 = 0.3999 Rdsw = 250
+lmin=1.8e-7 lmax=1.0e-5 wmin=1.8e-7 wmax=1.0e-3
*+Tref=27.0
+Xj= 6.0000000E-08
*+Nch= 5.9500000E+17
+lln= 1.0000000            lwn= 1.0000000              wln= 0.00
+wwn= 0.00                 ll= 0.00
+lw= 0.00                  lwl= 0.00                   wint= 0.00
+wl= 0.00                  ww= 0.00                    wwl= 0.00
+Mobmod=  1                binunit= 2                  xl=  0
+xw=  0
*+binflag=  0
+Dwg= 0.00                 Dwb= 0.00
+K1= 0.5613000             K2= 1.0000000E-02
+K3= 0.00                  Dvt0= 8.0000000             Dvt1= 0.7500000
+Dvt2= 8.0000000E-03       Dvt0w= 0.00                 Dvt1w= 0.00
+Dvt2w= 0.00
*+Nlx= 1.6500000E-07
+W0= 0.00
+K3b= 0.00                 Ngate= 5.0000000E+20
+Vsat= 1.3800000E+05       Ua= -7.0000000E-10          Ub= 3.5000000E-18
+Uc= -5.2500000E-11        Prwb= 0.00
+Prwg= 0.00                Wr= 1.0000000               U0= 3.5000000E-02
+A0= 1.1000000             Keta= 4.0000000E-02         A1= 0.00
+A2= 1.0000000             Ags= -1.0000000E-02         B0= 0.00
+B1= 0.00
+Voff= -0.12350000         NFactor= 0.9000000          Cit= 0.00
+Cdsc= 0.00                Cdscb= 0.00                 Cdscd= 0.00
+Eta0= 0.2200000           Etab= 0.00                  Dsub= 0.8000000
+Pclm= 5.0000000E-02       Pdiblc1= 1.2000000E-02      Pdiblc2= 7.5000000E-03
+Pdiblcb= -1.3500000E-02   Drout= 1.7999999E-02        Pscbe1= 8.6600000E+08
+Pscbe2= 1.0000000E-20     Pvag= -0.2800000            Delta= 1.0000000E-02
+Alpha0= 0.00              Beta0= 30.0000000
+kt1= -0.3700000           kt2= -4.0000000E-02         At= 5.5000000E+04
+Ute= -1.4800000           Ua1= 9.5829000E-10          Ub1= -3.3473000E-19
+Uc1= 0.00                 Kt1l= 4.0000000E-09         Prt= 0.00
*+Cj= 0.00365
*+Mj= 0.54
*+Pb= 0.982
*+Cjsw= 7.9E-10
*+Mjsw= 0.31
*+Php= 0.841
*+Cta= 0                    Ctp= 0                      Pta= 0
*+Ptp= 0                    JS=1.50E-08                 JSW=2.50E-13
*+N=1.0                     Xti=3.0
+Cgdo=2.786E-10
+Cgso=2.786E-10            Cgbo=0.0E+00                Capmod= 2
*+NQSMOD= 0                 Elm= 5
+Xpart= 1
+Cgsl= 1.6E-10             Cgdl= 1.6E-10
*+Ckappa= 2.886
+Cf= 1.069e-10             Clc= 0.0000001              Cle= 0.6
+Dlc= 4E-08                Dwc= 0                      Vfbcv= -1


*
* Predictive Technology Model Beta Version
* 180nm PMOS SPICE Parametersv (normal one)
*

.model PMOS PMOS
+Level= 54 version=4.8
*+Tref=27.0
+Lint= 3.e-08
*+Tox= 4.2e-09
+Vth0= -0.42               Rdsw= 450
+lmin= 1.8e-7              lmax=1e-5
+wmin= 1.8e-7              wmax=1.0e-3
+Xj= 7.0000000E-08
*+Nch= 5.9200000E+17
+lln= 1.0000000            lwn= 1.0000000              wln= 0.00
+wwn= 0.00                 ll= 0.00
+lw= 0.00                  lwl= 0.00                   wint= 0.00
+wl= 0.00                  ww= 0.00                    wwl= 0.00
+Mobmod=  1                binunit= 2                  xl= 0.00
+xw= 0.00
*+binflag=  0
+Dwg= 0.00                   Dwb= 0.00
*+ACM= 0                    ldif= 0.00                  hdif= 0.00
+rsh= 0
*+rd= 0                       rs= 0
*+rsc= 0                    rdc= 0
+K1= 0.5560000             K2= 0.00
+K3= 0.00                  Dvt0= 11.2000000            Dvt1= 0.7200000
+Dvt2= -1.0000000E-02      Dvt0w= 0.00                 Dvt1w= 0.00
+Dvt2w= 0.00
*+Nlx= 9.5000000E-08
+W0= 0.00
+K3b= 0.00                 Ngate= 5.0000000E+20
+Vsat= 1.0500000E+05       Ua= -1.2000000E-10          Ub= 1.0000000E-18
+Uc= -2.9999999E-11        Prwb= 0.00
+Prwg= 0.00                Wr= 1.0000000               U0= 8.0000000E-03
+A0= 2.1199999             Keta= 2.9999999E-02         A1= 0.00
+A2= 0.4000000             Ags= -0.1000000             B0= 0.00
+B1= 0.00
+Voff= -6.40000000E-02     NFactor= 1.4000000          Cit= 0.00
+Cdsc= 0.00                Cdscb= 0.00                 Cdscd= 0.00
+Eta0= 8.5000000           Etab= 0.00                  Dsub= 2.8000000
+Pclm= 2.0000000           Pdiblc1= 0.1200000          Pdiblc2= 8.0000000E-05
+Pdiblcb= 0.1450000        Drout= 5.0000000E-02        Pscbe1= 1.0000000E-20
+Pscbe2= 1.0000000E-20     Pvag= -6.0000000E-02        Delta= 1.0000000E-02
+Alpha0= 0.00              Beta0= 30.0000000
+kt1= -0.3700000           kt2= -4.0000000E-02         At= 5.5000000E+04
+Ute= -1.4800000           Ua1= 9.5829000E-10          Ub1= -3.3473000E-19
+Uc1= 0.00                 Kt1l= 4.0000000E-09         Prt= 0.00
*+Cj= 0.00138
*+Mj= 1.05
*+Pb= 1.24
*+Cjsw= 1.44E-09
*+Mjsw= 0.43
*+Php= 0.841
*+Cta= 0.00093              Ctp= 0                      Pta= 0.00153
*+Ptp= 0                    JS=1.50E-08                 JSW=2.50E-13
*+N=1.0                     Xti=3.0
+Cgdo=2.786E-10
+Cgso=2.786E-10            Cgbo=0.0E+00                Capmod= 2
*+NQSMOD= 0                 Elm= 5
+Xpart= 1
+Cgsl= 1.6E-10             Cgdl= 1.6E-10
*+Ckappa= 2.886
+Cf= 1.058e-10             Clc= 0.0000001              Cle= 0.6
+Dlc= 3E-08                Dwc= 0                      Vfbcv= -1
