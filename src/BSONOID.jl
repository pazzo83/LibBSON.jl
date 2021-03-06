struct BSONOID
    _wrap_::Ptr{Nothing}
    _ref_::Any

    BSONOID() = begin
        buffer = Vector{UInt8}(undef, 12)
        ccall(
            (:bson_oid_init, libbson),
            Nothing, (Ptr{UInt8}, Ptr{Nothing}),
            buffer,
            C_NULL
            )
            r = unsafe_convert(Ptr{UInt8}, buffer)
        new(r, buffer)
    end

    BSONOID(str::AbstractString) = begin
        cstr = string(str)

        isValid = ccall(
            (:bson_oid_is_valid, libbson),
            Bool, (Ptr{UInt8}, Csize_t),
            cstr,
            length(cstr)
            )
        isValid || error("'" * str * "': not a valid BSONOID string")

        buffer = Vector{UInt8}(undef, 12)
        ccall(
            (:bson_oid_init_from_string, libbson),
            Nothing, (Ptr{UInt8}, Ptr{UInt8}),
            buffer,
            cstr
            )
            r = unsafe_convert(Ptr{UInt8}, buffer)
        new(r, buffer)
    end

    BSONOID(_ref_::Any) = new(pointer(_ref_), _ref_)
end
export BSONOID

import Base.==
==(lhs::BSONOID, rhs::BSONOID) = ccall(
    (:bson_oid_equal, libbson),
    Bool, (Ptr{Nothing}, Ptr{Nothing}),
    lhs._wrap_, rhs._wrap_
    )
export ==

hash(oid::BSONOID, h::UInt) = hash(
    ccall(
        (:bson_oid_hash, libbson),
        UInt32, (Ptr{UInt8},),
        oid._wrap_
        ),
    h
    )
export hash

function convert(::Type{AbstractString}, oid::BSONOID)
    cstr = Vector{UInt8}(undef, 25)
    ccall(
        (:bson_oid_to_string, libbson),
        Nothing, (Ptr{UInt8}, Ptr{UInt8}),
        oid._wrap_,
        cstr
        )
    return string(unsafe_string(unsafe_convert(Ptr{UInt8}, cstr)))
end
export convert

string(oid::BSONOID) = convert(AbstractString, oid)
export string

show(io::IO, oid::BSONOID) = print(io, "BSONOID($(convert(AbstractString, oid)))")
export show
