# protobuf.pony

Pure Pony protobuf runtime — wire codec, framing, scalar codecs, UTF-8
validation. The runtime that generated Pony code (emitted by
[`protoc-gen-pony`](https://github.com/TrogonStack/protoc-gen)) calls into.

## What's here

- **`Varint`** — varint encode/decode (`Array[U8] iso^` ↔ `U64`).
- **`ZigZag`** — zigzag encode/decode for signed scalars (`I32`/`I64`).
- **`Tag`** + **`TagCodec`** — protobuf field tag (field number + wire type).
- **`WireType`** — typed union (`WireVarint | WireFixed64 | WireLenDelim |
  WireFixed32`); proto2 group wire types are deliberately omitted.
- **`WireReader`** — cursor-style reader over `Array[U8] val`. Reads
  varints, tags, fixed-width fields, length-delimited bytes, UTF-8-validated
  strings; supports per-wire-type skip-unknown for forward-compat.
- **`WireWriter`** — accumulating writer, returns an `Array[U8] iso^` on
  `done()`. Includes a `write_string_field(field_num, s)` helper that
  internalizes proto3's "skip empty strings" rule.
- **`Scalar`** — paired encode/decode for all 12 protobuf scalar types
  (`bool`, `int32/64`, `uint32/64`, `sint32/64`, `fixed32/64`,
  `sfixed32/64`, `float`, `double`). Uses `F32/F64.from_bits/.bits` LLVM
  intrinsics for lossless float round-trip.
- **`LE`** — little-endian byte conversion helpers, shift-based (no
  `Platform.bigendian()` branch needed since bit shifts produce LE bytes
  on any host).
- **`WireError`** — typed-error union (`WireTruncated | WireOverflow |
  WireBadTag | WireInvalidUtf8`).

## Install

Add to your `corral.json` `deps`:

```json
{
  "locator": "github.com/TrogonStack/protobuf.pony",
  "version": "0.1.0"
}
```

Then in your Pony source:

```pony
use "protobuf"
```

## Usage

The typical caller is generated code from `protoc-gen-pony`. Sketch:

```pony
let writer = WireWriter
writer.write_tag(Tag(1, WireVarint))
Scalar.write_int32(writer, 42)
let bytes: Array[U8] val = recover val writer.done() end

let reader = WireReader(bytes)
match reader.read_tag()
| let t: Tag => /* dispatch on t.field_number, t.wire_type */
| let e: WireError => /* handle */
end
```

Hand-writing decoders is supported but the expected workflow is to define
your schemas in `.proto`, run `protoc-gen-pony`, and let the generated
`<Msg>Codec` primitives call into this runtime.

## Build + test

Requires [Task](https://taskfile.dev), [corral](https://github.com/ponylang/corral),
and `ponyc`.

```bash
corral fetch
task test
```

## License

MIT.
