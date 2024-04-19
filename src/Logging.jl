using Logging
using TimerOutputs
using TerminalLoggers
using LoggingExtras
using ProgressLogging
using ProgressMeter

export configure_logging!
"""
    configure_logging!(; log_level, log_file)

Configures the global logger to log anything more severe than `log_level`,
and to also copy the logs into the `log_file`, if provided.
Default `log_level` is `LogLevel(-1)` for progress logging.

For more complex or custom usecases, configure the global logger directly.
See the [Logging](https://docs.julialang.org/en/v1/stdlib/Logging/) and
[LoggingExtras](https://github.com/JuliaLogging/LoggingExtras.jl) packages
for more details.
"""
function configure_logging!(; log_level=nothing, log_file=nothing)
    log_level = something(
        log_level,
        # -1 is progress
        stderr isa Base.TTY ? Logging.LogLevel(-1) : Logging.Info,
    )

    loggers = AbstractLogger[console_logger(log_level)]
    if log_file !== nothing
        timestamp_logger(logger) = TransformerLogger(logger) do log
            merge(log, (; message = "$(Dates.format(now(), date_format)) $(log.message)",
                         level = convert(Logging.LogLevel, log.level))) # Sundials logs ints and FileLogger doesn't like it
        end
        push!(loggers, timestamp_logger(FileLogger(log_file; always_flush=false)))
    end
    global_logger(TeeLogger(Tuple(loggers)))
end

macro log_timeit(to, name, body)
    @gensym ct res
    esc(quote
        $res = @timeit($to, $name, @timed($body))
        @info "$($name):\t$(TimerOutputs.prettytime($res.time*1e9)) / $(TimerOutputs.prettymemory($res.bytes))"
        $res.value
    end)
end

struct RawStr
    x::String
end
nomarkdown(s::String) = RawStr(s)
nomarkdown(s) = s
Base.show(io::IO, ::MIME"text/plain", s::RawStr) = print(io, s.x)
function console_logger(log_level)
    # Disable VSCode logging until we can customize the progress message
    vscode = nothing
    #vscode = get(Base.loaded_modules, Base.PkgId(Base.UUID(0x9f5989ce84fe42d491ec6a7a8d53ed0f), "VSCodeServer"), nothing)
    if vscode isa Module
        # if we're running inside VSCode, use its logger with the given log_level
        vscode.VSCodeLogger(ConsoleLogger(stderr, log_level))
    elseif stderr isa Base.TTY
        # if we're running in some other terminal, use TerminalLogger with a markdown workaround
        TransformerLogger(log->merge(log, (;message=haskey(log.kwargs, :progress) ? log.message : nomarkdown(log.message))), TerminalLogger(stderr, log_level))
    else
        # else just use a normal console logger
        ConsoleLogger(stderr, log_level)
    end
end
