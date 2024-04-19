# CedarEDA docs build

These docs get built and upload to https://help.juliahub.com/cedareda/dev/.

To build them, use `julia +cedar --project make.jl`.
If you are iterating on docs, try `julia +cedar --project make.jl --loop`, which will load everything up, do a docs build, then wait for file changes and run the docs build again when it detects a change.
Note that there is a caching system employed for some of the `@example` blocks that would otherwise be too expensive to run every time; you will have to delete the cached figures to force a re-calculation of the affected example blocks.
To disable the caching system entirely, set `CI=true` in your environment first.
