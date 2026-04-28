use "pony_test"
use "pony_check"
use "../protobuf"

// ── Spec vectors ─────────────────────────────────────────────────────────────────────────────────────────────────────

class \nodoc\ iso _TestVarintEncodeOne is UnitTest
  fun name(): String => "protobuf/varint/encode/1"
  fun apply(h: TestHelper) =>
    let bytes: Array[U8] val = recover val Varint.encode(1) end
    h.assert_eq[USize](bytes.size(), 1)
    try h.assert_eq[U8](bytes(0)?, 0x01) end

class \nodoc\ iso _TestVarintEncodeOneFifty is UnitTest
  fun name(): String => "protobuf/varint/encode/150"
  fun apply(h: TestHelper) =>
    // Canonical spec example: 150 = 0x96 (10010110), 0x01 (00000001).
    let bytes: Array[U8] val = recover val Varint.encode(150) end
    h.assert_eq[USize](bytes.size(), 2)
    try
      h.assert_eq[U8](bytes(0)?, 0x96)
      h.assert_eq[U8](bytes(1)?, 0x01)
    end

class \nodoc\ iso _TestVarintEncodeThreeHundred is UnitTest
  fun name(): String => "protobuf/varint/encode/300"
  fun apply(h: TestHelper) =>
    let bytes: Array[U8] val = recover val Varint.encode(300) end
    h.assert_eq[USize](bytes.size(), 2)
    try
      h.assert_eq[U8](bytes(0)?, 0xAC)
      h.assert_eq[U8](bytes(1)?, 0x02)
    end

class \nodoc\ iso _TestVarintEncodeMax is UnitTest
  fun name(): String => "protobuf/varint/encode/u64_max"
  fun apply(h: TestHelper) =>
    let bytes: Array[U8] val = recover val Varint.encode(U64.max_value()) end
    h.assert_eq[USize](bytes.size(), 10)
    try h.assert_eq[U8](bytes(9)?, 0x01) end

class \nodoc\ iso _TestVarintDecodeOneFifty is UnitTest
  fun name(): String => "protobuf/varint/decode/150"
  fun apply(h: TestHelper) =>
    let buf: Array[U8] val = [as U8: 0x96; 0x01]
    match Varint.decode(buf)
    | let d: VarintDecoded =>
      h.assert_eq[U64](d.value, 150)
      h.assert_eq[USize](d.bytes_read, 2)
    | let e: WireError =>
      h.fail("expected decode, got " + e.label())
    end

class \nodoc\ iso _TestVarintDecodeTruncated is UnitTest
  fun name(): String => "protobuf/varint/decode/truncated"
  fun apply(h: TestHelper) =>
    // Continuation bit set but no follow-up byte.
    let buf: Array[U8] val = [as U8: 0x80]
    match Varint.decode(buf)
    | let _: VarintDecoded => h.fail("expected truncated error")
    | WireTruncated => h.assert_true(true)
    | let e: WireError => h.fail("expected truncated, got " + e.label())
    end

class \nodoc\ iso _TestVarintDecodeOverflow is UnitTest
  fun name(): String => "protobuf/varint/decode/overflow"
  fun apply(h: TestHelper) =>
    // 10 continuation bytes + 1 — past the 10-byte U64 ceiling.
    let buf: Array[U8] val =
      [as U8: 0xFF; 0xFF; 0xFF; 0xFF; 0xFF; 0xFF; 0xFF; 0xFF; 0xFF; 0xFF]
    match Varint.decode(buf)
    | let _: VarintDecoded => h.fail("expected overflow error")
    | WireOverflow => h.assert_true(true)
    | let e: WireError => h.fail("expected overflow, got " + e.label())
    end

class \nodoc\ iso _TestVarintDecodeEmpty is UnitTest
  fun name(): String => "protobuf/varint/decode/empty"
  fun apply(h: TestHelper) =>
    let buf: Array[U8] val = recover val Array[U8] end
    match Varint.decode(buf)
    | let _: VarintDecoded => h.fail("expected truncated error")
    | WireTruncated => h.assert_true(true)
    | let e: WireError => h.fail("expected truncated, got " + e.label())
    end

// ── ZigZag spec vectors ──────────────────────────────────────────────────────────────────────────────────────────────

class \nodoc\ iso _TestZigZagEncodeKnown is UnitTest
  fun name(): String => "protobuf/zigzag/encode/known"
  fun apply(h: TestHelper) =>
    h.assert_eq[U64](ZigZag.encode_i64(0), 0)
    h.assert_eq[U64](ZigZag.encode_i64(-1), 1)
    h.assert_eq[U64](ZigZag.encode_i64(1), 2)
    h.assert_eq[U64](ZigZag.encode_i64(-2), 3)
    h.assert_eq[U64](ZigZag.encode_i64(2147483647), 4294967294)
    h.assert_eq[U64](ZigZag.encode_i64(-2147483648), 4294967295)

class \nodoc\ iso _TestZigZagDecodeKnown is UnitTest
  fun name(): String => "protobuf/zigzag/decode/known"
  fun apply(h: TestHelper) =>
    h.assert_eq[I64](ZigZag.decode_i64(0), 0)
    h.assert_eq[I64](ZigZag.decode_i64(1), -1)
    h.assert_eq[I64](ZigZag.decode_i64(2), 1)
    h.assert_eq[I64](ZigZag.decode_i64(3), -2)
    h.assert_eq[I64](ZigZag.decode_i64(4294967294), 2147483647)
    h.assert_eq[I64](ZigZag.decode_i64(4294967295), -2147483648)

// ── Tag ──────────────────────────────────────────────────────────────────────────────────────────────────────────────

class \nodoc\ iso _TestTagEncodedValue is UnitTest
  fun name(): String => "protobuf/tag/encoded_value"
  fun apply(h: TestHelper) =>
    h.assert_eq[U64](Tag(1, WireVarint).encoded_value(), 8)
    h.assert_eq[U64](Tag(2, WireLenDelim).encoded_value(), 18)
    h.assert_eq[U64](Tag(3, WireFixed32).encoded_value(), 29)

class \nodoc\ iso _TestTagDecodeRoundTrip is UnitTest
  fun name(): String => "protobuf/tag/decode/roundtrip"
  fun apply(h: TestHelper) =>
    let original = Tag(42, WireFixed64)
    let bytes: Array[U8] val = recover val original.encode() end
    match TagCodec.decode(bytes)
    | let d: TagDecoded =>
      h.assert_eq[U32](d.tag_value.field_number, 42)
      h.assert_eq[U8](d.tag_value.wire_type.value(), 1)
      h.assert_eq[USize](d.bytes_read, bytes.size())
    | let e: WireError =>
      h.fail("expected decode, got " + e.label())
    end

class \nodoc\ iso _TestTagDecodeZeroFieldRejected is UnitTest
  fun name(): String => "protobuf/tag/decode/zero_field_rejected"
  fun apply(h: TestHelper) =>
    // Field 0 is invalid; encoded value 0 means "field 0, wire type 0".
    let buf: Array[U8] val = [as U8: 0x00]
    match TagCodec.decode(buf)
    | let _: TagDecoded => h.fail("expected bad_tag error")
    | WireBadTag => h.assert_true(true)
    | let e: WireError => h.fail("expected bad_tag, got " + e.label())
    end

class \nodoc\ iso _TestTagDecodeUnknownWireType is UnitTest
  fun name(): String => "protobuf/tag/decode/unknown_wire"
  fun apply(h: TestHelper) =>
    // (field 1 << 3) | 3 = 11 — wire type 3 is the proto2 group start
    // marker we deliberately don't accept.
    let buf: Array[U8] val = [as U8: 0x0B]
    match TagCodec.decode(buf)
    | let _: TagDecoded => h.fail("expected bad_tag error")
    | WireBadTag => h.assert_true(true)
    | let e: WireError => h.fail("expected bad_tag, got " + e.label())
    end

// ── Property tests ───────────────────────────────────────────────────────────────────────────────────────────────────

class \nodoc\ iso _PropVarintRoundTrip is Property1[U64]
  fun name(): String => "prop/protobuf/varint/roundtrip"

  fun gen(): Generator[U64] =>
    Generators.u64()

  fun ref property(arg1: U64, h: PropertyHelper) =>
    let bytes: Array[U8] val = recover val Varint.encode(arg1) end
    match Varint.decode(bytes)
    | let d: VarintDecoded =>
      h.assert_eq[U64](d.value, arg1)
      h.assert_eq[USize](d.bytes_read, bytes.size())
    | let e: WireError =>
      h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _PropZigZagI64RoundTrip is Property1[I64]
  fun name(): String => "prop/protobuf/zigzag/i64_roundtrip"

  fun gen(): Generator[I64] =>
    Generators.i64()

  fun ref property(arg1: I64, h: PropertyHelper) =>
    h.assert_eq[I64](ZigZag.decode_i64(ZigZag.encode_i64(arg1)), arg1)

class \nodoc\ iso _PropZigZagI32RoundTrip is Property1[I32]
  fun name(): String => "prop/protobuf/zigzag/i32_roundtrip"

  fun gen(): Generator[I32] =>
    Generators.i32()

  fun ref property(arg1: I32, h: PropertyHelper) =>
    h.assert_eq[I32](ZigZag.decode_i32(ZigZag.encode_i32(arg1)), arg1)

class \nodoc\ iso _PropTagRoundTrip is Property1[U32]
  fun name(): String => "prop/protobuf/tag/roundtrip"

  fun gen(): Generator[U32] =>
    // Field numbers are 1..(2^29 - 1). Skip 19000..19999 (reserved range)
    // by keeping the generator below it — keeps the property simple.
    Generators.u32(1, 18999)

  fun ref property(arg1: U32, h: PropertyHelper) =>
    let original = Tag(arg1, WireLenDelim)
    let bytes: Array[U8] val = recover val original.encode() end
    match TagCodec.decode(bytes)
    | let d: TagDecoded =>
      h.assert_eq[U32](d.tag_value.field_number, arg1)
      h.assert_eq[U8](d.tag_value.wire_type.value(), WireLenDelim.value())
    | let e: WireError =>
      h.fail("decode failed: " + e.label())
    end
