# Spectre Syntax Support

Spectre refers to the netlist language used by the [Spectre Circuit Simulator](https://en.wikipedia.org/wiki/Spectre_Circuit_Simulator) and is closely related to SPICE.
CedarEDA supports the following syntax elements in Spectre, please file an issue on our [public issue tracker](https://github.com/CedarEDA/PublicIssues) for Spectre features that are important to you, but are not yet implemented.

## Spectre Elements

Type            | Spectre Element | Arguments
----------------|-----------------|--------------
Voltage Source  | `vsource`       | `type=dc`, `type=sin`, `type=pwl`
Current Source  | `isource`       | `type=dc`, `type=sin`, `type=pwl`
Ideal Resistor  | `resistor`      | `r`
Ideal Capacitor | `capactor`      | `c`
Ideal Inductor  | `inductor`      | `l`


## Spectre Models

Type            | Model Type           | Reference
----------------|----------------------|--------------
BSIM4 MOSFET    | `{n,p}mos LEVEL=54`  | [`Supported Models`]


## Spectre Commands

Supported Commands | Example
-------------------|--------------
`parameters`       | `parameters rl=10k freq=1M`

Ignored Commands | Script Equivalent
-----------------|------------------
`info`           | Depends
`dc`             | See [Running DC Analysis](@ref)
`tran`           | See [Running Transient Analysis](@ref)
`noise`          | Coming Sooon
`options`        | These parameters must be passed in the Julia driver harness


## Spectre Numbers
Numbers in Spectre support the following scaling suffixes:

Suffix | Scale
-------|------
T      | 10^12
G      | 10^9
M      | 10^6
K      | 10^3
k      | 10^3
_      | 1
%      | 10^-2
c      | 10^-2
m      | 10^-3
u      | 10^-6
n      | 10^-9
p      | 10^-12
f      | 10^-15
a      | 10^-18

## Spectre Equations

The following mathematical operators are supported:

Operator | Meaning
---------|--------
`+`      | Addition
`-`      | Subtraction
`*`      | Multiplication
`/`      | Division
`^`      | Exponentiation
`!`      | Boolean not
`==`      | Boolean equal
`!=`      | Boolean not equal
`>`      | Greater than
`<`      | Less than
`<=`      | Less than or equal
`>=`      | Greater than or equal

The following mathematical functions are supported

Function     | Description
-------------|-------------
`max(x, y)`  | Maximum of `x` and `y`
`min(x, y)`  | Minimum of `x` and `y`
`abs(x)`     | Absolute value of `x`
`ln(x)`      | Logarithm of `x` to base ℯ
`log(x)`     | Logarithm of `x` to base ℯ
`log10(x)`   | Logarithm of `x` to base 10
`exp(x)`     | `ℯ^x`
`pow(x,y)`   | `x` to the power of `y`
`sqrt(x)`    | Square root of `x`
`sinh(x)`    | Hyperbolic sine of `x`
`cosh(x)`    | Hyperbolic cosine of `x`
`tanh(x)`    | Hyperbolic tangent of `x`
`sin(x)`     | Sine of `x` (in radians)
`cos(x)`     | Cosine of `x` (in radians)
`tan(x)`     | Tangent of `x` (in radians)
`atan(x)`    | Inverse tangent of `x`
`arctan(x)`  | Inverse tangent of `x`
`asinh(x)`   | Inverse hyperbolic sine of `x`
`acosh(x)`   | Inverse hyperbolic cosine of `x`
`atanh(x)`   | Inverse hyperbolic tangent of `x`
`int(x)`     | Integer value less than or equal to `x`
`floor(x)`   | Integer value less than or equal to `x`
`ceil(x)`    | Integer value greater than or equal to `x`
