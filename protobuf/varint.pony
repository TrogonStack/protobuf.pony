// Varint wire format: each byte carries 7 payload bits + 1 continuation bit.
// Little-endian groups, max 10 bytes for U64. See:
// https://protobuf.dev/programming-guides/encoding/#varints

class val VarintDecoded
  let value: U64
  let bytes_read: USize

  new val create(value': U64, bytes_read': USize) =>
    value = value'
    bytes_read = bytes_read'

primitive Varint
  fun encode(value: U64): Array[U8] iso^ =>
    push_into(recover iso Array[U8](10) end, value)

  fun push_into(out: Array[U8] iso, value: U64): Array[U8] iso^ =>
    var v = value
    while v >= 0x80 do
      out.push(((v and 0x7F) or 0x80).u8())
      v = v >> 7
    end
    out.push(v.u8())
    consume out

  fun decode(buf: Array[U8] box, offset: USize = 0):
    (VarintDecoded | WireError)
  =>
    var result: U64 = 0
    var shift: U64 = 0
    var i: USize = offset
    while i < buf.size() do
      let b = try buf(i)? else return WireTruncated end
      // Drop continuation bit before merging the 7 payload bits.
      result = result or ((b and 0x7F).u64() << shift)
      if (b and 0x80) == 0 then
        return VarintDecoded(result, (i - offset) + 1)
      end
      shift = shift + 7
      // 10th byte (shift == 63) may only set bit 0; anything else overflows U64.
      if shift >= 64 then
        return WireOverflow
      end
      i = i + 1
    end
    WireTruncated

primitive ZigZag
  fun encode_i64(n: I64): U64 =>
    // (n << 1) XOR (n >> 63) — arithmetic shift sign-extends to all-ones
    // for negatives, flipping the low bit pattern into the unsigned mapping.
    ((n.u64() << 1) xor (n.shr(63).u64()))

  fun decode_i64(u: U64): I64 =>
    ((u >> 1).i64()) xor -((u and 1).i64())

  fun encode_i32(n: I32): U32 =>
    ((n.u32() << 1) xor (n.shr(31).u32()))

  fun decode_i32(u: U32): I32 =>
    ((u >> 1).i32()) xor -((u and 1).i32())
