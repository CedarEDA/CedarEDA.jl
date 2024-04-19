# SPICE Syntax Support

[SPICE](https://en.wikipedia.org/wiki/SPICE) defines the connections between circuit elements, hence the files being referred to as "netlists".
CedarEDA supports the following syntax elements in SPICE, please file an issue on our [public issue tracker](https://github.com/CedarEDA/PublicIssues) for SPICE features that are important to you, but are not yet implemented.

## SPICE Elements

Type            | Element  | Supported Arguments
----------------|----------|----------------------------
Voltage Source  | `V`      | `DC`, `SIN`, `PULSE`, `PWL`
Current Source  | `I`      | `DC`, `SIN`, `PULSE`, `PWL`
Ideal Resistor  | `R`      |
Ideal Capacitor | `C`      |
Ideal Inductor  | `L`      |
Subcircuit Call | `X`      | Instance parameter values


## SPICE Models

Type            | Model Type          | Reference
----------------|----------------------|--------------
BSIM4 MOSFET    | `{n,p}mos LEVEL=54`  | See ref.


## SPICE Commands

Supported Commands | Example
-------------------|----------
`.param`           | `.param c1 = 1p`
`.parameter`       | `.parameter rl = 10k`
`.parameters`      | `.parameters a=10 b=12`
`.option`          | See [SPICE Options](@ref)
`.options`         | See [SPICE Options](@ref)
`.subckt`          | `.subckt foo n1 n2 n3 x=1 y=10`
`.ends`            |
`.global`          | `.global vdd=1.2`
`.include`         | `.include "file.sp"`
`.lib`             | `.lib "models.lib" section_name`


Some commands are ignored with the expectation that the users configures them from their
run script.

Ignored Command    | Script Equivalent
-------------------|---------------------
`.tran`            | See [Running Transient Analysis](@ref)
`.dc`              | See [Running DC Analysis](@ref)
`.print`           | See [Working with Plots](@ref)


## SPICE Options


## SPICE Numbers
Numbers in SPICE are case insensitive and support the following scaling suffixes:

Suffix   | Scale
-------  |------
T        | 10^12
G        | 10^9
MEG      | 10^6
k        | 10^3
m        | 10^-3
mil      | 25.4u
u        | 10^-6
n        | 10^-9
p        | 10^-12
f        | 10^-15
a        | 10^-18

## SPICE Equations

The following mathematical operators are supported:

Operator | Meaning
---------|--------
`+`      | Addition
`-`      | Subtraction
`*`      | Multiplication
`/`      | Division
`**`     | Exponent

The following mathematical functions are supported:

Function     | Description
-------------|-----------------------------------
`min(x, y)`  | Minimum of `x` and `y`
`max(x, y)`  | Maximum of `x` and `y`
`abs(x)`     | Absolute value of `x`
`log(x)`     | Logarithm of `x` to base ℯ
`log10(x)`   | Logarithm of `x` to base 10
`sgn(x)`     | Sign of `x`: `x>0 = 1`, `x<0 = 1`, `x==0 = 0`
`sign(x, y)` | Magnitude of `x` with the sign of `y`: `sgn(y)*abs(x)`
`exp(x)`     | `ℯ^x`
`pow(x,y)`   | `x` to the power of `y`
`pwr(x,y)`   | Signed power: `sgn(x)*(abs(x)^y)`
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
`int(x)`     | Integer portion of `x`
`nint(x)`    | Round to nearest integer to `x`
`floor(x)`   | Integer value less than or equal to `x`
`ceil(x)`    | Integer value greater than or equal to `x`

