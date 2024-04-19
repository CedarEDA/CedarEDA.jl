# Only run the given commands if `filename` does not exist
macro skip_if_cached(cache_filename, ex)
    if get(ENV, "CI", "false") == "true" || !ispath(eval(cache_filename))
        return quote
            $(esc(ex))
        end
    else
        return nothing
    end
end

# Return the directory of the calling `.md` file's source, not the `build/` path.
# It's annoying that I can't emit a `@__DIR__` from this macro and instead need to
# pass it in from the outside, but c'est la vie.
macro __DOC_DIR__()
    docs_dir = @__DIR__
    return quote
        joinpath(
            $(docs_dir), "src",
            relpath($(Expr(:macrocall, Symbol("@__DIR__"), __source__)), joinpath($(docs_dir), "build")),
        )
    end
end
