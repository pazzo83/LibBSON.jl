# utils.jl
process_bson_object(obj) = obj
process_bson_object(obj::BSONObject) = dict(obj)
process_bson_object(obj::BSONArray) = vector(obj)

dict(bsonObject::BSONObject) = Dict(k => process_bson_object(v) for (k, v) in bsonObject)
export dict

process_bson_array(obj) = obj
process_bson_array(obj::BSONObject) = dict(obj)
process_bson_array(obj::BSONArray) = vector(obj)

vector(bsonArray::BSONArray) = [process_bson_array(a) for a in bsonArray]
export vector