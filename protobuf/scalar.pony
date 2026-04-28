primitive Scalar
  fun read_bool(r: WireReader ref): (Bool | WireError) =>
    match r.read_varint()
    | let v: U64 => v != 0
    | let e: WireError => e
    end

  fun write_bool(w: WireWriter ref, v: Bool) =>
    w.write_varint(if v then 1 else 0 end)

  fun read_int32(r: WireReader ref): (I32 | WireError) =>
    match r.read_varint()
    | let v: U64 => v.i64().i32()
    | let e: WireError => e
    end

  fun write_int32(w: WireWriter ref, v: I32) =>
    w.write_varint(v.i64().u64())

  fun read_int64(r: WireReader ref): (I64 | WireError) =>
    match r.read_varint()
    | let v: U64 => v.i64()
    | let e: WireError => e
    end

  fun write_int64(w: WireWriter ref, v: I64) =>
    w.write_varint(v.u64())

  fun read_uint32(r: WireReader ref): (U32 | WireError) =>
    match r.read_varint()
    | let v: U64 => v.u32()
    | let e: WireError => e
    end

  fun write_uint32(w: WireWriter ref, v: U32) =>
    w.write_varint(v.u64())

  fun read_uint64(r: WireReader ref): (U64 | WireError) =>
    r.read_varint()

  fun write_uint64(w: WireWriter ref, v: U64) =>
    w.write_varint(v)

  fun read_sint32(r: WireReader ref): (I32 | WireError) =>
    match r.read_varint()
    | let v: U64 => ZigZag.decode_i32(v.u32())
    | let e: WireError => e
    end

  fun write_sint32(w: WireWriter ref, v: I32) =>
    w.write_varint(ZigZag.encode_i32(v).u64())

  fun read_sint64(r: WireReader ref): (I64 | WireError) =>
    match r.read_varint()
    | let v: U64 => ZigZag.decode_i64(v)
    | let e: WireError => e
    end

  fun write_sint64(w: WireWriter ref, v: I64) =>
    w.write_varint(ZigZag.encode_i64(v))

  fun read_fixed32(r: WireReader ref): (U32 | WireError) =>
    r.read_fixed32()

  fun write_fixed32(w: WireWriter ref, v: U32) =>
    w.write_fixed32(v)

  fun read_fixed64(r: WireReader ref): (U64 | WireError) =>
    r.read_fixed64()

  fun write_fixed64(w: WireWriter ref, v: U64) =>
    w.write_fixed64(v)

  fun read_sfixed32(r: WireReader ref): (I32 | WireError) =>
    match r.read_fixed32()
    | let v: U32 => v.i32()
    | let e: WireError => e
    end

  fun write_sfixed32(w: WireWriter ref, v: I32) =>
    w.write_fixed32(v.u32())

  fun read_sfixed64(r: WireReader ref): (I64 | WireError) =>
    match r.read_fixed64()
    | let v: U64 => v.i64()
    | let e: WireError => e
    end

  fun write_sfixed64(w: WireWriter ref, v: I64) =>
    w.write_fixed64(v.u64())

  fun read_float(r: WireReader ref): (F32 | WireError) =>
    match r.read_fixed32()
    | let v: U32 => F32.from_bits(v)
    | let e: WireError => e
    end

  fun write_float(w: WireWriter ref, v: F32) =>
    w.write_fixed32(v.bits())

  fun read_double(r: WireReader ref): (F64 | WireError) =>
    match r.read_fixed64()
    | let v: U64 => F64.from_bits(v)
    | let e: WireError => e
    end

  fun write_double(w: WireWriter ref, v: F64) =>
    w.write_fixed64(v.bits())
