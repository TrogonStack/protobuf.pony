use "pony_test"
use "pony_check"
use "../protobuf"

// ── LE byte ordering ─────────────────────────────────────────────────────────────────────────────────────────────────

class \nodoc\ iso _TestLEU32EncodeKnown is UnitTest
  fun name(): String => "protobuf/le/u32/encode_known"
  fun apply(h: TestHelper) =>
    let bytes: Array[U8] val = recover val LE.u32_to_le_bytes(0x01020304) end
    h.assert_eq[USize](bytes.size(), 4)
    try
      h.assert_eq[U8](bytes(0)?, 0x04)
      h.assert_eq[U8](bytes(1)?, 0x03)
      h.assert_eq[U8](bytes(2)?, 0x02)
      h.assert_eq[U8](bytes(3)?, 0x01)
    end

class \nodoc\ iso _TestLEU32DecodeKnown is UnitTest
  fun name(): String => "protobuf/le/u32/decode_known"
  fun apply(h: TestHelper) =>
    let buf: Array[U8] val = [as U8: 0x04; 0x03; 0x02; 0x01]
    match LE.u32_from_le_bytes(buf, 0)
    | let v: U32 => h.assert_eq[U32](v, 0x01020304)
    | let e: WireError => h.fail("expected u32, got " + e.label())
    end

class \nodoc\ iso _TestLEU32DecodeTruncated is UnitTest
  fun name(): String => "protobuf/le/u32/decode_truncated"
  fun apply(h: TestHelper) =>
    let buf: Array[U8] val = [as U8: 0x04; 0x03; 0x02]
    match LE.u32_from_le_bytes(buf, 0)
    | let _: U32 => h.fail("expected truncated error")
    | WireTruncated => h.assert_true(true)
    | let e: WireError => h.fail("expected truncated, got " + e.label())
    end

// ── Scalar spec vectors ──────────────────────────────────────────────────────────────────────────────────────────────

class \nodoc\ iso _TestFloatOneEncoded is UnitTest
  fun name(): String => "protobuf/scalar/float/1.0_encoded"
  fun apply(h: TestHelper) =>
    let w = WireWriter
    Scalar.write_float(w, 1.0)
    let bytes: Array[U8] val = recover val w.done() end
    h.assert_eq[USize](bytes.size(), 4)
    try
      h.assert_eq[U8](bytes(0)?, 0x00)
      h.assert_eq[U8](bytes(1)?, 0x00)
      h.assert_eq[U8](bytes(2)?, 0x80)
      h.assert_eq[U8](bytes(3)?, 0x3F)
    end

class \nodoc\ iso _TestDoubleOneEncoded is UnitTest
  fun name(): String => "protobuf/scalar/double/1.0_encoded"
  fun apply(h: TestHelper) =>
    let w = WireWriter
    Scalar.write_double(w, 1.0)
    let bytes: Array[U8] val = recover val w.done() end
    h.assert_eq[USize](bytes.size(), 8)
    try
      // IEEE 754 double 1.0: sign=0, exp=0x3FF (1023), mantissa=0.
      // Little-endian: 00 00 00 00 00 00 F0 3F
      h.assert_eq[U8](bytes(6)?, 0xF0)
      h.assert_eq[U8](bytes(7)?, 0x3F)
    end

class \nodoc\ iso _TestStringHelloEncoded is UnitTest
  fun name(): String => "protobuf/wire/string/hello_encoded"
  fun apply(h: TestHelper) =>
    let w = WireWriter
    w.write_string("hello")
    let bytes: Array[U8] val = recover val w.done() end
    h.assert_eq[USize](bytes.size(), 6)
    try
      h.assert_eq[U8](bytes(0)?, 0x05)
      h.assert_eq[U8](bytes(1)?, 'h')
      h.assert_eq[U8](bytes(2)?, 'e')
      h.assert_eq[U8](bytes(3)?, 'l')
      h.assert_eq[U8](bytes(4)?, 'l')
      h.assert_eq[U8](bytes(5)?, 'o')
    end

// ── Reader cursor + skip ─────────────────────────────────────────────────────────────────────────────────────────────

class \nodoc\ iso _TestReaderAtEnd is UnitTest
  fun name(): String => "protobuf/wire_reader/at_end"
  fun apply(h: TestHelper) =>
    let buf: Array[U8] val = [as U8: 0x01]
    let r = WireReader(buf)
    h.assert_false(r.at_end())
    match r.read_varint()
    | let _: U64 => h.assert_true(r.at_end())
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _TestReaderSkipVarint is UnitTest
  fun name(): String => "protobuf/wire_reader/skip/varint"
  fun apply(h: TestHelper) =>
    let buf: Array[U8] val = [as U8: 0x96; 0x01; 0x42]
    let r = WireReader(buf)
    match r.skip(WireVarint)
    | None => h.assert_eq[USize](r.position(), 2)
    | let e: WireError => h.fail("skip failed: " + e.label())
    end

class \nodoc\ iso _TestReaderSkipFixed64 is UnitTest
  fun name(): String => "protobuf/wire_reader/skip/fixed64"
  fun apply(h: TestHelper) =>
    let buf: Array[U8] val =
      [as U8: 0x01; 0x02; 0x03; 0x04; 0x05; 0x06; 0x07; 0x08; 0xFF]
    let r = WireReader(buf)
    match r.skip(WireFixed64)
    | None => h.assert_eq[USize](r.position(), 8)
    | let e: WireError => h.fail("skip failed: " + e.label())
    end

class \nodoc\ iso _TestReaderSkipFixed32 is UnitTest
  fun name(): String => "protobuf/wire_reader/skip/fixed32"
  fun apply(h: TestHelper) =>
    let buf: Array[U8] val = [as U8: 0x01; 0x02; 0x03; 0x04; 0xFF]
    let r = WireReader(buf)
    match r.skip(WireFixed32)
    | None => h.assert_eq[USize](r.position(), 4)
    | let e: WireError => h.fail("skip failed: " + e.label())
    end

class \nodoc\ iso _TestReaderSkipLenDelim is UnitTest
  fun name(): String => "protobuf/wire_reader/skip/len_delim"
  fun apply(h: TestHelper) =>
    // len=3 followed by 3 bytes + 1 trailing
    let buf: Array[U8] val = [as U8: 0x03; 0xAA; 0xBB; 0xCC; 0xFF]
    let r = WireReader(buf)
    match r.skip(WireLenDelim)
    | None => h.assert_eq[USize](r.position(), 4)
    | let e: WireError => h.fail("skip failed: " + e.label())
    end

class \nodoc\ iso _TestReaderSkipFixed64Truncated is UnitTest
  fun name(): String => "protobuf/wire_reader/skip/fixed64_truncated"
  fun apply(h: TestHelper) =>
    let buf: Array[U8] val = [as U8: 0x01; 0x02; 0x03]
    let r = WireReader(buf)
    match r.skip(WireFixed64)
    | None => h.fail("expected truncated error")
    | WireTruncated => h.assert_true(true)
    | let e: WireError => h.fail("expected truncated, got " + e.label())
    end

// ── String / UTF-8 validation ────────────────────────────────────────────────────────────────────────────────────────

class \nodoc\ iso _TestReadStringValid is UnitTest
  fun name(): String => "protobuf/wire_reader/read_string/valid_ascii"
  fun apply(h: TestHelper) =>
    let buf: Array[U8] val = [as U8: 0x05; 'h'; 'e'; 'l'; 'l'; 'o']
    let r = WireReader(buf)
    match r.read_string()
    | let s: String val => h.assert_eq[String val](s, "hello")
    | let e: WireError => h.fail("expected string, got " + e.label())
    end

class \nodoc\ iso _TestReadStringValidMultibyte is UnitTest
  fun name(): String => "protobuf/wire_reader/read_string/valid_multibyte"
  fun apply(h: TestHelper) =>
    // U+00E9 (é) = 0xC3 0xA9 in UTF-8
    let buf: Array[U8] val = [as U8: 0x02; 0xC3; 0xA9]
    let r = WireReader(buf)
    match r.read_string()
    | let s: String val => h.assert_eq[USize](s.size(), 2)
    | let e: WireError => h.fail("expected string, got " + e.label())
    end

class \nodoc\ iso _TestReadStringInvalidUtf8Lead is UnitTest
  fun name(): String => "protobuf/wire_reader/read_string/invalid_lead"
  fun apply(h: TestHelper) =>
    // Continuation byte 0x80 as a lead — not a valid UTF-8 start.
    let buf: Array[U8] val = [as U8: 0x01; 0x80]
    let r = WireReader(buf)
    match r.read_string()
    | let _: String val => h.fail("expected invalid utf-8 error")
    | WireInvalidUtf8 => h.assert_true(true)
    | let e: WireError => h.fail("expected invalid_utf8, got " + e.label())
    end

class \nodoc\ iso _TestReadStringInvalidUtf8Truncated is UnitTest
  fun name(): String => "protobuf/wire_reader/read_string/truncated_seq"
  fun apply(h: TestHelper) =>
    // 0xC3 starts a 2-byte sequence but no continuation byte follows.
    let buf: Array[U8] val = [as U8: 0x01; 0xC3]
    let r = WireReader(buf)
    match r.read_string()
    | let _: String val => h.fail("expected invalid utf-8 error")
    | WireInvalidUtf8 => h.assert_true(true)
    | let e: WireError => h.fail("expected invalid_utf8, got " + e.label())
    end

class \nodoc\ iso _TestReadStringOverlong is UnitTest
  fun name(): String => "protobuf/wire_reader/read_string/overlong"
  fun apply(h: TestHelper) =>
    // Overlong encoding of NUL (U+0000) as 2 bytes: 0xC0 0x80 — invalid.
    let buf: Array[U8] val = [as U8: 0x02; 0xC0; 0x80]
    let r = WireReader(buf)
    match r.read_string()
    | let _: String val => h.fail("expected invalid utf-8 error")
    | WireInvalidUtf8 => h.assert_true(true)
    | let e: WireError => h.fail("expected invalid_utf8, got " + e.label())
    end

class \nodoc\ iso _TestReadStringSurrogate is UnitTest
  fun name(): String => "protobuf/wire_reader/read_string/surrogate"
  fun apply(h: TestHelper) =>
    // U+D800 encoded as 0xED 0xA0 0x80 — UTF-16 surrogate, invalid in UTF-8.
    let buf: Array[U8] val = [as U8: 0x03; 0xED; 0xA0; 0x80]
    let r = WireReader(buf)
    match r.read_string()
    | let _: String val => h.fail("expected invalid utf-8 error")
    | WireInvalidUtf8 => h.assert_true(true)
    | let e: WireError => h.fail("expected invalid_utf8, got " + e.label())
    end

// ── Roundtrip property tests per scalar ──────────────────────────────────────────────────────────────────────────────

class \nodoc\ iso _PropBoolRoundTrip is Property1[Bool]
  fun name(): String => "prop/protobuf/scalar/bool"
  fun gen(): Generator[Bool] => Generators.bool()
  fun ref property(arg1: Bool, h: PropertyHelper) =>
    let w = WireWriter
    Scalar.write_bool(w, arg1)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match Scalar.read_bool(r)
    | let v: Bool => h.assert_eq[Bool](v, arg1)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _PropInt32RoundTrip is Property1[I32]
  fun name(): String => "prop/protobuf/scalar/int32"
  fun gen(): Generator[I32] => Generators.i32()
  fun ref property(arg1: I32, h: PropertyHelper) =>
    let w = WireWriter
    Scalar.write_int32(w, arg1)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match Scalar.read_int32(r)
    | let v: I32 => h.assert_eq[I32](v, arg1)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _PropInt64RoundTrip is Property1[I64]
  fun name(): String => "prop/protobuf/scalar/int64"
  fun gen(): Generator[I64] => Generators.i64()
  fun ref property(arg1: I64, h: PropertyHelper) =>
    let w = WireWriter
    Scalar.write_int64(w, arg1)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match Scalar.read_int64(r)
    | let v: I64 => h.assert_eq[I64](v, arg1)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _PropUint32RoundTrip is Property1[U32]
  fun name(): String => "prop/protobuf/scalar/uint32"
  fun gen(): Generator[U32] => Generators.u32()
  fun ref property(arg1: U32, h: PropertyHelper) =>
    let w = WireWriter
    Scalar.write_uint32(w, arg1)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match Scalar.read_uint32(r)
    | let v: U32 => h.assert_eq[U32](v, arg1)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _PropUint64RoundTrip is Property1[U64]
  fun name(): String => "prop/protobuf/scalar/uint64"
  fun gen(): Generator[U64] => Generators.u64()
  fun ref property(arg1: U64, h: PropertyHelper) =>
    let w = WireWriter
    Scalar.write_uint64(w, arg1)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match Scalar.read_uint64(r)
    | let v: U64 => h.assert_eq[U64](v, arg1)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _PropSint32RoundTrip is Property1[I32]
  fun name(): String => "prop/protobuf/scalar/sint32"
  fun gen(): Generator[I32] => Generators.i32()
  fun ref property(arg1: I32, h: PropertyHelper) =>
    let w = WireWriter
    Scalar.write_sint32(w, arg1)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match Scalar.read_sint32(r)
    | let v: I32 => h.assert_eq[I32](v, arg1)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _PropSint64RoundTrip is Property1[I64]
  fun name(): String => "prop/protobuf/scalar/sint64"
  fun gen(): Generator[I64] => Generators.i64()
  fun ref property(arg1: I64, h: PropertyHelper) =>
    let w = WireWriter
    Scalar.write_sint64(w, arg1)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match Scalar.read_sint64(r)
    | let v: I64 => h.assert_eq[I64](v, arg1)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _PropFixed32RoundTrip is Property1[U32]
  fun name(): String => "prop/protobuf/scalar/fixed32"
  fun gen(): Generator[U32] => Generators.u32()
  fun ref property(arg1: U32, h: PropertyHelper) =>
    let w = WireWriter
    Scalar.write_fixed32(w, arg1)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match Scalar.read_fixed32(r)
    | let v: U32 => h.assert_eq[U32](v, arg1)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _PropFixed64RoundTrip is Property1[U64]
  fun name(): String => "prop/protobuf/scalar/fixed64"
  fun gen(): Generator[U64] => Generators.u64()
  fun ref property(arg1: U64, h: PropertyHelper) =>
    let w = WireWriter
    Scalar.write_fixed64(w, arg1)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match Scalar.read_fixed64(r)
    | let v: U64 => h.assert_eq[U64](v, arg1)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _PropSfixed32RoundTrip is Property1[I32]
  fun name(): String => "prop/protobuf/scalar/sfixed32"
  fun gen(): Generator[I32] => Generators.i32()
  fun ref property(arg1: I32, h: PropertyHelper) =>
    let w = WireWriter
    Scalar.write_sfixed32(w, arg1)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match Scalar.read_sfixed32(r)
    | let v: I32 => h.assert_eq[I32](v, arg1)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _PropSfixed64RoundTrip is Property1[I64]
  fun name(): String => "prop/protobuf/scalar/sfixed64"
  fun gen(): Generator[I64] => Generators.i64()
  fun ref property(arg1: I64, h: PropertyHelper) =>
    let w = WireWriter
    Scalar.write_sfixed64(w, arg1)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match Scalar.read_sfixed64(r)
    | let v: I64 => h.assert_eq[I64](v, arg1)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _PropFloatRoundTrip is Property1[U32]
  fun name(): String => "prop/protobuf/scalar/float"
  fun gen(): Generator[U32] => Generators.u32()
  fun ref property(arg1: U32, h: PropertyHelper) =>
    // Use U32 as the source of bits — covers the entire F32 space (incl. NaN
    // bit-patterns) while letting us compare via .bits() instead of float ==.
    let v = F32.from_bits(arg1)
    let w = WireWriter
    Scalar.write_float(w, v)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match Scalar.read_float(r)
    | let got: F32 => h.assert_eq[U32](got.bits(), arg1)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _PropDoubleRoundTrip is Property1[U64]
  fun name(): String => "prop/protobuf/scalar/double"
  fun gen(): Generator[U64] => Generators.u64()
  fun ref property(arg1: U64, h: PropertyHelper) =>
    let v = F64.from_bits(arg1)
    let w = WireWriter
    Scalar.write_double(w, v)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match Scalar.read_double(r)
    | let got: F64 => h.assert_eq[U64](got.bits(), arg1)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

// ── Length-delimited roundtrip ───────────────────────────────────────────────────────────────────────────────────────

class \nodoc\ iso _TestLenDelimRoundTrip is UnitTest
  fun name(): String => "protobuf/wire/len_delim/roundtrip"
  fun apply(h: TestHelper) =>
    let payload: Array[U8] val = [as U8: 0xDE; 0xAD; 0xBE; 0xEF]
    let w = WireWriter
    w.write_len_delim(payload)
    let bytes: Array[U8] val = recover val w.done() end
    let r = WireReader(bytes)
    match r.read_len_delim()
    | let got: Array[U8] val =>
      h.assert_eq[USize](got.size(), 4)
      try
        h.assert_eq[U8](got(0)?, 0xDE)
        h.assert_eq[U8](got(1)?, 0xAD)
        h.assert_eq[U8](got(2)?, 0xBE)
        h.assert_eq[U8](got(3)?, 0xEF)
      end
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

class \nodoc\ iso _TestLenDelimEmpty is UnitTest
  fun name(): String => "protobuf/wire/len_delim/empty"
  fun apply(h: TestHelper) =>
    let payload: Array[U8] val = recover val Array[U8] end
    let w = WireWriter
    w.write_len_delim(payload)
    let bytes: Array[U8] val = recover val w.done() end
    h.assert_eq[USize](bytes.size(), 1)
    try h.assert_eq[U8](bytes(0)?, 0x00) end
    let r = WireReader(bytes)
    match r.read_len_delim()
    | let got: Array[U8] val => h.assert_eq[USize](got.size(), 0)
    | let e: WireError => h.fail("decode failed: " + e.label())
    end

// ── Fuzz: arbitrary bytes never panic the readers ────────────────────────────────────────────────────────────────────

// Generators yield Array[U8] ref, but WireReader takes val. ref → val isn't a
// free alias, so copy through a trn buffer that freezes to val on consume.
primitive _ToVal
  fun apply(arg: Array[U8] box): Array[U8] val =>
    let n = arg.size()
    let trn_buf = recover trn Array[U8](n) end
    var i: USize = 0
    while i < n do
      try trn_buf.push(arg(i)?) end
      i = i + 1
    end
    consume trn_buf

class \nodoc\ iso _PropFuzzReadVarint is Property1[Array[U8]]
  fun name(): String => "prop/protobuf/fuzz/read_varint"
  fun gen(): Generator[Array[U8]] =>
    Generators.array_of[U8](Generators.u8())

  fun ref property(arg1: Array[U8], h: PropertyHelper) =>
    let r = WireReader(_ToVal(arg1))
    // Either succeeds or returns an error — never traps.
    match r.read_varint()
    | let _: U64 => h.assert_true(true)
    | let _: WireError => h.assert_true(true)
    end

class \nodoc\ iso _PropFuzzReadTag is Property1[Array[U8]]
  fun name(): String => "prop/protobuf/fuzz/read_tag"
  fun gen(): Generator[Array[U8]] =>
    Generators.array_of[U8](Generators.u8())

  fun ref property(arg1: Array[U8], h: PropertyHelper) =>
    let r = WireReader(_ToVal(arg1))
    match r.read_tag()
    | let _: Tag => h.assert_true(true)
    | let _: WireError => h.assert_true(true)
    end

class \nodoc\ iso _PropFuzzReadString is Property1[Array[U8]]
  fun name(): String => "prop/protobuf/fuzz/read_string"
  fun gen(): Generator[Array[U8]] =>
    Generators.array_of[U8](Generators.u8())

  fun ref property(arg1: Array[U8], h: PropertyHelper) =>
    let r = WireReader(_ToVal(arg1))
    match r.read_string()
    | let _: String val => h.assert_true(true)
    | let _: WireError => h.assert_true(true)
    end
