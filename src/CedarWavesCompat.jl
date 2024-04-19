using CedarWaves, SciMLBase
export Signal

# Ideally, we'd specify this as something like:
#const SignalF64Array{N} = Array{Signal{Float64,LinearInterpolator,Vector{Float64},Vector{Float64}}, N} where {N}
const SignalF64Array{N} = Array{ContinuousSignal{Float64, Float64, Vector{Float64}}, N} where {N}

# Until we remake `CedarWaves`, this is an easy stand-in adapter for the `Signal()`
# constructor I've been using so far.
function Signal(xs, ys)
    return PWL(xs, ys)
end

"""
    FunctionMeasure(probes, callback, measure_name)

A generic helper type to define a measure as a function of another measure;
can take in potentially multiple source measures (typically a `Probe` or
another `FunctionMeasure`) and invokes the wrapped function upon those
probes.

`M` is the type of the measure that this function returns; e.g. `DxMeasure`
"""
struct FunctionMeasure <: AbstractMeasure
    probes::Vector{<:Probe}
    fn::Function
    name::String
    original_function::Union{Function,Nothing}

    FunctionMeasure(probes, fn, name, original_function) = new(probes, fn, name, original_function)
    FunctionMeasure(probes, fn, name) = new(probes, fn, name, nothing)
end
get_name(r::FunctionMeasure) = r.name
function Base.show(io::IO, r::FunctionMeasure)
    print(io, r.name)
end
function Base.show(io::IO, ::MIME"text/plain", r::FunctionMeasure)
    print(io, r.name)
end
function Base.in(m::FunctionMeasure, domain::Interval)
    return FunctionCheck(m, m-> m in domain)
end

function Base.in(m::Probe, domain::Interval)
    fm = FunctionMeasure([m], identity, string(m))
    return FunctionCheck(fm, m-> m in domain)
end

abstract type AbstractCheck; end
"""
    FunctionCheck(measure, fn)

A definition of a check to be executed in the future on the `measure`, applying the `fn` to the
"""
struct FunctionCheck <: AbstractCheck
    measure::AbstractMeasure
    fn::Function
end
get_name(r::FunctionCheck) = get_name(r.measure)


function apply(ts, probe::Probe, idxs)
    if ts isa Union{TransientSolutionType, SensitivitySolutionType}
        get_tran(ts, probe, idxs)
    elseif ts isa DCSolutionType
        get_dc(ts, probe, idxs)
    elseif ts isa ACSolutionType
        abs(get_ac(ts, probe, idxs)) #TODO this is bad for measuring e.g. phase
    elseif ts isa NoiseSolutionType
        sqrt(abs(get_noise(ts, probe, idxs))) #TODO this is bad for measuring e.g. phase
    elseif ts isa SurrogateSolutionType
        getproperty(ts.tran, Symbol(probe))[idxs...]
    else
        throw(ArgumentError("Unable to apply probe to solution type $(typeof(ts))"))
    end
end
apply(ts, r::FunctionMeasure, idxs) = r.fn((apply(ts, p, idxs) for p in r.probes)...)
apply(ts, r::FunctionCheck, idxs) = r.fn(apply(ts, r.measure, idxs))

function get_num_signal_args(m::Method, type_name = AbstractSignal)
    # Peel type signature to get actual types of method arguments
    sig = m.sig
    while isa(sig, UnionAll)
        sig = sig.body
    end
    return length(filter(T -> isa(T, Type) && T <: AbstractSignal, collect(sig.parameters)))
end

"""
    @GenSignalProbeMethods(signal_function)

Generate new methods for a measurement function to support Probes (delayed calculation).

# Examples

```julia
function mymeasfunc(s::AbstractSignal)
    mean(s^2)
end

@GenSignalProbeMethods mymeasfunc # generates methods for mymeasfunc(Probe(:vout))

mymeasfunc(Probe(:vout))
```
"""
macro GenSignalProbeMethods(f)
    num_signal_inputs = Set{Int}()
    name = Symbol(f)
    for m in methods(f)
        nargs = get_num_signal_args(m)
        if nargs != 0
            push!(num_signal_inputs, nargs)
        end
    end
    if isempty(num_signal_inputs)
        throw(ArgumentError("Unable to find any methods for $(name) that had `AbstractSignal` signatures"))
    end

    gen_sig_name(idx) = Symbol(string("sig", idx))

    definitions = []
    for num_sigs in num_signal_inputs
        sigs = gen_sig_name.(1:num_sigs)
        sigs_with_types = [:($(sig)::Probe) for sig in sigs]
        sig_selector_string = [:(string($(sig))) for sig in sigs]

        #sigs_names = [:($(sig)::Symbol) for sig in sigs]
        #sig_probe_adapter = [:(Probe($(sig))) for sig in sigs]

        push!(definitions, esc(quote
            function $(name)($(sigs_with_types...), args...; kwargs...)
                return FunctionMeasure(
                    [$(sigs...)],
                    (sigs...,) -> $(name)(sigs..., args...; kwargs...),
                    string($(string(name)), "(", $(sig_selector_string...), ")"),
                    $f,
                )
            end
            #=
            function $(name)($(sigs_names...), args...; kwargs...)
                return $(name)($(sig_probe_adapter...), args...; kwargs...)
            end
            =#
        end))
    end
    return quote
        $(definitions...)
    end
end

# Probe wrapper methods
for f in CedarWaves.signal_funcs
    @eval import CedarWaves: $(Symbol(f))
    @eval @GenSignalProbeMethods $f
end

