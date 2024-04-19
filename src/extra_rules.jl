# Rules that should be in CedarWaves:
using ChainRulesCore: AbstractZero, Tangent, ZeroTangent

# We need this becaue AbstractMeasure<:Real, and ChainRules assumes all real numbers have things like `one` defined on them
# and represent their own deriviatives
function ChainRulesCore.frule((_, ẋ, ẏ)::Tuple{Any, Tangent{<:AbstractMeasure}, Any}, ::typeof(/), x::AbstractMeasure, y::Real)
    z = x/y
    @assert z isa DerivedMeasure
    ż = Tangent{DerivedMeasure}(value = ẋ.value/y - ẏ*z/y)
    return z, ż
end
# We need this becaue AbstractMeasure<:Number, and ChainRulesCore assumes that means it defines `zero`
ChainRulesCore.zero_tangent(::AbstractMeasure) = ZeroTangent()

# overload to make the tangent properties match the primal properties
function Base.getproperty(x::Tangent{<:AbstractMeasure, <:NamedTuple}, name::Symbol)
    backing = ChainRulesCore.backing(x)
    if name == :value
        # Note: this is a little fragile and depends exactly how the particular kind of measure stores its value
        # Really we should call back into AD and AD out `CedarWaves.get_value`
        # Or specialize per the AbstractMeasure subtype
        if hasproperty(backing, :value)
            return backing.value
        elseif hasproperty(backing, :values)
            return first(backing.values)
        elseif hasproperty(backing, :pt1) && hasproperty(backing, :pt2)
            return backing.pt2.x - backing.pt1.x
        end
    elseif hasproperty(backing, name)
        return getproperty(backing, name)
    else
        return ZeroTangent()
    end
end



# This should just be in CedarWaves.jl but also Diffractor should be able to AD this without errors.
function ChainRulesCore.frule((_, ṁeasure, v̇alue), ::Type{DerivedMeasure}, measure::AbstractMeasure, value)
    y = DerivedMeasure(measure, value)
    ẏ = Tangent{DerivedMeasure}(measures=Tangent{AbstractMeasure}[ṁeasure], value=v̇alue)
    return y, ẏ
end
# https://github.com/JuliaDiff/Diffractor.jl/issues/244
function ChainRulesCore.frule((_, k̇ws, _, ṁeasure, v̇alue), ::typeof(Core.kwcall), kws, ::Type{DerivedMeasure}, measure::AbstractMeasure, value)
    @assert iszero(k̇ws)
    y = DerivedMeasure(measure, value; kws...)
    ẏ = Tangent{DerivedMeasure}(measures=Any[ṁeasure], value=v̇alue)
    return y, ẏ
end


# This should be in ChainRules.jl, but complete
function ChainRulesCore.frule(dargs, ::typeof(range), args...)
    @assert all(iszero, dargs)
    return range(args...), ZeroTangent()
end
# https://github.com/JuliaDiff/Diffractor.jl/issues/244
function ChainRulesCore.frule(dargs, ::typeof(Core.kwcall), kws, ::typeof(range), args...)
    @assert all(iszero, dargs)
    return Core.kwcall(kws, range, args...), ZeroTangent()
end
