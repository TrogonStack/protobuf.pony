primitive WireVarint
  fun label(): String val => "varint"
  fun value(): U8 => 0

primitive WireFixed64
  fun label(): String val => "fixed64"
  fun value(): U8 => 1

primitive WireLenDelim
  fun label(): String val => "len_delim"
  fun value(): U8 => 2

primitive WireFixed32
  fun label(): String val => "fixed32"
  fun value(): U8 => 5

// Groups (wire types 3 and 4) are proto2-only and intentionally omitted —
// proto3 forbids them and editions deprecates them.

type WireType is (WireVarint | WireFixed64 | WireLenDelim | WireFixed32)

primitive WireTypeFromValue
  fun apply(v: U8): (WireType | WireUnknown) =>
    match v
    | 0 => WireVarint
    | 1 => WireFixed64
    | 2 => WireLenDelim
    | 5 => WireFixed32
    else
      WireUnknown
    end

primitive WireUnknown
  fun label(): String val => "unknown"
