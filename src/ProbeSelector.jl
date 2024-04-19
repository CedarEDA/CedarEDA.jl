using DAECompiler: IRODESystem, ScopeRef
struct Probe
    path::Vector{Symbol}
end
Probe(ref::ScopeRef) = Probe(ref_path(ref))
function ref_path(ref::ScopeRef)
    scope = getfield(ref, :scope)
    path = Symbol[scope.name]
    while scope.parent !== nothing
        scope = scope.parent
        push!(path, scope.name)
    end
    return reverse(path)
end
Base.string(probe::Probe) = join(string.(probe.path), ".")
function Base.show(io::IO, probe::Probe)
    print(io, string(probe))
end
function Base.getproperty(ref::Union{IRODESystem,ScopeRef}, probe::Probe)
    for part in probe.path
        ref = getproperty(ref, part)
    end
    return ref
end

function ProbeSelector(sys::IRODESystem, prefix=Symbol[])
    return TabCompleter(
        "Probes",
        sys;
        leaf = (tc, l) -> Probe(l),
        keys = x -> isempty(propertynames(x)) ? nothing : propertynames(x),
        getindex = getproperty,
    )
end
