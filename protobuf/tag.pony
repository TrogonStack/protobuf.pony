// A protobuf tag packs (field_number << 3) | wire_type into a varint.
// Field numbers are 1..(2^29 - 1); 19000..19999 are reserved by the spec.

class val Tag
  let field_number: U32
  let wire_type: WireType

  new val create(field_number': U32, wire_type': WireType) =>
    field_number = field_number'
    wire_type = wire_type'

  fun encoded_value(): U64 =>
    (field_number.u64() << 3) or wire_type.value().u64()

  fun encode(): Array[U8] iso^ =>
    Varint.encode(encoded_value())

class val TagDecoded
  // Field is `tag_value` rather than `tag` — `tag` is a reserved capability
  // keyword in Pony and cannot appear as a field name in member access.
  let tag_value: Tag
  let bytes_read: USize

  new val create(tag_value': Tag, bytes_read': USize) =>
    tag_value = tag_value'
    bytes_read = bytes_read'

primitive TagCodec
  fun decode(buf: Array[U8] box, offset: USize = 0):
    (TagDecoded | WireError)
  =>
    match Varint.decode(buf, offset)
    | let v: VarintDecoded =>
      let raw = v.value
      let wire_bits = (raw and 0x7).u8()
      let field_num = (raw >> 3).u32()
      if field_num == 0 then
        return WireBadTag
      end
      match WireTypeFromValue(wire_bits)
      | let wt: WireType => TagDecoded(Tag(field_num, wt), v.bytes_read)
      | WireUnknown => WireBadTag
      end
    | let e: WireError => e
    end
