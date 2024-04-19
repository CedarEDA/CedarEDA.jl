# Cedar License FAQ

The Cedar Electronic Design Automation (EDA) platform by
JuliaHub provides a composable, library-based interface to assist
analog design engineers in chip design.
The platform consists of a number of libraries that together form the Cedar EDA
platform.

We have released these libraries under the CERN-OHL-S Version 2.0 license.

## What is the CERN-OHL-S license?

The CERN-OHL-S license is shorthand for the
`CERN Open Hardware License Version 2 - Strongly Reciprocal`,
an OSI-approved license for open hardware specifications and tools.
It is a strong copyleft license, which means that if you sell products using
materials licensed under CERN-OHL-S, you must share all the source code you use
to make the products.

## Why did you choose the CERN-OHL-S license?
The CERN licenses are the most widely used open hardware licenses, and are approved by OSI.
We chose CERN-OHL-S instead of GPL because GPL is not an open hardware license.
Version 2.0 of the CERN-OHL comes in three versions – strongly reciprocal,
weakly reciprocal and permissive. We chose CERN-OHL-S instead of the weak
reciprocal or permissive versions, because we wanted to create a strong
community for our Cedar tools.
The EDA space is dominated by hard-to-get, proprietary tools, most only
available restrictive NDAs.
We want to help support the growing open hardware movement and create a level
playing field for manufacturers of open hardware. We chose the strongest
available license to try to maximize this effect.

## When do I have to share source code?
The license says:

```
4 Making and Conveying Products
You may Make Products, and/or Convey them, provided that You either provide
each recipient with a copy of the Complete Source or ensure that each
recipient is notified of the Source Location of the Complete Source.
```

If you make a product, such as an ASIC, PCB, FPGA gateware design or other
hardware product, using our software, you need to provide the complete
source code for the product.

## What source code do I have to share?
The license requires sharing of Complete Source, which is:

```
1.8 'Complete Source' means the set of all Source necessary to Make a
Product, in the preferred form for making modifications,
including necessary installation and interfacing information
both for the Product, and for any included Available Components….
Complete Source need not include the Source of any Available Component,
provided that You include in the Complete Source sufficient information to
enable a recipient to Make or source and use the Available Component to Make
the Product.
```

## Must I share my testbenches, workflow scripts, optimization setups, etc?

Yes, see the definition of Source:

```
 1.3 'Source' means information such as design materials or digital
      code which can be applied to Make or test a Product or to
      prepare a Product for use, Conveyance or sale, regardless of its
      medium or how it is expressed. It may include Notices.
```

Any code used for testing, validation or signoff should be included in the
Source release. The idea is that anybody who receives the Source from you can
confidently make another production run, or use the Source as the basis for
further improvements.

## Must I release my Source if I only use Cedar for testing, validation, signoff, or optimization?
Yes, these activities are part of using Cedar to make your product.
As described above, the source of the CERN-OHL-S is not restricted to the design
material, so you must also include any scripts or programs you write for these
purposes in the Source release.

## What is an Available Component?
The Available Components mechanism is a way to make it easier and more
practical to comply with  CERN-OHL-S. This mechanism was created so that
users of open hardware tools do not have to provide the source for
off-the-shelf components, like resistors or transistors.
For more on how this works, see the CERN-OHL-S rationale document. It says:

```
Starting with a circuit board as an example,
it almost goes without saying that if all the components
are common commodity electronic components, then it shouldn’t be necessary
to provide details any more specific than you’d find, for example,
in the project instructions in an electronics magazine.
The design might need three BC108 transistors, a 555 timer,
and five 220 Ohm resistors. Perhaps, for the circuit in question, the
resistors need to be specified as 0.25 watt resistors, and be accurate
to 10 percent tolerance. That is sufficient information for a maker to make
the board….We call components which are generally and readily available
(even if they have to be paid for, or you have to sign up to an NDA to get them),
Available Components. When you provide the Complete Source
(the design documentation) for your design under the CERN-OHL,
you do not have to provide the Complete Source for each of the
Available Components (of course, it’s great if you can!).
```

It also says,

```
For CERN-OHL-S, if the Available Components are in the digital domain,
you can’t use third party libraries unless they are part of the normal
distribution of a tool you are using (or are themselves licensed under a
Compatible License).
```

You might find this concept familiar from GPL3, which contains a clause about
System Libraries.

"Available Components" in CERN OHL play a similar role to "System Libraries"
in GPL/LGPL. These are components that we assume people generally have access
to.

## Are Process Development Kits (PDKs) considered Available Components?
That depends on the exact terms of the PDK, but generally, no.
Additionally, most commercial PDKs additionally place restrictions on designs
that make use of these PDKs to prohibit them from being disclosed as well
(not just the PDK itself).

## What if my fab or foundry requires proprietary PDKs or other proprietary software or hardware?
If it does, you may not be able to use open hardware designs, and you should
encourage your fab to provide the option of using open tools.
If this is not feasible, you may need a commercial license.
(See “What if I can’t comply with the license?” below).

## CERN says you shouldn’t use CERN-OHL-S for Software. Why are you using it?
Today, the boundaries between software and hardware are blurring.
Modern hardware design projects look much less like schematics and
drawings and much more like big software projects integrating a
variety of libraries that optimize, analyze and ultimately produce a
manufacturable design. With Cedar in particular, we’re attempting to
bring some of the best ideas from large scale software design into the
hardware design world.

It’s true that software should usually be kept under open source software
licenses, but that guidance is mostly intended for software that will end up
*running* on the device in question. But our software is not firmware;
it’s a hardware design platform that becomes an integral part of the hardware
design and verification processincludes design libraries.
If you use our software, you will end up with our designs as part of your
hardware design, so we think it’s fair that the CERN-OHL-S be applied to our
software.

## How do I include license notices on my products?
For guidance, please see the CERN-OHL Wiki here.

## What if I can’t comply with the license?
We prefer that you comply with the license.
But if you can't comply with the license, for example because you have
already designed in proprietary components, please contact us so we can help.
We may be able to grant you an alternative, commercial license,
or point you to complementary open hardware designs to help you comply
with the license. Please contact info@juliahub.com for assistance.

## I am creating my own components for others to use - must I license them under the CERN-OHL-S?

No, you may choose any license you wish for your project.
However, as described above, if you want your components to be usable with Cedar,
you must release the Complete Source of your component to any recipient under
CERN-OHL-S or a compatible license.
Additionally, if recipients of your components make use of Cedar in their own
Products (e.g. to integrate or validate your components), they must comply with
the terms of the CERN-OHL-S or otherwise have a valid Cedar license.

We understand that there may be situations where this is not feasible.
In those situations, we encourage you to contact us early to obtain a special purpose license for your particular situation.

## I would like to modify Cedar itself to make it work for my use case. Is this allowed?

Yes, however, if you use the modified version of Cedar and you subsequently
share it with others or use it to Make a Product,
you must license your modifications under the CERN-OHL-S and make your
modifications available.

We also encourage you to contribute your changes back to Cedar by signing the
Cedar CLA and sending us a Pull Request.
This way you will be able to take advantage of the significant testing and
validation effort performed on the main Cedar release, don’t have to worry
about tracking and sending people the correct version of Cedar,
as well as improving the quality of Cedar for everyone else.

However, this is optional and you are not required to contribute your
improvements upstream.

## May I benchmark Cedar and talk about the results?

Of course. If you find something out there that’s faster, please let us know. That’s a bug.

