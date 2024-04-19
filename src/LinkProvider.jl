# Note: to make use of this, you must install:
# https://github.com/pfitzseb/julia-link-extension

module LinkProvider
using ConcurrentCollections: ConcurrentDict
export run_callback

const callbacks = ConcurrentDict{Int32,Base.Callable}()
const global_link_id = Ref{UInt32}(0)

const ZERO = '\u2060'
const ONE = '\u200b'

hyperlink(callback, str) = Link(callback, str)
run_callback(id) = get(callbacks, id, () -> ())()

struct Link
    id::UInt32
    link::String

    function Link(callback, link)
        this_id = (global_link_id[] += 1)
        callbacks[this_id] = callback
        new(this_id, link)
    end
end

function Base.show(io::IO, link::Link)
    str = string(ONE, link.link, encode_id(link.id))
    print(io, str)
end

encode_id(x::UInt32) = replace(string(x, base=2), '1' => ONE, '0' => ZERO)

end
