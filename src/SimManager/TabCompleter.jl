using MacroTools: @capture

function default_leaf(obj)
    return (k, l) -> l
end

# Create a type-specific `keys()`
function default_keys(obj::T) where {T}
    # If `T` is an array, we have a special broadcasting `keys` type for that
    # which finds the keys of the first element, and `getindex` will re-construct
    # a vector containing the sub-elements as needed:
    if T <: AbstractArray
        return obj::T -> keys(obj[1])
    end
    return obj::T -> keys(obj)
end
function default_getindex(obj::T) where {T}
    if T <: AbstractArray
        return (objs::T, name::Symbol) -> [getindex(obj, name) for obj in objs]
    end
    return (obj::T, name::Symbol) -> getindex(obj, name)
end

"""
    TabCompleter{T}

A convenient object that provides tab-completion through some kind of recursive
datastructure; e.g. a dict of dicts, or an array of arrays.  The recursive
structure is followed until an object that has no children is found, at which
point a leaf function is called upon that object and returned to the user.

This enables the caller to create something that explores a deeply-nested
structure (typically a `sys` object that exposes the circuit's structure) but
instead of getting the leaf node itself, it passes through the `leaf()`
function allowing for things like returning a signal associated with that
circuit node, instead of the node itself.

The exploration of the original recursive object can be customized by providing
`keys()` and `getindex()` functions. If not specified, the `TabCompleter` will
attempt to guess an appropriate function based on `T`.

!!! note
    It's crucial to note that user callbacks passed as `leaf`, `keys`, or `getindex` must
    meet the `:foldable !:consistent` effects (note that it does not necessarily to taint
    its `:consistent`-cy). This requirement is vital for enhancing tab completion accuracy.
    However, if the user callback fails to satisfy these conditions, attempting tab
    completion could lead to undefined behavior.
"""
struct TabCompleter{T}
    name::String
    obj::T

    # `leaf(key, leaf_obj)` -> return value is what the user gets at a leaf node
    leaf::Function
    # `keys(obj)` -> return value is the valid children of `obj`
    keys::Function
    # `getindex(obj, key)` -> return value is the specified child of `obj`
    getindex::Function

    function TabCompleter(name::String, obj::T;
                          leaf = default_leaf(obj),
                          keys = default_keys(obj),
                          getindex = default_getindex(obj)) where {T}
        return new{T}(name, obj, leaf, keys, getindex)
    end
end

# A function call wrapper that executes the function call provided as arguments
# while allowing `REPLInterpreter` to aggressively infer its result.
Base.@assume_effects :foldable !:consistent @inline repl_evaluable(func, args...) = func(args...)
macro repl_evaluable(ex)
    @capture(ex, func_(args__)) || error("Expected call expression.")
    return :(repl_evaluable($(esc(func)), $(map(esc, args)...)))
end

function keys_or_nothing(tc::TabCompleter, obj)
    keys = getfield(tc, :keys)
    if applicable(keys, obj)
        return @repl_evaluable keys(obj)
    end
    return nothing
end

function Base.propertynames(tc::TabCompleter)
    keys = keys_or_nothing(tc, getfield(tc, :obj))
    if keys === nothing
        return Symbol[]
    end
    return keys
end
function Base.show(io::IO, tc::TabCompleter)
    propnames = sort(collect(propertynames(tc)))
    println(io, "$(getfield(tc, :name)) with $(length(propnames)) properties:")
    for name in propnames
        println(io, "  $(name)")
    end
end

function Base.getproperty(tc::TabCompleter, name::Symbol)
    child = @repl_evaluable getfield(tc, :getindex)(getfield(tc, :obj), name)
    # If this is a leaf, apply `leaf()` to `prop` before returning, otherwise create a new `TabCompleter`:
    keys = keys_or_nothing(tc, child)
    if keys === nothing
        return @repl_evaluable getfield(tc, :leaf)(name, child)
    else
        # If this is not a leaf, construct another TabCompleter with the same values
        # but with `obj` set to this `child`, so that we can recursively descend.
        return TabCompleter(
            getfield(tc, :name),
            child;
            leaf = getfield(tc, :leaf),
            keys = getfield(tc, :keys),
            getindex = getfield(tc, :getindex),
        )
    end
end

# TabCompleter looks complex inside, but really its just a AbstractDict analogue
# so we define the frule to avoid ADing that complexity
using ChainRulesCore: ChainRulesCore
function ChainRulesCore.frule((_, ṫc, _), ::typeof(getproperty), tc::TabCompleter, name::Symbol)
    return getproperty(tc, name), getproperty(ṫc.obj, name)
end
