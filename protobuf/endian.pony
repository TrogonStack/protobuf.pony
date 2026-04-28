// Bit shifts produce little-endian bytes regardless of host memory layout,
// so no `Platform.bigendian()` branch is needed.

primitive LE
  fun push_u32_le(out: Array[U8] iso, v: U32): Array[U8] iso^ =>
    out.push((v and 0xFF).u8())
    out.push(((v >> 8) and 0xFF).u8())
    out.push(((v >> 16) and 0xFF).u8())
    out.push(((v >> 24) and 0xFF).u8())
    consume out

  fun push_u64_le(out: Array[U8] iso, v: U64): Array[U8] iso^ =>
    out.push((v and 0xFF).u8())
    out.push(((v >> 8) and 0xFF).u8())
    out.push(((v >> 16) and 0xFF).u8())
    out.push(((v >> 24) and 0xFF).u8())
    out.push(((v >> 32) and 0xFF).u8())
    out.push(((v >> 40) and 0xFF).u8())
    out.push(((v >> 48) and 0xFF).u8())
    out.push(((v >> 56) and 0xFF).u8())
    consume out

  fun u32_to_le_bytes(v: U32): Array[U8] iso^ =>
    push_u32_le(recover iso Array[U8](4) end, v)

  fun u32_from_le_bytes(buf: Array[U8] box, offset: USize):
    (U32 | WireError)
  =>
    if buf.size() < (offset + 4) then return WireTruncated end
    try
      let b0 = buf(offset)?.u32()
      let b1 = buf(offset + 1)?.u32()
      let b2 = buf(offset + 2)?.u32()
      let b3 = buf(offset + 3)?.u32()
      b0 or (b1 << 8) or (b2 << 16) or (b3 << 24)
    else
      WireTruncated
    end

  fun u64_to_le_bytes(v: U64): Array[U8] iso^ =>
    push_u64_le(recover iso Array[U8](8) end, v)

  fun u64_from_le_bytes(buf: Array[U8] box, offset: USize):
    (U64 | WireError)
  =>
    if buf.size() < (offset + 8) then return WireTruncated end
    try
      let b0 = buf(offset)?.u64()
      let b1 = buf(offset + 1)?.u64()
      let b2 = buf(offset + 2)?.u64()
      let b3 = buf(offset + 3)?.u64()
      let b4 = buf(offset + 4)?.u64()
      let b5 = buf(offset + 5)?.u64()
      let b6 = buf(offset + 6)?.u64()
      let b7 = buf(offset + 7)?.u64()
      b0 or (b1 << 8) or (b2 << 16) or (b3 << 24) or
        (b4 << 32) or (b5 << 40) or (b6 << 48) or (b7 << 56)
    else
      WireTruncated
    end
