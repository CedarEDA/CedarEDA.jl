# All `0_setup.jl` files are magically invoked as part of the `docs/make.jl` routine.

# Copy example spice files over
cp("../../../examples/Filter/Butterworth/butterworth.spice", "butterworth.spice"; force=true)
cp("../../../examples/Amplifier/Operational Transconductance Amplifier (OTA)/ota.spice", "ota.spice"; force=true)
cp("../../../examples/Amplifier/Operational Transconductance Amplifier (OTA)/PTM_180nm_bulk.mod", "PTM_180nm_bulk.mod"; force=true)

# You could also do more extensive setup here such as generating figures, etc...
