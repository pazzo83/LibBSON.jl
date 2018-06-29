mutable struct BSONObject
    _wrap_::Ptr{Nothing}
    _owner_::Any

    BSONObject() = begin
        _wrap_ = ccall(
            (:bson_new, libbson),
            Ptr{Nothing}, ()
            )
        bsonObject = new(_wrap_, Union{})
        finalizer(destroy, bsonObject)
        return bsonObject
    end

    BSONObject(other::BSONObject) = begin
        _owner_ = Array{UInt8}(undef, 128)
        ccall(
                (:bson_copy_to, libbson),
                Nothing, (Ptr{Nothing}, Ptr{UInt8}),
                other._wrap_,
                pointer(_owner_)
        )
        bsonObject = new(Ptr{Nothing}(pointer(_owner_)), _owner_)
        finalizer(destroy, bsonObject)
        return bsonObject
    end

    BSONObject(dict::AbstractDict) = begin
        bsonObject = BSONObject()
        for (k, v) in dict
            append(bsonObject, k, v)
        end
        return bsonObject
    end

    BSONObject(jsonString::AbstractString) = begin
        jsonCStr = string(jsonString)
        bsonError = BSONError()
        _wrap_ = ccall(
            (:bson_new_from_json, libbson),
            Ptr{Nothing}, (Ptr{UInt8}, Csize_t, Ptr{UInt8}),
            jsonCStr,
            length(jsonCStr),
            bsonError._wrap_
            )
        _wrap_ != C_NULL || error(bsonError)
        bsonObject = new(_wrap_, Union{})
        finalizer(destroy, bsonObject)
        return bsonObject
    end

    BSONObject(data::Ptr{UInt8}, length::Integer, _ref_::Any) = begin
        buffer = Array{UInt8}(undef, 128)
        ccall(
            (:bson_init_static, libbson),
            Bool, (Ptr{Nothing}, Ptr{UInt8}, UInt32),
            buffer, data, length
            ) || error("bson_init_static: failure")
        b = unsafe_convert(Ptr{Nothing}, buffer)
        new(b, (_ref_, buffer))
    end

    BSONObject(_wrap_::Ptr{Nothing}, _owner_::Any) = new(_wrap_, _owner_)
end
export BSONObject

function convert(::Type{AbstractString}, bsonObject::BSONObject)
    cstr = ccall(
        (:bson_as_json, libbson),
        Ptr{UInt8}, (Ptr{Nothing}, Ptr{UInt8}),
        bsonObject._wrap_,
        C_NULL
        )
    result = String(unsafe_string(cstr))
    ccall(
        (:bson_free, libbson),
        Nothing, (Ptr{Nothing},),
        cstr
        )
    return result
end
export convert

string(bsonObject::BSONObject) = convert(AbstractString, bsonObject)

show(io::IO, bsonObject::BSONObject) = print(io, "BSONObject($(convert(AbstractString, bsonObject)))")
export show

length(bsonObject::BSONObject) =
    ccall(
        (:bson_count_keys, libbson),
        UInt32, (Ptr{Nothing},),
        bsonObject._wrap_
        )
export length

function append(bsonObject::BSONObject, key::AbstractString, val::Bool)
    keyCStr = string(key)
    ccall(
        (:bson_append_bool, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint, Bool),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::Real)
    keyCStr = string(key)
    ccall(
        (:bson_append_double, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint, Cdouble),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val
        ) || error("libBSON: overflow")
end

function append(bsonObject::BSONObject, key::AbstractString, val::DateTime)
    keyCStr = string(key)
    ts = round(Int64, datetime2unix(val)*1000)
    ccall(
        (:bson_append_date_time, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint, Clonglong),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        ts
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::Date)
    append(bsonObject, key, DateTime(val))
end
function append(bsonObject::BSONObject, key::AbstractString, val::BSONObject)
    keyCStr = string(key)
    ccall(
        (:bson_append_document, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint, Ptr{UInt8}),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val._wrap_
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::Union{Int8, UInt8, Int16, UInt16, Int32, UInt32})
    keyCStr = string(key)
    ccall(
        (:bson_append_int32, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint, Cint),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::Union{Int64, UInt64})
    keyCStr = string(key)
    ccall(
        (:bson_append_int64, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint, Clong),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::BSONOID)
    keyCStr = string(key)
    ccall(
        (:bson_append_oid, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint, Ptr{UInt8}),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        val._wrap_
        ) || error("libBSON: overflow")
end
append(bsonObject::BSONObject, key::AbstractString, val::Char) = append(bsonObject, key, string(val))
function append(bsonObject::BSONObject, key::AbstractString, val::AbstractString)
    keyCStr = string(key)
    valUTF8 = String(val)
    ccall(
        (:bson_append_utf8, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint, Ptr{UInt8}, Cint),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        valUTF8,
        sizeof(valUTF8)
        ) || error("libBSON: overflow")
end
function append(bsonObject::BSONObject, key::AbstractString, val::Nothing)
    append_null(bsonObject, key)
end
function append(bsonObject::BSONObject, key::AbstractString, val::Symbol)
    if val == :null
        append_null(bsonObject, key)
    elseif val == :minkey
        append_minkey(bsonObject, key)
    elseif val == :maxkey
        append_maxkey(bsonObject, key)
    else
        append(bsonObject, key, string(val))
    end
end
function append(bsonObject::BSONObject, key::AbstractString, val::AbstractDict)
    keyCStr = string(key)
    childBuffer = Array{UInt8}(undef, 128)
    ccall(
        (:bson_append_document_begin, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint, Ptr{Nothing}),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        childBuffer
        ) || error("bson_append_document_begin: failure")
    childBSON = BSONObject(unsafe_convert(Ptr{Nothing}, childBuffer), childBuffer)
    for (k, v) in val
        append(childBSON, k, v)
    end
    ccall(
        (:bson_append_document_end, libbson),
        Bool, (Ptr{Nothing}, Ptr{Nothing}),
        bsonObject._wrap_,
        childBuffer
        ) || error("bson_append_document_end: failure")
end
function append(bsonObject::BSONObject, key::AbstractString, valBinary::Vector{UInt8})
    keyCStr = string(key)
    ccall(
        (:bson_append_binary, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint, Cint, Ptr{UInt8}, Cint),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        0, #BSON_SUBTYPE_BINARY
        valBinary,
        length(valBinary)
        ) || error("libBSON: overflow")
end

function append(bsonObject::BSONObject, key::AbstractString, val::Vector)
    keyCStr = string(key)
    childBuffer = Array{UInt8}(undef, 128)
    ccall(
        (:bson_append_array_begin, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint, Ptr{Nothing}),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr),
        childBuffer
        ) || error("bson_append_array_begin: failure")
    childBSONArray = BSONArray(unsafe_convert(Ptr{Nothing}, childBuffer), childBuffer)
    for element in val
        append(childBSONArray, element)
    end
    ccall(
        (:bson_append_array_end, libbson),
        Bool, (Ptr{Nothing}, Ptr{Nothing}),
        bsonObject._wrap_,
        childBuffer
        ) || error("bson_append_array_end: failure")
end
export append

function append_null(bsonObject::BSONObject, key::AbstractString)
    keyCStr = string(key)
    ccall(
        (:bson_append_null, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr)
        ) || error("libBSON: overflow")
end
export append_null

function append_minkey(bsonObject::BSONObject, key::AbstractString)
    keyCStr = string(key)
    ccall(
        (:bson_append_minkey, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr)
        ) || error("libBSON: overflow")
end
export append_minkey

function append_maxkey(bsonObject::BSONObject, key::AbstractString)
    keyCStr = string(key)
    ccall(
        (:bson_append_maxkey, libbson),
        Bool, (Ptr{Nothing}, Ptr{UInt8}, Cint),
        bsonObject._wrap_,
        keyCStr,
        length(keyCStr)
        ) || error("libBSON: overflow")
end
export append_maxkey



# Private

function destroy(bsonObject::BSONObject)
    ccall(
        (:bson_destroy, libbson),
        Nothing, (Ptr{Nothing},),
        bsonObject._wrap_
        )
end
